/* C 变更明细 */
/* last_status / last_margin：同一 client 更早的最近一条，不限在分析窗内 */
/* 先扫该客户全部 C 行，用 LAG 带出上一条，再裁到分析窗 */
/* 不要对窗口内每一行各查一次全表历史 */
/* 结果里没有这两列或值为空：写未验，禁止用备注反推上一条 */

WITH c_log AS (
    SELECT
        updatedate,
        clientid,
        status,
        margin,
        username,
        remark,
        LAG(status) OVER (
            PARTITION BY clientid
            ORDER BY updatedate
        ) AS last_status,
        LAG(margin) OVER (
            PARTITION BY clientid
            ORDER BY updatedate
        ) AS last_margin
    FROM configuration.wolf_rateadjust_log
    WHERE level = 'C'
        AND clientid = '{client_id}'
)
SELECT
    updatedate::date AS change_date,
    clientid,
    status,
    margin,
    last_status,
    last_margin,
    username,
    remark
FROM c_log
WHERE updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY updatedate
LIMIT 30;
