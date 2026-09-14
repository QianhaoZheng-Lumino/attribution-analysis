-- C 变更明细

SELECT
    updatedate::date AS change_date,
    clientid,
    status,
    margin,
    username,
    remark
FROM configuration.wolf_rateadjust_log
WHERE level = 'C'
    AND clientid = '{client_id}'
    AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY updatedate
LIMIT 30;
