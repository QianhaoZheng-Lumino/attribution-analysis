/* 11 CSLRC 明细（event_count > 0 时跑） */
/* 占位符: {client_id} {w_start} {w_end} */
/* MCP tables: configuration.wolfl2lconfiglog */
/* 按 SID×账号聚合，不是日志行 dump。COUNT 仍是日志行数。 */
/* n_limit>0 → 操作「限售」；仅 n_open>0 → 其他（取消限售/全部可卖） */
/* LIMIT 50 限制的是 SID 数。禁止对全历史 ORDER BY updatetime DESC */

SELECT
    supplierid,
    supplieraccountid,
    SUM(CASE WHEN islimit = 1 THEN 1 ELSE 0 END) AS n_limit,
    SUM(CASE WHEN islimit = 0 THEN 1 ELSE 0 END) AS n_open,
    COUNT(*) AS n_rows,
    MAX(updatetime) AS last_updatetime
FROM configuration.wolfl2lconfiglog
WHERE clientid = '{client_id}'
    AND l2llevel = 'CSLRC'
    AND updatetime::date BETWEEN '{w_start}'::date AND '{w_end}'::date
GROUP BY supplierid, supplieraccountid
ORDER BY SUM(CASE WHEN islimit = 1 THEN 1 ELSE 0 END) DESC, COUNT(*) DESC
LIMIT 50;
