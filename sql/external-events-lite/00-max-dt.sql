/* 00-max-dt | 营销日历最新快照分区（Step 0 可选） */
/* 主查询仍是 01-single-country-window.sql（WHERE 内已有 MAX 子查询，不依赖本文件） */
/* 禁止：无 WHERE 的 MAX(dt) / 裸表 LIMIT → MCP 500 */
/* 禁止：SELECT MAX(dt) 不 CAST（MCP 把 date 打成毫秒） */
/* Agent：本文件 500 → 标「快照探测未验」，继续跑 01；禁止写成「无节日」 */

SELECT CAST(MAX(dt) AS VARCHAR) AS max_dt
FROM ads.ads_marketing_calendar_event_wide_d_f
WHERE dt >= CURRENT_DATE - 30;
