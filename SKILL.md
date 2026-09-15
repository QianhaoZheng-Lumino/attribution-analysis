---
name: attribution-analysis
description: >-
  酒店业务产量异动识别与归因分析（Overseas API）。使用 user-data-mcp 查指标和明细表，
  识别 GP/TTV/订单量/BKS/预订量/create 口径产量等指标的异常波动。
  适用于用户提到异动归因、掉产归因、涨产归因、指标波动、GP下降、产量异常、BKS波动、
  client产量变化、环比/同比分析、完整归因、指定 client_id 与 analysis_date 深查、
  渠道在线时长、渠道下线，以及 attribution / yield drop / GP drop / BKS anomaly。
  执行顺序以 SKILL.md 正文「触发与执行模式」为准，禁止只凭本 description 连跑 Phase 1→4。
---

# 归因分析 Skill

先判意图，再跑 Phase。复杂 SQL 一律 lite 分批。改本 Skill 才读 [docs/decisions-summary.md](docs/decisions-summary.md)。

## 触发与执行模式

**自动触发：** 对话含异动/掉产/涨产/归因/BKS/产量/GP/环比，且涉及酒店 API 指标。

**意图判定（先判意图，再跑 Phase 1）：**

| 意图 | 用户怎么说 | 门禁 `need_attribution` | 默认行为 |
|------|------------|-------------------------|----------|
| **探查型** | 「有没有掉？」「看看本周」 | 任意 | **只 Phase 1** → 🔴 CHECKPOINT 问是否继续。禁止自动 2–4 |
| **归因型** | 「为什么掉/涨？」「归因」「掉产原因」 | **是** | Phase 1 后 **自动 Phase 2→4**（须已有 `client_id` / parent，见下） |
| **归因型** | 同上 | **否** | 🛑 STOP 停在 Phase 1。须用户再要「完整归因 / gold」才继续 |
| **完整型** | 「完整归因」「按 gold 回归」「Phase 1→4」 | 任意 | **Phase 1→4 全跑**；门禁否须声明「按完整归因执行」 |

**范围硬约束：** Phase 2–4（含 3a、在线时长、限流）**必须有 `client_id`**（或 parent 下已锁定的 focus client）。**大盘 Phase 1 不得自动进 3a / 在线 / 限流。** 归因型门禁过但范围仍是大盘 → 🔴 CHECKPOINT：列出异动，**问指定 client 后再 2–4**。

禁止把「确认参数后默认只跑 Phase 1」套到归因型（门禁过）或完整型。

**Gold 回归（定责口径，不抄旧 3a 表头）：** [gold-snaptravel2b](examples/gold-snaptravel2b-20260801.md)（涨/S）、[gold-agoda](examples/gold-agoda-20260320.md)（跌/C，门禁否）、[gold-hbgpkg-0706](examples/gold-hbgpkg-20260706.md)（边界/CS）、[gold-hbgpkg-0710](examples/gold-hbgpkg-20260710.md)（CS 崩量，门禁否）。后三份仅因完整型/gold 才跑 2–4。意图示例见 [examples.md](examples.md)。

## 不要做什么

- 无 MCP / 未认证：手写 SQL、编造产量或配置结论、借用别人的 `agent_user_key`
- 用 `search_meta_data` 查数、探权限、或「先搜有没有这张表」
- 探查型自动进 Phase 2–4；大盘/仅 parent 无 focus 时自动跑 3a / 在线时长 / 限流
- `execute_sql` 手写、凭记忆、抄别的 level 改一改；一次调用里塞 14 路 / 多表 UNION
- `{sid_list}` 留空 `IN ()`；只靠全表 `ORDER BY`+`LIMIT 50` 写结构 SID「未覆盖涨尾 / 未返回」
- MCP 500 写成 event_count=0 或「已排除」；权限未证就把 0 行当成业务 0
- 把 #23 机构供应商白名单快照当 3a 变更证据；把 LCDH 叫白名单；当已有 #3 DidaBase 专用表
- 抄 gold / case 的旧 3a 表头；ES 后续动作不按 [es-cause-catalog.md](docs/es-cause-catalog.md) 自编
- 把 `mcp.json`、对话导出、真实 key 写入仓库

## 失败模式（触发 → 一线 → 仍失败）

