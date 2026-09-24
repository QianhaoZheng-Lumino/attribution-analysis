/* 01-fetch-logs | 单 client 原始上下线日志（分页） */
/* 占位符: {client_id} {status} {offset} */
/* MCP tables: ["rateaccuracy.channel_online_states_new"] */
/* 硬规则: 必须 client_id 等值；禁止无 WHERE / 禁止 ORDER BY channel_operation_time（易 500） */
/* 分页: LIMIT 8000 OFFSET {offset}；status 分 0 / 1 两次拉全 */
/* 不要按时间过滤：窗口前最后一次有效动作决定起点状态 */
/* Fallback：默认请跑 03-window-avg.sql。仅当开窗 SQL 仍 500 时拉全 log 再跑 scripts/test-online-hours.py */
/* remark 仅展示，不参与小时计算 */

SELECT
    id,
    client_id,
    status::int AS status,
    source,
    remark,
    channel_operation_time
FROM rateaccuracy.channel_online_states_new
WHERE client_id = '{client_id}'
  AND status = {status}
LIMIT 8000 OFFSET {offset};
