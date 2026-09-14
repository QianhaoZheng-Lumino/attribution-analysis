# Agoda @ 2026-03-20 归因分析报告（Gold · 跌产 + C/Dida 主路径）

> **执行模式：** 本案例 `need_attribution=否`，**仅因完整型 / gold 回归才跑 Phase 2–4**。日常归因型对话门禁否应停在 Phase 1。  
> **金样例用途：** 跌产路径回归；2b **门 2：家数同向 ≥70% 且无单 SID≥50%** 才写死 C/Dida（本案 70.7%，Top SID 29.6%/28.5%）；3a 14/14 排除配置主因；3b 查价稳/产量降 → **倾向 C**；Top supplier **并列 S**；D 线 **MY 开斋节弱并列**。成品格式以 [04-report-skeleton.md](../phases/04-report-skeleton.md) 为准，本文 3a 表头不要抄。  
> 模板：[phases/04-report.md](../phases/04-report.md) · lite 分批重跑 · `client_id = Agoda`

---

## Executive Summary

Agoda 主账号在 2026-03-20 起 7 天窗口预订量 **-16.5%**（2,739→2,287），**正常波动（方向下降）**；methodology：`|WoW|` 16.5% < 20%、`|Z|` 0.55 < 1.5、未越界 → 等级不是「轻微异动」。need_attribution=**否**，但作为 **跌产 gold** 仍跑完整 Phase 2–4。41 个有效 supplier 中 **70.7% 同向下降** → **2b 初判 C/Dida**。

- **主因（倾向 C）：** 机构级查价 **几乎持平**（有价 PPS ~816M→815M，-0.1%），产量降 → **渠道侧需求/转化收缩**，非 Dida 关房主因。
- **结构：** **EPS 116（-134，30%）+ Traveloka 131（-129，29%）**；Country **TH -113（25%）**。
- **并列 S：** EPS / Traveloka 验证 B 显示 **多 client 同降**（SnapEBK、AgodaEBK、DidaOpaq 等）→ supplier 平台侧共跌成分。
- **已排除：** 主账号 C/CDH/LCDH/Configuration **无变更**（14/14）；CS×257 关房 **无对应产量**。
- **并列 D（弱）：** MY **Hari Raya**（3/19）D1 命中 + D2 YoY **节中凹陷**（y2 during 25 vs pre 211）；占变化 **14.6%**；TH 无 Top30 → **不得**归因 TH。
- **Phase 4 P0：** 按 [es-cause-catalog.md](../docs/es-cause-catalog.md) **B2**（查价不太掉、无强配置）→ 可能渠道侧需求/转化/看不见的操作，**运营问客户**；禁止写成已确认。

---

## 0. 分析参数

| 项 | 值 |
|---|---|
| client_id | **Agoda**（主账号） |
| parent_client_id | Agoda（parent 全量 7 天：74,211→60,727，**-18.2%**） |
| analysis_date | **2026-03-20** |
| 当前期 | 2026-03-20 ~ 03-26（7 天） |
| 对比期 | 2026-03-13 ~ 03-19（7 天） |
| 配置窗口 | 2026-03-19 ~ 03-21（±1 天） |
| 指标 | create 口径预订量 |

---

## 1. Phase 1：异动识别 ✅

| 指标 | 数值 |
|---|---|
| 当前期 / 对比期总量 | **2,287** / **2,739** |
| 日均 | **326.7** / **391.3** |
| **WoW** | **-16.5%** |
| vs 历史 **42** 天均值 | **-10.5%**（历史日均 ~365） |
| Z-score | **-0.55** |
| below_normal_range | **否**（326.7 > Q1×0.7 ≈ 223） |
| **综合评分** | **20 / 100**（WoW>10% 得 10 + vs 均值>10% 得 10） |
| **异动等级** | **正常波动**（方向：**下降**，日均 < 对比×0.9） |
| need_attribution | **否**（\|WoW\| 16.5% < 20% 门禁） |

**说明：** 本案例为 **边界跌产 gold**——评分 20、等级按 methodology §6 为正常波动，但 3/20 起进入 sustained 低位平台，业务惯例仍做完整归因。原文曾误写「轻微异动」和「49 天」，**以 42 天基准 + 正常波动为准**。parent 口径跌幅更大（**-18.2%**）。

**日趋势：** 3/13–3/19 对比期均值 ~391；3/20 起当前期 ~327；3/28 前后仍有低位（历史扫描锚点）。

---

## 2. Phase 2：定责与下钻 ✅

### 2b 定责 → **C / Dida（初判）+ 并列 S（Top supplier 平台共跌）**

