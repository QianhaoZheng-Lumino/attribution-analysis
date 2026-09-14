# MCP 权限 / 稳定性矩阵

> **状态：** 初版（2026-08-17）· 第二波 #4  
> **目标：** Agent **不再因 MCP 500 误判「无配置」**；14/14 **必须尝试测满**，500 走 fallback。  
> **重要：** 500 **≠ 无权限**（见 [decisions-summary.md](decisions-summary.md) §2）；多为 **SQL 复杂度 / 大表扫描 / 网关超时**。

---

## 1. 两层治理：矩阵 + SQL 优化

| 层级 | 解决什么 | 能否消灭 500 |
|------|----------|--------------|
| **A. 本矩阵（流程）** | 500 时怎么标、怎么 fallback、置信度上限 | ❌ 不能 |
| **B. lite SQL 优化（工程）** | 降低触发 500 的概率 | ✅ 部分（主要手段） |
| **C. 平台侧（data-api）** | 网关超时、ads 域开放、大表索引 | 需 infra 配合 |

**彻底减少 500：主要靠 B（持续优化 SQL）**；A 保证 **测满 14/14 且不错判**；C 为长期项。

### SQL 优化原则（已拍板 + 待加强）

| 规则 | 说明 |
|------|------|
| **一次 MCP = 一个 SELECT 文件** | 禁止 14 路 UNION、禁止多表 UNION 批量 |
| **禁止** | 多层 CTE 嵌套、窗口函数批量、GROUPING SETS、PERCENTILE_CONT（Phase 1 改 Agent 侧算） |
| **大表** | `wolf_rateadjust_hotel_log` 仅 **单 level + 窄日期** COUNT（SH 必填 `{sid_list}`，禁止 clientid）；hotel_bks 走 lite（CDH/LCDH/SH）；n>50000 或 500 → BI |
| **ads 域** | 机构级 PPS 常 500 → SS 层 + `didamonitor_funnel_*` 加总 fallback |
| **失败重试** | 单文件失败 → **缩日期窗重试 1 次** → 仍 500 标「MCP 未验」 |
| **计数口径** | CDH/LCDH/SH：`event_count` = **酒店行数**，不是「操作次数」；批量开房可达万级 |

---

## 2. Phase 3a：14 类配置矩阵

**Agent 必须：** `checklist/01–14` **逐个 MCP**（含 0 也要跑），输出 **14 行清单** + `checklist_progress`（如 `11/14`，未验标原因）。

| # | Level | lite 文件 | MCP 稳定性 | 典型 fallback | 报告措辞（500 时） |
|---|-------|-----------|------------|---------------|-------------------|
| 1 | CS | `checklist/01-cs.sql` | ✅ 稳定 | — | — |
| 2 | C | `checklist/02-c.sql` | ✅ 稳定 | — | — |
| 3 | S | `checklist/03-s.sql` | ✅ 稳定 | `detail/03-s-detail.sql` | 全局 LIMIT 30；默认弱/背景 |
| 4 | CSA | `checklist/04-csa.sql` | ✅ 稳定 | `detail/04-csa-detail.sql` | detail 500 → BI |
| 5 | CBD | `checklist/05-cbd.sql` | ✅ 稳定 | — | — |
| 6 | SBD | `checklist/06-sbd.sql` | ✅ 稳定 | `detail/06-sbd-detail.sql` | 全局 LIMIT 30；n=0 跳过 |
| 7 | CDH | `checklist/07-cdh.sql` | ⚠️ 条件可用 | **`detail/07-cdh-hotel-bks-lite.sql`** | event_count>0 **必跑 hotel_bks**；仍 500 → BI |
| 8 | SH | `checklist/08-sh.sql` | ⚠️ 大表；**必填 `{sid_list}`** | **`detail/08-sh-hotel-bks-lite.sql`** | 禁止 `clientid`；无 SID → 未跑；**n≥10 必跑 hotel_bks**；MCP 冒烟 ✅ 最大 6082 酒店；n>50000 或 500 → BI |
| 9 | LCDH | `checklist/09-lcdh.sql` | ⚠️ 大表 | **`detail/09-lcdh-hotel-bks-lite.sql`** | 同 CDH |
| 10 | L2L | `checklist/10-l2l.sql` | COUNT ✅ | `detail/10-l2l-detail.sql` | 明细走 `detail/10-l2l-detail.sql` |
| 11 | CSLRC | `checklist/11-cslrc.sql` | COUNT ✅ | `detail/11-cslrc-detail.sql` | 明细走 `detail/11-cslrc-detail.sql` |
| 12 | C Bottom | `checklist/12-c-bottom.sql` | ✅ 稳定 | — | 过滤字段 **`item`**（非 clientid） |
| 13 | S Bottom | `checklist/13-s-bottom.sql` | ✅ COUNT 稳定 | **`detail/13-s-bottom-detail.sql`** | 抄 C Bottom 用 `update_by` → 500；`item` = 供应商 |
| 14 | Configuration | `checklist/14-configuration.sql` | ✅ 稳定 | `detail/14-configuration-detail.sql`；`search/01-didabiz-pps-daily.sql` | 用 **`created_at`** + **14 key**；mandatory fees 是 **`DidaHotelMandatoryFeesConfig`**（`Confg` 表内 0 行） |

