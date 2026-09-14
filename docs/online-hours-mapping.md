# 渠道在线时长 — 触发、口径与解读

> **2026-09-04 定稿口径**；**2026-09-09 计算路径改为 MCP 开窗 SQL**。表：`rateaccuracy.channel_online_states_new`  
> SQL：`sql/online-hours-lite/03-window-avg.sql`（MCP 默认）· `sql/online-hours.sql`（日表，MCP/Hologres）· 全客户批处理仅 Hologres

---

## 1. 它回答什么问题

**只服务于供给/竞争力线（3a + 3b）**，用于解释 **DidaBiz 查价量（QPS/PPS）下降** 是否因 **渠道侧下线/在线变短**。

| 能解释 | 不能解释 |
|--------|---------|
| **在线时长↓ → 查价↓**（漏斗上段，见 §2） | **产量方向**（须看转化；见 §2） |
| DidaBiz QPS↓ 是否因渠道下线/在线变短 | 验价准确率（禁止用在线表） |
| 2b=C/Dida 时是否倾向 **C（渠道侧）** | SS 层 supplier 问题 |
| BKS↓ 且 **转化近似不变** 时的间接 C 侧证据 | 价格竞争力（看查验比） |

---

## 2. 因果链：在线时长只解释查价（2026-09-04 补充）

### 2.1 核心（已定）

**在线时长减少 → 查价减少。**

渠道不在线就不会发 Search 请求，因此在线时长异动 **只绑定漏斗上段（DidaBiz QPS/PPS）**，是查价量变化的 **直接、机械** 解释之一。

```
在线时长 ↓  ──→  查价（QPS/PPS）↓     ← 在线时长能解释到这里
                    │
                    ↓（转化不变时）
                 产量 ↓
```

### 2.2 产量须看转化

查价减少 **在转化不变** 时，通常会导致产量减少。  
若 **转化同时变化**，产量方向由转化与查价的 **净效应** 决定，**不能**从在线时长直接推断 BKS：

```
查价 ↓  +  转化 ↑  →  产量可涨可跌（看谁更强）
查价 ↓  +  转化 ≈   →  产量倾向 ↓
```

| 在线 | 查价 | 转化 | 产量 | 读法 |
|------|------|------|------|------|
| ↓ | ↓ | ≈ | ↓ | 在线缩短 → 查价少 → 产量少（典型 C 下线跌产） |
| ↓ | ↓ | **↑** | **↑** | 在线缩短 **只解释查价下降**；产量涨由 **转化提升** 驱动 |
| ≈24h | ↓ | — | ↓ | **不是下线** → 需求 / 其他 C（上限 **不**解释查价总量，见 A6） |

### 2.3 案例：SnapTravel2B @ 2026-08-01（涨产 gold）

| 指标 | WoW | 与在线时长的关系 |
|------|-----|------------------|
| 日均在线 | **-2.55h** | 邮件解析有上下线；**可解释部分查价下降** |
| 查价量 | **-19.6%** | 与在线缩短 **同向**，合理 |
| 验价量 | **+24.4%** | **转化跳升** — 在线时长 **不能解释** |
| 产量 | **+73.5%** | 由 **S 平台共涨 + C 转化放大** 驱动，**非**在线时长 |

→ 最终定责 **S 主因 + C 转化放大并列**；在线时长仅作 **3b 查价下降的辅助 C 证据**，**不得**用来解释涨产或推翻 S 主因。

### 2.4 报告写法

- ✅ 「在线缩短 **X h**，与查价 **-Y%** 同向，**倾向 C 侧下线/在线变短**（邮件解析 source 时）」
- ✅ 「查价降但产量涨 → **转化提升**；在线时长只解释查价段」
- ❌ 「在线缩短导致产量下降/上升」— **禁止**（未经过转化链）
- ❌ 用在线时长 **定责产量方向** 或 **推翻** 2b/3b 主结论

---

## 3. 字段与动作语义