| 验证 | 结果 |
|---|---|
| **验证 A（2_SID）** | 41 个有效 supplier 中 **29 降 / 10 升（70.7% 降）**；Top SID **29.6% / 28.5%**（均 <50%）→ **门 2 允许写死 C/Dida** |
| **验证 B — 116-EPS** | **多 client 同降**：SnapEBK -3,648、AgodaEBK -1,817、DidaOpaq -1,503、**Agoda -134**… |
| **验证 B — 131-Traveloka** | **多 client 同降**：DidaOpaq -2,314、AgodaEBK -1,913、**Agoda -129**… |
| **2b 初判** | **C/Dida**（Agoda 下多数 supplier 普跌）；Top SID 上 **S 平台共跌并列**，非 CS（非 Agoda 独有链路） |

**Top 贡献 supplier（总量变化 -452）：**

| Supplier | prev → cur | change | 贡献% |
|---|---|---|---|
| **116-EPS** | 459 → 325 | **-134** | **29.6%** |
| **131-Traveloka** | 848 → 719 | **-129** | **28.5%** |
| 1835-DCshareIND | 318 → 270 | -48 | 10.6% |
| 565-Ctrip | 44 → 0 | -44 | 9.7% |

**少数上涨（不构成主因）：** 1647-DCSiteminder +32、1834-DCshareIND_Prepay +16 等，体量小。

### 2c 下钻（2c_progress **5/5** · 模板 [2c-structure-report-template.md](../docs/2c-structure-report-template.md)）

#### 主结构 · Country（4_Country · `04-country.sql`）

| Country | prev → cur | change | 占总量变化 |
|---|---|---|---|
| **TH** | 592 → 479 | **-113** | **25.0%** |
| **MY** | 211 → 145 | **-66** | 14.6% |
| **VN** | 397 → 353 | -44 | 9.7% |

*Top3 占 ~49%（总量变化 -452）；TR -43、ID -24 等同向；**东南亚多国同步回落**，非单一 CS 链路。*

#### 主结构 · Chain（6_Chain · `06-chain.sql`）

| Chain | prev → cur | change | 占总量变化 |
|---|---|---|---|
| **Independent** | 2074 → 1664 | **-410** | **90.7%** |
| Wyndham | 46 → 28 | -18 | 4.0% |
| Club Quarters | 14 → 6 | -8 | 1.8% |

*Top3 占 ~97%；**跌产集中在 Independent 单体**；Centre point +36、Worldwide Hotels +36（反向，体量小）。*

#### 结构补充（描述性 · 不构成定责）

- **Lead Time（`08-lt.sql`）：** 4~7 天 **-170**（38%）、>70 天 **-98**（22%）；Top2 ~60%；29~42 天 +27（反向，小）。中短提前期与超远期同跌，无单一 LT 桶主导。
- **LOS（`10-los.sql`）：** 1 晚 **-146**（32%）、4~7 晚 **-102**（23%）；Top2 ~55%。各连住段同向普跌，短住略多。
- **Nationality（`12-nationality.sql`）：** `channel_nationality` 大量为空，变化集中于 `(empty)`/Unknown → **客源国籍字段缺失，本节从略**。

→ **结构小结：** 多国 SEA + **Independent 单体** + 短住/中 LT 同步回落，与 2b **C/Dida 需求收缩** 叙事一致；**非单一 Country/Chain 可定责**。

---

## 3. Phase 3：内部证据 ✅

### 3a 配置（checklist **14/14 ✅**，窗口 3/19~3/21）

| # | Level | event_count | 关键 operation | 信号 |
|---|---|---|---|---|
| 1 | CS | **4** | **257 关**（3/21，×2 记录）；1995、2040 **关**（3/20） | **弱**（非 Top 116/131；257 主账号 **无产量**） |
| 2 | C | 0 | — | — |
| 3 | S | **12** | 全局 supplier 操作 | 弱/背景 |
| 4 | CSA | **19** | 全局/多 supplier | 弱/背景 |
| 5 | CBD | 0 | — | — |
| 6 | SBD | 0 | — | — |
| 7 | CDH | 0 | — | — |
| 8 | SH | 0 | — | — |
| 9 | LCDH | 0 | — | — |
| 10 | L2L | 0 | — | — |
| 11 | CSLRC | 0 | — | — |
| 12 | C Bottom | 0 | — | — |
| 13 | S Bottom | **1** | 全局 supplier | 弱 |
| 14 | Configuration | 0 | 6 key 无 | — |

