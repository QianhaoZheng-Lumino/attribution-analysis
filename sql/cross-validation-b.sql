/* 交叉验证 B：在指定 Supplier 下，各 Client 的产量变化 */
/* 用途：Phase 2b — 判断 S（supplier 普遍掉） vs CS（仅 focus client 掉） */
/* 前置：Phase 2a 已识别 Top supplier（sid）及 focus client（来自 params） */
/* 验证 A 见 dimension-contribution.sql 的 2_SID 层级，无需重复跑本文件 */

WITH params AS (
    SELECT
        '2026-03-20'::date AS analysis_date,
        NULLIF('10', '')::int AS n_days,
        'EPS' AS sid,                              /* Phase 2a Top 贡献 supplier（必填） */
        'SnapTravel' AS focus_parent_client_id,    /* Phase 2a 分析的 parent client（可选，用于标注） */
        'SnapEBK' AS focus_client_id               /* Phase 2a 分析的 client（可选，用于标注） */
),
date_calculator AS (
    SELECT
        analysis_date,
        n_days,
        sid,
        focus_parent_client_id,
        focus_client_id,
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
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN 1
            WHEN legacy_current_days = 7 THEN 1
            ELSE 0
        END AS is_full_cycle_int,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN n_days
            ELSE 7
        END AS expected_days,
        LEAST(analysis_date - GREATEST(14, COALESCE(n_days, 0)), analysis_date - 7) AS min_data_date
    FROM date_calculator
    WHERE (LEAST(analysis_date + 6, CURRENT_DATE - 1) - analysis_date + 1) > 0
),
client_performance AS (
    SELECT
        a.clientid,
        a.parentclientid,
        MAX(a.clientgroup) AS client_group,
        SUM(CASE
            WHEN a.channel_createdate BETWEEN dc.analysis_date AND dc.current_end_date
            THEN 1 ELSE 0
        END) AS current_bookings,
        SUM(CASE
            WHEN a.channel_createdate BETWEEN dc.compare_start_date AND dc.compare_end_date
            THEN 1 ELSE 0
        END) AS previous_bookings
    FROM public.npd_booking_view AS a
    CROSS JOIN decision dc
    WHERE a.channel_status IN ('Confirmed', 'Canceled')
        AND a.rebook_sequence = 1
        AND a.sid = dc.sid
        AND a.channel_createdate BETWEEN dc.min_data_date AND dc.current_end_date
    GROUP BY a.clientid, a.parentclientid
),
client_metrics AS (
    SELECT
        cp.*,
        cp.current_bookings - cp.previous_bookings AS booking_change,
        CASE
            WHEN cp.previous_bookings = 0 THEN NULL
            ELSE (cp.current_bookings - cp.previous_bookings) * 100.0 / cp.previous_bookings
        END AS change_rate_percentage,
        CASE
            WHEN cp.current_bookings - cp.previous_bookings > 0 THEN '上升'
            WHEN cp.current_bookings - cp.previous_bookings < 0 THEN '下降'
            ELSE '持平'
        END AS trend_direction
    FROM client_performance cp
    WHERE cp.current_bookings > 0 OR cp.previous_bookings > 0
),
parent_client_metrics AS (
    SELECT
        parentclientid,
        SUM(current_bookings) AS current_bookings,
        SUM(previous_bookings) AS previous_bookings,
        SUM(current_bookings) - SUM(previous_bookings) AS booking_change,
        CASE
            WHEN SUM(previous_bookings) = 0 THEN NULL
            ELSE (SUM(current_bookings) - SUM(previous_bookings)) * 100.0 / SUM(previous_bookings)
        END AS change_rate_percentage,
        CASE
            WHEN SUM(current_bookings) - SUM(previous_bookings) > 0 THEN '上升'
            WHEN SUM(current_bookings) - SUM(previous_bookings) < 0 THEN '下降'
            ELSE '持平'
        END AS trend_direction
    FROM client_metrics
    GROUP BY parentclientid
),
parent_with_contribution AS (
    SELECT
        pcm.*,
        CASE
            WHEN SUM(pcm.booking_change) OVER() = 0 THEN 0
            ELSE pcm.booking_change * 100.0 / NULLIF(SUM(pcm.booking_change) OVER(), 0)
        END AS contribution_percentage
    FROM parent_client_metrics pcm
),
validation_stats AS (
    SELECT
        COUNT(*) FILTER (WHERE booking_change < 0) AS clients_dropping,
        COUNT(*) FILTER (WHERE booking_change > 0) AS clients_rising,
        COUNT(*) FILTER (WHERE booking_change = 0) AS clients_flat,
        COUNT(*) AS clients_total,
        COUNT(*) FILTER (WHERE booking_change < 0) * 100.0 / NULLIF(COUNT(*), 0) AS pct_clients_dropping,
        SUM(booking_change) FILTER (WHERE booking_change < 0) AS total_drop_volume,
        SUM(ABS(booking_change)) AS total_abs_change
    FROM parent_with_contribution
),
focus_client_stats AS (
    SELECT
        pwc.*
    FROM parent_with_contribution pwc
    CROSS JOIN params p
    WHERE (p.focus_parent_client_id IS NOT NULL AND p.focus_parent_client_id != ''
           AND pwc.parentclientid = p.focus_parent_client_id)
       OR (p.focus_client_id IS NOT NULL AND p.focus_client_id != ''
           AND pwc.parentclientid IN (
               SELECT DISTINCT parentclientid FROM client_metrics cm WHERE cm.clientid = p.focus_client_id
           ))
    LIMIT 1
),
validation_conclusion AS (
    SELECT
        vs.*,
        fcs.parentclientid AS focus_parent_client_id,
        fcs.booking_change AS focus_booking_change,
        fcs.change_rate_percentage AS focus_change_rate,
        fcs.contribution_percentage AS focus_contribution_pct,
        CASE
            WHEN vs.clients_total = 0 THEN '数据不足'
            WHEN vs.pct_clients_dropping >= 70 THEN '倾向 S（多数 client 下降）'
            WHEN vs.clients_dropping <= 2
                 AND fcs.booking_change < 0
                 AND ABS(fcs.contribution_percentage) >= 50
            THEN '倾向 CS（仅 focus client 显著下降）'
            WHEN vs.pct_clients_dropping >= 40 THEN '倾向 S（部分 client 下降，需结合验证 A）'
            WHEN fcs.booking_change < 0 AND vs.clients_dropping = 1 THEN '倾向 CS（仅 1 个 client 下降）'
            ELSE '需人工判断'
        END AS validation_b_hint
    FROM validation_stats vs
    LEFT JOIN focus_client_stats fcs ON TRUE
)
/* ========== 明细：Supplier 下各 Parent Client ========== */
SELECT
    'client_detail' AS result_type,
    dc.analysis_date,
    dc.sid AS supplier_sid,
    p.focus_parent_client_id,
    p.focus_client_id,
    CASE WHEN dc.use_new_logic = 1 THEN '新逻辑（前后n天）' ELSE '原逻辑（上周同期）' END AS logic_type,
    CONCAT(
        TO_CHAR(dc.analysis_date, 'YYYY-MM-DD'), ' 至 ', TO_CHAR(dc.current_end_date, 'YYYY-MM-DD'),
        ' (', dc.current_days, '天) vs ',
        TO_CHAR(dc.compare_start_date, 'YYYY-MM-DD'), ' 至 ', TO_CHAR(dc.compare_end_date, 'YYYY-MM-DD'),
        ' (', dc.current_days, '天)'
    ) AS comparison_range,
    pwc.parentclientid,
    NULL::varchar AS clientid,
    pwc.current_bookings,
    pwc.previous_bookings,
    pwc.booking_change,
    ROUND(pwc.contribution_percentage::numeric, 2) AS contribution_percentage,
    ROUND(pwc.change_rate_percentage::numeric, 2) AS change_rate_percentage,
    pwc.trend_direction,
    CASE
        WHEN p.focus_parent_client_id IS NOT NULL AND p.focus_parent_client_id != ''
             AND pwc.parentclientid = p.focus_parent_client_id THEN TRUE
        WHEN p.focus_client_id IS NOT NULL AND p.focus_client_id != ''
             AND pwc.parentclientid IN (
                 SELECT DISTINCT parentclientid FROM client_metrics cm WHERE cm.clientid = p.focus_client_id
             ) THEN TRUE
        ELSE FALSE
    END AS is_focus_client,
    NULL::varchar AS validation_b_hint,
    NULL::bigint AS clients_dropping,
    NULL::bigint AS clients_total,
    NULL::numeric AS pct_clients_dropping
