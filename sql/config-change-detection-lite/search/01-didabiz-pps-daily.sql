-- DidaBiz 查价：按日拆分（比跨日 SUM 更不易 500）
-- 占位符: {client_id} {compare_start} {current_end}
-- dt 是 text（YYYY-MM-DD）。勿写 stat_date；勿 dt::date（MCP 会把 date 打成毫秒）
-- 同一天可能多行（biz_type）；机构总量需把各 biz_type 相加

SELECT
    dt AS stat_date,
    biz_type,
    client_pps AS total_search,
    available_client_pps AS avail_search,
    ROUND(100.0 * available_client_pps / NULLIF(client_pps, 0), 2) AS avail_rate_pct
FROM ads.ads_hotel_monitor_rate_search_statistic_by_client_id
WHERE client_id = '{client_id}'
    AND dt >= '{compare_start}'
    AND dt <= '{current_end}'
ORDER BY dt, biz_type;
