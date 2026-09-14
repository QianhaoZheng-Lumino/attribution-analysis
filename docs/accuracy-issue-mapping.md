# 验价准确率与 issue 下钻

> Phase 3 **证据线 C** 专用。与 [config-search-precheck-mapping.md](./config-search-precheck-mapping.md) **严格分离**。

## 硬规则

1. **配置变更不影响验价准确率。** 不得用 14 类配置清单、限流表、在线时长表去「解释」准确率变化。
2. **准确率反映接口问题 / 技术指标**，不是 Dida 配置定责线。
3. 验价（precheck / RP / Prebook）**只有一张表**，1:1 发 supplier；按 `supplier_id` 等维度区分。见用户 SQL2。

---

## 数据源

| 表 | 用途 |
|----|------|
| `data_ovs.rate_accuracy_channel_multi_dimension` | 验价多维明细 + issue 字段 |
| 用户 SQL2 | 准确率贡献度（13 层 GROUPING SETS） |
| `sql/rate-accuracy-contribution.sql` | BI 完整版 |
| `sql/rate-accuracy-contribution-lite/` | MCP 分批 + `issue/` 下钻 |

字段：

- `precheck` / `success_precheck` → total_rp / success_rp
- `is_request_chain = True` → 用 `issue_type_chain` / `issue_id_chain`
- 否则 → `issue_type` / `issue_id`

**下钻优先级：`issue_type`（粗）→ `issue_id`（细）。** `error_type` 为渠道/API 错误码，辅助参考。

---

## issue_type（粗，5 类）

| 码 | 英文 | 含义 |
|----|------|------|
| 0 | None | 无问题 |
| 10 | Timeout | 超时 |
| 20 | NoRoom | 无房/关房/限流/RP锁（验价失败分类名，**非配置归因**） |
| 30 | PriceChanged | 价格/取消/餐型等政策不一致 |
| 40 | Other | 其他/未知/渠道侧修正 |

---

## issue_id（细，中文报告用 issue_id_channel_cn）

### 1xxx — 超时/异常（≈ issue_type 10）

| issue_id | 中文 |
|----------|------|
| 1001 | Hotel反查超时 |
| 1002 | Hotel反查异常 |
| 1003 | 验价超时 |

### 2xxx — 无房/供给类失败（≈ issue_type 20）

| issue_id | 中文 | 备注 |
|----------|------|------|
| 2001 | Hotel无房;RatePlan有房 | |
| 2002 | Hotel有房;RatePlan无房 | |
| 2003 | Hotel无房;RatePlan无房 | |
| 2004 | 调价关房 | 验价失败分类，**不回去查 wolf 配置** |
| 2005 | 超QPS | 验价失败分类，**不用限流表交叉** |
| 2006 | RP被锁 | |

### 3xxx — 价格/政策不一致（≈ issue_type 30）

| issue_id | 中文 |
|----------|------|
| 3001 | 总价不一致 |
| 3002 | 价格列表不一致 |
| 3003–3015 | 总价/价目/取消/餐型 各种组合 |

→ 验价时价格/政策与查价时不一致，**技术指标/同步问题**。

### 4xxx — 其他（≈ issue_type 40）

| issue_id | 中文 |
|----------|------|
| 4001 | 未知 |
| 4002 | Agoda后台数据修正 |
| 4003 | Agoda 内部数据修正 |

→ 偏 **渠道侧**，移交报告收口。

---

## error_type（渠道/API 层，辅助）

映射为 `error_desc`（英文），码段示例：

| 码 | 含义 |
|----|------|
| 2005 | NoAvailableRoom |
| 2022 | LimitedCall |
| 2029 | HotelStopSell |
| 2050 | RatePlanLocked |
| 2070 | SupplierException |

与 `issue_id` **不是同一套枚举**。准确率主读 **issue_type + issue_id**。

---

## 准确率归因 SOP（3c）（2026-09-04 #19 定稿）

阈值用 **百分点（pp）**：`item_accuracy_delta_pp` =（当前准确率 − 对比准确率）× 100。  
例：94% → 88% = **−6pp** → 启动；94% → 91% = **−3pp** → 不启动。  
**禁止**用验价量 `precheck` 升降代替准确率。

### 1. 每案必跑探测（未过线 =「无线索」的唯一定义）

```
Read 01-total.sql 原文 → MCP（必填 client_id，同 Phase 1 窗）
```

| `\|item_accuracy_delta_pp\|` | 报告 |
|------------------------------|------|
| **≥ 5pp**（涨跌双向） | **启动** 3c 下钻（§2） |
| **< 5pp** | **已探测、未启动**。这就是「无线索」 |
| MCP 500 / 无行 | **未验**，禁止写「无线索」或「无异常」 |

### 2. 启动后下钻（过 5pp 才跑）

与 3a/3b **并行、不混**。顺序：

```
① 维贡献（对齐 2c，不要 13 层全跑）
   C/Dida：02-sid + 04-country + 06-chain（再按 2c Top 补 08/10/12）
   S/CS：  02-sid + 05-sid-country + 07-sid-chain（再按 2c Top 补 09/11/13）
   → 找 |item_accuracy_delta_pp| 最大的维；within_contribution_pp 手算排序

② issue 粗因
   issue/01-issue-type.sql（当前窗 vs 对比窗占比）
   → 上升最多的 issue_type（10 超时 / 20 无房类 / 30 价策不一致 / 40 其他）

③ issue 细因
   issue/02-issue-id.sql（建议 AND issue_type = 上步 Top）
   → 用 issue_id_channel_cn 写报告（见上文码表）

④ 合成
   准确率↓ + Timeout/30xx↑ → 并列技术指标（不推翻 2b/3a/3b）
   准确率↓ + 4002/4003↑ → 倾向渠道数据修正 → 报告收口
   准确率↑ 过 5pp → 仍出 issue 表，**禁止**写「准确率导致涨产」
   ❌ 禁止：用配置 / 限流 / 在线解释准确率
```

issue 仍 500 → 缩到锁定 SID + 更短窗；再失败标 **MCP 500 · 未验**，已启动的维表仍保留。

### 3. 与 BKS 的关系

```
BKS 异动
├─ 3a+3b：有价率、查验比、QPS（配置/竞争力/在线/限流）
└─ 3c：01-total |Δ|≥5pp → 维 + issue → 技术/接口/渠道数据（并列，不单定责产量）
```

查验比 ↓ = 价格竞争力；准确率 ↓ = 验价技术质量。**二者不同因。**

---

## SQL2 输出字段（准确率贡献）

| 字段 | 含义 |
|------|------|
| `current_accuracy` / `previous_accuracy` | success_precheck / precheck |
| `item_accuracy_delta_pp` | 该维度准确率变化（百分点） |
| `within_contribution_pp` | 层内准确率变化贡献 |
| `contribution_pct_precheck` | 验价量变化贡献 |

报告需包含 **准确率贡献表**（用户已确认）。

---

## MCP 注意

`rate_accuracy_channel_multi_dimension` 大表；完整 GROUPING SETS 易 500。  
**MCP：** `sql/rate-accuracy-contribution-lite/` 按 hierarchy 分批；issue 用 `issue/01-issue-type.sql`（仍可能需更窄过滤）。
