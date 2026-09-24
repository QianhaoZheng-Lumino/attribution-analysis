/* 04-window-source | 分析窗内 source / remark（只展示，不参与小时计算） */
/* MCP tables: ["rateaccuracy.channel_online_states_new"] */
/* {client_id} 必填。本文件允许按分析窗过滤时间。 */
/* {start_date} 含，{end_date} 不含（与 03-window-avg 同一对日期）。 */
/* MCP 禁区（2026-09-21）：不要对 channel_operation_time 写 AT TIME ZONE。 */
/* 用 TIMESTAMPTZ '...+08' 与列直接比较。 */

SELECT
    COALESCE(source, '') AS source,
    status::int AS status,
    COALESCE(remark, '') AS remark,
    COUNT(*) AS n
FROM rateaccuracy.channel_online_states_new
WHERE client_id = '{client_id}'
  AND channel_operation_time >= TIMESTAMPTZ '{start_date} 00:00:00+08'
  AND channel_operation_time < TIMESTAMPTZ '{end_date} 00:00:00+08'
GROUP BY 1, 2, 3
ORDER BY n DESC
LIMIT 30;
