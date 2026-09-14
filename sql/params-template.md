# 共享参数模板（Phase 2 / Phase 3 lite 通用）

Agent 在跑 lite SQL 前，先按 Phase 1 相同规则计算日期，填入占位符。

## 占位符

| 占位符 | 说明 | Agoda 示例 |
|--------|------|------------|
| `{client_id}` | 机构 client（Phase 2/3 必填） | `Agoda` |
| `{sid_list}` | **SH：checklist/08-sh.sql 与 detail/08-sh-hotel-bks-lite.sql**。结构 SID：2b 锁定，或占本案 \|ΔBKS\|≥10%。整数逗号分隔。无结构 SID 时用 02-sid \|change\| Top3。禁止空列表、禁止用 clientid 滤 SH | `26, 95, 61` |
| `{parent_client_id}` | 父 client（仅 resolve 用） | 空或 `Agoda` |
| `{analysis_date}` | 异动锚点 | `2026-03-20` |
| `{w_start}` | 配置窗口起 = analysis_date - 1 | `2026-03-19` |
| `{w_end}` | 配置窗口止 = analysis_date + 1 | `2026-03-21` |
| `{lag_start}` | L2L detail 专用 = w_start − 30 天 | `2026-06-10`（SnapEBK w_start=07-10） |
| `{current_start}` | 当前期起 | `2026-03-20` |
| `{current_end}` | 当前期止 | `2026-03-26` |
| `{compare_start}` | 对比期起 | `2026-03-13` |
| `{compare_end}` | 对比期止 | `2026-03-19` |
| `{compare_days}` | 产量 before/after 天数 | `7` |
| `{start_date}` / `{end_date}` / `{n_days}` | 在线时长窗口（`end_date` 不含） | 默认 compare_start ~ current_end+1 |

## 日期窗口（原逻辑 n_days 空）

```
current_start  = analysis_date
current_end    = min(analysis_date + 6, 昨天)
compare_start  = analysis_date - 7
compare_end    = compare_start + (current_end - current_start)
w_start        = analysis_date - 1 day
w_end          = analysis_date + 1 day
```

## parent_client_id 解析

若用户给的是 parent 而非 client_id，**先跑**：

`config-change-detection-lite/00-resolve-clients.sql`

取返回的 client_id 列表，对每个 client 分批执行（或选产量最大的一个）。

## MCP 调用

```json
{
  "sql": "...",
  "tables": ["public.npd_booking_view"],
  "timeout_seconds": 60
}
```

**规则：一次 MCP 调用 = 一个 SELECT 文件。禁止 UNION / 多层 CTE / LAG() 批量。禁止手写替代 checklist。`03-fourteen-level-checklist.sql` 禁止 MCP。**
