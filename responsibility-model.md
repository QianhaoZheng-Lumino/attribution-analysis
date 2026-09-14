# 责任归属模型（C / Dida / S / CS）

**贡献度 ≠ 责任。** 定责只做 **C×S 交叉验证（2b）**；Country/Chain 等是 **定责后下钻（2c）**，见 [cross-validation-design.md](cross-validation-design.md)。

## 四方定义

| 代号 | 含义 |
|------|------|
| **C** | Client 渠道自身 |
| **Dida** | 我方内部（配置、查价验价等；2b 与 C 合并，Phase 3 区分） |
| **S** | Supplier 供应商 |
| **CS** | Client-Supplier 链路 |

## Phase 2b：C×S 交叉验证（双门，2026-09-09）

```
验证 A（总是）：Client C 下各 supplier → 2a 的 2_SID 层级
验证 B（门 1）：结构 SID 下各 client → cross-validation-b.sql / lite 14-sid-client-validation.sql
```

**有效 SID：** `previous_bookings >= 5`。占比分母 = 本 client `|ΔBKS|`（与 2a `02-sid` 贡献% 相同）。跌产/涨产同一套门（同向 = 降或涨）。

| 门 | 观测 | 动作 |
|----|------|------|
| **门 1 必跑 B** | 任一有效 SID 占本 client `|ΔBKS|` **≥10%** | **必跑验证 B**（过线 SID 每家各一次；MCP 一家一次 lite） |
| **门 1 跳过 B** | **没有** SID ≥10% | 才可跳过 B |
| **门 2 写死 C/Dida** | 家数同向 **≥70%** 且 **没有** 单 SID ≥50% | 才允许写 **C 或 Dida** |
| **门 2 禁止写死** | 家数 <70%，或单 SID ≥50% | **禁止**写死 C/Dida；用验证 B 判 **S** 或 **CS** |

**70% 只管「宽不宽」，不是跳过 B 的开关。** 写死 C/Dida 之后，B 仍可 **并列 S/CS**，不翻主因。

验证 B 读法（已跑的 SID 上）：
1. S 下多数 client 同向 → **S**（或并列 S）
2. 仅 focus client 变，或本 client 逆势 → **CS**（或并列）
3. **禁止**用「某结构 SID 的 B 是 CS」否决已满足门 2 的 C/Dida 主因

涨产额外：客户 WoW **显著高于** 大盘，且 Top S 上本 client 增量全平台最大，B 显示多 client 亦涨 → **非 CS**；写 **「C 与 S 并列待 3b 区分」**，**禁止** 3b 未跑前写「C 主因」。

**2b 仅为初判**；C vs Dida 的最终主次靠 Phase 3。

### 禁止加码 / 借口

| 借口 | 实际 |
|------|------|
| 家数过 70%，跳过 B | 跳过 B **只看门 1**（无 SID≥10%） |
| 用户说别查了 / 时间紧 | 门 1 触发必须跑 B |
| 量集中也不改家数门槛，仍写 C/Dida | 单 SID≥50% → 门 2 **禁止写死** |
| 任一结构 SID 的 B 是 CS → 不得写 C/Dida | **禁止。** 会把 30/30 普跌改判成 CS |
| 把 50% 降到 30% 更稳 | **禁止。** 会误伤 max SID 约 30% 的可写死样本 |

## Phase 2c：定责后自动下钻

2b 完成后 **自动**执行，规则见 [phases/02c-drilldown.md](phases/02c-drilldown.md)。

| 2b 结论 | 下钻看什么 |
|---------|-----------|
| **C 或 Dida** | Country, Chain, LT, LOS, Nationality |
| **S 或 CS** | SID+Country, SID+Chain, SID+Account(≥10%), SID+LT/LOS/Nationality |

**C 与 Dida 下钻清单相同。** Dida vs C 靠 Phase 3。

## Phase 3：C vs Dida / 链路佐证

| 证据 | 结论 |
|------|------|
| A 配置 + B 指标与预期一致 | **Dida** |
| A 无 + B 有价率/查验比正常 | **C** → 报告收口 |
| B 查验比↓（无配置） | 竞争力 / 渠道侧 |
| C 准确率异常 | **独立技术线**，见 [accuracy-issue-mapping.md](docs/accuracy-issue-mapping.md) |

**A+B+C 合成规则：** [docs/evidence-synthesis-rules.md](docs/evidence-synthesis-rules.md)

## 文件索引

| 步骤 | 文件 |
|------|------|
| 2a 贡献度 | sql/dimension-contribution.sql |
| 2b 验证 B | sql/cross-validation-b.sql |
| 2c 下钻 SOP | phases/02c-drilldown.md |
| 全流程 | phases/02-dimension-drilldown.md |
