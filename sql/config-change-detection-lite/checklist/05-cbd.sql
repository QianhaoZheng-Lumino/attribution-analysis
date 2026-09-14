-- #5 CBD（预订日期窗口）

SELECT
    'CBD' AS level,
    COUNT(*) AS event_count,
    MIN(bookingstartdate::date) AS first_dt,
    MAX(bookingstartdate::date) AS last_dt
FROM configuration.wolf_rateadjust_log
WHERE level = 'CBD'
    AND clientid = '{client_id}'
    AND bookingstartdate::date BETWEEN '{w_start}'::date AND '{w_end}'::date;
