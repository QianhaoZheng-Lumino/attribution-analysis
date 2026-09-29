/* CS 变更明细（event_count > 0 时跑） */
/* 同一 client + supplier，按 updatedate 取更早的最近一条，不限在分析窗内 */
/* 先扫该客户全部 CS 行，用 LAG 带出上一条，再裁到分析窗 */
/* 不要对窗口内每一行各查一次全表历史 */
/* 没有 last_status / last_margin 或值为空：写未验，禁止用备注反推 */

WITH cs_log AS (
    SELECT
        updatedate,
        clientid,
        supplierid,
        status,
        margin,
        username,
        remark,
        LAG(status) OVER (
            PARTITION BY clientid, supplierid
            ORDER BY updatedate
        ) AS last_status,
        LAG(margin) OVER (
            PARTITION BY clientid, supplierid
            ORDER BY updatedate
        ) AS last_margin
    FROM configuration.wolf_rateadjust_log
    WHERE level = 'CS'
        AND clientid = '{client_id}'
)
SELECT
    updatedate::date AS change_date,
    clientid,
    supplierid,
    status,
    margin,
    last_status,
    last_margin,
    username,
    remark
FROM cs_log
WHERE updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY updatedate
LIMIT 30;
