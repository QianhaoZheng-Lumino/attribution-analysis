# 异动归因 Skill — 关键决策摘要

> 从 7/28–7/30 创建对话蒸馏。完整对话导出已从仓库删除（曾含明文 `agent_user_key` 与本机路径，禁止再入库）。口径以本文 + `SKILL.md` 为准。

## 文档用途

- 新对话继续改 Skill 时，**先读本文 + `SKILL.md`**
- 记录「为什么这样设计」，避免重复讨论已拍板事项
- **待办只写 [backlog.md](./backlog.md)**；本文与 `ROADMAP.md` 不再另列清单（#21）

---

## 1. 总体架构（四 Phase）

```
Phase 1  异动识别（lite 三步）     → 无异动则结束
Phase 2  2a 贡献度 → 2b C×S 定责 → 2c 自动下钻
Phase 3  内部证据（14 类配置 + 查价验价 + 外部事件库待接）
Phase 4  报告收口（合成报告；数据说不清 → 查 es-cause-catalog，禁止写成已确认）
```

**已定：先定责（C×S 交叉），再自动下钻；不做全维度宽交叉。**

---

## 2. 数据源与 MCP

| 决策 | 内容 |
|------|------|
| 主数据源 | `user-data-mcp`（`~/.cursor/mcp.json`） |
| 查任意 Hologres 表 | `search_meta_data` + `execute_sql`（SELECT，≤1 万行，行级权限） |
| 查指标趋势 | `analyse_query` / `search_metrics` |
| MCP「不稳定」含义 | **非权限问题**；复杂/长 SQL（多层 CTE、PERCENTILE_CONT、FILTER）易 **HTTP 500** |
| 应对策略 | **拆分 lite 版 SQL**，完整 SQL 作 source of truth，MCP 跑短查询。**禁止手写 SQL、禁止 14 路 UNION**（`03-fourteen-level-checklist.sql` 仅 BI） |

**元数据搜不到的表**（如 `wolf_rateadjust_hotel_log`）仍可能通过 `execute_sql` 直接查，只是 `search_meta_data` 无索引。

---

## 3. Phase 1：异动识别

### 3.1 方法论（用户 SQL 蒸馏）

- **三维评分**：WoW（40 分）+ Z-score（30 分）+ 历史范围偏离（30 分）
- **历史基准**：analysis_date 前 42 天；Q1/Q3 用 PERCENTILE_CONT
- **归因门禁**：\|WoW\|>20% 或 \|Z\|>1.5 或 below_normal_range → `need_attribution=是`
- **执行模式（2026-09-04 #17）：** 探查 → 只 Phase 1；归因型 + 门禁是 + 已有 client → 自动 2–4；归因型 + 门禁否 → 停，须「完整/gold」才继续；**大盘不得自动 3a/在线/限流**。详见 `SKILL.md`
- **探查拐点选日（#24）：** **不写入 Skill / Phase 1。** `analysis_date` 在对话里对齐即可。

### 3.2 参数约定

| 参数 | 默认/说明 |
|------|-----------|
| `analysis_date` | 分析锚点，默认 7 天前 |
| `parent_client_id` / `client_id` | 分析范围（如 Agoda、HBGPKG） |
| `n_days` | 对比窗口；≥7 走新逻辑，`min_data_date = LEAST(analysis_date - GREATEST(14, n_days), analysis_date - 7)` |
| 默认指标 | `npd_booking_view` 日预订量（create 口径） |

### 3.3 SQL vs 方法论分工

| 场景 | 做法 |
|------|------|
| 预订量异动（Phase 1 默认） | **直接跑 SQL**（lite 三步） |
| 判定规则、门禁、扩展其他指标 | **读 methodology.md** |
| MCP 执行 | **勿直接跑完整 `anomaly-detection.sql`**，用 `sql/anomaly-detection-lite/` 01→02→03 |

### 3.4 文件

- `methodology.md` — 判定标准
- `sql/anomaly-detection.sql` — 完整版（非 MCP）
- `sql/anomaly-detection-lite/` — MCP 稳定版
- `phases/01-anomaly-detection.md` — SOP

---

## 4. Phase 2：定责与下钻

### 4.1 核心原则

1. **贡献度 ≠ 责任**
2. **交叉验证只用于定责**（C / Dida / S / CS），仅 **C×S 供应轴**
3. **下钻不追加宽表交叉验证**（禁止 country×chain 等新 SQL）。执行分两条路径：
   - **BI / 非 MCP：** `dimension-contribution.sql` **全量 1 次** → 2c **只过滤排序，0 额外 SQL**
   - **MCP：** 必须用 `dimension-contribution-lite/` **分批**；`02-sid`（2b）+ 2c 路径文件（C/Dida **5/5** 或 S/CS country+chain+lt+los+nat）。**禁止**写「MCP 上 2c 0 额外 SQL」
