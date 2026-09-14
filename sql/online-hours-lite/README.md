# 渠道每日在线时长 lite（Phase 3 辅助）

**默认（2026-09-09）：** MCP 跑 `03-window-avg.sql` 直出两窗日均；日表明细用 `../online-hours.sql`。均须 `{client_id}` 等值。  
开窗 SQL 已在 MCP 复测通过（含 SuperPlus 42 天、SnapTravel2B gold 窗与手算 **23.45 / 20.9 / −2.55** 一致）。**不是**「开窗函数必 500」。  
**禁止**无 `client_id` 扫全客户。全客户 × 日可在 Hologres 跑 `channel_daily_online_hours.sql`（可选，#22 不阻塞）。

**Fallback：** 默认 SQL 仍 500 时，才用本目录 `00-count` + `01-fetch-logs` 拉全 log，再跑 `scripts/test-online-hours.py`。禁止手算日均。

触发：**DidaBiz QPS/PPS WoW \|变化\| > 10%**（涨跌双向），或用户问在线时长；**窗口与 Phase 1 对齐**。  
**禁止**用本表解释验价准确率。

## 复用输出

| 列 | 含义 |
|----|------|
| `avg_online_hours_previous` / `_current` | 对比窗 / 当前窗日均小时 |
| `delta_h` | current − previous；**≤ −2** → 在线时长有异动 |
| `dt, online_hours, online_pct` | 日表明细（`../online-hours.sql`） |

## 占位符

| 占位符 | 说明 | 示例 |
|--------|------|------|
| `{client_id}` | **必填** | `Check24` |
| `{start_date}` | 开窗起日（含）= `compare_start` | `2026-07-25` |
| `{end_date}` | 开窗止日（不含）= `current_end+1` | `2026-08-08` |
| `{n_days}` | `end_date - start_date` | `14` |
| `{compare_start}` / `{compare_end}` | 对比窗（止日含） | `2026-07-25` / `2026-07-31` |
| `{current_start}` / `{current_end}` | 当前窗（止日含） | `2026-08-01` / `2026-08-07` |
| `{status}` / `{offset}` | 仅 fallback `01-fetch-logs` | `1` / `0` |

## MCP 顺序（2026-09-09）

```
Step 0  填 {client_id}（禁止空、禁止一次查多个 client）
Step 1  03-window-avg.sql — 两窗日均 + delta_h（默认；禁止手算）
        需要日表时改跑 ../online-hours.sql（MCP 返回的 dt 或为毫秒 epoch，须转北京日）
Step 1b 02-email-source-clients.sql（可选，邮件解析客户名单）
Step 2  04-window-source.sql — 窗内主导 source / 下线 remark（允许时间过滤；不算小时）
Step 3  对照 mapping §6–§8（在线↓只解释查价）
Step F  仅当 Step 1 的 MCP 500：00-count → 01-fetch-logs 分页拉全
        （禁止时间 WHERE、禁止 ORDER BY channel_operation_time）
        → python scripts/test-online-hours.py ...
```

`tables`: `["rateaccuracy.channel_online_states_new"]`

## 口径（Hologres / MCP SQL 与脚本一致）

1. 字段：`channel_operation_time`（库内 **timestamptz**）。SQL 用 `AT TIME ZONE 'Asia/Shanghai'`。**不要** `to_timestamp(col/1000)`（那是 MCP JSON 毫秒的 Python 算法）。不用 `log_time`。
2. **`status=0` 下线，`status=1` 上线**；区间 `[本次,下次)` 内 status=1 计入在线
3. 同一时刻留 `id` 最大；连续相同 status 忽略
4. 窗口开始前最后一次有效动作 = 起点状态（故 **算小时的 SQL 禁止按分析窗过滤 log**）
5. 按北京日切开，单日 cap 24h
6. 无日志且窗口前也无动作 → 当天 0h
7. `source` / `remark` 不参与小时计算

## 异动与 source 可信度

| 规则 | 阈值 |
|------|------|
| 触发查在线 | DidaBiz QPS/PPS **\|WoW\| > 10%** |
| 在线时长异动 | 当前窗日均比对比窗 **少 ≥ 2 小时** |
| **因果** | **在线↓ → 查价↓ only**；产量看转化 |
| **邮件解析** source | **完全可信** |
| **数据库分析** source | **仅参考**，不得强定责 C 下线 |

完整解读：[docs/online-hours-mapping.md](../../docs/online-hours-mapping.md)

## 解读（摘要）

| 现象 | 指向 |
|------|------|
| 日均在线 **↓≥2h** + QPS↓>10% + **邮件解析** 有上下线动作 | **倾向 C**（中～强） |
| 同上但 **仅数据库分析** | **弱 / 待确认**，仅辅助 |
| 在线接近 24h，QPS 仍↓ | 不是下线 → 需求 / 渠道请求逻辑。上限只打有价率（A6） |
| 邮件解析客户短时频繁翻转 | 按动作间隔合计，不按日志条数 |

## 海外全客户批量

只在 Hologres 跑 `../channel_daily_online_hours.sql`。MCP 不要跑全量。
