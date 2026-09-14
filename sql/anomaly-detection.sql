-- 异动识别 SQL（来源：用户脚本，供 execute_sql 直接运行）
-- 使用前替换 params 中的参数

WITH params AS (
    SELECT
        '2026-03-16'::date AS analysis_date,
        '' AS client_id,
        'Agoda' AS parent_client_id,
        NULLIF('10', '')::int AS n_days
),
date_calculator AS (
    SELECT
        analysis_date,
        client_id,
        parent_client_id,
        n_days,
        (CURRENT_DATE - 1) AS max_date,
        LEAST(analysis_date + 6, CURRENT_DATE - 1) AS legacy_current_end,
        (LEAST(analysis_date + 6, CURRENT_DATE - 1) - analysis_date + 1) AS legacy_current_days,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
            THEN LEAST(analysis_date + n_days - 1, CURRENT_DATE - 1)
            ELSE NULL
        END AS new_current_end,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
            THEN LEAST(analysis_date + n_days - 1, CURRENT_DATE - 1) - analysis_date + 1
            ELSE NULL
        END AS new_current_days
    FROM params
),
decision AS (
    SELECT
        *,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN 1
            ELSE 0
        END AS use_new_logic,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN new_current_end
            ELSE legacy_current_end
        END AS current_end_date,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN new_current_days
            ELSE legacy_current_days
        END AS current_days,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN analysis_date - n_days
            ELSE analysis_date - 7
        END AS compare_start_date,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN analysis_date - 1
            ELSE (analysis_date - 7) + (LEAST(analysis_date + 6, CURRENT_DATE - 1) - analysis_date + 1) - 1
        END AS compare_end_date,
        LEAST(analysis_date - GREATEST(14, COALESCE(n_days, 0)), analysis_date - 7) AS min_data_date,
        CASE
            WHEN client_id IS NOT NULL AND client_id != '' THEN 'Client ID'
            WHEN parent_client_id IS NOT NULL AND parent_client_id != '' THEN 'Parent Client ID'
            ELSE 'Overseas API (大盘)'
        END AS filter_type
    FROM date_calculator
    WHERE (LEAST(analysis_date + 6, CURRENT_DATE - 1) - analysis_date + 1) > 0
),
historical_baseline AS (
    SELECT
        AVG(daily_bookings) AS avg_daily_bookings,
        STDDEV(daily_bookings) AS std_daily_bookings,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY daily_bookings) AS q1_bookings,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY daily_bookings) AS q3_bookings,
        MIN(daily_bookings) AS min_daily_bookings,
        MAX(daily_bookings) AS max_daily_bookings
    FROM (
        SELECT
            DATE(a.channel_createdate) AS booking_date,
            COUNT(*) AS daily_bookings
        FROM public.npd_booking_view a
        CROSS JOIN decision dc
        WHERE a.channel_status IN ('Confirmed', 'Canceled')
            AND a.rebook_sequence = 1
            AND (
                CASE
                    WHEN dc.client_id != '' AND dc.client_id IS NOT NULL THEN dc.client_id = a.clientid
                    WHEN dc.parent_client_id != '' AND dc.parent_client_id IS NOT NULL THEN dc.parent_client_id = a.parentclientid
                    ELSE a.clientgroup = 'Overseas API'
                END
            )
            AND a.channel_createdate >= dc.analysis_date - INTERVAL '42 days'
            AND a.channel_createdate < dc.analysis_date
        GROUP BY booking_date
    ) daily_stats
),
current_performance AS (
    SELECT
        SUM(CASE WHEN a.channel_createdate BETWEEN dc.analysis_date AND dc.current_end_date THEN 1 ELSE 0 END) AS current_total_bookings,
        SUM(CASE WHEN a.channel_createdate BETWEEN dc.analysis_date AND dc.current_end_date THEN 1 ELSE 0 END)::float / NULLIF(MAX(dc.current_days), 0) AS current_daily_avg,
        SUM(CASE WHEN a.channel_createdate BETWEEN dc.compare_start_date AND dc.compare_end_date THEN 1 ELSE 0 END) AS previous_total_bookings,
        SUM(CASE WHEN a.channel_createdate BETWEEN dc.compare_start_date AND dc.compare_end_date THEN 1 ELSE 0 END)::float / NULLIF(MAX(dc.current_days), 0) AS previous_daily_avg
    FROM public.npd_booking_view a
    CROSS JOIN decision dc
    WHERE a.channel_status IN ('Confirmed', 'Canceled')
        AND a.rebook_sequence = 1
        AND (
            CASE
                WHEN dc.client_id != '' AND dc.client_id IS NOT NULL THEN dc.client_id = a.clientid
                WHEN dc.parent_client_id != '' AND dc.parent_client_id IS NOT NULL THEN dc.parent_client_id = a.parentclientid
                ELSE a.clientgroup = 'Overseas API'
            END
        )
        AND a.channel_createdate BETWEEN dc.min_data_date AND dc.current_end_date
),
anomaly_metrics AS (
    SELECT
        cp.*,
        hb.avg_daily_bookings,
        hb.std_daily_bookings,
        hb.q1_bookings,
        hb.q3_bookings,
        CASE WHEN cp.previous_daily_avg = 0 THEN NULL
             ELSE (cp.current_daily_avg - cp.previous_daily_avg) * 100.0 / cp.previous_daily_avg
        END AS week_over_week_change,
        CASE WHEN hb.avg_daily_bookings = 0 THEN NULL
             ELSE (cp.current_daily_avg - hb.avg_daily_bookings) * 100.0 / hb.avg_daily_bookings
        END AS vs_historical_avg_change,
        CASE WHEN hb.std_daily_bookings = 0 THEN 0
             ELSE (cp.current_daily_avg - hb.avg_daily_bookings) / hb.std_daily_bookings
        END AS z_score,
        cp.current_daily_avg < hb.q1_bookings * 0.7 AS below_normal_range,
        cp.current_daily_avg > hb.q3_bookings * 1.3 AS above_normal_range
    FROM current_performance cp
    CROSS JOIN historical_baseline hb
),
anomaly_detection AS (
    SELECT
        am.*,
        (
            CASE
                WHEN ABS(am.week_over_week_change) > 50 THEN 40
                WHEN ABS(am.week_over_week_change) > 30 THEN 30
                WHEN ABS(am.week_over_week_change) > 20 THEN 20
                WHEN ABS(am.week_over_week_change) > 10 THEN 10
                ELSE 0
            END
            +
            CASE
                WHEN ABS(am.z_score) > 3 THEN 30
                WHEN ABS(am.z_score) > 2 THEN 20
                WHEN ABS(am.z_score) > 1 THEN 10
                ELSE 0
            END
            +
            CASE
                WHEN am.below_normal_range OR am.above_normal_range THEN 30
                WHEN ABS(am.vs_historical_avg_change) > 30 THEN 20
                WHEN ABS(am.vs_historical_avg_change) > 20 THEN 15
                WHEN ABS(am.vs_historical_avg_change) > 10 THEN 10
                ELSE 0
            END
        ) AS anomaly_score,
        CASE
            WHEN ABS(am.week_over_week_change) > 50 OR ABS(am.z_score) > 3 OR am.current_daily_avg < hb.q1_bookings * 0.6 THEN '严重异动'
            WHEN ABS(am.week_over_week_change) > 30 OR ABS(am.z_score) > 2 OR am.current_daily_avg < hb.q1_bookings * 0.8 OR am.current_daily_avg > hb.q3_bookings * 1.5 THEN '明显异动'
            WHEN ABS(am.week_over_week_change) > 20 OR ABS(am.z_score) > 1.5 OR am.below_normal_range OR am.above_normal_range THEN '轻微异动'
            ELSE '正常波动'
        END AS anomaly_level,
        CASE
            WHEN am.current_daily_avg < am.previous_daily_avg * 0.9 THEN '下降'
            WHEN am.current_daily_avg > am.previous_daily_avg * 1.1 THEN '上升'
            ELSE '平稳'
        END AS anomaly_direction,
        CASE
            WHEN ABS(am.week_over_week_change) > 20 OR ABS(am.z_score) > 1.5 OR am.below_normal_range THEN '需要归因分析'
            ELSE '无需深入分析'
        END AS need_attribution
    FROM anomaly_metrics am
    CROSS JOIN historical_baseline hb
)
SELECT
    '异动识别报告' AS report_type,
    p.analysis_date,
    p.client_id,
    p.parent_client_id,
    p.n_days,
    dc.filter_type,
    CASE WHEN dc.use_new_logic = 1 THEN '新逻辑（前后n天）' ELSE '原逻辑（上周同期）' END AS logic_type,
    dc.current_days AS current_period_days,
    dc.current_end_date,
    dc.compare_start_date,
    dc.compare_end_date,
    ad.current_total_bookings,
    ad.current_daily_avg,
    ad.previous_total_bookings,
    ad.previous_daily_avg,
    ROUND(ad.avg_daily_bookings::numeric, 2) AS historical_avg_daily,
    ROUND(ad.std_daily_bookings::numeric, 2) AS historical_std_daily,
    ad.q1_bookings,
    ad.q3_bookings,
    ROUND(ad.week_over_week_change::numeric, 2) AS wow_change_percent,
    ROUND(ad.vs_historical_avg_change::numeric, 2) AS vs_historical_change_percent,
    ROUND(ad.z_score::numeric, 2) AS z_score_value,
    ad.below_normal_range,
    ad.above_normal_range,
    ad.anomaly_score,
    ad.anomaly_level,
    ad.anomaly_direction,
    ad.need_attribution
FROM anomaly_detection ad
CROSS JOIN params p
CROSS JOIN decision dc
ORDER BY ad.anomaly_score DESC
