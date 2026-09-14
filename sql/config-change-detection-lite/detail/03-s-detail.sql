-- #3 S 明细（event_count > 0 时跑；全局 supplier，无 client）
-- 占位符: {w_start} {w_end}
-- MCP tables: configuration.wolf_rateadjust_log
-- 信号默认弱/背景，除非验证 B 钉死该 SID

SELECT
    updatedate::date AS change_date,
    supplierid,
    status,
    margin,
    username,
    remark
FROM configuration.wolf_rateadjust_log
WHERE level = 'S'
    AND username != 'JobAPI'
    AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY updatedate
LIMIT 30;
