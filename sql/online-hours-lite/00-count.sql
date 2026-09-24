/* 00-count | 渠道在线日志条数（按 status） */
/* 占位符: {client_id} */
/* MCP tables: ["rateaccuracy.channel_online_states_new"] */
/* 仅 fallback 估算分页。默认请跑 03-window-avg.sql。status=1 上线 / 0 下线。 */

SELECT
    status::int AS status,
    COUNT(*) AS cnt
FROM rateaccuracy.channel_online_states_new
WHERE client_id = '{client_id}'
GROUP BY status
ORDER BY status;
