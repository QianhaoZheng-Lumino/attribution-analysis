---
name: attribution-analysis
description: >-
  酒店业务产量异动识别与归因分析（Overseas API）。使用 user-data-mcp 查指标和明细表，
  识别 GP/TTV/订单量/BKS/预订量/create 口径产量等指标的异常波动。
  适用于用户提到异动归因、掉产归因、涨产归因、指标波动、GP下降、产量异常、BKS波动、
  client产量变化、环比/同比分析、完整归因、指定 client_id 与 analysis_date 深查、
  渠道在线时长、渠道下线等场景。执行顺序以 SKILL.md 正文「触发与执行模式」为准，禁止只凭本 description 连跑 Phase 1→4。
---

# 归因分析 Skill

分阶段执行。**Phase 1→4 SOP + lite SQL + 4 个 gold 已可用**。复杂 SQL 一律走 lite 分批。跑归因先看下文执行模式，不要一律 1→4。改本 Skill 才读 [docs/decisions-summary.md](docs/decisions-summary.md)。

设计详见 [cross-validation-design.md](cross-validation-design.md)。

## 触发与执行模式

**自动触发：** 对话含异动/掉产/涨产/归因/BKS/产量/GP/环比 等词，且涉及酒店 API 指标。

**意图判定（先判意图，再跑 Phase 1）：**

| 意图 | 用户怎么说 | 门禁 `need_attribution` | 默认行为 |
|------|------------|-------------------------|----------|
| **探查型** | 「有没有掉？」「看看本周」 | 任意 | **只 Phase 1** → 问是否继续。禁止自动 2–4 |
| **归因型** | 「为什么掉/涨？」「归因」「掉产原因」 | **是** | Phase 1 后 **自动 Phase 2→4**（须已有 `client_id` / parent，见下） |
| **归因型** | 同上 | **否** | **停在 Phase 1**。须用户再要「完整归因 / gold」才继续 |
| **完整型** | 「完整归因」「按 gold 回归」「Phase 1→4」 | 任意 | **Phase 1→4 全跑**；门禁否须声明「按完整归因执行」 |

**范围硬约束：** Phase 2–4（含 3a 配置、在线时长、限流）**必须有 `client_id`**（或 parent 下已锁定的 focus client）。**大盘 Phase 1 不得自动进 3a / 在线 / 限流。** 归因型门禁过但范围仍是大盘 → Phase 1 结束，列出异动，**问用户指定 client 后再 2–4**。

禁止把「确认参数后默认只跑 Phase 1」套到归因型（门禁过）或完整型。

**Gold 回归：** [gold-snaptravel2b](examples/gold-snaptravel2b-20260801.md)（涨/S）、[gold-agoda](examples/gold-agoda-20260320.md)（跌/C，门禁否）、[gold-hbgpkg-0706](examples/gold-hbgpkg-20260706.md)（边界/CS）、[gold-hbgpkg-0710](examples/gold-hbgpkg-20260710.md)（CS 崩量，门禁否）。后三份仅因完整型/gold 才跑 2–4。

## 快速开始

先确认参数（缺失则询问或用默认），再按上表执行，不要一律停在 Phase 1。

| 参数 | 说明 | 默认值 |
|------|------|--------|
| analysis_date | 分析锚点日期 | 7 天前。用户说「本周」= 本周一，「上周」= 上周一 |
| 分析范围 | client_id / parent_client_id / 大盘 | 大盘（Overseas API） |
| n_days | 对比窗口（≥7 走新逻辑） | NULL（原逻辑 7 天） |
| 指标 | 默认 create 口径预订量 | `npd_booking_view` 日预订量 |

**判定方法论见 [methodology.md](methodology.md)**（WoW + Z-score + 历史 42 天基准 + 综合评分）。

## 数据源

**必须**已配置 `user-data-mcp`（同事自备 `~/.cursor/mcp.json` + 自己的 `agent_user_key`）。工具不可用或未认证 → **停止**，禁止手写 SQL、禁止编造配置/产量结论。

配置样例（占位符，禁止把真实 key 写入本仓库）：

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
| `execute_sql` | **Phase 1–3 查明细的唯一入口。** 表名来自 lite SQL / [tables.md](tables.md)，Read 原文只填占位符 |
| `analyse_query` | 指标平台趋势（口径与 `npd_booking_view` 不同；Phase 1 默认仍走 lite SQL） |
| `search_metrics` | 按名称/编码查找指标编码 |
| `get_analyse_dimension` | Phase 2 指标平台下钻维度（BKS 下钻仍走 dimension-contribution-lite） |
| `search_meta_data` | **不是查数。** 禁止用它代替 `execute_sql`、禁止当权限探测、禁止「先搜有没有这张表」 |

常用指标见 [metrics.md](metrics.md)。表名见 [tables.md](tables.md)。

渠道每日在线时长：MCP 默认 `sql/online-hours-lite/03-window-avg.sql`（两窗日均）或 `sql/online-hours.sql`（日表）；须 `{client_id}`。禁止手算日均。仅当开窗 SQL 仍 500 才拉 log 跑 `scripts/test-online-hours.py`。禁止无 client 扫全表。

## Phase 1：异动识别

详细流程见 [phases/01-anomaly-detection.md](phases/01-anomaly-detection.md)。

### 执行清单