FROM parent_with_contribution pwc
CROSS JOIN decision dc
CROSS JOIN params p

UNION ALL

/* ========== 汇总：验证 B 结论 ========== */
SELECT
    'validation_summary' AS result_type,
    dc.analysis_date,
    dc.sid AS supplier_sid,
    p.focus_parent_client_id,
    p.focus_client_id,
    CASE WHEN dc.use_new_logic = 1 THEN '新逻辑（前后n天）' ELSE '原逻辑（上周同期）' END AS logic_type,
    CONCAT(
        TO_CHAR(dc.analysis_date, 'YYYY-MM-DD'), ' 至 ', TO_CHAR(dc.current_end_date, 'YYYY-MM-DD'),
        ' (', dc.current_days, '天) vs ',
        TO_CHAR(dc.compare_start_date, 'YYYY-MM-DD'), ' 至 ', TO_CHAR(dc.compare_end_date, 'YYYY-MM-DD'),
        ' (', dc.current_days, '天)'
    ) AS comparison_range,
    vc.focus_parent_client_id AS parentclientid,
    NULL::varchar AS clientid,
    NULL::bigint AS current_bookings,
    NULL::bigint AS previous_bookings,
    vc.focus_booking_change AS booking_change,
    ROUND(vc.focus_contribution_pct::numeric, 2) AS contribution_percentage,
    ROUND(vc.focus_change_rate::numeric, 2) AS change_rate_percentage,
    NULL::varchar AS trend_direction,
    TRUE AS is_focus_client,
    vc.validation_b_hint,
    vc.clients_dropping,
    vc.clients_total,
    ROUND(vc.pct_clients_dropping::numeric, 2) AS pct_clients_dropping
FROM validation_conclusion vc
CROSS JOIN decision dc
CROSS JOIN params p

ORDER BY
    result_type DESC,
    ABS(contribution_percentage) DESC NULLS LAST