| 字段 | 规则 |
|------|------|
| `channel_operation_time` | **动作发生时间**（库内 timestamptz；MCP 拉原始 log 时序列化为毫秒）。SQL 用 `AT TIME ZONE 'Asia/Shanghai'`，**不用** `log_time`，**不要** `to_timestamp(col/1000)` |
| **`status = 0`** | **下线动作** — 从该时刻起进入下线状态 |
| **`status = 1`** | **上线动作** — 从该时刻起进入在线状态 |
| `source` | 动作来源；**决定信号可信度**（见 §5） |
| `remark` | 下线/上线原因（如「下线_请求为0」「online_adaptive」） |

同一 `client_id`、同一毫秒多条：留 **`id` 最大** 一条。  
连续相同 `status`：后一条为重复动作，状态不变，区间继续延伸。

---

## 4. 计算口径（与 SQL 一致）

1. 按 `channel_operation_time` 排序，相邻动作为 `[本次, 下次)` 区间  
2. **本次 status=1 → 区间计入在线；status=0 → 不计入**  
3. 窗口开始前 **最后一次有效动作** 决定窗口起点 0 点时的初始在线/离线状态  
4. 按 **北京时间自然日 0 点** 切开，单日 cap **24h**  
5. 输出：`client_id, dt, online_hours, online_pct`  
**MCP 默认实现 = `sql/online-hours-lite/03-window-avg.sql`（禁止手算）。** 日表明细用 `sql/online-hours.sql`。仅当二者 MCP 仍 500 才用 `scripts/test-online-hours.py`（JSON 毫秒 → Python）。

**时间窗口：** 必须与 **Phase 1 当前期 / 对比期完全对齐**（`compare_start` ~ `current_end`，见 `params-template.md`）。

汇总对比：
- `avg_online_hours_current` = 当前期日均 `online_hours`
- `avg_online_hours_previous` = 对比期日均 `online_hours`
- `online_hours_wow_pct` = (current − previous) / previous × 100（previous=0 时单独标注）

---

## 5. 数据来源可信度（2026-09-04 定稿）

`source` 字段常见取值：`邮件解析`、`数据库分析`、`每日全量同步`、`手工录入`、`渠道后台抓取`。

| source | 可信度 | 归因用法 |
|--------|--------|---------|
| **邮件解析** | **完全可信** | 可作 **强～中** 证据支持「渠道主动下线/恢复」 |
| **数据库分析** | **有疑问，仅参考** | 只能 **辅助**；**不得**单独作为「已确认 C 下线」 |
| 每日全量同步 | 辅助 | 多为 0 点「延续上次状态」，通常 **不算状态变化** |
| 手工录入 / 渠道后台抓取 | 个案 | 结合 remark 解读 |

**混源客户**（同一 client 既有邮件解析又有数据库分析）：  
报告须注明 **本窗口内主导 source**；若窗口内有效下线动作 **仅来自数据库分析**，信号强度 **降为弱 / inconclusive**。

> 典型：`Check24` 走数据库分析（约每 10 分钟探测），**不是**邮件解析客户；在线时长 **仅辅助**，不能强定责。

**邮件解析客户（Overseas API 重点，2026-09-04 MCP 拉取）：**

| client_id | 备注 |
|-----------|------|
| SuperPlus | 高日志量 |
| SnapTravelCUG | |
| SnapTravel2B | gold 涨产案例 |
| SnapEBK | |
| Lvzan | |
| SnapTravelRS | |
| AgodaPKG | gold 跌产案例 |
| Barli2b / NgChow / Agoda / AgodaUK | 邮件解析，非典型 Overseas 归因对象 |

完整名单：`sql/online-hours-lite/02-email-source-clients.sql`（表内 `source='邮件解析'` 动态维护）。

---

## 6. 何时查（触发条件）

### 6.1 必须查

满足 **全部**：

1. 已跑 **3b 机构级**（`00-client-total` 或 funnel fallback）  
2. **DidaBiz 查价量（QPS 或 PPS total_search）WoW \|变化\| > 10%**（与限流触发阈值一致，**涨跌双向**）  
3. 分析粒度为 **单 client**（`client_id` 必填）

### 6.2 建议查

