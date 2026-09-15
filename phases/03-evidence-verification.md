# Phase 3：内部证据验证

> 状态：SQL 已定稿；**14 类逐项必查**为强制 SOP。Phase 2 完成后执行。**无 `client_id`（大盘）禁止进入** 3a / 在线 / 限流。  
> **MCP 硬规则：** 禁止手写 SQL 替代 checklist/detail；禁止跑 `03-fourteen-level-checklist.sql` 及任何 14 路 / 多表 UNION。一次 MCP = 一个文件原文。

## 目标

用**可观测的内部数据**验证或修正 Phase 2 的责任方向，重点是把 **「C 或 Dida」拆成 C vs Dida**。

| 证据线 | 数据源 | 对接指标 | 指向 |
|--------|--------|---------|------|
| **A 内部配置** | config-change-detection-lite | QPS、有价率、验价量、查验比 | **Dida** |
| **B 查价归因** | `search-attribution-lite/` | 有价率、查验比 | Dida / CS / 竞争力 |
| **C 验价准确率** | `rate-accuracy-contribution-lite/` + issue | **仅准确率** | 接口/链路/渠道数据 |
| D 外部事件 | `ads.ads_marketing_calendar_event_wide_d_f` | — | **C**（HOLIDAY；触发见 mapping §5） |

每条证据标注：**强佐证 / 弱佐证 / inconclusive**

### ⚠️ 硬规则：配置线与准确率线不得混淆

- **配置变更不影响验价准确率。** 14 类配置、限流表、在线时长表 **不得** 用于解释准确率变化。
- 配置 → 查价量 / 有价率 / 验价量 / 查验比。见 [docs/config-search-precheck-mapping.md](../docs/config-search-precheck-mapping.md)
- 准确率 → `issue_type` / `issue_id` 独立下钻。见 [docs/accuracy-issue-mapping.md](../docs/accuracy-issue-mapping.md)

---

## 证据线 A：14 类内部配置

完整 SQL：`sql/config-change-detection.sql`  
片段说明：`sql/config-change-detection/README.md`

### 核心概念

| 概念 | 含义 |
|------|------|
| **调价** | 各 level 的 margin 叠加 → 最终 Markup；影响价格竞争力 |
| **开关房** | 链路中断（如 Agoda–EPS CS 关房 → 查价/下单不通） |
| **兜底 Bottom** | C/S 级 markup 下限；S Bottom 影响产量 |
| **LCDH** | 机构酒店级击穿 C Bottom（**新增/删除**击穿兜底名单中的 hotel） |

### 14 类 level 清单

| Level | 含义 | 数据源 |
|-------|------|--------|
| CS | ClientSupplier 链路：开关房/调价/新 supplier | wolf_rateadjust_log |
| C | Client 机构 | wolf_rateadjust_log |
| S | Supplier 全局 | wolf_rateadjust_log |
| CSA | ClientSupplierAccount | wolf_rateadjust_log |
| CBD | Client 预订日期窗口期 | wolf_rateadjust_log |
| SBD | Supplier 预订日期窗口期 | wolf_rateadjust_log |
| CDH | Client × DidaHotel 批量 | wolf_rateadjust_hotel_log |
| SH | Supplier × SupplierHotel 批量（≥10 家） | wolf_rateadjust_hotel_log |
| LCDH | 击穿 C Bottom（机构酒店） | wolf_rateadjust_hotel_log |
| L2L | LevelToLevel 面纱 | wolfl2lclientlevelconfiglog |
| CSLRC | 机构特殊售卖限制 | wolfl2lconfiglog |
| C Bottom | 机构兜底 margin | bottom_margin_log |
| S Bottom | 供应商兜底 margin | bottom_margin_log |
| **Configuration** | Wolf2.0 系统参数（PPS/映射等） | client_configuration_change_log |

Configuration 监控 **14** 个 **Wolf2.0配置** key（`created_at`；mandatory fees 必须是 **`DidaHotelMandatoryFeesConfig`**，不是 Confg）。

- **查价容量：** `MultiHotelPriceSearchRealTimePPS`、`SingleHotelPriceSearchRealTimePPS`、`PriceSearchCachePPS`、`PriceConfirmQPS`、`HotelSearchTimeout`、`RatePlanSearchTimeout`、`MultiHotelRealTimeSearchCount`、`MultiHotelCacheSearchCount`
- **房型 Top：** `MappedRoomTypeTopCountForOptimalCancellationBreakfast`、`UnmappedRoomTypeTopCountForOptimalCancellationBreakfast`、`MappedRoomTypeTopCountForBreakfastCancellation`、`UnmappedRoomTypeTopCountForBreakfastCancellation`
- **其他：** `IgnoreChineseCode`、`DidaHotelMandatoryFeesConfig`

