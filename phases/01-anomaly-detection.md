# Phase 1：异动识别

目标：确认「有没有异动、异动有多大、方向如何、是否需要归因」，**不做维度归因**。

**判定标准见 [methodology.md](../methodology.md)**，本文档是执行 SOP。

## Step 1：解析用户意图

从用户输入提取或追问：

```
必填：
- analysis_date（分析起始日，锚点日期）
- 分析范围：client_id / parent_client_id / 大盘

选填：
- n_days（对比窗口，>=7 走新逻辑，否则走原逻辑 7 天）
- 指标（默认：create 口径预订量）
```

**默认理解：**
- 「掉产 / 预订量异常」→ 日预订量，`npd_booking_view`
- 未指定客户 → 大盘（`clientgroup = 'Overseas API'`）
- 未指定日期 → `analysis_date = 7 天前`，原逻辑 7 天窗口
- 指定了 parent_client（如 Agoda）→ 按 parent_client_id 过滤

## Step 2：确认数据口径

### 预订量异动（默认）

| 项 | 值 |
|----|-----|
| 表 | `public.npd_booking_view` |
| 过滤 | `channel_status IN ('Confirmed','Canceled')`, `rebook_sequence = 1` |
| 时间 | `channel_createdate` |
| 截止 | 不含当天，最大 = 昨天 |

## Step 3：计算时间窗口

按 [methodology.md §3](../methodology.md) 计算日期，填入 lite SQL 占位符。
计算规则详见 [sql/anomaly-detection-lite/README.md](../sql/anomaly-detection-lite/README.md)。

## Step 4：拉取数据（MCP 推荐路径）

### 路径 A：Lite 三步 SQL（MCP 首选）

**不要**在 MCP 上直接跑完整 `anomaly-detection.sql`（易 500）。

按顺序执行 [sql/anomaly-detection-lite/](../sql/anomaly-detection-lite/)：

| 步骤 | 文件 | 产出 |
|------|------|------|
| 1 | `01-period-totals.sql` | current/previous 总量与日均 |
| 2 | `02-historical-baseline.sql` | hist_avg, hist_std |
| 3 | `03-daily-series.sql` | 42 天日序列 → Agent 算 Q1/Q3 |

每步替换占位符后 `execute_sql`，`tables: ["public.npd_booking_view"]`。

### 路径 B：完整 SQL（非 MCP 或本地 DB）

运行 [sql/anomaly-detection.sql](../sql/anomaly-detection.sql)，一次出结果。

### 路径 C：analyse_query + 后处理

指标平台口径，判定标准仍用 methodology.md。

## Step 5：Agent 本地评分

用 Step 4 结果，按 [methodology.md §4–§8](../methodology.md) 计算：

```
输入（来自 lite 三步）：
  current_daily_avg, previous_daily_avg  ← Step 1
  historical_avg_daily, historical_std  ← Step 2
  Q1, Q3                               ← Step 3 日序列计算

计算：
  week_over_week_change = (current - previous) / previous × 100
  vs_historical_avg_change = (current - hist_avg) / hist_avg × 100
  z_score = (current - hist_avg) / hist_std
  below_normal_range = current < Q1 × 0.7
  above_normal_range = current > Q3 × 1.3
  anomaly_score, anomaly_level, anomaly_direction, need_attribution
```

**不要简化为「环比 > 10% 就算异动」。**

### 评分检查清单

```
- [ ] Step 1 成功：有 current_daily_avg / previous_daily_avg
- [ ] Step 2 成功：有 hist_avg / hist_std
- [ ] Step 3 成功：有日序列且算出 Q1/Q3
- [ ] 已算 WoW、Z-score、anomaly_score
- [ ] 已判定 anomaly_level 和 need_attribution
```

任一步 MCP 失败 → 缩小日期范围重试，**不要**跳过 Q1/Q3 直接判级（可标注「四分位未计算，结论置信度降低」）。

## Step 6：输出报告

使用 SKILL.md 输出模板：

```markdown
## 分析参数
- 分析锚点：{analysis_date}
- 分析范围：{filter_type} = {client / parent / 大盘}
- 窗口逻辑：{原逻辑/新逻辑}，当前期 {current_days} 天
- 当前期：{current_start} ~ {current_end}
- 对比期：{compare_start} ~ {compare_end}
- 数据路径：lite 三步 / 完整 SQL

## 核心结论
- 异动等级：**{...}**
- 异动评分：{score}/100
- 异动方向：{下降/上升/平稳}
- 是否需要归因：**{需要/无需}**
- 环比 WoW：{wow}%
- vs 历史均值：{vs_hist}%
- Z-score：{z}

## 数据明细
| 项 | 当前期 | 对比期 | 历史基准 |
|----|--------|--------|---------|
| 日均预订 | ... | ... | avg=..., Q1=..., Q3=... |
```

## Step 7：确认下一步（2026-09-04 #17）

按 [SKILL.md](../SKILL.md) **执行模式表**，不要只看门禁、也不要一律停 Phase 1。

| 意图 | 门禁 | 本步 |
|------|------|------|
| 探查型 | 任意 | 输出 Phase 1 → **问是否继续**。禁止自动 2–4 |
| 归因型 | **是** | 已有 `client_id` / focus client → **自动 Phase 2→4**。范围仍是**大盘** → 问指定 client，**不得**进 3a/在线/限流 |
| 归因型 | **否** | **结束**（或问一句要不要完整归因）。禁止因「为什么掉」就自动 2–4 |
| 完整型 / gold | 任意 | **Phase 1→4**；门禁否须写「按完整归因执行」 |

Phase 2 入口：`phases/02-dimension-drilldown.md`（MCP lite / BI 全量见该文）。

## 禁止在此阶段

- 探查型或归因型门禁否时做维度下钻、根因猜测
- 大盘范围自动跑 3a / 在线时长 / 限流（无 `client_id`）
- 跳过 lite 三步在 MCP 上硬跑完整 SQL
- 跳过评分体系