**禁止写法：**

- ❌ **手写 SQL 替代 checklist**（MCP 的 `sql` 必须来自 `Read checklist/NN-*.sql` 填参后的原文）
- ❌ `03-fourteen-level-checklist.sql`（14 UNION）→ **必 500**
- ❌ 6 表 UNION 一次查 L2L～Configuration → **必 500**
- ❌ 500 当 `event_count=0` → **禁止「已排除 Dida」**
- ❌ 未 Read checklist 就把 500 标「MCP 未验」（常见假 500：`bottom_margin_log.clientid`、`configuration.updatedate`）
- ❌ Configuration 写成 `DidaHotelMandatoryFeesConfg` → 该 key 表内 0 行，等于没监控 mandatory fees
- ❌ Configuration 仍用旧 6 key（缺 CachePPS / QPS / timeout）→ 会漏 AgodaEBK 类变更

**置信度门禁（与报告收口一致）：**

| checklist_progress | 配置相关最高置信度 |
|--------------------|-------------------|
| **14/14 且全 ✅** | 可「已确认 / 已排除 Dida」（需与 B 线一致） |
| **14/14 含 ⚠️ 未验** | **倾向** |
| **<14 行** | **部分未验**，禁止排除 Dida |

---

## 3. Phase 3b / 其他模块矩阵

| 模块 | lite 文件 | MCP | fallback |
|------|-----------|-----|----------|
| 3b 机构 PPS | `search-attribution-lite/00-client-total.sql` | ✅ `dt` 为 text，用字符串区间（勿 `stat_date` / `dt::date`）；Agoda/CVCTrend/Check24App/DidaOpaq ✅ | **`00a`+`00b` funnel**（仍 500 或需口径对齐时） |
| 3b SS supplier | `01-ss-supplier.sql` | ✅ 多数可用 | — |
| 3b country/chain | `02-didabiz-pps-country.sql` 等 | ⚠️ 待回归 | SS 结构 + 产量 2c |
| 限流 | `rate-limit-lite/01-ss-supplier-window.sql` | ✅ | Top SID 逐个查 |
| 在线时长 | **`03-window-avg.sql`**（默认）或 `online-hours.sql` | ✅ 等值 `client_id`；开窗 SQL 已复测 | 仍 500 → fetch + **`scripts/test-online-hours.py`**；禁止无 client 全表 |
| 外部 D | `external-events-lite/01-single-country-window.sql` | ✅ | — |
| Phase 1 | `anomaly-detection-lite/` 01–03 | ✅ | 勿跑完整 anomaly-detection.sql |
| Phase 2a | `dimension-contribution-lite/02-sid.sql` | ✅ | 完整 dimension-contribution.sql → BI |
| 2b 验证 B | `cross-validation-b.sql` | ✅ | `14-sid-client-validation.sql` |

---

## 4. 案例实测索引

### CVCTrend @ 2026-07-17（涨产 · **2026-08-18 复测修正**）

