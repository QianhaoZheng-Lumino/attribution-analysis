/* 4 CSA 明细（event_count > 0 时跑） */
/* 占位符: {client_id} {w_start} {w_end} */
/* MCP tables: configuration.wolf_rateadjust_log */
/* 外层排除 JobAPI。上一条保留 JobAPI 行，与完整脚本先取上一条再排除操作人一致 */
/* 先扫该客户全部 CSA 行，用 LAG 带出上一条，再裁到分析窗并排除 JobAPI */
/* 认法：先比 last_status，再比 last_margin。必须读 remark。空列写未验 */

WITH csa_log AS (
    SELECT
        updatedate,
        clientid,
        supplierid,
        supplieraccountid,
        status,
        margin,
        username,
        remark,
        LAG(status) OVER (
            PARTITION BY clientid, supplierid, supplieraccountid
            ORDER BY updatedate
        ) AS last_status,
        LAG(margin) OVER (
            PARTITION BY clientid, supplierid, supplieraccountid
            ORDER BY updatedate
        ) AS last_margin
    FROM configuration.wolf_rateadjust_log
    WHERE level = 'CSA'
        AND clientid = '{client_id}'
)
SELECT
    updatedate::date AS change_date,
    clientid,
    supplierid,
    supplieraccountid,
    status,
    margin,
    last_status,
    last_margin,
    username,
    remark
FROM csa_log
WHERE updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
    AND username != 'JobAPI'
ORDER BY updatedate
LIMIT 30;
