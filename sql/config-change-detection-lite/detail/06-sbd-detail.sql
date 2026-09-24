/* 6 SBD 明细（event_count > 0 时跑；全局，无 client） */
/* 占位符: {w_start} {w_end} */
/* MCP tables: configuration.wolf_rateadjust_log */

SELECT
    updatedate::date AS change_date,
    supplierid,
    bookingstartdate::date AS booking_start,
    status,
    margin,
    username,
    remark
FROM configuration.wolf_rateadjust_log
WHERE level = 'SBD'
    AND bookingstartdate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY updatedate
LIMIT 30;
