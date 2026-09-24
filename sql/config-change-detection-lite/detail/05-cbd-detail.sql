/* CBD 变更明细（event_count > 0 时必跑） */
/* 与 checklist/05-cbd.sql 同过滤：bookingstartdate 落在配置窗 */
/* 必须读 remark；status=1 仍可能是加价。Agent 用相邻行 / 历史 CBD 比 last_margin */

SELECT
    updatedate,
    bookingstartdate::date AS booking_start,
    bookingenddate::date AS booking_end,
    status,
    margin,
    countrycode,
    username,
    remark
FROM configuration.wolf_rateadjust_log
WHERE level = 'CBD'
    AND clientid = '{client_id}'
    AND bookingstartdate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY updatedate
LIMIT 30;