| # | Level | MCP | 备注 |
|---|-------|-----|------|
| 1–11 | CS~CSLRC | ✅ | 单文件逐个跑；CDH=92485 批量开房 |
| **CDH hotel_bks** | **detail/07-cdh-hotel-bks-lite.sql** | ✅ | **92,485 酒店 · before 0 → after 4**（弱信号） |
| **LCDH hotel_bks** | **detail/09-lcdh-hotel-bks-lite.sql** | ✅ | CVCTrend 窗 0 酒店；**NuiteeLMB 4/29：18,509 酒店 · 208→140** |
| **SH hotel_bks** | **detail/08-sh-hotel-bks-lite.sql** | ✅ | CVCTrend×26：145 酒店 · **0→0**（弱）；Check24App×591：6082 · **0→0** |
| 12 | C Bottom | ✅ **0** | 必须用 **`item='CVCTrend'`**（误用 clientid 会 500） |
| 13 | S Bottom | ✅ | 用户 BI/MCP 复测通过 |
| 14 | Configuration | ✅ | `created_at` + 14 key |
| **checklist** | **14/14 ✅** | | |
| ads 00-client-total | ✅ 字符串区间 | 查价 1081万→4290万；有价率 69.5%→80.7% | |
| **00a funnel search** | ✅ | 查价 1081万→4290万；有价率 69.5%→80.7% | |
| **00b funnel precheck** | ✅ | 113→343 | |
| 00 合并版 | ❌ 弃用 | 已拆 00a+00b | |
| SS 01-ss-supplier | ✅ | | |

**机构查验比（Agent 合并）：** 7510643/113≈66,466 → 34618761/343≈100,928

### 其他 gold 参考

| 案例 | 14/14 | 典型 MCP 缺口 |
|------|-------|---------------|
| gold-agoda-20260320 | ✅ | ads 机构 500 |
| gold-snaptravel2b-20260801 | ✅ | ads 500 → funnel fallback |
| gold-hbgpkg-20260706 | ✅ | precheck 聚合 500 |

---

## 5. Agent 执行 SOP（500 时）

```
1. 单 level checklist 失败
   → 同 SQL 缩 w_start/w_end 为 analysis_date 单日，重试 1 次
   → 仍 500：清单该行写「MCP 500 · 未验」，checklist_progress 不含 ✅

2. 禁止改用 UNION 批量「省事」

3. event_count > 0 但 detail 500
   → 报告写「有条目 · 明细未拉取 · BI 补查」

4. CDH/LCDH event_count > 0；SH event_count ≥ 10
   → 必跑 detail/07 / 09 / 08-sh-hotel-bks-lite.sql
   → after_hotel_bks ≈ 0 且 BKS 大涨/大跌：信号弱，禁止写「CDH/LCDH/SH 定责」
   → 仍 500 或 SH n>50000：BI / Hologres

5. 合成前自检
   → 14 行是否齐全？
   → 是否有 500 被误标为 0？
   → 3b 机构级是否 fallback？
```

---

## 6. 待办 SQL 优化（降低 500 率）

| 优先级 | 项 | 方向 |
|--------|-----|------|
| P1 | L2L | 已用 ::date 窄窗 + LAG 前伸，禁止全历史 ORDER BY DESC |
| P1 | CDH checklist | ✅ `detail/07-cdh-hotel-bks-lite.sql`；`07-cdh.sql` 可加 DISTINCT didahotelid |
| P1 | LCDH hotel_bks | ✅ `detail/09-lcdh-hotel-bks-lite.sql`（NuiteeLMB 18k 酒店 MCP ✅） |
| P1 | SH hotel_bks | ✅ `detail/08-sh-hotel-bks-lite.sql`（Check24App 6082 酒店 MCP ✅；SOP 已接） |
| P2 | ads 机构 3b | ✅ **`00a` + `00b` 分拆**（2026-08-18 CVCTrend 复测通过） |
| P2 | 14/14 自动化回归 | 固定 client+日期 smoke test（CVCTrend 7/17 + Agoda 3/20） |
| P3 | 平台 | 向 data-api 反馈 ads 域、hotel_log 大表超时 |

---

## 7. 相关文档

- [decisions-summary.md](decisions-summary.md) §2 MCP 不稳定含义  
- [config-change-detection-lite/README.md](../sql/config-change-detection-lite/README.md)  
- [search-attribution-lite/README.md](../sql/search-attribution-lite/README.md)  
- [phases/03-evidence-verification.md](../phases/03-evidence-verification.md)  
- [phases/04-report.md](../phases/04-report.md) 合成门禁  
