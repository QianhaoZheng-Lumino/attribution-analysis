# CSA 自动上下线 lite（辅助）

报告节名：**CSA 自动上下线**（Autoline）。  
从 `configuration.wolf_rateadjust_log`（`level = 'CSA'`）拼账号开闭区间，按账号输出两窗日均在线小时。

**业务含义：** Autoline——准确率等指标触发账号自动下线，过一段时间再上线。本指标量开闭折成的小时数。  
**与渠道「在线时长」不同：** 渠道用 `rateaccuracy.channel_online_states_new`（整渠）；本节用 CSA 日志（client × supplier × account）。  
**与 3a CSA 行的关系：** 现行 3a CSA detail **外层排除 JobAPI**，偏向人工/非自动操作；Autoline 时长**必须保留 JobAPI 行**（自动上下线常记在 JobAPI 下）。二者读法不同；**已拍不删 3a CSA / 不改 14→13**（见文末）。

## 何时查（出数，与限流同一套）

1. 已有 focus `{client_id}`（大盘 / 无 focus 不查）
2. 填 `{sid_list}`：2b **锁定** SID，或 `02-sid` 占本案 **|ΔBKS| ≥ 10%**；都没有 → `02-sid` `|change|` Top3  
   （`{sid_list}` 是本案结构 SID，**不是**客户常驻供应商名单）
3. 禁止空 `IN ()`。一次一个 client。
4. 窗 = Phase 1 / 限流同一套 `compare_*` / `current_*`

结构 `{sid_list}` 一旦圈定 → **必跑、报告必出表**（与限流相同：未过异动阈值仍出表作排除）。

## 异动与账号筛选（已拍板）

| 项 | 口径 |
|----|------|
| 节名 | **CSA 自动上下线** |
| 异动 | 高产账号上，\|当前窗日均 − 对比窗日均\| **≥ 3h**（**双向**：变少或变多都算） |
| 解读 | **任一**高产账号过线 → 写「有 Autoline 异动」，表内标出这些账号 |
| 死号 | 两窗日均都 **&lt; 1h** → 不参与 3h 判定（仍可出表） |
| 高产（目标） | 每个结构 SID 内，按对比窗 BKS **降序累加，覆盖该 SID 对比窗产量前 80%** 的账号参与异动判定 |
| 高产（过渡） | 用 `02-account-bks.sql`（对比窗 **BKS ≥ 5**）；**80% 累加暂缓** |
| 因果（已拍） | Autoline **掉线** → SS 请求↓ + 有价请求↓，有价率大致不变 → 产量可↓；**上线变多** → 请求/有价请求可↑ → 产量可↑。**涨跌对称** |
| 与限流差 | 限流常见 **有价率↓ + 限流率↑**（跌向定责更严）；Autoline 典型是 **有价率平 + 请求/有价请求同向变**，**涨跌都可倾向** |
| 与渠道在线差 | 渠道在线（A5）**只解释查价段、不定产量**；Autoline **可以解释产量**。**禁止**抄 A5 |
| 定责位置 | **不新开定责字母**。**时长与产量同向**（Δh≤−3h 且 BKS↓，或 Δh≥+3h 且 BKS↑）→ **可倾向作主因**（**D6**，CS 链路，**双向**）。字母常 **CS**；与平台共向并存时主因/并列按 2b。时长与产量不同向 → 不得写主因 |
| JobAPI | **不排除**。时长链必须保留 JobAPI。3a CSA detail 排除 JobAPI 的规则 **不要**抄到本目录 |

## 报告位置

`### 3b 查价` 下：`#### 限流/缓存` / `#### 在线时长`（渠道）旁 → **`#### CSA 自动上下线`**。  
证据对照表**必有**同名一行（checker：成品**必有** H4，对齐限流；无 `{sid_list}` / 未跑用写法 1：一行 `—` + 解读「未查」）。

## 文件

| 文件 | 用途 | MCP tables |
|------|------|------------|
| `01-daily-account.sql` | 日表明细（排查 / 可选）；两窗可各跑一次 | `configuration.wolf_rateadjust_log` |
| `02-account-bks.sql` | 对比窗 BKS≥5 高产账号（过渡） | `dwd.dwd_hotel_order_channel_supplier_booking_mf` |
| `03-window-avg.sql` | **Phase 3 主用**：账号两窗日均 + `delta_h` | `configuration.wolf_rateadjust_log` |

