# D2 占位符与输出列（必读）

规则详述：[external-events-mapping.md §10](../../docs/external-events-mapping.md) · 完整 rubric 示例：**§10.7**

## 硬规则

1. **禁止手写 D2 SQL** — MCP 必须执行 `02-holiday-yoy-bks-lite.sql` 原文（仅替换占位符），与 Phase 3 checklist 同规。
2. **Rubric 只看国别列** — `country_pre_bks` / `country_during_bks` / `country_post_bks`；**禁止**用 `pre_bks`（client 全量）替代国别 pre。
3. **节窗日期只来自 seed** — `holiday-canonical-seed.csv`，禁止从 ads 表猜去年日期。
4. **触发 D2** — D1 命中 Top30 HOLIDAY **且** 该国占 \|ΔBKS\| **≥10%**（分母：C=client 总量；S/CS=锁定 SID 变化）。否则仅 D1。
5. **门槛** — `country_holiday_span_bks ≥ 20` 且 `client_window_bks ≥ 100`，否则 `gate_status` inconclusive。
6. **口径（MVP）** — `channel_createdate`；**未来**改 `checkoutdate`（§10.9 / holiday-canonical-seed.md）。

## 占位符

| 占位符 | 来源 | Agoda × MY.HARI_RAYA_PUASA 示例 |
|--------|------|----------------------------------|
| `{client_id}` | Phase 0 | `Agoda` |
| `{country_code}` | 2c 取国（C=`4_Country`；S/CS=`5_SID+Country`）+ D1 | `MY` |
| `{y1_holiday_start}` / `{y1_holiday_end}` | seed **year=分析年-1** | `2025-03-31` / `2025-03-31` |
| `{y2_holiday_start}` / `{y2_holiday_end}` | seed **year=分析年** | `2026-03-20` / `2026-03-20` |
| `{pre_days}` / `{post_days}` | 默认 7；单日节可 3 | `7` / `7` |
| `{client_window_start}` / `{client_window_end}` | Phase 1  WoW 窗（compare~current） | `2026-03-13` / `2026-03-26` |

## 输出列含义

| 列 | 口径 | Rubric 用？ |
|----|------|-------------|
| `country_pre_bks` | **该国酒店**，节前 N 天 | ✅ |
| `country_during_bks` | **该国酒店**，节窗内 | ✅ |
| `country_post_bks` | **该国酒店**，节后 N 天 | ✅ |
| `country_holiday_span_bks` | 上述 pre+during+post 合计 | 门槛 |
| `pre_bks` / `during_bks` / `post_bks` | **client 全球**，同时间段 | ❌ 仅看整体趋势 |
| `client_window_bks` | Phase 1 分析窗 client 总量 | 门槛 |
| `gate_status` | `ok` / `inconclusive_*` | 是否可评 D2 |

## D2 冒烟（2026-08-18 · `02-holiday-yoy-bks-lite.sql` 结构 · MCP ✅）

| smoke_case | cohort | country_pre | country_during | country_post | span | client_window | gate |
|------------|--------|-------------|----------------|--------------|------|---------------|------|
| **MY.HARI_RAYA_PUASA** | y1 | 242 | 23 | 154 | 419 | — | ok |
| | y2 | 211 | 25 | 148 | 384 | 5,026 | ok |
| **ID.IDUL_FITRI** | y1 | 353 | 44 | 323 | 720 | — | ok |
| | y2 | 555 | 82 | 520 | 1,157 | 5,026 | ok |
| **TH.SONGKRAN** | y1 | 403 | 190 | 504 | 1,097 | — | ok |
| | y2 | 400 | 145 | 286 | 831 | 4,830 | ok |

**读数注意：** `pre_bks`（client 全球）与国别 pre 可差 **10 倍**（如 TH y1：2653 vs 403）— 2026-08-18 已记入事故复盘。

**Rubric 结论（Agoda 3/20 案）：** 仅 **MY** 进 D2 → **弱并列**（14.6%<30%）；ID 虽同窗但不触发；TH 无 D1 命中。

## 更多 seed 行 → 占位符

| holiday_key | y1 节窗 | y2 节窗 |
|-------------|---------|---------|
| TH.SONGKRAN | 2025-04-13 ~ 04-16 | 2026-04-13 ~ 04-15 |
| ID.IDUL_FITRI | 2025-03-31 | 2026-03-20 |
| JP.GOLDEN_WEEK | 2025-04-29 ~ 05-06 | 2026-04-29 ~ 05-06 |

## 异常排查（可选）

若国别 pre/post 日均差 **>3 倍** 且不符合业务直觉，再跑 `02-holiday-yoy-bks-daily-check.sql`（按日分解，**不得**替代主查询做 rubric）。