**3a 小结：** 主账号 **C/CDH/LCDH/Configuration 无强信号**；CS 4 条在 **257/1995/2040**，与 Top 跌量 **116-EPS / 131-Traveloka 无关** → **已确认：非 Dida 机构配置主因**。  
（子账号 AgodaEBK 曾有 CDH 46 酒店关房，占 parent 体量极小，见历史 BI 记录，不单定责 parent 异动。）

---

### 3b 查价（B 线）

#### 机构级（必跑）

| 指标 | 对比期 → 当前期 | WoW | 来源 |
|---|---|---|---|
| **有价 PPS（DidaBiz）** | ~816M → ~815M | **~-0.1%** | 历史 BI 实测（gold 重跑时 `00-client-total` 曾误用 **`stat_date`** → MCP 500；已改 **`dt::date`**） |
| **产量（BKS）** | 391.3 → 326.7 日均 | **-16.5%** | Phase 1 ✅ |

**机构级解读：** 查价/有价 **几乎不动**，产量 **明显下滑** → 典型 **「C 侧需求/转化收缩」** 形态（非关房导致无价）。与 evidence-synthesis **C/Dida + A 无 + B 正常 → 倾向 C** 一致。

#### SS 层 Top supplier（结构补充）

| SID | SS 请求 / 有价率 / 查验比 | 备注 |
|---|---|---|
| **116-EPS** | MCP `clientsupplierhotelcallcountsummary` **无 Agoda 行** | 2026-03 窗 empty；用验证 B + 历史逻辑 |
| **131-Traveloka** | 同上 | — |

→ SS lite **本次未出数**；2b 验证 B 已证明 **平台共跌**，不替代机构级「查价稳」结论。

#### 限流/缓存

**未查。** 出数看 **结构 SID**（锁定或占 \|ΔBKS\|≥10%），解读看 SS 有价/请求 10%。本窗 `clientsupplierhotelcallcountsummary` **无 Agoda 行** → 无结构数据。不得用机构 PPS 代替。

#### 在线时长

**未查（未触发）。** 机构 DidaBiz 有价 PPS **~-0.1%**，\|WoW\| 未超 10%。（若日后 PPS 超 10%，须跑 `online-hours-lite/`。）

---

### 3c 准确率

| 项 | 值 |
|---|---|
| 探测 `01-total` | **本 gold 未跑**（现行每案必跑） |
| 是否启动 | **未验** — 不得写「无线索」。client 聚合曾返回 null |
| 备注 | 回归须出 Δpp；\|Δ\|≥5pp 才 issue 下钻 |

---

### 3d 外部事件 D 线（HOLIDAY-only ✅ · D1+D2 · 2026-08-18）

| 项 | 值 |
|---|---|
| 是否触发 | **必查** — P0（2b 倾向 C/Dida + A 无强 + B 查价稳）+ P1 TH 25% / MY 14.6% |
| 取国来源 | **`4_Country`**（C/Dida 路径） |

**窗口：** 当前 2026-03-20~03-26；对比 2026-03-13~03-19。

#### Step D1（`01-single-country-window.sql` · ads）

| 国家 | Top30 HOLIDAY | 城市 | 日期 | 与 BKS 方向 |
|---|---|---|---|---|
| **MY** | Hari Raya Puasa Holiday | 吉隆坡 | **3/19**（邻接当前窗） | MY **-66**，跌产 **同向** |
| TH | — | — | — | Top30 无重叠（March Equinox 承塔萊 **rank 75** 已过滤） |
| JP / VN | — | — | — | 无 Top30 节日 |

→ 仅 **MY** 进入 D2（D1 命中 + 国别占比 ≥10%）。**TH 跌 -113 不得归因节日。**

#### Step D2（`02-holiday-yoy-bks-lite.sql` · seed `MY.HARI_RAYA_PUASA`）

| 占位符 | 值 |
|---|---|
| y1 节窗 | 2025-03-31 |
| y2 节窗 | 2026-03-20 |
| pre/post | 各 7 天 |
| `client_window` | 2026-03-13 ~ 03-26 |

**MCP 国别 BKS（Rubric 用 `country_*_bks`）：**

| cohort | country_pre | country_during | country_post | span | gate |
|---|---:|---:|---:|---:|---|
| y1 | 242 | 23 | 154 | 419 | ok |
| y2 | 211 | 25 | 148 | 384 | ok |

`client_window_bks` = **5,026**（≥100 ✅）。

**YoY 形态：** 两年 **节中凹陷**（during 23↔25，远低于 pre ~211–242）；post 略回升但未超 pre（post/pre ≈ 0.64↔0.70）→ YoY **同向**。

