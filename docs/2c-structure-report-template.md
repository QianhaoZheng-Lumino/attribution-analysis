# Phase 2c 结构维度 · 报告模板

> **用途：** Chain / LT / LOS / Nationality（及 S 路径 SID 交叉维）写入 Phase 2 / 报告收口。  
> **原则：** 必跑 SQL；**Country + Chain 用表 Top3**；**LT / LOS / Nationality 用段落 Top2–3**；禁止全表。  
> **定责：** 均为 **2c 结构/描述性**，不替代 2b。

关联：`dimension-contribution-lite/` · [02c-drilldown.md](../phases/02c-drilldown.md) · [04-report.md](../phases/04-report.md)

---

## 1. 哪些维度、何时写

### C / Dida 路径（必跑 lite）

| 维度 | SQL | 报告块 | 定位 |
|------|-----|--------|------|
| **Country** | `04-country.sql` | **表 Top 3** | 主结构 · 酒店国 |
| **Chain** | `06-chain.sql` | **表 Top 3** | 主结构 · 集团/单体（与 Country 同级展开） |
| **LT** | `08-lt.sql` | **段落** Top2–3 | 预订提前期 · 描述性 |
| **LOS** | `10-los.sql` | **段落** Top2–3 | 连住 · 描述性 |
| **Nationality** | `12-nationality.sql` | **段落** Top2–3 | 客源国 · 描述性 |

### S / CS 路径（锁定 Top SID 后）

| 维度 | SQL | 报告块 |
|------|-----|--------|
| **SID+Country** | `05-sid-country.sql` | **表 Top 3** |
| **SID+Chain** | `07-sid-chain.sql` | **表 Top 3** |
| **SID+Account** | `03-sid-account.sql` | 小表，**\|占 {SID} 变化\| ≥10%**（含新建/清零、含反向） |
| **SID+LT / LOS / Nationality** | `09` / `11` / `13` | 各 **1 段落** |

**LT / LOS / Nationality 整段可省略**（一行「无单维主导」）当：Top1 `|贡献%| < 5%` 且 Top3 累计 **< 15%**（贡献% 用 **本路径分母**，S/CS 为 sid）。  
**Chain 与 Country 同级**：只要跑了 SQL，**默认出 Top3 表**（除非 event 极少 &lt;3 行）。

---

## 2. 展示规则

### 2.1 贡献占比（2026-09-04 #14 定稿）

Agent **手算**；lite SQL 不产出百分比。分母按路径，**列名必须与分母一致**。

| 位置 | 分母 | 列名 |
|------|------|------|
| **2b** `02-sid` | client 总量变化 `total_booking_change` | 贡献% / 占 **client 变化** |
| **2c C/Dida**（4/6/8/10/12） | 同上 | **占总量** |
| **2c S/CS**（5/7/9/11/13） | **该锁定 SID 的** `sid_booking_change`（来自 `02-sid`） | **占 {SID} 变化** |
| 对照（可选 footnote） | client 总量 或 client 同维 Δ | 一句即可，如「26 上 US ≈ client US 的 85%」 |

```
C/Dida 贡献% = booking_change / total_booking_change × 100
S/CS 贡献%   = booking_change / sid_booking_change × 100
```

`sid_booking_change` = 锁定 supplier 在 `02-sid` 的 `booking_change`（例：SnapTravel2B 的 26-Agoda **+2,588**，不是 client **+3,156**）。

**SID+Account ≥10%：** 分母同样是 **`sid_booking_change`**（不是 client 总量）。按 **`|贡献%|`** 进表，**含反向**（清零/对冲）。`0→N` 只写贡献%，不写环比%。否则小 SID 上的大账号过不了门槛。

**BI 注意：** 完整 `dimension-contribution.sql` 的 `contribution_percentage` **不是** sid 分母。S/CS 写入报告前 **必须按上式重算**，禁止直接贴 SQL 列。

**进表排序（2c 结构）：** 按 `|booking_change / 分母|` 降序。与异动同号仍叫「同向」，用于解读，**不再作为进表过滤器**。SQL 必须 `ORDER BY ABS(SUM差)`，禁止 `ABS(booking_change)` 别名（Hologres 500）。MCP 仍可能打乱顺序，Agent 必须按绝对值本地再排。

### 2.2 表 vs 段落

| 维度 | 格式 | 行数 |
|------|------|------|
| **Country / Chain**（及 SID+ 版） | ✅ **3 列表** + footnote | 固定 **Top 3**（同 Country 样式） |
| **LT / LOS / Nationality** | ❌ **1 段话** | Top **2–3** 项 + 集中度一句 |
| **SID+Account** | 小表 | **\|占 {SID} 变化\| ≥10%**，含新建/清零 |

**Country / Chain 表：** 固定 Top 3，按 **`|贡献%|`**，**含反向**。footnote：`*Top3 占 ~X%；{一句解读}。*` 含反向时写明（如 `*含 Hyatt −13 反向。*`）。排不进 Top3 的小反向一句带过。