```
Phase 1 进度:
- [ ] 1. 解析参数，计算日期窗口（见 anomaly-detection-lite/README.md）
- [ ] 2. lite 三步 SQL：01 → 02 → 03
- [ ] 3. Agent 本地算 Q1/Q3 + 按 methodology 评分
- [ ] 4. 输出异动识别报告
- [ ] 5. 按「执行模式」表决定停或进 Phase 2（勿一律自动、勿一律只停 Phase 1）
```

Phase 1 MCP **用 lite 三步**，勿直接跑完整 `anomaly-detection.sql`。

### 异动判定规则（摘要）

完整规则见 [methodology.md](methodology.md)。核心：**三维评分，不是单一环比阈值**。

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

## 后续阶段

| 阶段 | 文件 | 状态 |
|------|------|------|
| Phase 1 异动识别 | phases/01-anomaly-detection.md + sql/anomaly-detection-lite/ | ✅ |
| Phase 2 定责下钻 | [phases/02-dimension-drilldown.md](phases/02-dimension-drilldown.md) | ✅ 2a→2b→2c（MCP lite 分批；BI 全量 1 次）。**2b 双门：** ≥10% 必跑 B；写死 C/Dida 须家数≥70% 且无单 SID≥50%（[responsibility-model.md](responsibility-model.md)） |
| Phase 3 内部证据 | phases/03-evidence-verification.md | ✅ 3a/3b/3c/3d + 限流。**3a 须填操作枚举+作用域；倾向 C 须出门禁（#26）。MCP：禁止手写 SQL、禁止 14 路 UNION** |
| Phase 4 报告收口 | [phases/04-report.md](phases/04-report.md) + [04-report-skeleton.md](phases/04-report-skeleton.md) | ✅ 标题/表头锁定（#27）；ES 后续动作见 [es-cause-catalog.md](docs/es-cause-catalog.md) |

外部事件库：Phase 3d — [docs/external-events-mapping.md](docs/external-events-mapping.md) + `sql/external-events-lite/`。

## 注意事项

1. **先查口径再下结论**：同一指标可能有 checkout/checkin/create 多个版本，务必确认统计周期。
2. **MCP 硬规则（3a）：一次调用 = 一个 lite 文件。** `execute_sql` 的 SQL **必须**来自 `Read` 对应 `checklist/` 或 `detail/` 原文，只替换占位符。**禁止**手写、凭记忆、抄别的 level 改一改。**禁止** 14 路 / 多表 UNION。违反 = 配置结论作废；500 标「未验」，不得写成 0。
2b. **`{sid_list}` 必填：** SH、SS `01-ss-supplier`、限流 `01-ss-supplier-window` 共用（2b 锁定或 \|ΔBKS\|≥10%；无则 02-sid \|change\| Top3）。禁止空 `IN ()`。禁止只靠全表 `ORDER BY`+`LIMIT 50` 写结构 SID「未覆盖涨尾 / 未返回」。
3. **权限约束**：`execute_sql` 结果受 `agent_user_key` 对应账号的行级权限影响。无 MCP / 未认证 → 停，不要用别人的 key。同事装完先按 [README.md](README.md)「权限自测」逐表 `SELECT 1 LIMIT 1`。500 ≠ 无权限；空结果可能是行级过滤；`search_meta_data` 搜不到仍可能有 `execute_sql` 权限。缺表标「未验」，不得写成 0。
4. **未支持（不要当已落地）：** #23 机构供应商白名单现为配置快照，**禁止**当 3a 变更证据；#3 DidaBase 专用表**没有**，CS 查价只用 SS 近似。
5. **Limit 数据量**：`execute_sql` 最多 1 万行，SQL 末尾加 LIMIT。
6. **时间格式**：`analyse_query` 的 begin_time/end_time 支持 ISO 格式，自动转北京时间。
7. **date_group_type**：1=小时，2=天，3=周，4=月，5=分钟，6=年。

## 示例

意图判定见 [examples.md](examples.md)。回归定责只用 `examples/gold-*.md`。ES 后续动作只按 [docs/es-cause-catalog.md](docs/es-cause-catalog.md)。

## 归因口径（Phase 3–4 必读）

- [docs/es-cause-catalog.md](docs/es-cause-catalog.md) — **#5 ES 后续动作**
- [docs/evidence-synthesis-rules.md](docs/evidence-synthesis-rules.md) — **A+B+C 综合判断**
- [docs/accuracy-issue-mapping.md](docs/accuracy-issue-mapping.md) — 准确率下钻（与配置分离）
- [docs/external-events-mapping.md](docs/external-events-mapping.md) — Phase 3d 营销日历
- [docs/mcp-permission-matrix.md](docs/mcp-permission-matrix.md) — MCP 500 ≠ 无配置；14/14 fallback
- [docs/config-search-precheck-mapping.md](docs/config-search-precheck-mapping.md) — 配置 → 查价/验价预期
- [docs/online-hours-mapping.md](docs/online-hours-mapping.md) — 在线时长触发与解读

## 改本 Skill（跑归因跳过）

- [README.md](README.md) — 同事第一天
- [docs/decisions-summary.md](docs/decisions-summary.md) — 已拍板决策
- 维护待办仅本机（`.gitignore` 分享包排除；跑归因不要 Read）
- 改完验收：`python scripts/check-first-day.py` + `python scripts/check-report-skeleton.py`

禁止把 `mcp.json`、对话导出、真实 `agent_user_key` 写入仓库。
