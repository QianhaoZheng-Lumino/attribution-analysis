-- 00-client-total | Phase 3b 查价归因 lite
-- 机构 DidaBiz PPS 总量（无价率/查验比需结合 01+ 或 Agent 手算 precheck 总量）
-- 占位符: {client_id} {analysis_date} {current_end} {compare_start} {compare_end}
-- MCP tables: ads.ads_hotel_monitor_rate_search_statistic_by_client_id
-- dt 类型是 text（YYYY-MM-DD）。禁止：
--   1) 写 stat_date（无此列 → 500）
--   2) dt::date（WHERE/CASE 无法分区裁剪；SELECT 时 MCP 把 date 序列化成毫秒）
--   3) pg_typeof 与 COUNT/SUM 混用（MCP 必 500）
-- 不滤 biz_type：机构总量 = 各 biz_type 之和
-- 完整版: ../search-attribution.sql

SELECT
    'DidaBiz PPS' AS db_level,
    'Total' AS hierarchy_level,
    '{client_id}' AS index,
    SUM(CASE WHEN dt BETWEEN '{analysis_date}' AND '{current_end}' THEN client_pps ELSE 0 END) AS current_total_search,
    SUM(CASE WHEN dt BETWEEN '{compare_start}' AND '{compare_end}' THEN client_pps ELSE 0 END) AS previous_total_search,
    SUM(CASE WHEN dt BETWEEN '{analysis_date}' AND '{current_end}' THEN available_client_pps ELSE 0 END) AS current_avail_search,
    SUM(CASE WHEN dt BETWEEN '{compare_start}' AND '{compare_end}' THEN available_client_pps ELSE 0 END) AS previous_avail_search,
    ROUND(100.0 * SUM(CASE WHEN dt BETWEEN '{analysis_date}' AND '{current_end}' THEN available_client_pps ELSE 0 END)
        / NULLIF(SUM(CASE WHEN dt BETWEEN '{analysis_date}' AND '{current_end}' THEN client_pps ELSE 0 END), 0), 2) AS current_avail_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN dt BETWEEN '{compare_start}' AND '{compare_end}' THEN available_client_pps ELSE 0 END)
        / NULLIF(SUM(CASE WHEN dt BETWEEN '{compare_start}' AND '{compare_end}' THEN client_pps ELSE 0 END), 0), 2) AS previous_avail_rate_pct
FROM ads.ads_hotel_monitor_rate_search_statistic_by_client_id
WHERE client_id = '{client_id}'
    AND dt >= '{compare_start}'
    AND dt <= '{current_end}';
