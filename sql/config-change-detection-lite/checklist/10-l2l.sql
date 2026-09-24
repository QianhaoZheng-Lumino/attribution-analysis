/* 10 L2L */

SELECT
    'L2L' AS level,
    COUNT(*) AS event_count,
    MIN(updatetime::date) AS first_dt,
    MAX(updatetime::date) AS last_dt
FROM configuration.wolfl2lclientlevelconfiglog
WHERE clientid = '{client_id}'
    AND updatetime::date BETWEEN '{w_start}'::date AND '{w_end}'::date;
