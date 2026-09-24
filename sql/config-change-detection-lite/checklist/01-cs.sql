/* 1 CS | 窗口内记录数（简化：无 LAG，MCP 稳定） */
/* 占位符: {client_id} {w_start} {w_end} */
/* event_count > 0 → 跑 detail/01-cs-detail.sql */

SELECT
    'CS' AS level,
    COUNT(*) AS event_count,
    MIN(updatedate::date) AS first_dt,
    MAX(updatedate::date) AS last_dt
FROM configuration.wolf_rateadjust_log
WHERE level = 'CS'
    AND clientid = '{client_id}'
    AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date;
