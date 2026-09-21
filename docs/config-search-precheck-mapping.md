# 配置 → 查价/验价量预期映射

> Phase 3 **证据线 A + B** 用。与 [accuracy-issue-mapping.md](./accuracy-issue-mapping.md) **严格分离**。

## 硬规则

| 指标 | 配置变更是否影响 | 辅助表 |
|------|-----------------|--------|
| 查价量（QPS/PPS/SS total_search） | ✅ 可能（在线时长、需求、渠道请求逻辑） | 在线时长。**不是** QPS/PPS 上限 |
| 查价有价率（avail/total） | ✅ 可能（关房类；**QPS/PPS 上限**） | Configuration 上限只打有价，不打总量 |
| 验价量 / 查验比（rp、avail/rp） | ✅ 可能（加价/降价→竞争力） | — |
| **验价准确率（success_rp/total_rp）** | **❌ 不影响** | **不得用配置/限流/在线表解释** |

**配置证据只对接：QPS、有价率、验价量、查验比。** 详见准确率文档。

---

## 核心规律

- **关房** → 主要影响「有没有价」、SS 请求量；查价 **请求次数** 往往不变（C 级）。
- **加价/降价** → 查价量、有价 **通常不变**；主要影响 **验价量** 和 **查验比**（价格竞争力）。
- **CDH/LCDH** → 看 **酒店数量 + 是否高请求酒店**；关了无请求的 hotel 可能无指标变化。
- **Configuration QPS/PPS 上限（#5 A6，2026-09-14）：** **不改查价总量**。上限↑ → 通过的有价请求↑、有价率↑；上限↓ → 有价请求↓、有价率↓。

---

## 按配置 Level 的预期变化

### C / CBD / C Bottom（机构级）

| 操作 | DidaBiz 查价量 | 有价 avail | 验价 rp | 查验比 avail/rp |
|------|---------------|-----------|---------|----------------|
| 关房 | 不变 | **↓ 不再返回有价** | 间接 ↓ | ↓ |
| 加价 | 不变 | 不变 | **↓**（价劣，渠道不验） | **↑** |
| 降价 | 不变 | 不变 | **↑** | **↓** |

C 级关房 **很少见**。**CBD 与 C 同级**。C Bottom 机制同 C。  
**关房 / 加价 / 降价同等。** 认操作见 `phases/03-evidence-verification.md` #26（禁止 `status=1` 当开窗）。  
B 只对 **方向**（上表 ↑↓）：同向才强；反向 = inconclusive / 未拉回。不定「查验比 +10%」一类单边门槛。机构加价 + 查验比↑ + BKS↓ = **强**，禁止标弱、禁止改写成「倾向 C」。CBD detail **必须读 `remark` + last_margin**。

### CDH / LCDH（机构×酒店批量）

| 操作 | 条件 | 预期 |
|------|------|------|
| CDH 关房 | 关的多 + 这些 hotel 原有渠道请求 | DidaBiz **无价 ↑**（对应酒店） |
| CDH 关房 | 关的 hotel 本无请求 | **无明显变化** |
| CDH/LCDH 调价 | 取决于 hotel 数量与历史请求集中度 | 同 C 加价/降价，**子集**生效 |
| LCDH | **仅调价，无开关房** | — |

**术语：** 日志 `击穿兜底：新增` = **LCDH 新增酒店（击穿兜底名单）**（绕开 C Bottom 的 hotel 级调价资格）；`删除` = 移出该名单。**禁止**把 LCDH 叫「白名单」。  
**另：** 「机构供应商白名单」是 **另一张表**（client×supplier 供给，#23），现为当前配置快照，**不是** LCDH，也 **未纳入** 3a。Wolf2.0配置（Configuration 14 key）也 **不是** 白名单。

### S / S Bottom（供应商级）

| 操作 | SS 查价量 | SS 有价 | 验价 rp | 查验比 |
|------|----------|---------|---------|--------|
| 关房 | **↓ 甚至清零** | **↓ 无价** | ↓ | ↓ |
| 加价 | 不变 | 不变 | **↓** | **↑** |
| 降价 | 不变 | 不变 | **↑** | **↓** |

S Bottom：**仅 margin，无开关**。