不加 IP/License/币种等。n>0 跑 `detail/14-configuration-detail.sql`；PPS/QPS 变了须 3b 同向才强。

**术语（禁止混称「白名单」）：**

| 叫法 | 是什么 | 禁止叫 |
|------|--------|--------|
| **Wolf2.0配置** | Configuration 这 14 个 key | 白名单 |
| **击穿兜底名单** | LCDH 新增/删除的 hotel | 白名单 |
| **机构供应商白名单** | #23，client×supplier 供给快照，未纳入 3a | —（仅此项可用「白名单」） |

**机构供应商白名单（#23 · 未纳入）：** 可能影响 CS 供给/产量，但库里目前是 **当前配置快照，不是变更日志**，窗口内无法 before/after。**禁止**查快照当 3a 证据。等用户与技术落成日志表后再加 checklist。勿与 LCDH 击穿兜底名单、勿与 Wolf2.0配置、勿与 Skill 权限白名单混称。

### ⚠️ 14 类逐项必查（强制，不可省略）

**规则：**

1. Phase 3 **必须输出 14 行清单**，每一 level **一行**；`event_count=0` 也要写「无」并标 ✓，**禁止只报 CS/C/CDH**。
2. **执行顺序（MCP 分批）：**
   - **Step A** 逐条跑 `sql/config-change-detection-lite/checklist/01-cs.sql` … `14-configuration.sql`（**禁止** UNION 版 `03-fourteen-level-checklist.sql`）
   - **Step A'** 跑 `02-client-before-after-bks.sql` 取机构级产量
   - **Step B** 对 `event_count > 0` 的 level，按 `sql/config-change-detection-lite/README.md` Step 3 表跑列出的 detail 路径（**CBD 必跑** `detail/05-cbd-detail.sql`，**必须读 `remark` + 比 last_margin**；**S Bottom 必跑** `detail/13-s-bottom-detail.sql`，**禁止抄 C Bottom**）。10/11/04 必须 Read `detail/10-l2l-detail.sql`、`detail/11-cslrc-detail.sql`、`detail/04-csa-detail.sql`；禁止手写 last_level 列。
   - **Step B'（CDH/LCDH/SH 必跑）** CDH/LCDH：`event_count > 0` 跑 **`detail/07-cdh-hotel-bks-lite.sql`** / **`detail/09-lcdh-hotel-bks-lite.sql`**。SH：`event_count ≥ 10` 跑 **`detail/08-sh-hotel-bks-lite.sql`**（JOIN `supplierid`+`supplierhotelid`，禁止 `didahotelid` / `clientid` 滤日志；`<10` 不跑不解读；`>50000` 或 MCP 500 → BI）。均为 WITH 酒店清单 join 订单，按 SID/`didahotelid` 聚合 `before/after_hotel_bks`。
   - **Step C** 可选 `search/01-didabiz-pps-daily.sql` 查价（按日，比跨日 SUM 稳定）
3. 完整 SQL 末尾有 `before/after_bks > 0` 过滤 → **无产量行的配置会消失**；以 Step A 为准补全清单，Step B 补产量证据。
4. MCP 分步探测时，**按下面 14 行表逐条打勾**，不得合并为「其他无」。
5. **禁止手写替代 checklist（硬规则）：** MCP `execute_sql` 的 `sql` 参数 **必须** 来自 `Read checklist/NN-*.sql` → 替换 `{client_id}` 等占位符后的 **原文**；**禁止**凭记忆、类比其他 level、或「看起来差不多」自行写 SQL。
   - **错例（CVCTrend 回归）：** #12 手写 `clientid='…'`（`bottom_margin_log` 应为 **`item`**）；#14 手写 `updatedate`（应为 **`created_at`** + 14 key）；6 表 UNION 批量查 9–14 → 假 500。
   - **错例（S Bottom）：** 抄 `12-c-bottom-detail.sql` 用 `update_by` → **必 500**。必须 Read `detail/13-s-bottom-detail.sql`（`update_user`；`item` = 供应商号）。
   - **500 时：** 先 **Read 对应 checklist 文件** → 用原文 **重试 1 次**（可缩窗）→ 仍 500 才标 **「MCP 500 · 未验」**；**禁止**未读文件就把失败归因于「MCP 不稳定」。
   - **成品报告：** 3a **不写**来源文件列、**不开附录**。执行仍必须 Read checklist 原文（本规则）；MCP 500 写在对应节解读，不单独开附录。