#### Step D3（Rubric · 见 external-events-mapping §10.7）

| # | 条件 | 判定 |
|---|---|---|
| ① | MY 占 \|ΔBKS\| ≥10% | ✅ 14.6% |
| ①′ | 国别占比 <30% → 上限 **弱** | ✅ |
| ② | 节日邻接异动窗 | ✅ 3/19 邻 3/20 |
| ③ | 国别方向与异动同向 | ✅ MY 211→145 跌；y2 节中凹 |
| ④ | YoY during/post 同向 | ✅ |

**定级：弱（并列背景）**

**D 线解读：**

> **弱并列**。MY Hari Raya（3/19，D1 Top30）与 3/20 跌产窗邻接；YoY 同节 MY 产单呈节中凹陷（y2 during **25** vs pre **211**），与今年 MY 国别收缩 **同向**，但 MY 仅占全量变化 **14.6%**，**不能**解释 TH 主跌（-113）或机构 -16.5%；主因仍为 **C（查价稳/产量降）** 并列 **S**。

- **禁止：** 写「节日导致 Agoda 跌产」；D **不抢** 3b「查价稳→倾向 C」主结论
- **Phase 4（可选）：** 问 Agoda MY 开斋节后搜索/促销是否收缩（弱假设）

**Lite 来源：** `external-events-lite/01-single-country-window.sql`（MY）；`02-holiday-yoy-bks-lite.sql`（D2 · **create 口径**）；节窗 `holiday-canonical-seed.csv`

> **口径说明：** D2 当前按 `channel_createdate` 切 pre/during/post（与 Phase 1/2c 一致）。**未来优化**改 `checkoutdate` 对齐节日消费（见 mapping §10.9）；届时 gold 数字需重跑。

---

## 4. Phase 3d：综合判断

### 责任修正

| 项 | 结论 | 置信度 |
|---|---|---|
| Phase 2b 初判 | C/Dida（70.7% supplier 降） | — |
| **修正后主因** | **C（Agoda 渠道侧需求/转化收缩）** | **倾向** |
| **并列** | **S 成分**（EPS/Traveloka 全平台多 client 同降） | **倾向** |
| **并列** | **D** MY 开斋节 **弱并列**（D2 YoY 节中凹）；TH 无 Top30 节 | **弱** |
| **非主因** | Dida 机构配置（C/CDH/Configuration 无；CS 257 无产量） | **已确认** |
| **结构** | EPS + Traveloka ≈ **58%**；TH ≈ **25%** | **已确认** |

### 证据对照表

| 线 | 关键发现 | 与 BKS 同向？ | 强度 |
|---|---|---|---|
| **A 配置** | 14/14 无 C/CDH/Configuration；CS 257 弱 | 否 | 弱/无 |
| **B 机构** | 有价 PPS **平**；BKS **降** | **转化/需求** | 中～强 |
| **B SS** | MCP 无 Agoda SS 行 | — | 未验 |
| **2b B** | EPS/Traveloka **多 client 降** | 同向 | 中 |
| **D 外部** | MY Hari Raya D1+D2 节中凹；TH 无 Top30 匹配 | MY 跌同向 | **弱** |
| **C 准确率** | **未验**（未跑 01-total Δpp） | — | 缺口 |

### 一句话结论

Agoda 3/20 起 **主账号产量 -16.5%**，**多数 supplier 普跌（70.7%）**；**查价几乎持平、配置无强信号** → **倾向 C（渠道需求收缩）**，**并列** EPS/Traveloka **平台 supplier 共跌（S）** 及 **MY 开斋节弱并列（D）**；TH 主跌 **不能**归因节日。

---

## 5. 根因结论

### 已确认

| 根因/结构 | 责任方 | 证据 | 影响估算 |
|---|---|---|---|
| 多 supplier 普跌结构 | C/Dida 初判 | 验证 A 70.7% | 2b 定责 |
| 非 Dida 机构配置主因 | 排除 Dida | 3a 14/14 | — |
| EPS + Traveloka 共跌 | S 并列 | 验证 B | ~58% 变化量 |

### 倾向（待 Phase 4）

| 假设 | 责任方 | 支撑证据 | 缺什么 |
|---|---|---|---|
| Agoda SEA 流量/促销/API 策略收缩 | **C** | 查价平 + 产量降；TH/MY/VN 多国跌 | BD 确认 3/20 前后策略 |
| EPS/Traveloka 供给侧同步走弱 | **S** | 全平台多 client 在两条 SID 上同降 | supplier 侧资源/对接 |

