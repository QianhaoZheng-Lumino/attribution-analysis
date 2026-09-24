/* 3 S 明细（event_count > 0 时跑；全局 supplier，无 client） */
/* 占位符: {w_start} {w_end} */
/* MCP tables: configuration.wolf_rateadjust_log */
/* 信号默认弱/背景，除非验证 B 钉死该 SID */
/* 上一条：同一 supplier、排除 JobAPI、按 updatedate 更早的最近一条 */
/* 同一天多条都保留。按天收成一行会把当天先降后加看成没调价 */
/* 空的 last_status / last_margin 写未验，禁止用备注反推 */

SELECT
    t.updatedate::date AS change_date,
    t.supplierid,
    t.status,
    t.margin,
    (
        SELECT p.status
        FROM configuration.wolf_rateadjust_log p
        WHERE p.level = 'S'
            AND p.username != 'JobAPI'
            AND p.supplierid = t.supplierid
            AND p.updatedate < t.updatedate
        ORDER BY p.updatedate DESC
        LIMIT 1
    ) AS last_status,
    (
        SELECT p.margin
        FROM configuration.wolf_rateadjust_log p
        WHERE p.level = 'S'
            AND p.username != 'JobAPI'
            AND p.supplierid = t.supplierid
            AND p.updatedate < t.updatedate
        ORDER BY p.updatedate DESC
        LIMIT 1
    ) AS last_margin,
    t.username,
    t.remark
FROM configuration.wolf_rateadjust_log t
WHERE t.level = 'S'
    AND t.username != 'JobAPI'
    AND t.updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY t.updatedate
LIMIT 30;