| # | Level | 必查数据源 | 清单字段 |
|---|-------|-----------|----------|
| 1 | CS | wolf_rateadjust_log | 条数 / 开关房·调价 / before→after bks |
| 2 | C | wolf_rateadjust_log | 同上 |
| 3 | S | wolf_rateadjust_log | 同上 |
| 4 | CSA | wolf_rateadjust_log | 同上 |
| 5 | CBD | wolf_rateadjust_log | 与 C **同级**。开关房 / 加价 / 降价 + **remark** |
| 6 | SBD | wolf_rateadjust_log | 窗口期操作 |
| 7 | CDH | wolf_rateadjust_hotel_log | hotel_cnt / **hotel_bks** |
| 8 | SH | wolf_rateadjust_hotel_log | **结构 SID**（`{sid_list}`）+ **hotel_bks**（≥10 才跑/解读） |
| 9 | LCDH | wolf_rateadjust_hotel_log | 增删 / **hotel_bks** |
| 10 | L2L | wolfl2lclientlevelconfiglog | 等级变化。**升级/降级不得标弱**（见 mapping） |
| 11 | CSLRC | wolfl2lconfiglog | 限售 islimit |
| 12 | **C Bottom** | bottom_margin_log (Client) | **margin 变化（机构全量）** |
| 13 | S Bottom | bottom_margin_log (Supplier) | margin 变化 |
| 14 | Configuration | client_configuration_change_log | 14 key |

**SH 特别提示：**

- 表无可用 `clientid`（加上会变成 0）。**禁止** `clientid` 过滤，**禁止**不带 SID 扫全表。
- 跑 08 前必须已有 2b。`{sid_list}` = 锁定 SID 或占 \|ΔBKS\|≥10% 的 SID；没有则 02-sid \|change\| Top3。
- **`event_count ≥ 10` 必跑** `detail/08-sh-hotel-bks-lite.sql`（映射 `supplierid`+`supplierhotelid`；日志 `didahotelid` 恒为 0，禁止抄 CDH）。
- `<10` 不跑 hotel_bks、**不解读**；不得把零散酒店行写成主因。
- **解读优先 `before_hotel_bks` / `after_hotel_bks`**（仅变更酒店、且仅本 client）。平台 SH 打到本机构产量常为 0。
- **after_hotel_bks ≈ 0** 且机构 BKS 大涨/大跌 → 信号 **弱 / inconclusive**，禁止写「SH 定责」。
- MCP 500 或 checklist `n>50000` → 人去 Hologres 跑同一 SQL，禁止当 0。

**CDH / LCDH 特别提示：**

- checklist `event_count` = **酒店行数**（批量开房可达万级），不是操作次数。
- **`event_count > 0` 必跑** `detail/07-cdh-hotel-bks-lite.sql` / `detail/09-lcdh-hotel-bks-lite.sql`（MCP 单行聚合；WITH 清单 join 订单）。
- **解读优先 `before_hotel_bks` / `after_hotel_bks`**（仅变更酒店）；机构全量 before/after 会被稀释。
- **批量开房但 after_hotel_bks ≈ 0** → 信号 **弱 / inconclusive**，禁止写「CDH/LCDH 导致涨/掉产」。
- MCP 500 或超大规模仍失败 → BI `cdh-lcdh-hotel-bks.sql`。

**S Bottom 特别提示：**

- 与 C Bottom **同表**，列不同。`item` = **供应商号**（不是 client）。操作人 = **`update_user`**（不是 `update_by`）。
- `event_count > 0` 必跑 **`detail/13-s-bottom-detail.sql`**。**禁止**抄 `12-c-bottom-detail.sql`（Check24 / DidaOpaq 曾因此 500）。
- checklist 仍为 **全局 Supplier**（不加 client、不加 `{sid_list}`）。明细 `LIMIT 30`。

**C Bottom 特别提示（高优先级）：**

- 作用于 **整个 client 所有 supplier**，不是单条 CS；**机构级 markup 下限**变更，可能解释「多 supplier 同向」或「大 supplier 波动」。
- margin **上调**（兜底下调数值变大）→ 可卖价抬高 → 产量易降；**下调** → 反之。
- 窗口内 **连续多次调整**（如 5.4→5.6→5.5→5.4）仍算 **一条强线索**，需在清单单独列出每次变更时间与方向。
- 信号强度：时间吻合 + margin 变动 + 机构产量/查价同向 → **强～中**（与仅 CS 小 supplier 关房但 0 单不同）。

Lite 扫描脚本：`sql/config-change-detection-lite/checklist/`（14 个单文件，见该目录 README）

---

### 按 Phase 2b 结论的**展示顺序**（#26 · 不是 level 排行）

必查 14 类全部完成后，**按作用域收口**，禁止「开关房 > 调价」或「C 先于 CBD」。

```
1. 先写本窗「机构」且操作 ∈ 关房 / 加价 / 等级变 / Configuration PPS
2. 再写「链路」且产量对得上的关房 / 加价
3. 再写供应商 / 酒店批
同作用域内关房与加价并列。
```

