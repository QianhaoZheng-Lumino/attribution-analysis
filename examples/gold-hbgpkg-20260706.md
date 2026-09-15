# HBGPKG @ 2026-07-06 归因分析报告（Gold · 正常波动 + CS 路径）

> **执行模式：** 本案例 `need_attribution=否`，**仅因完整型 / gold 回归才跑 Phase 2–4**。日常归因型对话门禁否应停在 Phase 1。  
> **金样例用途：** **need_attribution=否** 边界案例；**CS 链路/竞争力**路径（Meituan 平台平、HBGPKG 独跌幅度最大）；**并列 S**（EPS 平台共跌）；3a 14/14；3b 机构级 funnel。  
> 模板：[phases/04-report.md](../phases/04-report.md) · lite 分批重跑 · `client_id = HBGPKG`（**非** parent_client_id）

---

## Executive Summary

HBGPKG 在 2026-07-06 起 7 天窗口预订量 **-7.8%**（2,543→2,344），**正常波动**（评分 0/100，need_attribution=**否**）。作为 **CS 路径 gold**，仍跑完整 Phase 2–4。

- **异动：** 正常波动，WoW **-7.8%**，未过 20% 归因门禁
- **结构：** **Meituan 224（-91，46%）+ EPS 116（-61，31%）**；Country **US -78（39%）**
- **主因（倾向 CS）：** **HBGPKG×Meituan** — 平台 Meituan **5,749→5,779 持平**，HBGPKG **232→141（-91）** 跌幅全平台最大；**无 CS/C wolf 配置** → 倾向 **链路竞争力/对接**（非关房）
- **并列 S：** **EPS 116** 平台 **76,716→66,869（-12.8%）**，多 client 同降
- **已排除：** Dida 机构配置主因（14/14：CS/C/CDH/Configuration=0）；LCDH +255 酒店 **弱信号**（零单稀释）
- **并列 D：** US **World Population Day**（7/10，弱节日）→ **极弱背景**。
- **后续动作：** 目录 **C2**（Meituan 上几乎只有本 client 大动、3a 无 CS 配置）→ 问 HBGPKG/Meituan 对接 7/6 前后 US 链路查验比/竞争力；禁止写成已确认

---

## 0. 分析参数

| 项 | 值 |
|---|---|
| client_id | **HBGPKG** |
| parent_client_id | **Hotelbeds**（非 HBGPKG） |
| analysis_date | **2026-07-06** |
| 当前期 | 2026-07-06 ~ 07-12（7 天） |
| 对比期 | 2026-06-29 ~ 07-05（7 天） |
| 配置窗口 | 2026-07-05 ~ 07-07（±1 天） |
| 指标 | create 口径预订量 |

---

## 1. Phase 1：异动识别 ✅

| 指标 | 数值 |
|---|---|
| 当前期 / 对比期总量 | **2,344** / **2,543** |
| 日均 | **334.9** / **363.3** |
| **WoW** | **-7.82%** |
| vs 历史 49 天均值 | **-0.08%**（历史日均 ~335） |
| Z-score | **-0.00** |
| below_normal_range | **否** |
| **综合评分** | **0 / 100** |
| **异动等级** | **正常波动** |
| need_attribution | **否** |

**日趋势：** 对比期与当前期日均接近历史中枢（~335–363），无单日跳变；属 **轻微回落**，非严重掉产。

**说明：** 本 gold 展示 **门禁=否仍可做结构归因**（培训/CS 路径），与 Agoda/SnapTravel「门禁=是」案例互补。

---

## 2. Phase 2：定责与下钻 ✅

### 2b 定责 → **未达 70% 多数；倾向 CS（Meituan×HBGPKG）+ 并列 S（EPS）**

