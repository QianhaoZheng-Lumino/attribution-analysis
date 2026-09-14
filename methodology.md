# 异动识别方法论

本文档从 `public.npd_booking_view` 异动识别 SQL 蒸馏而来，是 Phase 1 的**判定标准**。

## 1. 分析对象

| 项 | 规则 |
|----|------|
| 核心指标 | 日预订量（`COUNT(*)`，create 口径） |
| 数据源 | `public.npd_booking_view` |
| 订单过滤 | `channel_status IN ('Confirmed','Canceled')` 且 `rebook_sequence = 1` |
| 时间字段 | `channel_createdate` |
| 数据截止 | **不含当天**，最大日期 = 昨天（`CURRENT_DATE - 1`） |

## 2. 分析范围（三选一）

按优先级过滤，只生效一个：

| 优先级 | 参数 | 过滤字段 |
|--------|------|---------|
| 1 | `client_id` 非空 | `clientid = client_id` |
| 2 | `parent_client_id` 非空 | `parentclientid = parent_client_id` |
| 3 | 均为空 | `clientgroup = 'Overseas API'`（大盘默认） |

## 3. 时间窗口逻辑

锚点：`analysis_date`（分析起始日）

### 3.1 原逻辑（`n_days` 为空或 < 7）

```
当前期：analysis_date ~ min(analysis_date + 6, 昨天)
对比期：analysis_date 前 7 天，长度与当前期对齐
```

适用：默认 7 天窗口的「上周同期」对比。

### 3.2 新逻辑（`n_days >= 7` 且数据充足）

```
当前期：analysis_date ~ min(analysis_date + n_days - 1, 昨天)
对比期：(analysis_date - n_days) ~ (analysis_date - 1)
```

适用：自定义 N 天前后对比，如 14 天、30 天。

### 3.3 历史基准期

```
分析日前 42 天：analysis_date - 42 ~ analysis_date（不含 analysis_date 当天）
```

用于计算历史均值、标准差、四分位数。

## 4. 核心计算指标

所有对比均使用**日均预订量**（总量 / 当前期天数），消除窗口长度差异。

| 指标 | 公式 |
|------|------|
| `current_daily_avg` | 当前期总预订 / 当前期天数 |
| `previous_daily_avg` | 对比期总预订 / 当前期天数 |
| `week_over_week_change` | `(current - previous) / previous × 100%` |
| `vs_historical_avg_change` | `(current - hist_avg) / hist_avg × 100%` |
| `z_score` | `(current - hist_avg) / hist_std` |
| `below_normal_range` | `current < Q1 × 0.7` |
| `above_normal_range` | `current > Q3 × 1.3` |

历史基准来自 42 天日粒度序列的：avg、stddev、Q1、Q3、min、max。

## 5. 综合异动评分（0–100）

三维度加权，**取满足条件的分值相加**（非百分比折算）：

### 5.1 环比变化（权重 40 分）

| \|WoW\| | 得分 |
|---------|------|
| > 50% | 40 |
| > 30% | 30 |
| > 20% | 20 |
| > 10% | 10 |
| 否则 | 0 |

### 5.2 Z-score（权重 30 分）

| \|Z\| | 得分 |
|-------|------|
| > 3 | 30 |
| > 2 | 20 |
| > 1 | 10 |
| 否则 | 0 |

### 5.3 历史范围偏离（权重 30 分）

| 条件 | 得分 |
|------|------|
| below_normal_range 或 above_normal_range | 30 |
| \|vs_historical_avg_change\| > 30% | 20 |
| > 20% | 15 |
| > 10% | 10 |
| 否则 | 0 |

## 6. 异动等级（四档，取最严）

| 等级 | 触发条件（满足任一） |
|------|---------------------|
| **严重异动** | \|WoW\| > 50% **或** \|Z\| > 3 **或** current < Q1 × 0.6 |
| **明显异动** | \|WoW\| > 30% **或** \|Z\| > 2 **或** current < Q1 × 0.8 **或** current > Q3 × 1.5 |
| **轻微异动** | \|WoW\| > 20% **或** \|Z\| > 1.5 **或** below/above_normal_range |
| **正常波动** | 以上均不满足 |

## 7. 异动方向

| 方向 | 条件 |
|------|------|
| 下降 | `current_daily_avg < previous_daily_avg × 0.9` |
| 上升 | `current_daily_avg > previous_daily_avg × 1.1` |
| 平稳 | 其余 |

## 8. 是否进入归因（Phase 2 门禁）

满足**任一**即标记 `需要归因分析`：

- \|WoW\| > 20%
- \|Z\| > 1.5
- `below_normal_range = true`

否则 → `无需深入分析`。

## 9. 解读模板

| 等级 | 解读 |
|------|------|
| 严重异动 | 「{客户}在{日期}出现严重异常，{预订量大幅下降/异常激增}，建议立即进行归因分析」 |
| 明显异动 | 「…明显异常，{显著下降/显著增长}，建议进行归因分析」 |
| 轻微异动 | 「…轻微异常，{小幅下降/小幅增长}，建议关注后续趋势」 |
| 正常波动 | 「…表现正常，波动在合理范围内」 |

## 10. MCP 实现路径

**判定标准必须与本方法论一致。** MCP 上推荐 lite 三步，完整 SQL 作源真相。

### 路径 A：Lite 三步（MCP 首选）

见 [sql/anomaly-detection-lite/README.md](sql/anomaly-detection-lite/README.md)：

1. `01-period-totals.sql` — 当前/对比期
2. `02-historical-baseline.sql` — avg/std
3. `03-daily-series.sql` — 日序列 → Agent 算 Q1/Q3
4. Agent 本地按 §4–§8 评分

完整 `anomaly-detection.sql` 在 MCP 上可能 500（SQL 过长/含 PERCENTILE_CONT），不在 MCP 直接跑。

### 路径 B：完整 SQL（本地 DB / 非 MCP）

一次运行 [sql/anomaly-detection.sql](sql/anomaly-detection.sql)。

### 路径 C：analyse_query + 后处理

指标平台口径；有争议以 npd_booking_view 为准。

## 11. 默认参数

| 参数 | 默认值 |
|------|--------|
| analysis_date | 用户指定，或 7 天前 |
| n_days | NULL（走原逻辑 7 天） |
| client_id | 空 |
| parent_client_id | 空 → 大盘 Overseas API |
| 历史基准窗口 | 42 天 |