**C 或 Dida** — 机构（C / **CBD** / C Bottom / L2L / Configuration）先于链路、酒店。  
**CS** — CS / CSA，关房与加价同等。  
**S** — S / S Bottom / SH。

### 配置评级：作用域 × 操作（#26）

**禁止**给 14 个 level 各打固定高/中/低。分值跟 **这一条日志的操作 + B 方向** 走。

```
Phase 3a 进度:
- [ ] 14/14 checklist（Read 原文；**SH 必填 {sid_list}**）
- [ ] n>0 跑 detail（CBD=05-cbd-detail；CS/C 含 remark）
- [ ] CDH/LCDH n>0、SH n≥10 跑 hotel_bks；≈0 不得定责
- [ ] 14 行填满：操作枚举 + 作用域 + Δmargin/remark + 信号
- [ ] 倾向 C 出门禁打勾；不通过则主因不得写 C
```

**作用域：**

| 作用域 | level | 14/14 SID 同降时 |
|--------|-------|------------------|
| **机构** | C、**CBD**、C Bottom、L2L、CSLRC、Configuration | 默认能解释全 SID，**主因候选** |
| **链路** | CS、CSA | 产量对得上该 SID；零单 → 弱 |
| **供应商** | S、SBD、S Bottom、SH | 验证 B 多 client 才定 S；**SH 看 hotel_bks**，≈0 → 弱 |
| **酒店批** | CDH、LCDH | 看 `hotel_bks`，≈0 → 弱 |

**操作枚举（必填，只许这些词）：** `关房 | 开房 | 加价 | 降价 | 等级变 | 限售 | 其他 | 无 | 未验`

**操作怎么认（同一条日志只取一个，按序）：**

1. `status` **1→0** → **关房**（同时调了 margin 也认关房）
2. `status` **0→1** → **开房**
3. 否则比 `last_margin`：cur > last → **加价**；cur < last → **降价**
4. `last_margin` 空，但 remark 含「加价 / 限制产量 / 提价」→ **加价**；含「促销 / 降价 / promo」→ **降价**
5. L2L：`last_level（LAG(level)）` ≠ `level` → **等级变**；相等 → **其他**
6. CSLRC：detail 按 SID 聚合。`n_limit>0` → **限售**；仅 `n_open>0` → **其他**。条数以 checklist COUNT 为准
7. Configuration 监控 key 有变更 → **其他**（信号按 PPS/QPS mapping）
8. 对不上 → **其他**；n=0 → **无**；MCP 500 → **未验**

`status=1` **不是**操作名。开着的窗上调 margin = 加价/降价。禁止信号列写「开窗/调价」。

**`last_margin`（禁止猜）：**

| level | 比什么 |
|-------|--------|
| C / CS / CSA | 同一 client（+ supplier / account）按 `updatedate` 的上一条 |
| CBD | 同一 client + 同一预订窗的上一条；没有则该 client **上一段 CBD** |
| C Bottom | 同一 `item` 上一条 |

CBD/C `n>0` 且 detail 只有当前 margin → 再查历史 `ORDER BY updatedate DESC LIMIT 5`。**不要**把 LAG 写进 checklist。

**一行 level 多条日志：** 跌产填最狠的（关房 > 加价 > 其它）；涨产填开房 > 降价 > 其它。其余 footnote。相对对比期仍贵的「回撤」**禁止**主操作写成降价。

**B 同向（方向表，不钉 +10%/−2pp/0.5）：** 见 [config-search-precheck-mapping.md](../docs/config-search-precheck-mapping.md)。  
跌产：加价兑现 = 查验比↑或验价↓；关房兑现 = 有价率↓；等级变兑现 = BKS 同向。  
涨产：降价兑现 = 查验比↓或验价↑；开房兑现 = 有价率↑。  
同向 → 强（可主因）。反向 → inconclusive / 「降价未拉回」，**禁止**「已确认」也**禁止**假装无配置。

**3a 14 行必填列：** `# / Level / n / 操作(枚举) / 作用域 / Δmargin 或 remark / 信号`（**7 列**，不写 SQL 路径）  
缺一列 = 3a 未收口。`n>0` 必跑 detail；wolf **必须读 remark**。执行按 checklist 原文，路径不进成品报告。

**写「倾向 C / 证据支持 C」出门禁（按操作选行；全部通过才准写 C）：**

- [ ] 机构操作 **没有** 关房 / 加价 / 等级变 / Configuration PPS
- [ ] 若有加价：B **未**按加价兑现（查验比未↑ 且 验价未↓）
- [ ] 若有关房：B **未**按关房兑现（有价率未↓）
- [ ] 链路关房/加价要么零单，要么已写入并列（不得写「无配置」）

