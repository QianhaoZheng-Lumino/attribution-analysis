/* 00a-funnel-search-total | Phase 3b fallback A — 机构查价加总（ads 500 时） */
/* 数据源: data_ovs.didamonitor_funnel_client_country 按 client 加总 */
/* 占位符: {client_id} {analysis_date} {current_end} {compare_start} {compare_end} */
/* 与 00b-funnel-precheck-total.sql 同窗；Agent 本地合并算有价率/查验比 */
/* MCP tables: data_ovs.didamonitor_funnel_client_country */

SELECT
    'DidaBiz PPS (funnel fallback)' AS db_level,
    'Total' AS hierarchy_level,
    '{client_id}' AS index,
    SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.total_count ELSE 0 END) AS current_total_search,
    SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.total_count ELSE 0 END) AS previous_total_search,
    SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.availiblity_count ELSE 0 END) AS current_avail_search,
    SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.availiblity_count ELSE 0 END) AS previous_avail_search,
    ROUND(100.0 * SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.availiblity_count ELSE 0 END)
        / NULLIF(SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.total_count ELSE 0 END), 0), 2) AS current_avail_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.availiblity_count ELSE 0 END)
        / NULLIF(SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.total_count ELSE 0 END), 0), 2) AS previous_avail_rate_pct
FROM data_ovs.didamonitor_funnel_client_country a
WHERE a.dt = CURRENT_DATE
    AND a.client_id = '{client_id}'
    AND a.date BETWEEN '{compare_start}'::date AND '{current_end}'::date;