| 验证 | 结果 |
|---|---|
| **验证 A（2_SID）** | 42 个有效 supplier 中 **24 降 / 15 升（57.1% 降）** → **未达 70%**，不能写死 **C/Dida 多数** |
| **验证 B — Meituan 224** | 平台 **5,749→5,779（持平）**；HBGPKG **232→141（-91，跌幅最大）**；Lvzan、tb_guantu 等亦降 |
| **验证 B — EPS 116** | 平台 **76,716→66,869（-12.8%）**；AgodaEBK、SnapEBK、DidaOpaq 等多 client 同降 |
| **2b 初判** | **非单一 CS**（Meituan 上非仅 HBGPKG 独降）；**结构：Meituan 链路 + EPS 平台 S 成分并列** |

**Top 贡献 supplier（总量变化 -199）：**

| Supplier | prev → cur | change | 贡献% |
|---|---|---|---|
| **224-Meituan** | 232 → 141 | **-91** | **45.7%** |
| **116-EPS** | 382 → 321 | **-61** | **30.7%** |
| 1566-Yalago | 59 → 28 | -31 | 15.6% |
| 565-Ctrip | 91 → 62 | -29 | 14.6% |

### 2c 下钻（2c_progress **5/5** · 模板 [2c-structure-report-template.md](../docs/2c-structure-report-template.md)）

#### 主结构 · Country（4_Country · `04-country.sql`）

| Country | prev → cur | change | 占总量变化 |
|---|---|---|---|
| **US** | 976 → 898 | **-78** | **39.2%** |
| **JP** | 239 → 169 | **-70** | 35.2% |
| **SG** | 98 → 66 | **-32** | 16.1% |

*Top3 占 ~**90%**；**US + JP + SG 三国同跌**；HK -26 同向。Meituan 跌量与 **US** 下钻方向一致。*

#### 主结构 · Chain（6_Chain · `06-chain.sql`）

| Chain | prev → cur | change | 占总量变化 |
|---|---|---|---|
| **Independent** | 826 → 759 | **-67** | **33.7%** |
| **Far East Hotels** | 43 → 12 | **-31** | 15.6% |
| **Hilton Hotels** | 73 → 48 | **-25** | 12.6% |

*Top3 占 ~**62%**；**单体 + 远东/希尔顿同跌**；Harbour Plaza -25、APA -20 同向（未进 Top3）。*

#### 结构补充（描述性 · 不构成定责）

- **Lead Time（`08-lt.sql`）：** `other` **-92**（46%）、>70 天 **-70**（35%）；Top2 ~**81%**；4~7 天 -35、1 天 -11 同向。空桶/other 占比高，**无清晰 LT 形态可定责**。
- **LOS（`10-los.sql`）：** 1 晚 **-105**（53%）、4~7 晚 **-49**（25%）；Top2 ~**78%**。**短住段回落略多**，与各桶同向普跌一致。
- **Nationality（`12-nationality.sql`）：** `channel_nationality` 大量为空 → **客源国籍字段缺失，本节从略**。

→ **结构小结：** **US/JP/SG 多国 × Independent 单体 × 短住** 同步小幅回落，与 2b **Meituan + EPS 并列**、机构 **-7.8% 正常波动** 一致；**非单一 Country/Chain 可定责**。

---

## 3. Phase 3：内部证据 ✅

### 3a 配置（checklist **14/14 ✅**，窗口 7/5~7/7）

| # | Level | event_count | 关键 operation | 信号 |
|---|---|---|---|---|
| 1 | CS | **0** | — | — |
| 2 | C | **0** | — | — |
| 3 | S | **5** | 全局 supplier 操作 | 弱/背景 |
| 4 | CSA | **1** | S591-Letsfly **开通** margin=0 (7/6) | **弱**（非 Top 224/116） |
| 5 | CBD | 0 | — | — |
| 6 | SBD | 0 | — | — |
| 7 | CDH | 0 | — | — |
| 8 | SH | 0 | — | — |
| 9 | **LCDH** | **255** | HBGPKG **增酒店** (7/5 窗) | **弱**（击穿兜底新增；同期产量 -7.8%，hotel 级零单稀释） |
| 10 | L2L | 0 | — | — |
| 11 | CSLRC | 0 | — | — |
| 12 | C Bottom | 0 | — | — |
| 13 | S Bottom | **1** | 全局 supplier | 弱 |
| 14 | Configuration | 0 | — | — |

