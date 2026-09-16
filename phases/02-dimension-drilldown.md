# Phase 2：维度贡献 → 定责 → 自动下钻

> 入口见 [SKILL.md](../SKILL.md) 执行模式：归因型且门禁 **是**，或完整型/gold（门禁否也可）。探查型、归因型门禁否、**大盘无 client** → 不进入本文。

```
2a   贡献度（MCP lite 分批 / BI 全量 1 次）
2b   C×S 交叉验证                  定责 C/Dida | S | CS
2c   自动下钻                      读 2a 缓存；MCP 须补跑路径文件
```

**两条路径（2026-09-04 #13 定稿）：**

| 环境 | 2a | 2c |
|------|----|----|
| **MCP** | `dimension-contribution-lite/`：`02-sid` 必跑 | **必须再跑**路径文件（下表）；禁止只跑 SID/Country |
| **BI / 非 MCP** | `dimension-contribution.sql` **全量 1 次** | **只过滤排序，0 额外 SQL** |

2c **不追加** country×chain 等宽表交叉验证（与「MCP 必跑 lite」不是一回事）。

- 设计：[cross-validation-design.md](../cross-validation-design.md)
- 定责：[responsibility-model.md](../responsibility-model.md)
- 下钻：[02c-drilldown.md](02c-drilldown.md)
- 术语：[glossary.md](../glossary.md)

---

## Step 2a：维度贡献

参数与 Phase 1 一致，**必须指定 client**。

**MCP 首选** [sql/dimension-contribution-lite/](../sql/dimension-contribution-lite/) 分批执行（`02-sid.sql` 必跑 + 2c 路径文件）。

**BI / 非 MCP** 一次跑 [sql/dimension-contribution.sql](../sql/dimension-contribution.sql)。

产出缓存供 2b（`2_SID`）和 2c（各 hierarchy）使用；lite 版贡献% 由 Agent 手算（**S/CS 2c ÷ sid 变化**，见 `2c-structure-report-template.md` §2.1）。

---

## Step 2b：C×S 定责（双门）

规则全文：[responsibility-model.md](../responsibility-model.md)。**70% 不是跳过 B 的开关。**

### 验证 A

从 2a 取 `hierarchy_level = '2_SID'`（有效 SID：`previous_bookings >= 5`）。记：家数同向%、各 SID 占本 client `|ΔBKS|`。

### 验证 B（门 1）

任一 SID 占 `|ΔBKS|` **≥10%** → **必跑** [cross-validation-b.sql](../sql/cross-validation-b.sql)（MCP：`14-sid-client-validation.sql`，过线 SID **每家一次**）。无 SID ≥10% 才可跳过。

### 写死 C/Dida（门 2）

家数同向 **≥70%** 且 **没有** 单 SID ≥50% → 才允许写 **C/Dida**。否则禁止写死，用 B 判 **S** 或 **CS**。写死后 B 可并列，不翻主因。

### 输出

- 责任方向：**C/Dida** | **S** | **CS**
- 门 1 过线 SID 列表 + 各家 B 摘要（跳过须写「无 SID≥10%」）
- 锁定的 Top supplier S（S/CS 路径）
- **涨产且 Top S 上多 client 同涨**：输出 **「非 CS；S 成分 + 待 3b 区分 C 放大」**，不写「C 主因」
- → **自动进入 2c**

---

## Step 2c：自动下钻

按 [02c-drilldown.md](02c-drilldown.md) 执行，**无需用户确认**。

| 2b 结论 | 下钻层级 |
|---------|---------|
| C/Dida | 4_Country, 6_Chain, 8_LT, 10_LOS, 12_Nationality |
| S/CS | 5_SID+Country, 7_SID+Chain, 3_SID+Account（**\|占 SID 变化\| ≥10%**，含反向）, 9/11/13 |

---

## Phase 2 完整输出模板

```markdown
# Phase 2 归因分析

## 2b 定责
- 方向：**{C/Dida | S | CS}**
- 验证 A：{摘要}
- 验证 B：{各 ≥10% SID 摘要；或「无 SID≥10%，跳过」}

## 2c 下钻
### {C/Dida 或 Supplier 路径标题}
{各 hierarchy Top 3 表}

## 并列假设
1. ...
2. ...

## Phase 3 待验证
- [ ] 配置表（3a）
- [ ] 查价/验价（3b/3c）
- [ ] 外部事件 D（触发见 external-events-mapping；A/B 已强则未查）
```

---

## 执行清单

```
- [ ] 2a 必跑：dimension-contribution-lite/02-sid.sql
- [ ] 2c 路径（C/Dida **5/5** 或 S/CS **6 文件**，见下表）— 缺任一 → 2c_progress 未达标
- [ ] 2b-A 读 2_SID → 定责方向
- [ ] 2b-B 若需要 → cross-validation-b.sql
- [ ] 2c 写入报告（Country+Chain 表；LT/LOS/Nationality 段落）→ Phase 3
```

### 2c MCP 必跑文件（lite · 禁止只跑 Country）

| 2b | 文件 | 报告 |
|----|------|------|
| **C/Dida** | `02-sid` + `04-country` + **`06-chain`** + **`08-lt`** + **`10-los`** + **`12-nationality`** | **5/5** |
| **S/CS** | `02-sid` + `05-sid-country` + **`07-sid-chain`** + `03-sid-account`（占 SID 变化≥10%） + **`09-sid-lt`** + **`11-sid-los`** + **`13-sid-nationality`** | 至少 country+chain+lt+los+nat |

BI 一次跑完整 `dimension-contribution.sql` 可替代 lite 分批，但报告仍须覆盖上表各 hierarchy。

**2c_progress：** C/Dida 路径 `{n}/5`（country/chain/lt/los/nationality 均 MCP ✅ 或 BI 全量 ✅）。
