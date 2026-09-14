-- CS 变更明细（event_count > 0 时跑）
-- 无 LAG；Agent 读 status/margin 变化判断开关房/调价

SELECT
    updatedate::date AS change_date,
    clientid,
    supplierid,
    status,
    margin,
    username,
    remark
FROM configuration.wolf_rateadjust_log
WHERE level = 'CS'
    AND clientid = '{client_id}'
    AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY updatedate
LIMIT 30;
