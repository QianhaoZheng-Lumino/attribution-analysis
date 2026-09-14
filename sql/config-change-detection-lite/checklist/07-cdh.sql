-- #7 CDH | ⚠️ wolf_rateadjust_hotel_log 大表，MCP 可能 500；失败标「MCP 不可用→BI」

SELECT
    'CDH' AS level,
    COUNT(*) AS event_count,
    MIN(updatedate::date) AS first_dt,
    MAX(updatedate::date) AS last_dt
FROM configuration.wolf_rateadjust_hotel_log
WHERE level = 'CDH'
    AND clientid = '{client_id}'
    AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date;
