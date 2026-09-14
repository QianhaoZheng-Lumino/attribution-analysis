-- 04-didabiz-qps-los.sql | Phase 3b lite | 占位符见 ../params-template.md
-- 完整版 ../search-attribution.sql（MCP 禁止 UNION）

WITH search AS (
    SELECT CASE WHEN a.los = 1 THEN '1' WHEN a.los = 2 THEN '2' WHEN a.los = 3 THEN '3'
             WHEN a.los BETWEEN 4 AND 7 THEN '4~7' WHEN a.los BETWEEN 8 AND 14 THEN '8~14'
             WHEN a.los BETWEEN 15 AND 28 THEN '15~28' WHEN a.los > 28 THEN '>28' END AS index,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.amount ELSE 0 END) AS current_total_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.amount ELSE 0 END) AS previous_total_search,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.activeamount ELSE 0 END) AS current_avail_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.activeamount ELSE 0 END) AS previous_avail_search
    FROM public.clientloscallcount a
    WHERE a.clientid = '{client_id}' AND a.date BETWEEN '{compare_start}'::date AND '{current_end}'::date
        AND a.biztype IN ('HotelRateSearch_RealTime_MultiHotel', 'HotelRateSearch_RealTime_SingleHotel', 'HotelRateSearch_Cache_MultiHotel')
    GROUP BY 1
),
precheck AS (
    SELECT a.los AS index,
        SUM(CASE WHEN a.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_period_precheck,
        SUM(CASE WHEN a.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_period_precheck
    FROM data_ovs.rate_accuracy_channel_multi_dimension a
    WHERE a.dt = CURRENT_DATE AND a.client_id = '{client_id}'
        AND a.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date AND a.los IS NOT NULL
    GROUP BY 1
)
SELECT 'DidaBiz QPS' AS db_level, 'LOS' AS hierarchy_level, s.index,
    s.current_total_search, s.previous_total_search, s.current_avail_search, s.previous_avail_search,
    COALESCE(p.current_period_precheck, 0) AS current_period_precheck,
    COALESCE(p.previous_period_precheck, 0) AS previous_period_precheck,

    ROUND(100.0 * s.current_avail_search / NULLIF(s.current_total_search, 0), 2) AS current_avail_rate_pct,
    ROUND(100.0 * s.previous_avail_search / NULLIF(s.previous_total_search, 0), 2) AS previous_avail_rate_pct,
    ROUND(s.current_avail_search::numeric / NULLIF(p.current_period_precheck, 0), 2) AS current_check_ratio,
    ROUND(s.previous_avail_search::numeric / NULLIF(p.previous_period_precheck, 0), 2) AS previous_check_ratio
FROM search s
LEFT JOIN precheck p ON s.index = p.index

WHERE s.index IS NOT NULL
ORDER BY (s.current_avail_search - s.previous_avail_search) ASC LIMIT 30;
