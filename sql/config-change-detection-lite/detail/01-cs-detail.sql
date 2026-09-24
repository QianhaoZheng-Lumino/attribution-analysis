/* CS 变更明细（event_count > 0 时跑） */
/* last_status / last_margin：同一 client + supplier 更早的最近一条 */
/* 读这两列判断开关房和调价。没有这两列或值为空：写未验，禁止用备注反推 */

SELECT
    t.updatedate::date AS change_date,
    t.clientid,
    t.supplierid,
    t.status,
    t.margin,
    (
        SELECT p.status
        FROM configuration.wolf_rateadjust_log p
        WHERE p.level = 'CS'
            AND p.clientid = t.clientid
            AND p.supplierid = t.supplierid
            AND p.updatedate < t.updatedate
        ORDER BY p.updatedate DESC
        LIMIT 1
    ) AS last_status,
    (
        SELECT p.margin
        FROM configuration.wolf_rateadjust_log p
        WHERE p.level = 'CS'
            AND p.clientid = t.clientid
            AND p.supplierid = t.supplierid
            AND p.updatedate < t.updatedate
        ORDER BY p.updatedate DESC
        LIMIT 1
    ) AS last_margin,
    t.username,
    t.remark
FROM configuration.wolf_rateadjust_log t
WHERE t.level = 'CS'
    AND t.clientid = '{client_id}'
    AND t.updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY t.updatedate
LIMIT 30;