4. **定责后自动下钻**（2c），无需用户逐步点选

### 4.2 责任四方

| 代号 | 含义 |
|------|------|
| **C** | Client 渠道自身 |
| **Dida** | 我方内部（配置、查价验价）；2b 与 C 合并，Phase 3 区分 |
| **S** | Supplier 供应商 |
| **CS** | Client×Supplier 链路 |

### 4.3 Phase 2b：C×S 交叉验证（双门，2026-09-09）

| 门 | 规则 |
|----|------|
| **门 1 跑 B** | 任一有效 SID 占本 client `|ΔBKS|` **≥10%** → 必跑验证 B（过线每家一次）。无 SID ≥10% 才跳过。**禁止**因家数 ≥70% 跳过 B |
| **门 2 写死 C/Dida** | 家数同向 **≥70%** 且 **没有** 单 SID ≥50%。否则禁止写死，用 B 判 S 或 CS |
| B 读法 | 多数 client 同向 → **S**；仅 focus / 逆势 → **CS**。写死 C/Dida 后可并列，不翻主因 |

- 70% 只管「宽不宽」，**不是**跳过 B 的开关（#7 数字仍不改）
- **禁止加码：** 结构 SID 的 B 是 CS 不得否决门 2；50% 不得降到 30%
- 10 份旧 case/gold 回放：主因四方与 2c 路径 0 翻案；Check24 须补跑 B（并列可加厚）

### 4.4 Phase 2c：定责后自动下钻

| 2b 结论 | 下钻维度（从 2a 过滤，Top 3） |
|---------|------------------------------|
| **C 或 Dida** | Country, Chain, LT, LOS, Nationality |
| **S 或 CS** | SID+Country, SID+Chain, SID+Account, SID+LT/LOS/Nationality |

- **C 与 Dida 下钻清单相同**；Dida vs C 靠 Phase 3
- **SID+Account**：仅当 **占该 SID 变化** `ABS(%) ≥ 10%` 才写入报告
- **2c 贡献% 分母（#14）：** C/Dida ÷ client 总量；S/CS ÷ **锁定 SID 的 booking_change**；列名「占 {SID} 变化」
- LT/LOS/Nationality 为**描述性**（需求结构变化），不单独做宽交叉
- **报告模板：** [2c-structure-report-template.md](./2c-structure-report-template.md)（**Country+Chain 表 Top3**；LT/LOS/Nationality 段落）

### 4.5 贡献度 SQL 13 层 hierarchy

`2_SID` → `3_SID+Account` → `4_Country` → … → `13_SID+Nationality`（见 `dimension-contribution.sql`）

### 4.6 文件

- `responsibility-model.md` / `cross-validation-design.md`
- `sql/dimension-contribution.sql` / `sql/cross-validation-b.sql`
- `phases/02-dimension-drilldown.md` / `02a` / `02c-drilldown.md`

---

## 5. Phase 3：内部证据（14 类配置）

### 5.1 设计原则

- **不是「看到配置变了就定责」**，要 **变更前后产量/查价验证**
- **输出配置证据清单 + 信号强度解读**，**不做**单一「30% 自动确认 Dida」公式
- MCP 大 SQL 易 500 → 用 **`config-change-detection-lite/`** 分批查
- **机构供应商白名单（#23）：** 现为当前配置、非日志 → **不进 3a**；等改成 log 后再纳入

### 5.2 14 类 Level（查优先级顺序）

**展示顺序 = 作用域**（机构 → 链路 → S → 酒店），不是 C 比 CBD 优先，也不是开关房 > 调价（2026-09-05 #26）。  
**评级 = 作用域 × 操作 + B 方向**。写「倾向 C」须过出门禁。

**CS 路径：** CS → CSA

**S 路径：** S → S Bottom → SH（SH 酒店级看 `08-sh-hotel-bks-lite`；≈0 不得定责）

| Level | 数据源 | 含义 |
|-------|--------|------|
| CS/C/S/CSA | wolf_rateadjust_log | 开关房、调价、提前天数、新上线 |
| CBD/SBD | wolf_rateadjust_log | 预订日期窗口。**CBD = C**（机构窗上的加减价/开关）；detail 必读 `remark` |
| CDH/LCDH | wolf_rateadjust_hotel_log | 机构侧酒店批量调整 / 击穿兜底 |
| SH | wolf_rateadjust_hotel_log | 供应商侧酒店批量（≥10 家） |
| L2L | wolfl2lclientlevelconfiglog | L2L 等级 + BRG。**升级/降级都能打产量，不得标弱**（2026-09-05） |
| CSLRC | wolfl2lconfiglog | 售卖限制 |
| Bottom | bottom_margin_log | 兜底 margin |
| **Configuration** | client_configuration_change_log | Wolf2.0 PPS/QPS/timeout/映射 **14 key**（**第 14 类**） |

