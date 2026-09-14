# Phase 2c：定责后自动下钻

> 2b 输出责任方向后**自动执行**。  
> **MCP：** 2c **必须**按路径再跑 lite 文件（见 [02-dimension-drilldown.md](02-dimension-drilldown.md) 必跑表）；缺任一 → `2c_progress` 未达标。  
> **BI：** 全量 `dimension-contribution.sql` 已含 13 层 → 2c **只过滤，0 额外 SQL**。

设计见 [cross-validation-design.md](../cross-validation-design.md)。

## 输入

- **MCP：** 2a 的 `02-sid` + 本路径 2c lite 结果（尚未跑的 hierarchy **现在跑**）
- **BI：** 2a 全量 13 层结果（已在一次 SQL 里）
- 2b 责任方向：`C/Dida` | `S` | `CS`
- 2b 锁定的 Top supplier `S`（S/CS 路径必填）

## 下钻规则

从 2a / lite 分批结果筛选对应 hierarchy；**贡献% 分母见 [2c-structure-report-template.md](../docs/2c-structure-report-template.md) §2.1**（C/Dida ÷ client 总量；S/CS ÷ **sid 变化**）。按 `ABS(贡献%)` 降序。报告格式：Top 2–3 段落 + 集中度 footnote，禁止全表。

### 责任 = C 或 Dida（共用）

从 2a 结果筛选以下 hierarchy；**Country / Chain 表 Top3**；**LT / LOS / Nationality 段落 Top2–3**：

| hierarchy | 输出字段 |
|-----------|---------|
| `4_Country` | country_code, booking_change, contribution_percentage |
| `6_Chain` | chain |
| `8_LT` | lt |
| `10_LOS` | los |
| `12_Nationality` | nationality |

**跳过** supplier 组合层（`3_*`, `5_*`, `7_*`, `9_*`, `11_*`, `13_*`）。

### 责任 = S 或 CS

1. 锁定 sid = 2b 中的 Top supplier
2. 筛选该 sid 且 hierarchy 为：

| hierarchy | 输出字段 |
|-----------|---------|
| `5_SID+Country` | country_code |
| `7_SID+Chain` | chain |
| `3_SID+Account` | supplieraccountid（**仅占该 SID 变化 ≥10%**） |
| `9_SID+LT` | lt |
| `11_SID+LOS` | los |
| `13_SID+Nationality` | nationality |

每个 hierarchy 内 Top 3；**表头列名：占 {SID} 变化**（禁止「占总量」）。**Country / Chain 写表**；**LT / LOS / Nationality 写段落**。

## 输出模板

见 [2c-structure-report-template.md](../docs/2c-structure-report-template.md) §4（报告收口合并写法）。简版：

```markdown
### 2c 下钻
#### 主结构 · Country（表 Top 3）
#### 主结构 · Chain（表 Top 3）
#### 结构补充（LT / LOS / Nationality 各 1 行段落）
→ 结构小结（1 句）
```

## Agent 禁止

- ❌ 下钻时再跑 cross-validation-country 等**宽表交叉** SQL
- ❌ **MCP 上**只跑 `02-sid`（或再加 Country）就写完整 2c；Chain / LT / LOS / Nationality **缺文件 = 未达标**
- ❌ 把「BI 全量 1 次、2c 0 额外 SQL」套用到 MCP
- ❌ C/Dida 路径强行写 Supplier Account
- ❌ Account 贡献（**占 SID 变化**）<10% 仍展开长表
- ❌ S/CS 2c 用 client 总量作分母，或列名与分母不一致
- ❌ **Chain / LT / LOS 全表贴报告**（Chain 仅 Top3 表；LT/LOS 仅段落，见 structure-report-template）
- ❌ 把下钻 Top1 直接写成最终根因（Phase 3 未验证前标「初步」）
