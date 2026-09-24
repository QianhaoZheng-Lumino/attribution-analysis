/* 6 SBD（全局 supplier 预订窗口） */

SELECT
    'SBD' AS level,
    COUNT(*) AS event_count,
    MIN(bookingstartdate::date) AS first_dt,
    MAX(bookingstartdate::date) AS last_dt
FROM configuration.wolf_rateadjust_log
WHERE level = 'SBD'
    AND bookingstartdate::date BETWEEN '{w_start}'::date AND '{w_end}'::date;