### L2L / CSLRC

| 配置 | DidaBiz QPS | 有价 | 验价 | 产量 |
|------|------------|------|------|------|
| L2L 升级（`last_level` < `level` 或等级上调） | 不变 | 可能 **↑** | 间接 ↑ | **能打产量（涨）** |
| L2L 降级（`last_level` > `level` 或等级下调，含 BRG 2→3） | 不变 | 可能 **↓** | 间接 ↓ | **能打产量（跌）** |
| 等级未变（如 3→3 Job / 仅刷新惩罚天数） | — | — | — | 弱 / 背景 |
| CSLRC | — | 查价/验价 **难体现** | 低优先级 | — |

**硬规则（2026-09-05）：** 窗口内只要发生 **L2L 升级或降级**（`last_level` 与 `level` 不同），信号 **不得标弱**。默认 **中～强 / 主因候选（Dida 面纱）**。可与 CS 账号级结构并列，不互相替代。禁止用「查价没掉」「只打面纱不关房」把升降级写成弱/备查。`last_level` 是 `LAG(level)` 别名，表里没有 `prelevel` 列。

等级未变的 Job 写入仍可标弱。细粒度（各 level 对应可见性）后续再补，**不阻塞**本条。

### CS（Client×Supplier 链路）

| 操作 | SS（该 CS）查价量 | 有价 | 验价 rp | 备注 |
|------|------------------|------|---------|------|
| 关房 | **↓**（≈对该 Client 关 Supplier） | ↓ | ↓ | 同 S 关房，CS scope |
| 开房 | ↑ | ↑ | ↑ | |
| 加价 | 不变 | 不变 | **↓** | 该链路价劣 |
| 降价 | 不变 | 不变 | **可能 ↑** | 促销；若仍不增 → 仍无优势或另有原因 |

HBGPKG×Meituan 类问题：**CS scope** 对齐 client + supplier。

---

## 配置 vs 实际：交叉验证（3a + 3b）

```
发现配置变更（3a checklist）
  → 查该 level 的预期指标方向（上表）
  → 跑查价/验价量 SQL（3b，SQL1 lite）
  → 一致 → 强证据支持 Dida（配置）
  → 不一致 → 查非配置原因（下节）或渠道侧
  → 无配置但查验比 ↓ → 价格竞争力，非配置主因
```

---

## 查价请求变化的非配置原因

### DidaBiz 层（无 supplier，感知渠道侧）

**整体 QPS ↓：**

1. 酒店需求变少（市场）
2. **渠道在线时长 ↓** → `sql/online-hours-lite/03-window-avg.sql`（**触发：DidaBiz QPS/PPS \|WoW\|>10%**；**异动：日均少 ≥1.5h**；**禁止 AT TIME ZONE**）。MCP 500 才拉 log + 脚本。详见 [online-hours-mapping.md](./online-hours-mapping.md)
3. 渠道酒店匹配更换 / 关分销 / 缓存酒店增减 / 请求逻辑改变（见 [es-cause-catalog.md](./es-cause-catalog.md) A1/A2）

**有价请求 / 有价率变、查价总量几乎不动：** 先查 Configuration QPS/PPS 上限（A6），再查关房。

**某维度 QPS 变化：** 渠道自身配置（如 Check24 打开长远订单 → LT>70 ↑），通常 **不通知**，从数据推断 → 偏 **C 端**。

**多酒店 PPS 变化：** 查 Configuration（`MultiHotelPriceSearchRealTimePPS`、`PriceSearchCachePPS`、`MultiHotelRealTimeSearchCount` / `MultiHotelCacheSearchCount` 等 14 key）——这些 key **按 A6 打有价，不解释总量**。

### SS 层（供应商侧）

**有价减少但未必关房：**

1. **SS 限流** → 表 `dws.dws_hotel_flow_didamonitor_supplier_csa_di`（见下节）
2. 供应商资源变化
3. Ant 配置

限流表、在线表 **仅服务于查价/有价**，**不用于准确率**。

---

## SS 限流率与缓存命中率（3b 辅助）

**限流定义：** 供应商对 **每秒放行请求** 有上限；超过上限的请求 **到不了 supplier**。