有机构加价且查验比↑（或验价↓）→ 走合成序号 3，**出门禁不通过**。

### CDH / LCDH / SH 酒店级产量

| 字段 | 粒度 | 用途 |
|------|------|------|
| `before_bks_compare_window` / `after_*` | Client 或 CS 全量 | 原逻辑，易被非变更酒店稀释 |
| `before_hotel_bks` / `after_hotel_bks` | CDH/LCDH：**仅本次 didahotelid**；SH：**仅本次 supplierid+supplierhotelid 且本 client** | 解读时**优先看** |
| `affected_hotel_count` | 变更酒店数 | 判断批量幅度；SH `<10` 不解读 |

**SH** 映射用订单的 `supplierid`+`supplierhotelid`，禁止抄 CDH 的 `didahotelid`（SH 日志该列恒为 0）。lite：`detail/08-sh-hotel-bks-lite.sql`。

---

## 「确认 Dida」是什么意思？（判定标准）

之前问的「关房 + after_bks 降 >30% 还是人工读 operation」，不是要你们定一个**自动定责的硬阈值**，而是 Phase 3 **输出什么、怎么读**。

### 推荐做法：清单 + 人工/Agent 解读（不做单一硬规则）

Phase 3 **不自动改写成「确认 Dida」**，而是输出**配置证据清单**，每条带：

- level、category、operation 文案
- 变更时间 vs 异动窗口是否吻合
- before/after bks、查价（CDH/LCDH/SH 再加 hotel_bks）

**读证据时的信号强度：**

| 信号 | 强度 | 说明 |
|------|------|------|
| CS/C/CSA **关房** + 时间吻合 + after 产量/查价明显下降 | **强** | 链路中断，优先怀疑 Dida 配置 |
| **C / CBD / C Bottom 加价** + 时间吻合 + 机构 **查验比↑**（avail 稳、rp↓）+ BKS↓ | **强** | **Dida 价劣**，可作主因。**禁止标弱**。`status=1` 不是「开窗所以弱」 |
| **C / CBD 降价** + 验价↑ / 查验比↓ | **强～中** | 涨产同向；跌产则「降价未拉回」 |
| **Configuration** PPS/映射类变更 + DidaBiz 查价结构变化 | **强** | 系统性，影响整个 client |
| **C Bottom** margin 变更 + 时间吻合 + **机构级**产量/查价同向 | **强～中** | 影响全 supplier，优先于零单 CS |
| S Bottom / LCDH 变更 + 产量方向一致 | **中** | 需结合 markup 方向 |
| 仅 **小幅**调价 **且** B 不同向（查验比/验价无明显变） | **弱** | 记录但不单独定责 |
| 有配置变更但 before/after **无一致方向** | inconclusive | 可能是 coincident，不能定责 |

**与 Phase 2b 的关系：**

- 2b = **C 或 Dida** + Phase 3 发现 **C/CBD/CS/Configuration** 等内部配置 → 报告写 **「证据支持 Dida（配置）」**，从「C 或 Dida」中排除纯 C
- 2b = **C 或 Dida** + Phase 3 **无任何配置** + 查价正常 → 报告写 **「证据支持 C（渠道侧）」**，移交报告收口
- 2b = **C 或 Dida** + **CBD/C 加价** + 查验比同向 → **Dida（价劣）主因**，**禁止**再走「倾向 C」
- 2b = **CS** + Phase 3 发现 **CS 关房或加价** → **确认 Dida（CS 链路配置）**

不需要统一「30%」阈值。关房与加价/降价 **同等**，禁止把调价默认成弱。

---

## 证据线 B/C：查价与验价（查验订）

> 术语：**BKS** = 订单（Bookings）；**Search** = 查价；**Prebook / RP** = 验价（RatePlan，与 Prebook 等价，叫法不同）。

### 请求链路

```
渠道 ──查价(Search)──▶ Dida ──向多 supplier 询价──▶ 取最低价 ──▶ 返回渠道
                              │
渠道 ──验价(Prebook/RP)──▶ Dida ──向最低价 supplier 验价 ──▶ 准确则返回 ──▶ 下单(BKS)
```

- **查价**只反映「能不能返回有价」，**不能**反映价格是否有竞争力（此时渠道尚未看到价格）。
- **验价量**才反映竞争力：渠道看到价格后，认为有优势才会发起验价（类似 Dida 在多个 supplier 中选最低价）。
- 例：渠道每天 10000 次查价，昨日 2000 次验价、今日 1000 次验价 → 可能是价格相对竞对失去优势。

### didamonitor 三层（中间层）

