-- 邮件解析 source 客户名单（Overseas API 归因用）
-- MCP tables: ["rateaccuracy.channel_online_states_new"]
-- 用途：判断在线时长信号是否「完全可信」（见 docs/online-hours-mapping.md §4）
-- 注意：名单以表内 source='邮件解析' 为准，本 SQL 仅作快速参考；混源 client 须窗口内逐条看 source

SELECT
    client_id,
    COUNT(*) AS log_cnt,
    MAX(channel_operation_time) AS last_op_ms
FROM rateaccuracy.channel_online_states_new
WHERE source = '邮件解析'
GROUP BY client_id
ORDER BY log_cnt DESC
LIMIT 100
