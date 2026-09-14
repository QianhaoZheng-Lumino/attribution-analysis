-- 04-window-source | 分析窗内 source / remark（只展示，不参与小时计算）
-- MCP tables: ["rateaccuracy.channel_online_states_new"]
-- {client_id} 必填。本文件允许按分析窗过滤时间。
-- {start_date} 含，{end_date} 不含（与 03-window-avg 同一对日期）。

SELECT
    COALESCE(source, '') AS source,
    status::int AS status,
    COALESCE(remark, '') AS remark,
    COUNT(*) AS n
FROM rateaccuracy.channel_online_states_new
WHERE client_id = '{client_id}'
  AND (channel_operation_time AT TIME ZONE 'Asia/Shanghai') >= TIMESTAMP '{start_date} 00:00:00'
  AND (channel_operation_time AT TIME ZONE 'Asia/Shanghai') < TIMESTAMP '{end_date} 00:00:00'
GROUP BY 1, 2, 3
ORDER BY n DESC
LIMIT 30;