| 触发 | 一线修复 | 仍失败兜底 |
|------|----------|------------|
| `user-data-mcp` 不可用 / 未认证 | 🛑 STOP。禁止手写 SQL、禁止编造结论 | 告诉用户去配 MCP + 自己的 `agent_user_key`，本轮结束 |
| `execute_sql` 返回 500 / 超时 | 确认 SQL 来自 **一个** lite 原文、只换占位符；`timeout_seconds=30` 再跑同一文件一次 | 该步标「未验」。禁止写成 0、禁止改口「已排除」 |
| 查询成功但 0 行 | 记「有表权限、当前过滤下 0 行」。禁止当无权限，禁止换别的 client 凑数 | 权限自测同表 `SELECT 1` 有行 → 才可写业务 0；否则写「本账号看不到该范围」 |
| `search_meta_data` 搜不到表 | 改 `execute_sql` `SELECT 1 LIMIT 1` | 仍失败按上一行 500/0 行分支 |
| Phase 1 lite 任一步失败 | **串行**重跑该步（必须 01→02→03，禁止三步并行） | 缺哪步就缺哪项分数；禁止用单一环比凑结论 |
| 探查型却准备进 2–4 | 停。输出 Phase 1 报告 | 🔴 CHECKPOINT 问是否继续；用户未明确同意 → 结束 |
| 归因型门禁是但大盘 / 仅 parent、无 focus `client_id` | 停。列出异动 | 🔴 CHECKPOINT 问指定 `client_id`；禁止自动 3a / 在线 / 限流 |
| SH / SS / 限流 `{sid_list}` 为空 | 用 2b 锁定 SID，或 `02-sid` \|change\| Top3 | 禁止空 `IN ()`，该查询标「未验」 |
| 准备手写 SQL 或 14 路 UNION | 停。改 Read **一个** lite 原文 | 已发出的结果作废，不得写入报告 |

## 快速开始

先确认参数（缺失则询问或用默认），再按意图表执行。

| 参数 | 说明 | 默认值 |
|------|------|--------|
| analysis_date | 分析锚点日期 | 7 天前。「本周」= 本周一，「上周」= 上周一 |
| 分析范围 | client_id / parent_client_id / 大盘 | 大盘（Overseas API） |
| n_days | 对比窗口（≥7 走新逻辑） | NULL（原逻辑 7 天） |
| 指标 | 默认 create 口径预订量 | `npd_booking_view` 日预订量 |

同一指标可能有 checkout / checkin / create，先确认口径再下结论。方法论：[methodology.md](methodology.md)。

## 数据源

**必须**已配置 `user-data-mcp`（同事自备自己 runtime 的 MCP 配置 + `agent_user_key`）。工具不可用或未认证 → 🛑 STOP。

配置样例（占位符，禁止写入真实 key）：

```json
{
  "mcpServers": {
    "user-data-mcp": {
      "url": "https://<YOUR_MCP_ENDPOINT>",
      "headers": { "agent_user_key": "<YOUR_AGENT_USER_KEY>" }
    }
  }
}
```

| 工具 | 用途 |
|------|------|
| `execute_sql` | **Phase 1–3 查明细的唯一入口。** 表名来自 lite SQL / [tables.md](tables.md)，Read 原文只填占位符。末尾 LIMIT，最多 1 万行 |
| `analyse_query` | 指标平台趋势（口径与 `npd_booking_view` 不同；Phase 1 默认仍走 lite SQL）。`begin_time`/`end_time` 用 ISO，自动转北京时间。`date_group_type`：1小时 2天 3周 4月 5分钟 6年 |
| `search_metrics` | 按名称/编码查找指标编码 |
| `get_analyse_dimension` | Phase 2 指标平台下钻（BKS 下钻仍走 dimension-contribution-lite） |
| `search_meta_data` | **不是查数** |

常用指标 [metrics.md](metrics.md)。装完先按 [README.md](README.md)「权限自测」逐表 `SELECT 1 LIMIT 1`。500 ≠ 无权限。

渠道在线时长：须 `{client_id}`，默认 `sql/online-hours-lite/03-window-avg.sql`（两窗日均）或 `sql/online-hours.sql`。禁止手算日均。仅当开窗 SQL 仍 500 才跑 `scripts/test-online-hours.py`。禁止无 client 扫全表。#3 DidaBase 专用表没有，CS 查价只用 SS 近似。

## Phase 1：异动识别

**输入：** 上表四个参数。**输出：** 异动识别报告 + 是否过归因门禁。**不做维度归因。** SOP：[phases/01-anomaly-detection.md](phases/01-anomaly-detection.md)。

```
Phase 1 进度:
- [ ] 1. 解析参数，计算日期窗口（见 sql/anomaly-detection-lite/README.md）
- [ ] 2. lite 三步 SQL 串行：01 → 02 → 03（勿跑完整 anomaly-detection.sql）
- [ ] 3. Agent 本地算 Q1/Q3 + 按 methodology 评分
- [ ] 4. 输出异动识别报告
- [ ] 5. 🔴 CHECKPOINT 按「执行模式」表决定停或进 Phase 2
```