**3a 小结：** **CS/C/CDH/Configuration 无信号** → **已确认：非 Dida wolf 配置主因**；LCDH/CSA 仅弱背景。

---

### 3b 查价（B 线）✅

#### 机构级（funnel 加总 + client precheck）

| 指标 | 对比期 → 当前期 | WoW |
|---|---|---|
| 查价量（total_search） | 172.3 亿 → 154.1 亿 | **-10.6%** |
| 有价查价（avail） | 139.7 亿 → 123.2 亿 | **-11.8%** |
| **有价率** | 81.1% → **80.0%** | 略降 |
| **验价量（precheck）** | 34,115,259 → **27,231,046** | **-20.2%** |
| **查验比**（avail/rp） | ~409 → **~452** | **↑ ~10.5%** |
| **产量（BKS 日均）** | 363.3 → **334.9** | **-7.8%** |

**机构级解读：** 查价、验价、产量 **同向收缩**；查验比 **上升** → 与「加价/价劣、渠道少验」方向一致（evidence-synthesis **CS-2 / C Bottom 价劣** 读法），**非关房无价**（有价率仅略降）。

#### SS 层 Top supplier（224 / 116）

| SID | SS 请求 / 有价率 / 查验比 | 备注 |
|---|---|---|
| **224-Meituan** | MCP `clientsupplierhotelcallcountsummary` **无 HBGPKG 行** | 2026-07 窗 empty |
| **116-EPS** | 同上 | — |

→ **待 BI 补跑** `search-attribution-lite/01-ss-supplier`；机构级已支持「漏斗收缩 + 查验比↑」。

#### 限流/缓存

**未查。** 出数看 **结构 SID**（锁定或占 \|ΔBKS\|≥10%），不是 DidaBiz。本窗 SS callcount **无 HBGPKG 行** → 无结构数据。

#### 在线时长

**应触发、本 gold 未跑。** 机构查价 **-10.6%**（DidaBiz \|WoW\|>10%）→ 按现行 SOP **必须查** `online-hours-lite/`。定责不依赖在线；补跑后若日均少 ≥2h 且邮件解析，仅解释查价↓，不改 CS/S 主叙事。

---

### 3c 准确率

| 项 | 值 |
|---|---|
| 探测 `01-total` | **本 gold 未跑 Δpp**（lite README 仅有当期准确率 ≈94.35%，不够判 5pp） |
| 是否启动 | **未验** — 不得用 precheck 量降当「无线索」 |
| 备注 | 回归须 `01-total` 出 previous / current / Δpp |

---

### 3d 外部事件 D 线（HOLIDAY-only ✅ · D1 · 2026-08-18）

| 项 | 值 |
|---|---|
| 是否触发 | **必查** — P1 US 占变化 **39.2%** ≥10%；2b=CS 仅「倾向 / 中～强」**未达强**，不得跳过 |
| 取国来源 | **现行：`5_SID+Country`**（锁定 224-Meituan / 116-EPS）。本 gold 当时用 client `4_Country` US；与 Meituan 跌量同向，**数字沿用**。新案例禁止用 `4_Country` 代替 |

**窗口：** 当前 2026-07-06~07-12；对比 2026-06-29~07-05。

#### Step D1（`01-single-country-window.sql` · ads）

| 国家 | Top30 HOLIDAY | 城市 | 日期 | 与 BKS 方向 |
|---|---|---|---|---|
| **US** | World Population Day | 洛杉矶 | **7/10**（当前窗内） | US **-78**，跌产 **同向** |
| JP / SG | — | — | — | Top30 无重叠 |

→ D1 **弱命中** US 一节（rank 30、非消费型）；**canonical seed 无 `holiday_key`** → **D2 不触发**。

#### Step D2（`02-holiday-yoy-bks-lite.sql`）

| 项 | 判定 |
|---|---|
| seed 匹配 | ❌ World Population Day **不在** `holiday-canonical-seed.csv` |
| D2 门禁 | **跳过** — 无合法 `holiday_key` |

