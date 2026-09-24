/* C 变更明细 */
/* last_status / last_margin：同一 client 更早的最近一条，不限在分析窗内 */
/* 结果里没有这两列或值为空：写未验，禁止用备注反推上一条 */

SELECT
    t.updatedate::date AS change_date,
    t.clientid,
    t.status,
    t.margin,
    (
        SELECT p.status
        FROM configuration.wolf_rateadjust_log p
        WHERE p.level = 'C'
            AND p.clientid = t.clientid
            AND p.updatedate < t.updatedate
        ORDER BY p.updatedate DESC
        LIMIT 1
    ) AS last_status,
    (
        SELECT p.margin
        FROM configuration.wolf_rateadjust_log p
        WHERE p.level = 'C'
            AND p.clientid = t.clientid
            AND p.updatedate < t.updatedate
        ORDER BY p.updatedate DESC
        LIMIT 1
    ) AS last_margin,
    t.username,
    t.remark
FROM configuration.wolf_rateadjust_log t
WHERE t.level = 'C'
    AND t.clientid = '{client_id}'
    AND t.updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY t.updatedate
LIMIT 30;