| 层 | 视角 | 与配置层级对应 | 说明 |
|----|------|---------------|------|
| **DidaBiz** | 渠道侧 | **C**（机构） | 请求刚进入，尚无 supplier 信息 |
| **DidaBase** | Client×Supplier | **CS** | 已匹配多个 supplier，向它们要价 |
| **SS** | 供应商侧 | **S** | 真实发往 supplier 的请求 |

**注意：** DidaBiz / DidaBase / SS 的**请求绝对量不可跨层对比**（下层因 supplier 匹配会膨胀）。比率类指标须在**同一层、同一 scope** 内比较。

**验价特殊规则：** `total_rp` 在各层**数值相同**（验价为 Dida 对 Supplier **一对一**）；分子分母必须同一 scope（同 client、同 supplier、同时间窗、同层）。

### 核心指标

| 指标 | 分子 | 分母 | 含义 | 能否反映竞争力 |
|------|------|------|------|---------------|
| **查价有价率** | avail_search | total_search | 查价中有多少返回有价 | ❌ |
| **验价准确率** | success_rp | total_rp | 验价中有多少返回准确 | 部分（准确性，非意愿） |
| **查验比** | avail_search | total_rp | 有价查价 vs 验价量 | ✅ **反映价格竞争力** |

字段命名（与现有 SQL / 表对齐）：

| 业务名 | 常见字段 |
|--------|---------|
| total_search | `client_pps`（DidaBiz）/ `hotelcallamount`（SS） |
| avail_search | `available_client_pps` / `availcallamount` |
| total_rp | 待补充 SQL |
| success_rp | 待补充 SQL |

时间对齐：**天维度** WoW 对比即可，无需 Search→Prebook 滞后对齐。

### 层级选用（归因时）

| Phase 2b 定责 | 查价优先层 | 当前实现 |
|---------------|-----------|---------|
| **C 或 Dida** | DidaBiz | `ads.ads_hotel_monitor_rate_search_statistic_by_client_id` |
| **CS** | DidaBase（理想） | **`clientsupplierhotelcallcountsummary`（SS 层，近似 CS 视角）** |
| **S** | SS | 同上表，supplier 维度 |

> **SS 近似 CS：** 现有 `config-change-detection.sql` 中 CS 级查价变量名为 `ss_*`，数据源为 `public.clientsupplierhotelcallcountsummary`（SS 层汇总到 client×supplier）。在 DidaBase 专用表就绪前，**用 SS 近似 CS 视角**做查价有价率与查验比分析。DidaBase 表 / 验价聚合 SQL 由业务方后续补充。

### 解读顺序（两条并行线，勿混淆）

**供给 / 竞争力线（3a + 3b，含配置预期）：**

```
BKS 降
  → 同 scope 查价有价率 ↓？  → 供给/关房/链路
  → 同 scope 查验比 ↓？       → 价格竞争力（加价等）
  → 同 scope QPS ↓？          → 在线时长 / 需求 / 渠道请求逻辑
  → 有价率动而总量几乎不动？   → Configuration 上限（A6）或关房
```

**准确率线（3c，独立）：** 每案 `01-total`；`\|Δpp\| ≥ 5` 才下钻。

```
准确率 |Δ| ≥ 5pp
  → 对齐 2c 跑维 → issue_type 占比 → issue_id 细因
  → 接口/技术指标/渠道数据修正（并列，不单定责产量）
  → ❌ 不查配置 checklist、限流表、在线表
< 5pp → 已探测、未启动（= 无线索）
```

配置→指标预期全文：[config-search-precheck-mapping.md](../docs/config-search-precheck-mapping.md)

### 证据线 B：查价归因（SQL1 lite）

| 资源 | 用途 |
|------|------|
| `sql/search-attribution.sql` | BI 完整版（7 路 UNION + precheck join） |
| `sql/search-attribution-lite/` | **MCP 分批**（有价率 + 查验比） |

| 配置粒度 | 查价表 | lite 文件 |
|---------|--------|-----------|
| C 级 PPS | `ads.ads_hotel_monitor_rate_search_statistic_by_client_id` | `00-client-total.sql` |
| C 级 PPS 维 | `didamonitor_funnel_client_country/chain` | `02/03-*.sql` |
| C 级 QPS 维 | `clientloscallcount` 等 | `04/05/06-*.sql` |
| CS/SS | `clientsupplierhotelcallcountsummary` | **`01-ss-supplier.sql`（必跑，必填 `{sid_list}`）** |

验价量来自 `rate_accuracy_channel_multi_dimension`（与 SQL1 同窗口 join）。

### 证据线 C：验价准确率（SQL2 lite + issue 下钻）

