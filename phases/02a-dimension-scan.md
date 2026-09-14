# Phase 2a：贡献度缓存说明

> **结果用法**（不定责、不下钻结论）。  
> **BI：** 跑完 [dimension-contribution.sql](../sql/dimension-contribution.sql) 全量。  
> **MCP：** 先 `02-sid.sql`；2c 各 hierarchy **尚未在 2a 一次拿到**，须再跑路径 lite。

完整 Phase 2 流程见 [02-dimension-drilldown.md](02-dimension-drilldown.md)。

## 一次查询，两处使用

| 阶段 | 使用 2a 结果的哪部分 |
|------|---------------------|
| **2b 定责** | 仅 `2_SID` 层级（验证 A） |
| **2c 下钻** | 按责任方向过滤其他 hierarchy |

**不对每个 hierarchy 做宽表交叉验证。**

## hierarchy 索引

| 层级 | 2b | 2c（C/Dida） | 2c（S/CS） |
|------|-----|-------------|-----------|
| 2_SID | ✅ A | — | 锁定 S |
| 3_SID+Account | — | — | ✅ 占 SID 变化 ≥10% |
| 4_Country | — | ✅ | — |
| 5_SID+Country | — | — | ✅ |
| 6_Chain | — | ✅ | — |
| 7_SID+Chain | — | — | ✅ |
| 8_LT | — | ✅ | — |
| 9_SID+LT | — | — | ✅ |
| 10_LOS | — | ✅ | — |
| 11_SID+LOS | — | — | ✅ |
| 12_Nationality | — | ✅ | — |
| 13_SID+Nationality | — | — | ✅ |

术语见 [glossary.md](../glossary.md)。

## Agent 注意

- 2a（`02-sid`）完成后**直接进入 2b**，不要先写长篇扫描报告
- **BI：** 2c 数据已在全量结果里，过滤排序即可
- **MCP：** 2c **不是**「读 2a 就结束」；按 [02-dimension-drilldown.md](02-dimension-drilldown.md) 补跑路径文件
- 并列假设允许，不强制单一主因
