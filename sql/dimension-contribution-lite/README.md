# Phase 2 Lite：维度贡献分批 SQL（MCP 稳定版）

完整版 `../dimension-contribution.sql`（GROUPING SETS + 13 层）在 MCP 上易 **500**。
**MCP 执行一律走本目录单文件查询 + Agent 本地算贡献占比。**

完整 SQL 仍为逻辑源真相；lite 结果用于 2b 定责 + 2c 下钻。

**MCP vs BI：** 本目录是 **MCP 必跑路径**。BI 跑一次 `../dimension-contribution.sql` 后 2c 不必再查。MCP **禁止**套用「2c 0 额外 SQL」。

## 使用顺序

```
Step 0  按 ../params-template.md 计算日期 → 填入占位符
Step 1  01-total.sql           → 总量变化（可选）
Step 2  02-sid.sql             → 【必做】2b 验证 A
Step 2b 14-sid-client-validation.sql → 门 1：过线 SID（≥10%）每家一次
Step 3  04-country.sql 等      → 2c 下钻（按 2b 路径选文件；**报告格式**见 docs/2c-structure-report-template.md）
Step 4  Agent 本地算贡献%（分母见下，禁止一律 / total_change）
```

**2c 报告篇幅：** Country **表** Top3 + Chain **表** Top3；LT/LOS/Nationality **各 1 段话**（Top2–3）。禁止 chain 全表 / LT 全桶表。

## 2b 定责（读 02-sid.sql；双门见 responsibility-model.md）

统计 `previous_bookings >= 5` 的 supplier。占比分母 = 本 client `|ΔBKS|`。

- **门 1：** 任一 SID 占 `|ΔBKS|` **≥10%** → **必跑** `14-sid-client-validation.sql`（过线 SID 每家一次）。**禁止**因家数 ≥70% 跳过 B。无 SID ≥10% 才可跳过 B。
- **门 2：** 写死 C/Dida 须家数同向 **≥70%** 且 **没有** 单 SID ≥50%。否则禁止写死，用 B 判 S 或 CS。
- 写死 C/Dida 后 B 可并列 S/CS，不翻主因。禁止用「某 SID 的 B 是 CS」否决门 2。

## 2c 下钻文件对照

| 2b 结论 | 运行文件 |
|---------|---------|
| C/Dida | 04-country, 06-chain, 08-lt, 10-los, 12-nationality |
| S/CS | 03-sid-account, 05-sid-country, 07-sid-chain, 09-sid-lt, 11-sid-los, 13-sid-nationality |

Account 行当 **占该 SID 变化** `|contribution_pct| >= 10%` 写入报告（分母 = `02-sid` 的 sid `booking_change`），**含新建/清零**。

### 2c 结构过滤（与定责分离）

| 层 | 文件 | 留行规则 |
|----|------|---------|
| **定责** | `02-sid`、`14-sid-client-validation` | **对比期 ≥ 5**，不动 |
| **2c 结构** | `03/05/07/13` | 当前 ≥3 **或** 对比 ≥3 |
| **2c 结构** | `04/06/12` | 当前 ≥10 **或** 对比 ≥10 |
| **LT / LOS** | `08/09/10/11` | 不按对比期卡新建 |

SQL：`ORDER BY ABS(SUM(当前窗) - SUM(对比窗)) DESC`。**禁止** `ORDER BY ABS(booking_change)`——Hologres 对别名套 ABS 会 500。报告按 `|贡献%|` 进表，含反向。MCP 可能打乱顺序，Agent 本地再排。

### 贡献% 分母（2026-09-04 #14）

| 路径 | 公式 | 列名 |
|------|------|------|
| 2b `02-sid`、2c C/Dida | `booking_change / total_booking_change` | 占总量 / 占 client 变化 |
| 2c S/CS（`03/05/07/09/11/13`） | `booking_change / sid_booking_change` | **占 {SID} 变化** |

`sid_booking_change` 取自 `02-sid` 锁定行。BI 全量 SQL 的 `contribution_percentage` 不是 sid 分母，S/CS **必须重算**。

## 文件清单

| 文件 | hierarchy | 用途 |
|------|-----------|------|
| 01-total.sql | 1_Total | 总量 |
| 02-sid.sql | 2_SID | **2b 定责** |
| 03-sid-account.sql | 3_SID+Account | S/CS 路径 |
| 04-country.sql | 4_Country | C/Dida 路径 |
| 05-sid-country.sql | 5_SID+Country | S/CS 路径 |
| 06-chain.sql | 6_Chain | C/Dida 路径 |
| 07-sid-chain.sql | 7_SID+Chain | S/CS 路径 |
| 08-lt.sql | 8_LT | 结构 |
| 09-sid-lt.sql | 9_SID+LT | S/CS 结构 |
| 10-los.sql | 10_LOS | 结构 |
| 11-sid-los.sql | 11_SID+LOS | S/CS 结构 |
| 12-nationality.sql | 12_Nationality | 结构 |
| 13-sid-nationality.sql | 13_SID+Nationality | S/CS 结构 |
| 14-sid-client-validation.sql | — | cross-validation B lite |

## 已知限制

- 不用 GROUPING SETS / 窗口函数 / 多层 CTE
- `contribution_percentage` 由 Agent 手算（C/Dida ÷ client 总量；S/CS ÷ **sid 变化**）
- 与完整 SQL 数值可能有 ±1% 四舍五入差；S/CS **不要**直接用完整 SQL 的 contribution 列