**表：** `dws.dws_hotel_flow_didamonitor_supplier_csa_di`  
**Lite SQL：** `sql/rate-limit-lite/01-ss-supplier-window.sql`

**聚合：** 同一 `clientid × supplierid × 窗口` 内 **SUM 全部 supplieraccountid**；**不筛 biztype**。

| 指标 | 公式 | 用途 |
|------|------|------|
| **SS限流率** | `SUM(limit_requests_num) / SUM(requests_num)` | 定责/解读 |
| **缓存命中率** | `SUM(fromcache_requests_num) / SUM(all_requests_num)` | 定责/解读（**不变**） |
| **SS通过率** | `SUM(pass_requests_num) / SUM(requests_num)` | **背景信号**，不单定责 |
| **命中只吐缓存率** | `SUM(read_only_cache_requests_num) / SUM(requests_num)` | **背景信号**，不单定责 |

> **2026-09-04 定稿：** **SS限流率** = `limit/requests`；**废弃** `not_limit_requests_num`。  
> **只吐缓存** ≠ **缓存命中**（`fromcache/all`）。恒等式：`limit + pass + read_only_cache ≈ requests`。

### 何时查（2026-09-04 #18 定稿）

**出数 SID：** 2b 锁定，或占 client \|ΔBKS\| **≥10%** → **必跑** `rate-limit-lite`（SQL **必填 `{sid_list}`**，与 SH / `01-ss-supplier` 同一套；禁止全表 LIMIT 代替结构 SID）。  
**SS 有价率 / 请求量 \|WoW\| > 10%：** 只决定解读档（涨跌双向），结构 SID 未过 10% **仍出表**（排除用）。

| 3b 异动（\|WoW\| > 10%） | 查限流表 | 已定解读 |
|------------------------|----------|----------|
| **有价率** 涨或跌 | **SS限流率** WoW | 有价率↓且 SS限流率↑ → **倾向限流**（无关房时） |
| **请求量** 涨或跌 | **缓存命中率** WoW | 请求量↓且缓存命中率↑ → **倾向缓存替代实发** |
| 结构 SID 但两项均未过 10% | 四列都报 | **排除用** |
| 任意已出表 | **SS通过率** / **命中只吐缓存率** WoW | **背景信号**，仅报数，不单定责 |

未锁定且占变化 \<10% → 不查该 SID。SS 无行 → 未查。  
日期窗口与 `clientsupplierhotelcallcountsummary.date` **对齐**（同 params-template）。

**解读待研究（仅报数，不单定责）：** 有价率↑、请求量↑、或 **请求量↓但产量↑** 等组合 — 可能是特殊情况（见 SnapTravel2B 116-EPS）；不得据此推翻 2b/3d 主因。详见 [decisions-summary.md §5.10](./decisions-summary.md)。

---

## 完整解读顺序（BKS 降，供给/竞争力线）

```
BKS 降
  → 同 scope 查价有价率 ↓？  → 供给/关房/链路
  → 同 scope 查验比 ↓？       → 价格竞争力（含加价）
  → 同 scope QPS ↓？          → 在线时长 / 需求 / 渠道请求逻辑（A2）
  → 有价率动而总量几乎不动？   → Configuration 上限（A6）或关房
  → 结构 SID（锁定或 ≥10% BKS）→ 出限流表
  → SS 有价 \|WoW\|>10% → SS限流率：跌可定责；未过 10% 仅排除
  → SS 请求量 \|WoW\|>10% → 缓存命中率：跌可定责；未过 10% 仅排除
```

**准确率线独立**，见 [accuracy-issue-mapping.md](./accuracy-issue-mapping.md)。

---

## 相关 SQL / 表

| 资源 | 路径 |
|------|------|
| 配置 14 类 lite | `sql/config-change-detection-lite/checklist/` |
| 查价归因完整 SQL | `sql/search-attribution.sql`；MCP → `sql/search-attribution-lite/` |
| 查价 lite | `sql/search-attribution-lite/` |
| SS 限流/缓存 lite | `sql/rate-limit-lite/` |
| 表清单 | [tables.md](../tables.md) |
| ES 数据现象目录 | [es-cause-catalog.md](./es-cause-catalog.md) |