| 资源 | 用途 |
|------|------|
| `sql/rate-accuracy-contribution.sql` | BI 完整版（13 层 + within_contribution_pp） |
| `sql/rate-accuracy-contribution-lite/` | **MCP 分批** |
| `rate-accuracy-contribution-lite/issue/` | issue_type → issue_id |

验价 1:1 发 supplier。**准确率不受配置影响**，见 [accuracy-issue-mapping.md](../docs/accuracy-issue-mapping.md)。

---

## 证据线 D：外部事件（→ C）

表：`ads.ads_marketing_calendar_event_wide_d_f`  
Lite：`sql/external-events-lite/`  
规则：[external-events-mapping.md](../docs/external-events-mapping.md)

- **快照：** `MAX(dt)`；**Dida 全局**（禁止与 client 产量交叉定责）
- **默认类型：** **仅 HOLIDAY**（`city_rank_no <= 30`）；**排除** WEATHER / FAIR / CONCERT
- **触发：** 先跳过（A/B 已强）再 P0/P1；**S/CS 取国用 `5_SID+Country`**，C/Dida 用 `4_Country`。详见 [external-events-mapping.md](../docs/external-events-mapping.md) §5
- **MCP：** 一国一窗，跑 `01-single-country-window.sql`

---

## Agent 执行 SOP

```
1. 读取 Phase 2b 结论（C/Dida | CS | S）— 仅初判，3d 可修正
2. 【3a 配置】02-client-before-after-bks + checklist/01–14 → **必须 14/14 行**（MCP 逐文件）
3. 【3a】event_count>0 → 按 lite README Step 3 表跑列出的 detail；对照 config-search-precheck-mapping 预期指标
4. 【3b 查价】强制顺序：
   a. **2b = C/Dida 或涨产待区分** → 先 `00-client-total`（机构 **查价**，ads 表）；仍 500 → **`00a`+`00b`**（`didamonitor_funnel_*` 加总 fallback，见 search-attribution-lite README「术语」）
   b. 再 `01-ss-supplier`（**必填 `{sid_list}`**，与 SH 同一套；禁止全表 LIMIT 50 写「未覆盖涨尾」）
   c. 对齐 2c Top 维 → `02-didabiz-pps-country` 等
   d. 机构级 precheck 总量：rate_accuracy client 聚合（与 00 同窗，手算查验比）
5. 【3c 准确率】**每案**先 `rate-accuracy-contribution-lite/01-total.sql`。`\|item_accuracy_delta_pp\| ≥ 5`（pp）→ 按 2c 路径跑维 + `issue/01` + `issue/02`；未过线写「已探测、未启动」。禁止用 precheck 量代替。独立，不混配置。见 [accuracy-issue-mapping.md](../docs/accuracy-issue-mapping.md)
6. 辅助（限流/缓存）：**结构 SID 必出数**（2b 锁定或占 \|ΔBKS\|≥10%）→ `rate-limit-lite/01-ss-supplier-window.sql` **必填 `{sid_list}`**（与 SH / `01-ss-supplier` 同一套）。禁止全表 `ORDER BY`+`LIMIT 50` 代替结构 SID。SS 有价/请求 \|WoW\|>10% 只决定解读档。见 §5.10（涨方向/请求↓产量↑ **待研究**，仅报数；未过 10% 仍出表作排除）
6b. 辅助（在线时长）：**DidaBiz QPS/PPS \|WoW\| > 10%**（涨跌双向）或需排除渠道下线 → `online-hours-lite/03-window-avg.sql`（**必填 client_id**；窗口 = Phase 1）。禁止手算。MCP 500 才 fallback 拉 log + `scripts/test-online-hours.py`。**异动：日均少 ≥2h**。source/remark 用 `04-window-source.sql`。**邮件解析** 可信；**数据库分析** 仅辅助。**因果：在线↓→查价↓ only**。见 [online-hours-mapping.md](../docs/online-hours-mapping.md)
7. 【3d 外部事件 D】若 [external-events-mapping.md](../docs/external-events-mapping.md) §5 触发（**A/B 已强 → 跳过，写「未查」**）：
   - **取国：** C/Dida → 2c `4_Country` Top1–3；**S/CS → `5_SID+Country`**（锁定 2b 主 SID，该 SID 内 Top1–3）。禁止 S/CS 用 `4_Country`。
   - 一国一调用 `external-events-lite/01-single-country-window.sql`
   - 当前窗必查；对比窗可选
   - **（可选 D2）** D1 命中 Top 节日 → seed 对齐 `holiday_key` → Read `02-holiday-yoy-bks-lite.sql` 原文 MCP（占位符见 `d2-params-template.md`）；**禁止手写 D2 SQL**；rubric 仅用 `country_*_bks`；D2 的 ≥10% 分母与 §5.3 一致（C=client，S/CS=该 SID）
8. 【3d 合成】按 docs/evidence-synthesis-rules.md；**3a 未满 14/14 或 3b 缺机构级 → 禁止「已确认/已排除 Dida」**
9. 【Phase 4 报告收口】按 [phases/04-report.md](04-report.md) 模板 **完整输出**（对话交付，不写文件除非用户要求）：
   - Executive Summary → §0 参数 → Phase 1–3 → 3d 综合 → 根因结论 → 后续动作（P0/P1/P2）。**成品不要附录**；MCP 500 写在对应节
   - 对照 gold：`examples/gold-agoda-20260320.md`（跌/C）、`examples/gold-snaptravel2b-20260801.md`（涨/S）、`examples/gold-hbgpkg-20260706.md`（正常波动/CS）、`examples/gold-hbgpkg-20260710.md`（CS 崩量）
   - **合成门禁**与**置信度**用词见 04-report.md「合成门禁」「置信度定义」
```