| 维度 | 权重 | 关键阈值 |
|------|------|---------|
| 环比变化 WoW | 40 分 | >10/20/30/50% 阶梯 |
| Z-score | 30 分 | >1/2/3 阶梯 |
| 历史范围偏离 | 30 分 | Q1×0.7 / Q3×1.3，或 vs 均值 >10/20/30% |

**异动等级：** 严重异动 → 明显异动 → 轻微异动 → 正常波动

**归因门禁：** \|WoW\|>20% 或 \|Z\|>1.5 或 below_normal_range → 需要归因分析

### 输出模板

```markdown
# [指标名称] 异动识别报告

## 分析参数
- 指标：{name}（{code}）
- 统计口径：{desc 摘要}
- 分析周期：{begin} ~ {end}
- 时间粒度：{天/周/月}
- 筛选条件：{filters 或「无」}

## 核心结论
- 异动等级：**{严重异动 / 明显异动 / 轻微异动 / 正常波动}**
- 异动评分：{anomaly_score}/100
- 异动方向：{下降 / 上升 / 平稳}
- 是否需要归因：**{需要归因分析 / 无需深入分析}**
- 环比 WoW：{wow_change_percent}%
- vs 历史均值：{vs_historical_change_percent}%
- Z-score：{z_score_value}

## 趋势概览
| 日期 | 指标值 | 环比 |
|------|--------|------|
| ... | ... | ... |

## 初步判断
- {基于趋势和阈值的判断，不做维度归因}

## 下一步建议
- {探查型 / 归因型门禁否：问是否继续；归因型门禁是且已有 client：直接 Phase 2；大盘：先指定 client}
```

## Phase 2–4（有 `client_id` / focus 才进）

| 阶段 | 输入 | 输出 | 文件与硬规则 |
|------|------|------|----------------|
| Phase 2 定责 | Phase 1 报告、日期窗、`client_id` | 2b 定责 C/S/CS + 2c 结构 | [02-dimension-drilldown.md](phases/02-dimension-drilldown.md) → `sql/dimension-contribution-lite/`。**2b 双门：** ≥10% 必跑 B；写死 C/Dida 须家数≥70% 且无单 SID≥50%（[responsibility-model.md](responsibility-model.md)） |
| Phase 3 证据 | 2b 倾向 + `{sid_list}` | 3a/3b/3c/3d + 限流；缺表标「未验」 | [03-evidence-verification.md](phases/03-evidence-verification.md)。**一次调用 = 一个 lite。** 3a 须填操作枚举+作用域；倾向 C 须出门禁（#26）。在线时长见 [online-hours-mapping.md](docs/online-hours-mapping.md)；3d 见 [external-events-mapping.md](docs/external-events-mapping.md) + `sql/external-events-lite/` |
| Phase 4 报告 | Phase 1–3 结论 | 成品报告 | 复制 [04-report-skeleton.md](phases/04-report-skeleton.md) 只填空；SOP [04-report.md](phases/04-report.md)。标题/表头锁定（#27）。ES 后续动作只按 [es-cause-catalog.md](docs/es-cause-catalog.md) |

SH / SS `01-ss-supplier` / 限流 `01-ss-supplier-window` **必填 `{sid_list}`**（2b 锁定或 \|ΔBKS\|≥10%；无则 `02-sid` Top3）。

## 归因口径（Phase 3–4 必读）

- [docs/es-cause-catalog.md](docs/es-cause-catalog.md) — **#5 ES 后续动作**
- [docs/evidence-synthesis-rules.md](docs/evidence-synthesis-rules.md) — **A+B+C 综合判断**
- [docs/accuracy-issue-mapping.md](docs/accuracy-issue-mapping.md) — 准确率下钻（与配置分离）
- [docs/mcp-permission-matrix.md](docs/mcp-permission-matrix.md) — MCP 500 ≠ 无配置；14/14 fallback
- [docs/config-search-precheck-mapping.md](docs/config-search-precheck-mapping.md) — 配置 → 查价/验价预期

## 改本 Skill（跑归因跳过）

- [README.md](README.md) — 同事第一天
- [cross-validation-design.md](cross-validation-design.md) — 交叉验证设计
- 维护待办仅本机（跑归因不要 Read）
- 改完验收：`python scripts/check-first-day.py` + `python scripts/check-report-skeleton.py`
