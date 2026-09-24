/* 12 C Bottom（小表，MCP 稳定） */

SELECT
    'C Bottom' AS level,
    COUNT(*) AS event_count,
    MIN(update_time::date) AS first_dt,
    MAX(update_time::date) AS last_dt
FROM configuration.bottom_margin_log
WHERE level = 'Client'
    AND item = '{client_id}'
    AND update_time::date BETWEEN '{w_start}'::date AND '{w_end}'::date;