**Account：** `|贡献%| ≥ 10%` 的都进表（正负都算）。`0→N` 在 `prev → cur` 标「新建」，`N→0` 标「清零」。切走与接量对冲时贡献可超过 100%，footnote 写明，禁止当算错改分母。

### 2.3 段落维度 · 集中度（LT / LOS / Nationality）

| Top 累计 \|贡献%\| | 写法 |
|-------------------|------|
| **≥ 85%** | 只列 **Top 2** + 「Top2 占 ~X%；其余分散。」 |
| **70% – 84%** | 列 **Top 3** + 「Top3 占 ~X%；其余 ~Y%。」 |
| **< 70%** | Top 3 + 「无单维主导，多桶同向 {跌/涨}。」 |

**不要**贴 10+ 行 LT/LOS 全桶表。

---

## 3. Chain 表模板（6_Chain · 同 Country）

```markdown
#### 主结构 · Chain（6_Chain）

| Chain | prev → cur | change | 占总量 |
|---|---|---|---|
| Independent | 2074 → 1664 | -410 | 90.7% |
| Wyndham | 46 → 28 | -18 | 4.0% |
| Club Quarters | 14 → 6 | -8 | 1.8% |

*Top3 占 ~97%；跌产集中在 Independent 单体；Centre point +36 反向（小）。*
```

**Agoda @ 2026-03-20** 即上表（MCP `06-chain.sql`）。

---

## 4. LT / LOS / Nationality 段落模板

### Lead Time（8_LT）

```markdown
**Lead Time：** 4~7 天 **-170**（38%）、>70 天 **-98**（22%）；Top2 ~60%；29~42 天 +27（反向，小）。中短提前期与超远期同跌。
```

### LOS（10_LOS）

```markdown
**LOS：** 1 晚 **-146**（32%）、4~7 晚 **-102**（23%）；Top2 ~55%。各连住段同向普跌，短住略多。
```

### Nationality（12_Nationality）

```markdown
**Nationality（客源）：** {nat1} **{Δ}**（{pct}%）、…；Top{n} ~{cum}%；与 Country {对照一句}。
```

**数据限制：** `channel_nationality` 大量为空 →「**客源国籍字段缺失，本节从略**」。

---

## 5. 报告收口 §2c 合并写法（推荐）

```markdown
### 2c 下钻

#### 主结构 · Country（4_Country）

| Country | prev → cur | change | 占总量 |
|---|---|---|---|
| … | | | |

*Top3 footnote*

#### 主结构 · Chain（6_Chain）

| Chain | prev → cur | change | 占总量 |
|---|---|---|---|
| … | | | |

*Top3 footnote*

#### 结构补充（描述性 · LT / LOS / Nationality · 各 1 行）

- **Lead Time：** …
- **LOS：** …
- **Nationality：** …

→ **结构小结：** {1 句}
```

**篇幅预算：** Country 表 + Chain 表 + **≤3 行 bullet** + 1 句小结；**不贴** chain 20 行 / LT 全桶表。

---

## 6. S / CS 路径

表头列名必须是 **占 {SID} 变化**，禁止写「占总量」却用 sid 去除。

```markdown
**锁定 supplier：** `{sid}`（`02-sid` 贡献 {sid_Δ}，占 client **{client_pct}%**）。  
**贡献率分母：** 下表 = `booking_change / {sid_Δ}`（非 client 总量）。

#### {Top_SID} × Country（`05-sid-country.sql`）

| Country | prev → cur | change | 占 **{SID} 变化** |
|---|---|---|---|
| … | | | |

#### {Top_SID} × Chain（`07-sid-chain.sql`）

| Chain | prev → cur | change | 占 **{SID} 变化** |
|---|---|---|---|
| … | | | |

- **{sid} × Lead Time / LOS / Nationality：** 各 1 段落（% 同样除以 sid_Δ）
```

样例：[gold-snaptravel2b-20260801.md](../examples/gold-snaptravel2b-20260801.md)（26-Agoda × US = 100% **占 26 变化**）。

---

## 7. Agent 禁止

- ❌ Chain **全表**（Top3 以外逐行）  
- ❌ LT / LOS / Nationality **全表**  
- ❌ 因「描述性」不跑 `06/08/10/12`  
- ❌ 结构维 Top1 写成主因  
- ❌ Country 与 Nationality 混为一列  
- ❌ S/CS 表用 client 总量作分母，或列名写「占总量」实际除的是 sid  
- ❌ Account ≥10% 用 client 总量当门槛
- ❌ 涨产把清零/反向踢出 Country、Chain、Account 表（只写 footnote）  

---

## 8. lite 审计

| 文件 | C/Dida | 报告格式 |
|------|--------|----------|
| `04-country.sql` | ✅ | 表 Top3 |
| `06-chain.sql` | ✅ | **表 Top3** |
| `08-lt.sql` | ✅ | 段落 |
| `10-los.sql` | ✅ | 段落 |
| `12-nationality.sql` | ✅ | 段落 |

S/CS：`05`/`07` 表 Top3；`09`/`11`/`13` 段落。