#### Step D3（Rubric · 见 external-events-mapping §10.7）

| # | 条件 | 判定 |
|---|---|---|
| ① | US 占 \|ΔBKS\| ≥10% | ✅ 39.2% |
| ② | 节日在当前窗 | ✅ 7/10 |
| ③ | 国别方向与异动同向 | ✅ US 跌 |
| ④ | YoY during/post 同向 | ⏭️ 无 seed |

**定级：极弱 / 无解释力（一行带过）**

**D 线解读：**

> **极弱背景**。US World Population Day（7/10）为 rank 30 非消费节日，与 -7.8% **正常波动无 plausibly 强关联**；**不能**与 HBGPKG×Meituan 链路定责交叉；主因仍在 **CS/S**（2b/3b）。

- **禁止：** 与 HBGPKG -7.8% 交叉定责；旧版 FAIR/CONCERT **已退出** D 线

**Lite 来源：** `external-events-lite/01-single-country-window.sql`（US）；D2 **未跑**（无 seed）

> **口径说明：** D 线当前按 `channel_createdate` 对齐（与 Phase 1/2c 一致）。**未来优化**改 `checkoutdate`（见 mapping §10.9）。

---

## 4. Phase 3d：综合判断

### 责任修正

| 项 | 结论 | 置信度 |
|---|---|---|
| Phase 2b 初判 | 57.1% 降，未达 C/Dida 70%；Meituan 平 + EPS 平台跌 | — |
| **修正后主因** | **倾向 CS（HBGPKG×Meituan 链路/竞争力）** | **倾向** |
| **并列** | **S（EPS 116 平台共跌 -12.8%）** | **倾向** |
| **并列** | **D** US World Population Day **极弱背景**（D1 弱命中、无 seed → D2 不触发） | **极弱** |
| **非主因** | Dida wolf 配置（14/14 无 CS/C/CDH/Configuration） | **已确认** |
| **非主因** | LCDH +255 扩名单 | **弱/已排除主因** |

### 证据对照表

| 线 | 关键发现 | 与 BKS 同向？ | 强度 |
|---|---|---|---|
| **A 配置** | 14/14 无 CS/C；LCDH 255 弱 | 否 | 无/弱 |
| **B 机构** | 查价/验价↓；查验比↑；有价率略降 | 收缩 | 中 |
| **B SS** | callcount 无行 | — | 未验 |
| **限流** | SS 无行 → 未查（勿用机构 PPS 触发） | — | — |
| **在线时长** | DidaBiz -10.6% **应查未跑** | 只绑查价 | 缺口 |
| **2b Meituan** | 平台平、HBGPKG -91 最大 | 链路 | 中～强 |
| **2b EPS** | 平台 -12.8%、多 client 降 | 同向 | 中 |
| **D 外部** | US World Population Day D1；无 seed → D2 跳过 | US 跌同向 | **极弱** |
| **C 准确率** | **未验**（未跑 01-total Δpp） | — | 缺口 |

### 一句话结论

HBGPKG 7/6 起 **正常波动（-7.8%）**，结构 **Meituan + EPS**；**无 Dida 配置主因**；机构 **查验比↑ + 验价量↓** → **倾向 Meituan×HBGPKG 链路竞争力/对接（CS）**，**并列 EPS 平台共跌（S）**。

---

## 5. 根因结论

### 已确认

| 根因/结构 | 责任方 | 证据 | 影响估算 |
|---|---|---|---|
| 非 Dida wolf 配置主因 | 排除 Dida | 3a 14/14 | — |
| Meituan + EPS 结构 | 结构 | Phase 2 | ~76% 变化量 |
| EPS 平台共跌 | S 并列 | 验证 B 116 | 平台 -12.8% |

### 倾向（待 Phase 4 / BI 补 SS）

