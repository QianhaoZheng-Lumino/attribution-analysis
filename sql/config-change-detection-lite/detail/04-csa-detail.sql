/* 4 CSA 明细（event_count > 0 时跑） */
/* 占位符: {client_id} {w_start} {w_end} */
/* MCP tables: configuration.wolf_rateadjust_log */
/* 认法同 CS：status 1→0 关房；再比 margin；必须读 remark */

SELECT
    updatedate::date AS change_date,
    clientid,
    supplierid,
    supplieraccountid,
    status,
    margin,
    username,
    remark
FROM configuration.wolf_rateadjust_log
WHERE level = 'CSA'
    AND clientid = '{client_id}'
    AND username != 'JobAPI'
    AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY updatedate
LIMIT 30;
