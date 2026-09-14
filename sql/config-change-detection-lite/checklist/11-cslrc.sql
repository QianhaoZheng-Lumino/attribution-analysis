-- #11 CSLRC

SELECT
    'CSLRC' AS level,
    COUNT(*) AS event_count,
    MIN(updatetime::date) AS first_dt,
    MAX(updatetime::date) AS last_dt
FROM configuration.wolfl2lconfiglog
WHERE clientid = '{client_id}'
    AND l2llevel = 'CSLRC'
    AND updatetime::date BETWEEN '{w_start}'::date AND '{w_end}'::date;
