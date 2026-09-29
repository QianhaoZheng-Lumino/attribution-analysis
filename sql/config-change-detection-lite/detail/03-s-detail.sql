/* 3 S 明细（event_count > 0 时跑；全局 supplier，无 client） */
/* 占位符: {w_start} {w_end} */
/* MCP tables: configuration.wolf_rateadjust_log */
/* 信号默认弱/背景，除非验证 B 钉死该 SID */
/* 上一条：同一 supplier、排除 JobAPI、按 updatedate 更早的最近一条 */
/* 同一天多条都保留。按天收成一行会把当天先降后加看成没调价 */
/* 先圈出窗口内的 supplier，只扫这些 supplier 的历史，用 LAG 带上一条 */
/* 空的 last_status / last_margin 写未验，禁止用备注反推 */

WITH window_supplier AS (
    SELECT DISTINCT supplierid
    FROM configuration.wolf_rateadjust_log
    WHERE level = 'S'
        AND username != 'JobAPI'
        AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
),
s_log AS (
    SELECT
        updatedate,
        supplierid,
        status,
        margin,
        username,
        remark,
        LAG(status) OVER (
            PARTITION BY supplierid
            ORDER BY updatedate
        ) AS last_status,
        LAG(margin) OVER (
            PARTITION BY supplierid
            ORDER BY updatedate
        ) AS last_margin
    FROM configuration.wolf_rateadjust_log
    WHERE level = 'S'
        AND username != 'JobAPI'
        AND supplierid IN (SELECT supplierid FROM window_supplier)
)
SELECT
    updatedate::date AS change_date,
    supplierid,
    status,
    margin,
    last_status,
    last_margin,
    username,
    remark
FROM s_log
WHERE updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY updatedate
LIMIT 30;
