-- #13 S Bottom（全局 supplier 兜底）

SELECT
    'S Bottom' AS level,
    COUNT(*) AS event_count,
    MIN(update_time::date) AS first_dt,
    MAX(update_time::date) AS last_dt
FROM configuration.bottom_margin_log
WHERE level = 'Supplier'
    AND update_time::date BETWEEN '{w_start}'::date AND '{w_end}'::date;