**Phase 3 结束标志：** 立刻进入 **报告收口**；用户看到的是 **一篇完整归因报告**（非 Phase 1–3 分段摘要）。结构必须与 `04-report.md` 模板一致。

**禁止：**
- 仅探测 CS/C/CDH/LCDH/Configuration 就结束 Phase 3
- **只跑 SS 层、不跑机构级 B 线**就写「C 主因」
- checklist **未满 14 行**就写「配置已排除」
- **手写 SQL 替代** `checklist/01–14` 文件内容（见上文规则 5）
- **手写 SQL 替代** `external-events-lite/02-holiday-yoy-bks-lite.sql`（D2 必须用 `country_*_bks` 列）

### MCP 注意

- 完整 config SQL 层数多，易 500 → 按 level 或拆段执行
- 表名来自 lite / [tables.md](../tables.md) → **直接 `execute_sql`**。`configuration.*` 元数据常无收录。**禁止**用 `search_meta_data` 代替查数或当权限探测
- **500 ≠ 无配置**：必查 [docs/mcp-permission-matrix.md](../docs/mcp-permission-matrix.md)；500 标 **「MCP 500 · 未验」**，禁止写 event_count=0
- **500 也可能是错 SQL**：列名/表结构不对（如 #12 用 `clientid`、#14 用 `updatedate`）会先 500；**必须 Read checklist 原文重试**，不得直接标未验
- **14/14 必须逐个跑** checklist/01–14；禁止 UNION 批量；**禁止手写替代**；未验 level 计入 `checklist_progress`（如 11/14）
- **SQL 优化**是降低 500 的主手段；矩阵管 fallback 与措辞（见矩阵 §1）

---

## 输出模板

过程清单与 **成品 3a 同一套 7 列**（复制 skeleton 时用同一表头）。不要再用「窗口内条数 / hotel_bks / 查价」旧列。

```markdown
# 内部证据验证

## 14 类配置必查清单（14 行缺一不可）

**须标注 `checklist_progress`（如 14/14 ✅）。未满 14/14 时，配置结论只能写「部分未验」，禁止「已排除 Dida」。**

| # | Level | n | 操作(枚举) | 作用域 | Δmargin / remark | 信号 |
|---|---|---|---|---|---|---|
| 1 | CS | | | 链路 | | |
| 2 | C | | | 机构 | | |
| 3 | S | | | 供应商 | | |
| 4 | CSA | | | 链路 | | |
| 5 | CBD | | | 机构 | | |
| 6 | SBD | | | 供应商 | | |
| 7 | CDH | | | 酒店批 | | |
| 8 | SH | | | 供应商 | | |
| 9 | LCDH | | | 酒店批 | | |
| 10 | L2L | | | 机构 | | |
| 11 | CSLRC | | | 机构 | | |
| 12 | C Bottom | | | 机构 | | |
| 13 | S Bottom | | | 供应商 | | |
| 14 | Configuration | | | 机构 | | |

## 重点条目解读（按作用域收口，不是 level 排行）

| 作用域 | Level | 操作 | Δmargin / remark | 信号 |
|--------|-------|------|------------------|------|
| 链路 | CS | 关房 | 开→关；产量 120→45 | 强 |

## 责任修正

| Phase 2b | Phase 3 | 依据 |
|----------|---------|------|
| C 或 Dida | **Dida** | CS 关房 + 产量骤降 |
| C 或 Dida | **C** | 出门禁通过、查价正常 |
| CS | **Dida** | CS 关房 |

## 未解释部分

→ 报告收口：ES 查 [es-cause-catalog.md](../docs/es-cause-catalog.md)

## 综合判断（Phase 3d）

见 [evidence-synthesis-rules.md](../docs/evidence-synthesis-rules.md) 输出模板。
```
