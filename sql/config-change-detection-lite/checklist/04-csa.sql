-- #4 CSA

SELECT
    'CSA' AS level,
    COUNT(*) AS event_count,
    MIN(updatedate::date) AS first_dt,
    MAX(updatedate::date) AS last_dt
FROM configuration.wolf_rateadjust_log
WHERE level = 'CSA'
    AND clientid = '{client_id}'
    AND username != 'JobAPI'
    AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date;