### 5.3 信号强度解读

| 情况 | 信号 |
|------|------|
| CS/C **关房** + 时间吻合 + 产量/查价明显下降 | **强** → 支持 Dida |
| **C/CBD 加价** + 查验比↑ + BKS↓ | **强** → Dida 价劣主因；**禁止标弱** |
| Configuration 变更 + 查价结构变 | **强** |
| **L2L 升级或降级**（`last_level`（LAG(level)）≠ `level`） | **中～强** → Dida 面纱主因候选；**禁止标弱** |
| L2L 等级未变（3→3 / 仅刷新惩罚） | **弱** / 背景 |
| 仅小幅调价 **且** B 不同向 | **弱** → 记录，不单定责 |
| 2b=C/Dida，Phase 3 **无任何配置**、查价正常 | → 支持 **C**，交报告收口。**有 CBD/C 加价不得走本条** |

### 5.4 CDH/LCDH/SH 酒店级对比

- CDH/LCDH：只看 **本次 event 涉及的 didahotelid** 的前 7 天 vs 后 N 天 bks/ttv
- SH：只看 **本次 `supplierid`+`supplierhotelid`** 且 **本 client** 的订单；日志 `didahotelid` 恒为 0，禁止抄 CDH
- **优先看 hotel_bks**；机构全量 before/after 会被未变更酒店稀释
- CDH/LCDH 文件：`sql/config-change-detection/cdh-lcdh-hotel-bks.sql`；MCP lite：`detail/07` / `09`
- SH MCP：`detail/08-sh-hotel-bks-lite.sql`（checklist `n≥10` 必跑；`<10` 不解读；`n>50000` 或 500 → Hologres）

### 5.5 查价三层（讨论结论）

- 验证 SQL 实际用：**DidaBiz PPS**（client 级）+ **SS 层**（CS 级）
- **DidaBase 中间层仍没有**

### 5.6 配置 vs 准确率（2026-07-31 定稿）

- **配置变更不影响验价准确率**；准确率 = 接口/技术指标
- 配置线只对接：QPS、有价率、验价量、查验比 → [config-search-precheck-mapping.md](./config-search-precheck-mapping.md)
- 准确率线下钻：`issue_type` → `issue_id` → [accuracy-issue-mapping.md](./accuracy-issue-mapping.md)
- **禁止**用配置/限流/在线表解释准确率
- 辅助表：`rateaccuracy.channel_online_states_new`（在线）、`dws.dws_hotel_flow_didamonitor_supplier_csa_di`（限流 + 缓存，见 §5.9）

### 5.7 A+B+C 综合判断（2026-07-31）

- 文档：[evidence-synthesis-rules.md](./evidence-synthesis-rules.md)
- 供给/竞争力：A×B 配置预期对照 + 在线/限流辅助
- 准确率：C 线独立，**不与 A 混**
- 置信度：已确认 / 倾向 / 待验证 / 后续动作

### 5.8 用户 SQL1/SQL2 入库 + lite（2026-07-31）

- `sql/search-attribution.sql` + `search-attribution-lite/`（7 文件，3b）
- `sql/rate-accuracy-contribution.sql` + `rate-accuracy-contribution-lite/`（13 + issue 2，3c）
- MCP 实测：HBGPKG @ 2026-07-06 — `01-ss-supplier` ✅、`01-total` ✅
- 查验比字段为 **比率**（`check_ratio`），有价率为 **百分比**（`avail_rate_pct`）

### 5.10 限流/缓存触发规则（2026-09-04 #18 定稿）

**查哪些 SID（出数，OR）：**

| 条件 | 分母 | 例 |
|------|------|-----|
| 2b **锁定**的 SID（主锁 + 并列锁定） | — | SnapTravel **26** |
| `02-sid` 占 client **\|ΔBKS\| ≥10%** | **client 总量变化** | SnapTravel **26** 82%、**116** 15.4% |

未锁定且占变化 \<10% → **不查**该 SID。无 SS 行（Agoda/HBGPKG 窗 empty）→ 写「未查（SS 无行）」。

**10% 只决定解读档，不是出数门：**

