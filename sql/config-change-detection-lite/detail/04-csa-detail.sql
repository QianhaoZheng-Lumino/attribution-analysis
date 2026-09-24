/* 4 CSA 明细（event_count > 0 时跑） */
/* 占位符: {client_id} {w_start} {w_end} */
/* MCP tables: configuration.wolf_rateadjust_log */
/* 外层排除 JobAPI。上一条保留 JobAPI 行，与完整脚本先取上一条再排除操作人一致 */
/* 认法：先比 last_status，再比 last_margin。必须读 remark。空列写未验 */

SELECT
    t.updatedate::date AS change_date,
    t.clientid,
    t.supplierid,
    t.supplieraccountid,
    t.status,
    t.margin,
    (
        SELECT p.status
        FROM configuration.wolf_rateadjust_log p
        WHERE p.level = 'CSA'
            AND p.clientid = t.clientid
            AND p.supplierid = t.supplierid
            AND p.supplieraccountid = t.supplieraccountid
            AND p.updatedate < t.updatedate
        ORDER BY p.updatedate DESC
        LIMIT 1
    ) AS last_status,
    (
        SELECT p.margin
        FROM configuration.wolf_rateadjust_log p
        WHERE p.level = 'CSA'
            AND p.clientid = t.clientid
            AND p.supplierid = t.supplierid
            AND p.supplieraccountid = t.supplieraccountid
            AND p.updatedate < t.updatedate
        ORDER BY p.updatedate DESC
        LIMIT 1
    ) AS last_margin,
    t.username,
    t.remark
FROM configuration.wolf_rateadjust_log t
WHERE t.level = 'CSA'
    AND t.clientid = '{client_id}'
    AND t.username != 'JobAPI'
    AND t.updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY t.updatedate
LIMIT 30;
