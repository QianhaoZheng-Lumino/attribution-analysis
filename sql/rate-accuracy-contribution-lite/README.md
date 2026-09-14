# Phase 3c Lite：验价准确率分批 SQL（用户 SQL2）

完整版 `../rate-accuracy-contribution.sql`（13 层 GROUPING SETS + 窗口函数）在 MCP 上易 **500**。  
**MCP 一次调用 = 本目录一个文件。**

## 硬规则

- **配置/限流/在线表不得用于解释准确率。**
- **每案先跑 `01-total.sql`。** `\|item_accuracy_delta_pp\| ≥ 5`（百分点）才启动维下钻 + issue；未过线 = 「无线索」。
- 禁止用 `precheck` 量变化代替准确率。

## 使用顺序

```
Step 0  ../params-template.md（与 Phase 1 同窗；必填 client_id）
Step 1  01-total.sql              探测：|item_accuracy_delta_pp| ≥ 5pp？
        < 5pp → 停，写「已探测、未启动」
        ≥ 5pp → Step 2–4
Step 2  对齐 2c：C → 02-sid + 04-country + 06-chain；S/CS → 02-sid + 05-sid-country + 07-sid-chain
Step 3  issue/01-issue-type.sql   失败类型占比
Step 4  issue/02-issue-id.sql     细因（AND issue_type = Top）
```

详见 [accuracy-issue-mapping.md](../../docs/accuracy-issue-mapping.md) § 3c SOP。

## within_contribution_pp（Agent 本地算）

完整 SQL2 公式（层内）：

```
within_contribution_pp =
  (previous_precheck / SUM(previous_precheck) OVER (PARTITION BY hierarchy_level))
  × item_accuracy_delta_pp
```

lite 各层文件输出 `item_accuracy_delta_pp` 与 `previous_precheck`，Agent 在层内手算贡献排序。

`contribution_pct_precheck` = `precheck_change / total.precheck_change`（可选）。

## 文件清单

| 文件 | hierarchy | 用途 |
|------|-----------|------|
| 01-total.sql | 1_Total | **每案必跑**；\|Δpp\|≥5 才继续 |
| 02-sid.sql | 2_SID | supplier 准确率 |
| 03-sid-account.sql | 3_SID+Account | Account≥10% 时 |
| 04-country.sql | 4_Country | |
| 05-sid-country.sql | 5_SID+Country | CS 路径 |
| 06-chain.sql | 6_Chain | |
| 07-sid-chain.sql | 7_SID+Chain | |
| 08-lt.sql | 8_LT | |
| 09-sid-lt.sql | 9_SID+LT | |
| 10-los.sql | 10_LOS | |
| 11-sid-los.sql | 11_SID+LOS | |
| 12-nationality.sql | 12_Nationality | |
| 13-sid-nationality.sql | 13_SID+Nationality | |
| issue/01-issue-type.sql | — | issue_type 粗因 |
| issue/02-issue-id.sql | — | issue_id 细因 |

## MCP 实测

| 案例 | 文件 | 结果 |
|------|------|------|
| HBGPKG 2026-07-06 | 01-total | ✅ current_accuracy ≈ 94.35% |

issue 下钻仍可能 500，需更窄过滤（单 supplier + 单日）。

## 参考

- [accuracy-issue-mapping.md](../../docs/accuracy-issue-mapping.md)