| SS 有价率或请求量 \|WoW\| | 出表后怎么写 |
|--------------------------|--------------|
| **> 10%**（涨跌双向） | 按下表解读：跌可 **倾向限流/缓存**；涨或请求↓产量↑ → **仅报数**，不单定责 |
| **未过 10%** | 仍出表，标「未达限流异动阈值」，**用于排除限流主因**；禁止写「限流异动」 |

| 3b 异动（\|WoW\| > 10%） | 查 | 已定解读 |
|------------------------|-----|----------|
| **有价率** 涨或跌 | **SS限流率** WoW | 有价率↓ + SS限流率↑ + 无关房 → **倾向限流** |
| **请求量** 涨或跌 | **缓存命中率** WoW | 请求量↓ + 缓存命中率↑ + 无关房 → **倾向缓存替代实发** |
| 结构 SID 但两项均未过 10% | 四列都报 | **排除用**（SnapTravel 26：请求 -6%，仍出表） |

**解读（待研究，可能是特殊情况）：**

| 组合 | 现行解读 | 状态 |
|------|----------|------|
| 有价率↓ + **SS限流率**↑ + 无关房 | **倾向限流** | ✅ 已定 |
| 请求量↓ + 缓存命中率↑ + 无关房 | **倾向缓存替代实发** | ✅ 已定 |
| 有价率↑ / 请求量↑ 等同向或反向组合 | — | 🔲 **待研究**；仅报数，不单定责 |
| **请求量↓ 但产量↑**（如 SnapTravel2B 116-EPS） | — | 🔲 **特殊情况**；记录 WoW，**不得**推翻 2b/3d 主因 |

**案例：** SnapTravel2B @ 2026-08-01 — **26** 结构 82%、SS 请求未过 10% → **仍出数、排除限流**；**116** 结构 15.4% 且请求过 10% → 出数、涨产仅报数。

### 5.11 渠道在线时长（2026-09-04 定稿）

- 表：`rateaccuracy.channel_online_states_new`；lite：`sql/online-hours-lite/`
- **status：0=下线动作，1=上线动作**；时间用 `channel_operation_time`
- **触发：** DidaBiz QPS/PPS **\|WoW\| > 10%**（与限流同阈值）
- **异动：** 当前窗日均 online_hours 比对比窗 **少 ≥ 2 小时**
- **窗口：** 与 Phase 1 当前期/对比期 **完全对齐**
- **source 可信度：** **邮件解析=完全可信**；**数据库分析=仅参考**，不得强定责 C 下线
- **因果链：** **在线时长↓ → 查价↓**（只解释漏斗上段）；产量方向 **须看转化**（转化↑时查价↓仍可 BKS↑，见 SnapTravel2B gold）
- **计算（2026-09-09）：** MCP 默认 `03-window-avg.sql` / `online-hours.sql`（单 client 开窗；库内 timestamptz 用 `AT TIME ZONE`，禁止 `to_timestamp(ms/1000)`）。禁止手算。仅当仍 500 才拉 log + `test-online-hours.py`。禁止无 client 扫全表。
- **#22（2026-09-09 ✅）：** 以 MCP 单 client 开窗收口，不再等全客户物化表。全客户 Hologres SQL 可选、不阻塞。
- 全文：[online-hours-mapping.md](./online-hours-mapping.md)

### 5.12 3c 准确率启动（2026-09-04 #19）

- **每案必跑** `rate-accuracy-contribution-lite/01-total.sql`
- **启动：** `\|item_accuracy_delta_pp\| ≥ 5`（百分点，涨跌双向）→ 对齐 2c 跑维 + issue_type → issue_id
- **未启动：** <5pp = 「已探测、未启动」（无线索的唯一定义）
- **禁止**用 precheck 量代替；MCP 失败标未验，不得写无异常
- 启动后不推翻 2b/3a/3b；准确率↑禁止解释涨产。全文：[accuracy-issue-mapping.md](./accuracy-issue-mapping.md)

### 5.9 SS 限流率 / 缓存命中率（2026-09-04 更新）

- 表：`dws.dws_hotel_flow_didamonitor_supplier_csa_di`；lite：`sql/rate-limit-lite/`
- **聚合：** client × supplier × 窗口，**SUM 全部 supplieraccountid**，**不筛 biztype**
- **公式（2026-09-04 定稿）：**
  - **SS限流率** `SUM(limit_requests_num) / SUM(requests_num)` — **废弃** `not_limit_requests_num` 及 `1 - not_limit/requests`
  - 缓存命中率 `SUM(fromcache)/SUM(all)` — **不变**
  - **SS通过率** `SUM(pass)/SUM(requests)` — **背景信号**，不单定责
  - **命中只吐缓存率** `SUM(read_only_cache)/SUM(requests)` — **背景信号**，不单定责（≠ 缓存命中率）
