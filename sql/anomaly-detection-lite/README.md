# Phase 1 Lite SQL（MCP 稳定版）

完整版 `../anomaly-detection.sql` 在 MCP 上可能因 SQL 过长/过复杂返回 500。
**MCP 执行一律走本目录三步 SQL + Agent 本地评分。**

完整 SQL 仍为逻辑源真相；lite 版结果应与之一致。

## 使用顺序

```
Step 0  Agent 按 methodology.md §3 计算日期窗口 → 填入各 SQL 参数
Step 1  01-period-totals.sql      → 当前期/对比期总量
Step 2  02-historical-baseline.sql → 42天 avg/std
Step 3  03-daily-series.sql       → 42天日序列 → Agent 算 Q1/Q3
Step 4  Agent 按 methodology.md §4–§8 评分判定
```

## Step 0：日期窗口计算（Agent 在跑 SQL 前完成）

给定 `analysis_date`、`n_days`（空或 <7 则 n=7 走原逻辑）：

```
current_start  = analysis_date
current_end    = min(analysis_date + n_days - 1, 昨天)
current_days   = current_end - current_start + 1

compare_end    = analysis_date - 1
compare_start  = analysis_date - n_days   （新逻辑）
               或 analysis_date - 7 起对齐（原逻辑，见 methodology §3.1）

hist_start     = analysis_date - 42
hist_end       = analysis_date - 1        （推算值；不含 analysis_date 当天）
```

将计算结果代入下面 SQL 中的 `{current_start}` 等占位符。  
**02/03 填 `{analysis_date}` 作开区间上界，不要填 `{hist_end}`。** `{hist_end}` 只用于本地理解窗口，SQL 里没有这个占位符。

## 参数占位符

| 占位符 | 示例 |
|--------|------|
| `{current_start}` | `2026-03-20` |
| `{current_end}` | `2026-03-29` |
| `{compare_start}` | `2026-03-10` |
| `{compare_end}` | `2026-03-19` |
| `{hist_start}` | `2026-02-06` |
| `{hist_end}` | `2026-03-19` |
| `{analysis_date}` | `2026-03-20`（历史基准不含当天） |
| `{current_days}` | `10` |
| `{client_id}` | 空字符串或 `SnapEBK` |
| `{parent_client_id}` | `Agoda` 或空 |

## 客户过滤规则

SQL 内统一：

```sql
AND (
    CASE
        WHEN '{client_id}' <> '' THEN a.clientid = '{client_id}'
        WHEN '{parent_client_id}' <> '' THEN a.parentclientid = '{parent_client_id}'
        ELSE a.clientgroup = 'Overseas API'
    END
)
```

## MCP 调用

```json
{
  "sql": "...",
  "tables": ["public.npd_booking_view"],
  "timeout_seconds": 60
}
```

## 已知限制

- 不用 `PERCENTILE_CONT`（易 500）；Q1/Q3 由 Step 3 日序列在 Agent 侧计算
- 不用多层 CTE 嵌套；每文件单条 SELECT
- 若某步仍 500，缩小日期范围后重试
- MCP 可能打乱 `ORDER BY`。Q1/Q3：把 42 个 `daily_bookings` **自行按值升序**；趋势表：**自行按 booking_date 再排**。不要假设返回顺序 = SQL 顺序。

## Agent 评分

评分公式见 [methodology.md](../../methodology.md) §4–§8，在 Step 1–3 结果上本地计算，勿猜。

### Q1/Q3 计算（Step 3 日序列）

对 42 个 `daily_bookings` 升序排列：
- Q1 = 第 25% 位置（线性插值）
- Q3 = 第 75% 位置

然后：
- `below_normal_range` = current_daily_avg < Q1 × 0.7
- `above_normal_range` = current_daily_avg > Q3 × 1.3
