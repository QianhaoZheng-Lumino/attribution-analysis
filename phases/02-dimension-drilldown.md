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

## 查数波次

占位符在进入该波之前填好：`client_id`、`analysis_date`、产量窗口。`{sid_list}` 只在 W1 返回之后才算有值。每一批是两轮：先 Read 这批最多 5 个文件，下一轮再发已经 Read 过的查询。同一轮 `execute_sql` 最多 5 条。一次调用一个 lite 文件。某一条 500 只重试这一条，同批成功结果保留。

### W0 Phase 1

文件：`sql/anomaly-detection-lite/01-period-totals.sql`，然后 `02-historical-baseline.sql`，然后 `03-daily-series.sql`。一条完成后再发下一条。失败重试必须 `01 → 02 → 03` 串行，禁止三步并行。

### W1 定责入口

只跑 `sql/dimension-contribution-lite/02-sid.sql`。这一条回来之前，不发 W2、W3。

### W2 02-sid 已返回

先按现有规则填 `{sid_list}`（2b 锁定的 SID，或 `02-sid` 里 `|change|` Top3）。填完仍为空时，本波照样开始，只是不发 SH、`01-ss-supplier`、限流。

下列文件互不依赖。按优先级每批 5 条，直到发完。同一轮最多 5 条：

1. `14-sid-client-validation.sql`：只对占 `|ΔBKS| ≥ 10%` 的 SID，每家一条。没有这样的 SID 就跳过，并写「无 SID≥10%，跳过」。这些验证 B 优先占用前面批次的名额。
2. `sql/config-change-detection-lite/checklist/01-cs.sql` 到 `14-configuration.sql`，共 14 个文件，含结果为 0 的也要发。
3. 其余各一条：`02-client-before-after-bks.sql`、`sql/online-hours-lite/03-window-avg.sql`、`sql/rate-limit-lite/01-ss-supplier-window.sql`、`sql/search-attribution-lite/01-ss-supplier.sql`。

`{sid_list}` 仍空时，从本波拿掉 `checklist/08-sh.sql`、`01-ss-supplier`、`rate-limit-lite/01-ss-supplier-window.sql`。其余 checklist 照发。W2 不包含 2c 路径文件，也不包含任何 detail。`01-ss-supplier` 不等 `00-client-total`。`03-window-avg.sql` 在本波发送，不必等查价 WoW。

### W3 2b 方向已经写出

只跑该方向的文件，每批最多 5 条。`02-sid` 不重复跑。方向还没写出时不发本波。禁止两个方向一起投机跑。

| 方向 | 文件 |
|---|---|
| C/Dida | `04-country.sql`、`06-chain.sql`、`08-lt.sql`、`10-los.sql`、`12-nationality.sql` |
| S/CS | `05-sid-country.sql`、`07-sid-chain.sql`、`03-sid-account.sql`、`09-sid-lt.sql`、`11-sid-los.sql`、`13-sid-nationality.sql` |

验证 B 的跳过条件、写死 C/Dida 的双门、S/CS 的 Account 过滤，仍以 `responsibility-model.md` 为准。本波只改变发送批次。

### W4 checklist 已返回

只跑过线的 detail，每批最多 5 条。一般 level：`event_count > 0` 才跑配对 detail。SH：`event_count ≥ 10` 才跑 `detail/08-sh-hotel-bks-lite.sql`；`<10` 不跑；`>50000` 或 MCP 500 走现有 BI 兜底。CDH / LCDH：`event_count > 0` 才跑 `detail/07-cdh-hotel-bks-lite.sql` / `detail/09-lcdh-hotel-bks-lite.sql`。`event_count = 0` 不发 detail。S Bottom 只用 `detail/13-s-bottom-detail.sql`，禁止抄 C Bottom。

### 其余查询

3b 里除 `01-ss-supplier` 以外的下钻、3c、3d、准确率 issue、在线时长 500 兜底脚本，仍按 Phase 3 现有触发条件决定发不发。同一时刻有多条、且谁也不用谁的结果时，同样每批最多 5 条，每条一个文件。

## 执行清单

```
- [ ] W1：dimension-contribution-lite/02-sid.sql（回来之前不发 W2、W3）
- [ ] W2：验证 B（过线 SID 每家一次；无则写「无 SID≥10%，跳过」）+ checklist 与「查数波次」W2 其余文件
- [ ] W3：2b 方向写出后，只发该方向的 2c 文件（C/Dida 5 个或 S/CS 6 个）— 缺任一 → 2c_progress 未达标
- [ ] 2b-A 读 2_SID → 定责方向
- [ ] 2c 写入报告（Country+Chain 表；LT/LOS/Nationality 段落）
```

### 2c MCP 必跑文件（lite · 禁止只跑 Country）

| 2b | 文件 | 报告 |
|----|------|------|
| **C/Dida** | `02-sid` + `04-country` + **`06-chain`** + **`08-lt`** + **`10-los`** + **`12-nationality`** | **5/5** |
| **S/CS** | `02-sid` + `05-sid-country` + **`07-sid-chain`** + `03-sid-account`（占 SID 变化≥10%） + **`09-sid-lt`** + **`11-sid-los`** + **`13-sid-nationality`** | 至少 country+chain+lt+los+nat |

这些文件按「查数波次」W3 发送。方向未写出不发。禁止两个方向一起发。

BI 一次跑完整 `dimension-contribution.sql` 可替代 lite 分批，但报告仍须覆盖上表各 hierarchy。

**2c_progress：** C/Dida 路径 `{n}/5`（country/chain/lt/los/nationality 均 MCP ✅ 或 BI 全量 ✅）。