- **恒等式：** `limit + pass + read_only_cache ≈ requests`
- **触发：** 见 §5.10 — **结构 SID 必出数**（锁定或占 \|ΔBKS\|≥10%）；SS 有价/请求 \|WoW\|>10% 只决定解读档。无结构贡献则不查
- **窗口对齐** `clientsupplierhotelcallcountsummary.date`；**不做**「请求量↓ + 缓存命中率↓」反向规则
- 详见 [config-search-precheck-mapping.md](./config-search-precheck-mapping.md) § SS

### 5.6 外部事件（2026-09-04 定稿 · 仅 HOLIDAY）

- 表：`ads.ads_marketing_calendar_event_wide_d_f`；lite：`sql/external-events-lite/`
- **快照 `MAX(dt)`**；**Dida 全局**，禁止与 client 交叉定责
- **类型（归因）：** **仅 `HOLIDAY`**（`city_rank_no<=30`）；**不查** FAIR / CONCERT / WEATHER
- **触发：** **先跳过再必查**。A/B 已达「强」（含 2b=S 且验证 B 平台共涨/跌已钉）→ **不查 D**。否则 P0（2b 倾向 C/Dida 且 A/B 弱）或 P1（单国 ≥10% / 涨产 Top ≥70%）
- **取国：** C/Dida → `4_Country`；**S/CS → `5_SID+Country`**（锁定 SID；≥10% 分母=该 SID 变化）
- **MCP：** 一国一窗；详见 [external-events-mapping.md](./external-events-mapping.md) §5
- **D2（可选）：** seed + `02-holiday-yoy-bks-lite.sql`；**MVP 用 create 口径**；**未来**节日窗改 `checkoutdate`（§10.9）

### 5.7 文件

- `sql/config-change-detection.sql`（完整 ~724 行）
- `sql/config-change-detection-lite/`（MCP 分批）
- `sql/search-attribution-lite/`、`sql/rate-accuracy-contribution-lite/`（3b/3c MCP）
- `phases/03-evidence-verification.md`

---

## 6. Phase 4：报告收口

- 阶段标题是 **报告收口**；报告里跟进节叫 **后续动作**（不要把阶段名写进 H2）
- 2b=C/Dida 且 Phase 3 无强信号 → **倾向 C**；后续动作按 [es-cause-catalog.md](./es-cause-catalog.md)（B2），禁止空问流量
- **报告骨架（#27）：** 复制 `phases/04-report-skeleton.md` 只填空；验收 `scripts/check-report-skeleton.py`。只锁格式，不改定责口径。
- **#5（2026-09-14 ✅）：** ES 后续动作查目录。主因不改。A6：QPS/PPS 上限只打有价。D 组兑现禁止套 B2 问渠道。不强制回改 gold。

---

## 7. 已跑案例（测试记录）

| 案例 | 日期 | 要点 |
|------|------|------|
| **Agoda** | 2026-03-20 | Phase 1 跌 -16.5%；2b=C/Dida（70.7% 降）；14/14 无强配置；gold：`examples/gold-agoda-20260320.md` |
| **NuiteeLMB / DidaOpaq** | 7/29 | 14 类信号测试（见 examples/） |
| **HBGPKG** | 2026-07-06 | 正常波动 -7.8%；CS+S 并列；gold：`examples/gold-hbgpkg-20260706.md` |
| **HBGPKG** | 2026-07-10 | 正常波动 -11.4%；Meituan 223→20 CS 崩量；gold：`examples/gold-hbgpkg-20260710.md` |

---

## 8. 待办入口（#21：不再另开清单）

**唯一待办源：** [backlog.md](./backlog.md)

禁止在本文或 `ROADMAP.md` 再抄一份 #N 表。新想法追加到 backlog「扩展项」。开新对话用 backlog 里的模板，不要从本节挑过期条目。

---

## 9. 改 Skill 时的启动方式（跑归因的同事跳过）

1. Cursor **Open Folder** 打开本 Skill 目录（不要写死某人本机 `C:\Users\...` 路径）。
2. 新 Agent 对话，首条消息示例：

```
请读 attribution-analysis skill（SKILL.md + docs/backlog.md + docs/decisions-summary.md），
我们要做 backlog #N：[标题]。
```

3. 关键文件：`SKILL.md`（跑归因入口）、`docs/backlog.md`（维护待办）、本文（已拍板）、`ROADMAP.md`（架构，非待办）。不要再寻找对话导出。
