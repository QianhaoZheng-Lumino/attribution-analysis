-- 00b-funnel-precheck-total | Phase 3b fallback B — 机构验价量（ads 500 时）
-- 与 00a-funnel-search-total.sql 同窗；Agent 用 00a 的 avail + 本文件 precheck 算查验比
-- 占位符: {client_id} {analysis_date} {current_end} {compare_start} {compare_end}
-- MCP tables: data_ovs.rate_accuracy_channel_multi_dimension

SELECT
    '{client_id}' AS client_id,
    SUM(CASE WHEN a.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_period_precheck,
    SUM(CASE WHEN a.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_period_precheck
FROM data_ovs.rate_accuracy_channel_multi_dimension a
WHERE a.dt = CURRENT_DATE
    AND a.client_id = '{client_id}'
    AND a.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date;