| 场景 | 说明 |
|------|------|
| 2b = **C 或 Dida**，3a 无强配置，BKS↓ | 排除渠道下线 |
| 用户问「是否下线 / 在线多久」 | SKILL 触发词 |
| 3a Configuration **QPS/PPS 上限** 已查 | 上限只解释有价率；总量仍↓ → 在线时长 vs 需求 vs A2 |

### 6.3 不查

- 仅 SS/supplier 问题（2b=S 或 CS 且 QPS 正常）  
- 仅验价准确率问题（3c 独立线）  
- 仅有价率↓ / 查验比↓，**DidaBiz QPS 未超 10%**  
- 无 `client_id`（禁止空 WHERE 扫全表）

---

## 7. 在线时长「异动」判定

| 条件 | 判定 |
|------|------|
| 当前窗 **日均 online_hours 比对比窗少 ≥ 2 小时** | **在线时长有异动的** |
| 少 < 2h | 正常波动，不单报 |
| 当前窗日均接近 0（如 < 2h）且对比窗 ≥ 10h | **强信号**（疑似长期下线） |

与 QPS 10% 触发 **独立**：  
- 可先因 QPS↓>10% 触发查询，再用 **2h 规则** 判断在线是否「异动」。

---

## 8. 解读与合成（evidence-synthesis）

| 观察到… | 且 source 以… | 则… | 强度 |
|---------|--------------|-----|------|
| QPS↓>10% + 日均在线 **↓≥2h** | **邮件解析** 有明确上/下线动作 | **倾向 C（渠道下线/在线缩短）** | 中～强 |
| QPS↓>10% + 日均在线 **↓≥2h** | **仅数据库分析** | **辅助参考**；写「疑似下线，待渠道确认」 | 弱 |
| 在线 **≈24h**，QPS 仍↓ | 任意 | **不是下线** → 需求 / 其他 C（A6：上限不打总量） | — |
| 在线正常，BKS↓ 且 **转化≈** | — | 在线缩短 **不能解释** BKS；查其他 C/S 因素 | inconclusive |
| 在线↓，查价↓，BKS↑ | — | 在线 **只解释查价**；产量由 **转化↑** 驱动（§2） | — |

**禁止：**
- 用在线时长解释 **验价准确率**
- 用在线时长 **直接定责产量方向**（须经 §2 转化链）
- 对 **数据库分析** 客户写「已确认 C 下线」（除非邮件解析/人工录入 corroborate）

---

## 9. MCP 执行（2026-09-09）

```
Step 0  client_id = Phase 1 分析对象（必填；禁止扫全表）
Step 1  03-window-avg.sql
        {start_date}=compare_start  {end_date}=current_end+1
        {n_days}=end-start  两窗起止与 Phase 1 对齐
Step 1b （可选）02-email-source-clients.sql
Step 2  04-window-source.sql（窗内 source / 下线 remark；允许时间过滤）
Step 3  对照 §6 触发 + §7 异动 + §8 解读
Step F  仅 Step 1 仍 500：00-count → 01-fetch-logs 拉全 → test-online-hours.py
```

详见 `sql/online-hours-lite/README.md`。

---

## 10. 相关文档

- [config-search-precheck-mapping.md](./config-search-precheck-mapping.md) — DidaBiz QPS↓ 非配置原因  
- [es-cause-catalog.md](./es-cause-catalog.md) — A5 在线只解释查价；A6 上限只打有价  
- [evidence-synthesis-rules.md](./evidence-synthesis-rules.md) — 2b=C/Dida 序号 5  
- [accuracy-issue-mapping.md](./accuracy-issue-mapping.md) — 准确率线禁止用在线表
- `sql/online-hours-lite/03-window-avg.sql` — MCP 默认两窗日均
- `scripts/test-online-hours.py` — 仅 fallback

## 11. #22 已收口（2026-09-09）

归因 **不再等** 全客户物化表。MCP 默认对单 client 跑 `03-window-avg.sql` / `online-hours.sql`。

全客户 × 日的 Hologres SQL（`sql/channel_daily_online_hours.sql`）仍可选用，**不阻塞** Skill。触发 / 2h / source / 只解释查价 **不变**。

