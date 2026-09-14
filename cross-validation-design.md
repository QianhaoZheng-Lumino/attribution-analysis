# 交叉归因设计（定稿）

> 术语见 [glossary.md](glossary.md)。责任四方见 [responsibility-model.md](responsibility-model.md)。

## 核心原则

1. **交叉验证只用于定责**（C / Dida / S / CS）— 仅供应轴 C×S，不做全维度宽表交叉。
2. **下钻不追加宽表交叉验证**（禁止 country×chain 等新 SQL）。
   - **BI：** `dimension-contribution.sql` **全量 1 次** → 2c 只过滤排序，**0 额外 SQL**
   - **MCP：** `dimension-contribution-lite/` 分批；2c **必须**补跑路径文件（见 `phases/02-dimension-drilldown.md`）
3. **定责后自动下钻** — 2b 完成后 Agent 按责任方向自动执行 2c，无需用户逐步点选。

## 总体流程

```
Phase 2a   贡献度：MCP lite 分批 / BI dimension-contribution.sql 全量 1 次
    │
Phase 2b   C×S 交叉验证（验证 A + 条件性验证 B）
    │      → 输出：C/Dida | S | CS
    │
Phase 2c   自动下钻：BI 只过滤；MCP 按路径再跑 lite（禁止「MCP 0 额外 SQL」）
    │
Phase 3    配置 / 查价验价 / 外部事件 D（`external-events-lite/`）✅
```

## Phase 2b：仅 C×S 交叉验证

| 验证 | 数据 | 何时需要 |
|------|------|---------|
| **A** | 2a 结果中 `2_SID` 层级 | 总是 |
| **B** | [cross-validation-b.sql](sql/cross-validation-b.sql) | **门 1：** 任一 SID 占本 client `|ΔBKS|` ≥10%（每家一次）。无 SID ≥10% 才跳过 |

### 判定（双门，见 responsibility-model.md）

- **门 1：** ≥10% SID 必跑 B。**禁止**因家数 ≥70% 跳过 B。
- **门 2：** 写死 C/Dida 须家数同向 ≥70% **且** 没有单 SID ≥50%。否则用 B 判 S 或 CS。
- B 读法：S 下多数 client 同向 → **S**；仅 focus client / 逆势 → **CS**。写死 C/Dida 后可并列，不翻主因。

**涨产镜像**同一套门。客户涨幅远超大盘时，2b 最多写「C/S 并列待 3b」，不写「C 主因」。

70% 只管「宽不宽」，不是跳过 B 的开关。

**C 与 Dida 在 2b 合并**；区分留 Phase 3（配置、查价验价）。均无证据 → 报告收口倾向 **C**。

## Phase 2c：按责任方向自动下钻

从 2a 结果中筛选对应 hierarchy，按 `ABS(contribution_percentage)` 降序取 Top 3（下降异动）。

### 路径 C/Dida（共用）

| 层级 | 下钻内容 |
|------|---------|
| `4_Country` | 哪个**酒店国家**掉最多 |
| `6_Chain` | 哪个**集团**掉最多 |
| `8_LT` | 哪个**预订提前期**段 |
| `10_LOS` | 哪个**连住**段 |
| `12_Nationality` | 哪个**客源国籍** |

**不看** `3_SID+Account`、`5_SID+Country` 等 supplier 组合层（定责已偏 Client/Dida 侧）。

### 路径 S 或 CS

先锁定 2b 中的 **Top supplier S**，再在该 sid 相关行中取下钻：

| 层级 | 下钻内容 |
|------|---------|
| `5_SID+Country` | 该 supplier 在哪个**国家**掉最多 |
| `7_SID+Chain` | 该 supplier 在哪个**集团**掉最多 |
| `3_SID+Account` | 哪个 **Supplier Account** 掉最多（见阈值） |
| `9_SID+LT` | 该 supplier 在哪个 **LT** 段 |
| `11_SID+LOS` | 该 supplier 在哪个 **LOS** 段 |
| `13_SID+Nationality` | 该 supplier 对哪个**国籍**客源 |

过滤条件：`sid = S` 且 `hierarchy_level` 匹配。

### Supplier Account 下钻阈值

仅当 `3_SID+Account` 中某账号 **占该 SID 变化** `ABS(%) ≥ 10%` 时写入报告；否则省略 Account 段落。分母见 [2c-structure-report-template.md](docs/2c-structure-report-template.md) §2.1。

### 结构轴解读

LT / LOS / Nationality 在各路径中作为**描述性下钻**，标记「需求结构变化」，不单独做 C/S 宽交叉验证。

Country（酒店国）与 Nationality（客源国）**并列展示**；同时异常时在报告中对照说明。

### 多轴 Top 并存

**并列多条假设**，不强制单一主因。贡献占比相加可能 >100%（维度重叠），报告注明即可。

## 性能与数据量

| 步骤 | SQL 次数 |
|------|---------|
| dimension-contribution.sql | 1 |
| cross-validation-b.sql | 0–1 |
| 2c 下钻 | 0 |

## 明确不做

- ❌ 对每个维度（Country、Chain…）各跑一套宽表交叉 SQL
- ❌ 在 2b 用 `5_SID+Country` 四向组合定 CS（已由 A+B 完成）
- ❌ 2c 阶段追加 execute_sql

## 后续（Phase 3，与配置一并）

- [ ] 配置表验证（Dida）
- [ ] 查价 / 验价
- [x] 外部事件 D 线（取国：C=`4_Country` / S/CS=`5_SID+Country`；A/B 强则跳过）

## 已定决策记录

| 决策 | 结论 |
|------|------|
| 2c 是否自动下钻 | ✅ 自动 |
| C / Dida 下钻 | ✅ 共用 Client 侧重维度 |
| Account 阈值 | ✅ 贡献 ≥10% 才报告 |
| 外部事件库 | ✅ `sql/external-events-lite/` |
