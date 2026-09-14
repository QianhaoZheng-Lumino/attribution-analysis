-- #3 S（全局 supplier，无 client 过滤）

SELECT
    'S' AS level,
    COUNT(*) AS event_count,
    MIN(updatedate::date) AS first_dt,
    MAX(updatedate::date) AS last_dt
FROM configuration.wolf_rateadjust_log
WHERE level = 'S'
    AND username != 'JobAPI'
    AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date;