## MCP 顺序（拆开跑，禁止拼成一条）

```
Step 0  填 {client_id} + {sid_list}（禁止空 IN ()）
Step 1  03-window-avg.sql — 两窗日均 + delta_h（主用；禁止手算）
        填 compare/current 起止（止日含）+ {compare_n_days}/{current_n_days}
Step 2  02-account-bks.sql — 同窗同 sid_list；与 Step 1 可同批（不同表，勿 JOIN）
Step 3  Agent 本地：高产 = 02 返回的账号；死号剔除；|delta_h|≥3 → Autoline 异动
Step D  需要日形时再跑 01-daily-account（series_start/end = 对比或当前窗）
```

**禁止**把 `wolf_rateadjust_log` 与订单表写进同一条 SQL（曾 MCP 43019）。

## 占位符

| 占位符 | 说明 | 示例 |
|--------|------|------|
| `{client_id}` | 必填，单 client | `SnapTravel2B` |
| `{sid_list}` | 结构 SID，逗号分隔整数 | `26, 257` |
| `{compare_start}` / `{compare_end}` | 对比窗（止日含） | `2026-09-17` / `2026-09-23` |
| `{current_start}` / `{current_end}` | 当前窗（止日含） | `2026-09-24` / `2026-09-30` |
| `{compare_n_days}` / `{current_n_days}` | 各窗天数（止日含，整数） | `7` / `7` |
| `{series_start}` / `{series_end}` | 仅 `01` 日表起止（止日含） | `2026-09-17` / `2026-09-23` |

## 口径要点

- `status = 1` 为在线；分区 `clientid + supplierid + supplieraccountid`
- 原始 CSA 行不加时间 WHERE；LAG/LEAD 后再裁窗
- 未闭合右端 = `{current_end}`（或 `01` 的 `{series_end}`）次日 00:00，不用 `now()`
- **不要** `username != 'JobAPI'`

## 案例验证（2026-09-24 · SnapTravel2B）

- 窗：对比 9/17–23，当前 9/24–30；`sid_list=26,257`（本案 \|ΔBKS\| 过线，非账号常驻名单）
- 过渡高产 BKS≥5：2722 / 720 / 2343 / 165 / 2667 / 2668 均 \|Δh\|≥3h → **有 Autoline 异动**
- 同案 3a CSA=0：因 detail **排除 JobAPI**；Autoline 时长**含 JobAPI** 可见掉线——印证两节不可混读，也支持「先挂 Autoline、暂不删 3a」

## 挂接边界（已落地 / 禁止动）

| 可改 | 本轮 | 禁止本轮改 |
|------|------|------------|
| 本目录 SQL + README | ✅ | — |
| `04-report-skeleton` 追加 H4 + 证据行 | ✅ 追加 | 不改 3a 14 行表 |
| `04-report` / `03` 追加出数与解读 | ✅ 追加条目 | 不改 14/14、不删 CSA level |
| `02` W2 列表追加本目录文件 | ✅ 追加 | 不改 W2 五条上限语义 |
| `params-template` `{sid_list}` 用途加本目录 | ✅ 追加 | 不改 SH/SS/限流定义 |
| `check-report-skeleton.py` | ✅ **硬门**（对齐限流） | 成品必有 H4 + 证据对照表「CSA 自动上下线」行；有 H4 → 校验表头；无 SID/未跑用写法 1，禁止删节 |
| 3a CSA checklist/detail、14→13 | ❌ | **已拍不删**（见下） |
| 80% Pareto SQL | ❌ | 过渡仍用 BKS≥5 |

## 已拍：不删 3a CSA（保持 14 类 + Autoline 双轨）

2026-11-09 摸底后否决 14→13。理由：3a CSA **排除 JobAPI**，抓人工账号开关房/调价；Autoline **保留 JobAPI**，抓自动上下线时长。二者互补，不可互相否定。历史案（如 HopperCap1TPS 2026-08-04 CSA「LTB差」关账号约占掉量 10%）证明人工 CSA 仍有定责价值。删除会动 skeleton/checker/全部 gold·case，且系统性漏人工变更。**保持 14/14；不再重开删 CSA。**
