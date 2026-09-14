-- 03-didabiz-pps-chain.sql | Phase 3b lite | 占位符见 ../params-template.md
-- 完整版 ../search-attribution.sql（MCP 禁止 UNION）

WITH search AS (
    SELECT a.parent_chain_name AS index,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.total_count ELSE 0 END) AS current_total_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.total_count ELSE 0 END) AS previous_total_search,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.availiblity_count ELSE 0 END) AS current_avail_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.availiblity_count ELSE 0 END) AS previous_avail_search
    FROM data_ovs.didamonitor_funnel_client_chain a
    WHERE a.dt = CURRENT_DATE AND a.client_id = '{client_id}'
        AND a.date BETWEEN '{compare_start}'::date AND '{current_end}'::date
        AND a.parent_chain_name IS NOT NULL AND a.parent_chain_name != ''
    GROUP BY 1
),
precheck AS (
    SELECT COALESCE(a.chain, 'Independent') AS index,
        SUM(CASE WHEN a.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_period_precheck,
        SUM(CASE WHEN a.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_period_precheck
    FROM data_ovs.rate_accuracy_channel_multi_dimension a
    WHERE a.dt = CURRENT_DATE AND a.client_id = '{client_id}'
        AND a.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date AND a.chain IS NOT NULL
    GROUP BY 1
)
SELECT 'DidaBiz PPS' AS db_level, 'Chain' AS hierarchy_level, s.index,
    s.current_total_search, s.previous_total_search, s.current_avail_search, s.previous_avail_search,
    COALESCE(p.current_period_precheck, 0) AS current_period_precheck,
    COALESCE(p.previous_period_precheck, 0) AS previous_period_precheck,

    ROUND(100.0 * s.current_avail_search / NULLIF(s.current_total_search, 0), 2) AS current_avail_rate_pct,
    ROUND(100.0 * s.previous_avail_search / NULLIF(s.previous_total_search, 0), 2) AS previous_avail_rate_pct,
    ROUND(s.current_avail_search::numeric / NULLIF(p.current_period_precheck, 0), 2) AS current_check_ratio,
    ROUND(s.previous_avail_search::numeric / NULLIF(p.previous_period_precheck, 0), 2) AS previous_check_ratio
FROM search s
LEFT JOIN precheck p ON s.index = p.index

WHERE s.current_total_search > 0 OR s.previous_total_search > 0
ORDER BY (s.current_avail_search - s.previous_avail_search) ASC LIMIT 50;