### Phase 4 外部跟进

| 现象 | 可能方向 | 建议运营动作 |
|---|---|---|
| 查价稳、产量降、多国 SEA 跌 | **C** | 问 Agoda：**3/20 前后 TH/MY/VN 流量权重、促销结束、API QPS 是否下调？** |
| EPS/Traveloka 全 client 同降 | **S** | 内部 supplier 侧是否已知供给/接口异常；与 Agoda 并行排查 |
| MY 开斋节后产单形态（D2 节中凹 YoY 同向） | **D** | MY during 25 vs pre 211；仅占变化 14.6% | Phase 4 问 MY 促销/搜索 |
| TH 无 Top30 节日 | — | March Equinox rank 75 过滤 | **不得**归因 TH 节日 |

---

## 6. Phase 4 / 建议动作

| 优先级 | 动作 | 负责方 |
|---|---|---|
| **P0** | 联系 Agoda 确认 **3/20 前后 SEA（尤其 TH）** 流量与促销策略 | BD/运营 |
| **P1** | 对照 **EPS 116 / Traveloka 131** 全平台产量，区分 S 供给 vs C 独有 | 内部分析 |
| **P2** | 子账号 **AgodaEBK CDH** 局部关房是否需运营知会（占 parent 小） | 运营 |
| **P2** | BI 补跑 `search-attribution-lite`（Agoda SS 层 MCP 空时） | BI |

---

## 附录

### lite 流程验证

| 步骤 | 文件 | 结果 |
|---|---|---|
| Phase 1 | npd_booking_view 聚合 | ✅ |
| Phase 2 | `02-sid` + 2c **5/5**（`04-country` `06-chain` `08-lt` `10-los` `12-nationality`）+ 验证 B | ✅ |
| Phase 3a | checklist 01–14 逐条 | ✅ **14/14** |
| Phase 3b 机构 | `00-client-total.sql`（`dt::date`） | ⚠️ 重跑前曾 **stat_date 假 500**；修正后 Agoda 窗 ✅ |
| Phase 3b SS | 01-ss-supplier | ❌ Agoda 无 callcount 行 |
| Phase 3d D1 | `01-single-country-window.sql`（MY） | ✅ |
| Phase 3d D2 | `02-holiday-yoy-bks-lite.sql`（MY.HARI_RAYA_PUASA） | ✅ gate=ok |
| 3c / 限流 | — | 3c 未跑 01-total；限流 SS 无行未查 |
| 在线时长 | — | 未触发（DidaBiz ~-0.1%） |

### 数据限制

- `ads.ads_hotel_monitor_rate_search_statistic_by_client_id`：gold 期 **`00-client-total` 误用 `stat_date`** 导致 MCP 500（非 ads 域不可用）；**2026-08 已改 `dt::date`**
- `didamonitor_funnel_client_country` Agoda 窗 **空/null**（与 ads 修正无关）
- `clientsupplierhotelcallcountsummary` client=`Agoda` **无行**（2026-03）
- 机构有价 PPS **~-0.1%** 来自历史 BI 对话实测，gold 重跑时需 BI 复核

### 金样例三角对照

| | **Agoda @ 3/20** | **SnapTravel2B @ 8/1** | **HBGPKG @ 7/6** |
|---|---|---|---|
| 方向 | 跌 -16.5% | 涨 +73.5% | 跌 -7.8% |
| 2b | **C/Dida**（70.7% 且无 SID≥50%） | **S 主因** + C 放大 | CS + S 并列 |
| 3a | 14/14 无强配置 | 14/14 无强配置 | 14/14 |
| 3b | 查价**平**、产量降 | 查价降、验价升、产量升 | Meituan 平台平 |
| 主因 | **倾向 C** | **倾向 S** | 倾向 CS 链路 |

---

## 本案例验证的 Skill 规则

| 规则 | 本案体现 |
|---|---|
| 2b 双门写死 C/Dida | 70.7% 且无 SID≥50% → **C/Dida** |
| 验证 B 多 client 同降 | EPS/Traveloka → **S 并列**，非 CS |
| 3a 14/14 才能排除 Dida | CS 257 弱信号 **不能** 当主因 |
| A 无 + B 查价平 + BKS 降 | evidence-synthesis → **倾向 C** |
| D 线 §5 / §10.7 | 取国 `4_Country`；MY D1+D2 **弱并列**；TH 无 Top30 → 不归因 |
| Phase 1 边界 | \|WoW\|<20% 仍可作为跌产 gold（**完整型**才跑 2–4） |