| 假设 | 责任方 | 支撑证据 | 缺什么 |
|---|---|---|---|
| HBGPKG×Meituan US 链路竞争力/查验比 | **CS** | 平台平、HBGPKG -91 最大；机构查验比↑ | SS 224×US 查价；对接参数 |
| EPS 供给侧走弱 | **S** | 全平台多 client 在 116 降 | supplier 侧确认 |

### Phase 4 外部跟进

| 现象 | 可能方向 | 建议运营动作 |
|---|---|---|
| Meituan 平、HBGPKG 独跌幅度最大 + 查验比↑ | **CS 对接/竞争力** | 问 HBGPKG：7/6 前后 **Meituan US** 验价策略、margin、对接变更 |
| EPS 全 client 同降 | **S** | 内部查 EPS 供给/接口；与 Agoda 等对照 |
| 整体仅 -7.8% 正常波动 | **C 微调** | 是否渠道侧小幅缩量（P2） |

---

## 6. Phase 4 / 建议动作

| 优先级 | 动作 | 负责方 |
|---|---|---|
| **P0** | **Meituan 224 × US** SS 查价 + 对接排查（平台平、HBGPKG -91） | 运营/技术 |
| **P1** | **EPS 116** 平台级产量与查价对照（-61，31%） | 内部分析 |
| **P2** | BI 补跑 `search-attribution-lite/01-ss-supplier`（callcount MCP 空） | BI |
| **P2** | 运营问 HBGPKG 7/6 前后整体策略（正常波动背景） | BD |

---

## 附录

### lite 流程验证

| 步骤 | 文件 | 结果 |
|---|---|---|
| Phase 1 | npd_booking_view 聚合 | ✅ |
| Phase 2 | `02-sid` + 2c **5/5**（`04-country` `06-chain` `08-lt` `10-los` `12-nationality`）+ 验证 B | ✅ |
| Phase 3a | checklist 01–14 | ✅ **14/14** |
| Phase 3b 机构 | funnel + precheck | ✅ |
| Phase 3b SS | 01-ss-supplier | ❌ callcount 无 HBGPKG 行 |
| Phase 3d D1 | `01-single-country-window.sql`（US） | ✅ |
| Phase 3d D2 | — | ⏭️ 无 `holiday_key` |
| 3c / 限流 | — | 3c 未跑 01-total；限流 SS 无行未查 |
| 在线时长 | online-hours-lite | ⚠️ DidaBiz -10.6% 应查，本 gold 未跑 |

### 数据限制

- `clientsupplierhotelcallcountsummary` client=`HBGPKG` 2026-07 **无行**
- 机构 PPS：HBGPKG 用 funnel（非 ads 假 500 案例）；`00-client-total` 若跑 ads 须用 **`dt::date`**（勿写 `stat_date`）
- supplier 级 precheck 聚合 MCP **500**
- 旧报告写 59.5% supplier 降；本次 **57.1%（24/42）** — 均未达 70%

### 金样例四角对照

| | HBGPKG | Agoda | SnapTravel2B |
|---|---|---|---|
| 门禁 | **否**（正常波动） | 否（边界） | **是** |
| 2b | **CS + S 并列** | C/Dida + S | **S + C** |
| 3b 特征 | 查验比↑ | 查价平产量降 | 查价降验价升 |
| 主因 | **倾向 CS** | 倾向 C | 倾向 S |

---

## 本案例验证的 Skill 规则

| 规则 | 本案体现 |
|---|---|
| need_attribution=否 仍可交付完整报告 | **仅完整型/gold**；日常归因型应停 Phase 1 |
| 2b <70% 不写死 C/Dida | 57.1% → CS/S 并列叙事 |
| CS-2：平台 supplier 平、本 client 跌幅最大、无 CS 配置 | → 查 SS 查验比/对接 |
| 3a 14/14 排除 Dida | CS/C=0 |
| LCDH 弱信号不单定责 | +255 酒店零单稀释 |
| D 线 §5 | CS 未达强 → **仍查**；取国现行 `5_SID+Country`（本 gold 沿用 4_Country US） |
| 2c 5/5 | Country+Chain 表 Top3；LT/LOS 段落 |
