# Phase 3 证据线 D：外部营销日历

> 表：`ads.ads_marketing_calendar_event_wide_d_f`  
> Lite SQL：`sql/external-events-lite/`  
> 与 A/B/C **并列**，**不替代**配置或查价证据。

## 1. 表定位

| 项 | 说明 |
|----|------|
| **粒度** | **Dida 全局**地理 × 时间（**无 client_id / supplier_id**） |
| **禁止** | 与某 client 产量、TTV 做「交叉归因」；`city_ttv` / `city_rank_no` 仅为 **全局优先级排序** |
| **快照** | 始终 **`dt = MAX(dt)`**（最新快照分区） |
| **回答** | 异动窗口内，Top **hotel country** 是否有 **节假日（HOLIDAY）** 外部需求线索 |
| **责任** | 指向 **C（渠道/市场需求侧）** 或报告收口（问渠道）；**不能**定责 Dida 配置 / S / CS |

## 2. 字段速查

| 字段 | 用途 |
|------|------|
| `event_type` | 归因 **仅查 `HOLIDAY`**（2026-08-18 定稿） |
| `event_name` | 报告展示 |
| `event_start_date` / `event_end_date` | 与 Phase 1/3 **窗口重叠**匹配 |
| `country_code` | ISO2；对接 2c **hotel 国**：C/Dida → `4_Country`；**S/CS → `5_SID+Country`** |
| `city_code` / `city_name_cn` | 展示；Phase 1 **不做 city 级匹配** |
| `city_ttv` / `city_rank_no` | **全局**产量优先级；HOLIDAY 过滤用 |
| `event_extra_json` | WEATHER 明细（不查） |

## 3. 事件类型与重要性过滤

**永久排除（不作为 D 线证据）：**

| 类型 | 原因 |
|------|------|
| `WEATHER` | 噪声大、日更 |
| `FAIR_EVENT` | 展会/活动对产量归因 **不重要**（业务定稿 2026-08-18） |
| `CONCERT_EVENT` | 演唱会对产量归因 **不重要**（同上） |

**唯一纳入：**

| event_type | 规则 |
|------------|------|
| **HOLIDAY** | 仅 **`city_rank_no <= 30`**（Dida 全局 Top30 产量城市关联节日；过滤 Purple Heart Day 等低重要度地方节日） |

```sql
AND event_type = 'HOLIDAY'
AND city_rank_no <= 30
```

> 历史 gold 中 FAIR/CONCERT 仅为旧版 D 线输出，**回归与新案例一律 HOLIDAY-only**。

## 4. 窗口重叠

与 params-template 同窗：

```
event_start_date <= {window_end}
AND event_end_date >= {window_start}
```

- **当前窗**：`{analysis_date}` ~ `{current_end}`（必查）
- **对比窗**：`{compare_start}` ~ `{compare_end}`（可选，看事件是否跨窗切换）

## 5. 触发条件（2026-09-04 定稿）

**先判跳过，再判必查。** 强证据与 P1 单国 ≥10% 冲突时，**跳过优先**（不跑 D1/D2 MCP）。

### 5.1 跳过

| 条件 | 报告写法 |
|------|----------|
| **A 或 B 已达「强」** | 「未查（A/B 已强定责）」 |
| 2c 多国极度分散，无 Top 国 | 「未查（无结构国）」 |

**「强」操作定义（须同时可在合成表里写强度=强）：**

- **A：** 14 类中有与 BKS **同向**的强配置（合成规则表强度列 = **强**）
- **B / S：** 2b=**S** 且验证 B 已钉死 **平台共涨或共跌**（该 SID 多 client 同向）
- **B / CS：** 合成规则 CS 序号强度 = **强**（不是「中」「中～强」的倾向档）

**不算强、不得跳过：** 仅「倾向 C」；CS/S 仅倾向 / 中 / 中～强；A/B inconclusive。例：HBGPKG 倾向 CS → **仍查**。  
**算强、必须跳过：** SnapTravel2B — 验证 B 多 client 在 26 同涨 → **不查 D**（P1 US 97% 也不查）。

### 5.2 必查（未命中 §5.1）

| 优先级 | 条件 | 查哪些国家 |
|--------|------|------------|
| **P0** | A 无强信号 + B inconclusive/正常 + **2b 倾向 C/Dida** | §5.3 Top1–3 |
| **P1** | BKS 涨/跌且单一 hotel country 占变化 **≥10%** | 该国 |
| **P1** | BKS **涨** 且 Top 国占增量 **≥70%** | 该国 |

**查不到 HOLIDAY** → 写「营销日历无匹配节日」；**不**因此加强或削弱 C 结论。

### 5.3 取国（路径写死）

| 2b 路径 | 取自 | 排序 | P1 / D2 的 ≥10% 分母 |
|---------|------|------|----------------------|
| **C/Dida** | `4_Country` | `\|booking_change\|` Top1–3 | **client** 总量变化 |
| **S / CS** | `5_SID+Country`（先锁定 2b 主 SID；可多个并列 SID） | **该 SID 内** `\|booking_change\|` Top1–3 | **该 SID** 变化（与 2c #14 一致） |

禁止 S/CS 用 `4_Country` 代替。多个锁定 SID：各国去重后 **一国一调用**。

## 6. MCP 执行

```
Step 0  若 §5.1 跳过 → 停止，3d 写「未查（A/B 已强定责）」
Step 1  可选 00-max-dt.sql → 确认快照日（近 30 天分区；失败继续跑 01，禁止写成「无节日」）
        或跳过 00，直接用 01 内 `MAX(dt)` 子查询
Step 2  按 §5.3 取国：C/Dida=`4_Country`；S/CS=`5_SID+Country`
        对每个 country 跑一次 01-single-country-window.sql
        （一次 MCP = 一国一窗；禁止多国 UNION）
Step 3  Agent 按 BKS 方向解读 → 写入 3d 并列假设
```

**稳定性：**

- `search_meta_data` 无收录 → 直接 `execute_sql`
- 使用 `dt = (SELECT MAX(dt) FROM …)` 子查询
- 日期过滤用 `>=` / `<=`，避免 `BETWEEN …::date` 组合不稳定

## 7. 3d 解读（强度上限：倾向 / 待验证）

| 观察到 | BKS | 强度 | 报告写法 |
|--------|-----|------|----------|
| Top 国有 **Top30 HOLIDAY** 与窗口重叠 | **跌** | 中 | **并列**：节后回落 / 假前透支，待验证 |
| Top 国有 **Top30 HOLIDAY** 与窗口重叠 | **涨** | 弱～中 | **并列背景**（长假出行等）；禁止写「节日导致涨产」 |
| 无 HOLIDAY（或 rank>30 已过滤） | 任意 | — | 「营销日历无匹配节日」 |
| A 强配置 + 有节日 | 任意 | — | **以 A 为准**，D 不抢主因 |

**禁止：** 有节日 →「已确认涨/跌因」；D 线不得单独定责。  
**禁止：** 引用 FAIR/CONCERT 作 D 线证据（已退出归因范围）。

## 8. 报告收口衔接

| 3d D 线 | 后续动作 |
|---------|--------------|
| HOLIDAY + **跌产** | 问渠道：是否节后策略调整、是否预期内回调 |
| HOLIDAY + **涨产** | 问渠道：是否长假出行/假前放量（弱假设） |
| 无 HOLIDAY + A/B 空 | 继续渠道策略 / API / 流量排查 |

## 9. 案例速查

| 案例 | 2c Top 国 | 窗口 HOLIDAY（过滤后） | 用法 |
|------|-----------|------------------------|------|
| SnapTravel2B @ 2026-08-01 | S：`5_SID+Country`（26→US） | **现行 SOP 不查** | 验证 B 已强；旧 gold 曾跑地方节作极弱对照 |
| Agoda @ 2026-03-20 | C：`4_Country` TH/MY | MY Hari Raya（D1+D2） | **弱并列**；TH 无 Top30 |
| CVCTrend @ 2026-07-17 | PT/AR/US | US 有 Nelson Mandela Day 等 | **弱背景**；PT/AR 主增量无强节日匹配 |

## 10. 节日影响程度评估（YoY 同节日 · 草案）

> **目标：** 在「有 HOLIDAY 重叠」时，给出 **信号强弱**，而非仅列节日名。  
> **思路来源：** 用 **去年同一节日 vs 今年同一节日**，对比 **节前 / 节中 / 节后** 产量变化，并按 **国家（必选）/ 城市（可选）** 细分。

### 10.1 为什么值得做

| 现状（`01-single-country-window`） | 缺口 |
|-----------------------------------|------|
| 只回答「有没有节日」 | 不知道节日 **解释了多少产量变化** |
| 全局 Dida 表 | 需落到 **client × country** 产量才有用 |

YoY 同节日对比的优势：**控掉季节性**（暑假、春节档等），比单纯 WoW 更像「节日效应」。

### 10.2 推荐流程（Step D2，可选）

```
Step D1  01-single-country-window.sql → 命中 Top30 HOLIDAY 列表
Step D2  对每个「结构相关国」Top1 节日（**触发：** D1 命中 + 该国占 \|ΔBKS\| ≥10%，分母见 §5.3）：
         a. `holiday-canonical-seed.csv` 按 `holiday_key` + `country_code` 取 **y1/y2 节窗**（固定 2 年）
         b. 定义三节窗（默认各 7 天，可配置）：
            pre   = [start-7, start-1]
            during= [start, end]
            post  = [end+1, end+7]
         c. Read `02-holiday-yoy-bks-lite.sql` → MCP（**禁止手写**；见 d2-params-template.md）
            - Rubric 仅用 `country_*_bks`；`pre_bks` 为 client 全量背景
            - 今年三节窗 vs 去年同三节窗（YoY）
Step D3  按 10.3 打信号 → 写入 3d「D 线强度」
```

**Lite 文件：** `sql/external-events-lite/02-holiday-yoy-bks-lite.sql`  
**节窗来源：** `holiday-canonical-seed.csv`（`scripts/generate-holiday-canonical-seed.py` 年更；见 [holiday-canonical-seed.md](holiday-canonical-seed.md)）  
**输入：** `{client_id}` `{country_code}` + seed 中 `{y1/y2_holiday_start/end}` `{pre_days}` `{post_days}` `{client_window_*}`

### 10.3 信号强弱（建议 rubric）

| 等级 | 条件（需同时满足条数） | 报告写法 |
|------|------------------------|----------|
| **中** | ① Top 国占 \|ΔBKS\| ≥10%（分母 §5.3）；② 节日与异动窗重叠或 **post 窗** 重叠；③ **during+post** 国别 Δ 与异动 **同向**；④ YoY：今年 post（或 during）vs 去年同节 **同向或更强** | **并列**：节日后需求回落/假前透支，**倾向** |
| **弱** | ①② 满足 + ③ 同向，但 YoY 不一致 **或** 国别 Δ 占总量 \<30% | **弱并列** |
| **极弱 / 无** | 仅 rank 30 地方日（Colorado Day 等） **或** 国别方向相反 **或** 无 Top30 节日 | 一行带过 / 「日历无强匹配」 |
| **禁止** | 任意 | 「已确认节日导致 ±X%」 |

**短判例（仅 D1）：**

- **SnapTravel2B @ 8/1** → **现行 SOP 不查 D**（S + 验证 B 强）；旧跑 American Family Day 仅作极弱对照
- **Agoda @ 3/20 · TH** → D1 无 Top30 匹配 → **极弱/无**（TH 跌不能归因节日）

**完整 D1+D2 带数字示例 → §10.7（Agoda × MY 开斋节）**

### 10.4 国家 vs 城市

| 粒度 | 做法 | 限制 |
|------|------|------|
| **国家（推荐默认）** | `npd_booking_view` join `dida_hotel_view.country_code` | 与 2c 对齐，MCP 稳定 |
| **城市（可选）** | 日历 `city_name_cn` ↔ 酒店 city **映射未标准化** | 易 504；仅 **Top 节 + 国别已≥30%** 时 BI 试跑 |

### 10.5 局限（必须写进报告）

1. **相关 ≠ 因果** — D 线天花板仍为 **倾向 / 并列**，不能替代 A/B  
2. **同名节日不完全可比** — 伊斯兰历每年漂移；用 `event_name` 匹配 + 日期容差  
3. **日历 ≠ client 策略** — 渠道是否借势节日需报告收口问渠道  
4. **Top30 过滤** — Agoda 案例 March Equinox（rank 75）被滤掉，但业务上可能仍相关 → 可 BI 敏感性分析，**不进默认 D 线**

### 10.7 完整 Rubric 示例：Agoda @ 2026-03-20 × MY.HARI_RAYA_PUASA（D1+D2）

> MCP 冒烟：**2026-08-18** · 脚本 `02-holiday-yoy-bks-lite.sql` · seed 节窗 · pre/post=7 天

#### 背景（Phase 0–2）

| 项 | 数值 |
|----|------|
| client | Agoda |
| 异动 | WoW **-16.5%**（2,739→2,287，7 天窗） |
| 2c MY | 211→145，**Δ=-66**，占全 client 变化 **14.6%**（\|Δ总\|=452） |
| 2c TH | 592→479，**Δ=-113**，占 **25.0%**（主结构国，但 D1 无 Top30 节） |
| 2b | 倾向 **C/Dida**（70.7% supplier 同降） |

#### Step D1（ads · `01-single-country-window.sql`）

| 国 | Top30 HOLIDAY | 日期 | 与异动 |
|----|---------------|------|--------|
| **MY** | Hari Raya Puasa Holiday | **2026-03-19** 吉隆坡 | 邻接当前窗 3/20；MY 跌 **同向** |
| TH | — | — | March Equinox rank **75** 已过滤 → **不得**归因 TH 节日 |

→ 仅 **MY** 进入 D2（D1 命中 + 国别占比 **≥10%**）。

#### Step D2（seed + `02-holiday-yoy-bks-lite.sql`）

**占位符：**

| 字段 | 值 |
|------|-----|
| `holiday_key` | `MY.HARI_RAYA_PUASA` |
| y1 节窗 | 2025-03-31 |
| y2 节窗 | 2026-03-20 |
| `client_window` | 2026-03-13 ~ 2026-03-26 |

**MCP 输出（国别列 · Rubric 用）：**

| cohort | country_pre | country_during | country_post | span | client_window_bks | gate |
|--------|-------------|----------------|--------------|------|-------------------|------|
| y1 | **242** | **23** | **154** | 419 | — | ok |
| y2 | **211** | **25** | **148** | 384 | **5,026** | ok |

（同查 client 全量背景：y2 pre/during/post = 2,739 / 359 / 2,282 — **不可**与国别 pre 混读。）

**YoY 形态（国别 · 日均）：**

| 段 | y1 日均 | y2 日均 | 读法 |
|----|---------|---------|------|
| pre（7d） | 34.6 | 30.1 | 节前基数略降 |
| during | 23 | 25 | **节中凹陷**（约为 pre 的 70~80%） |
| post（7d） | 22.0 | 21.1 | 节后略回升但仍低于 pre |

两年 **during 凹陷 + post 未满 pre** 形态 **同向** → YoY ④ 满足。

#### Step D3（Rubric 逐条）

| # | 条件 | 判定 | 依据 |
|---|------|------|------|
| ① | Top 国占 \|ΔBKS\| ≥10% | ✅ | MY 14.6% |
| ①′ | （弱档）国别占比 <30% | ✅ | 14.6% **<30%** → 上限 **弱** |
| ② | 节日与异动窗重叠或 post 重叠 | ✅ | 3/19 邻接 3/20 当前窗 |
| ③ | during+post 国别方向与异动同向 | ✅ | 2c MY 211→145 **跌**；y2 节中凹（25≪211） |
| ④ | YoY post/during 效应同向或更强 | ✅ | y1/y2 during 23↔25；post/pre 比 ~0.64↔0.70 |
| — | TH 无 D1 命中 | — | **不能**用节日解释 TH **-113** |
| — | 全 client -16.5% | — | MY 66 单装不下总量 |

**定级：弱（并列背景）**

**报告写法（3d 段落模板）：**

> D 线：**弱并列**。MY Hari Raya（3/19，D1 Top30）与 3/20 跌产窗邻接；YoY 同节 MY 产单呈节中凹陷（y2 during **25** vs pre **211**），与今年 MY 国别收缩 **同向**，但 MY 仅占全量变化 **14.6%**，**不能**解释 TH 主跌（-113）或机构 -16.5%；主因仍为 **C（查价稳/产量降）** 并列 **S**。禁止写「节日导致跌产」。

#### D2 冒烟（同脚本 · 2026-08-18）

| smoke_case | y1 country pre/dur/post | y2 country pre/dur/post | gate | 备注 |
|------------|---------------------------|---------------------------|------|------|
| **MY.HARI_RAYA_PUASA** | 242 / 23 / 154 | 211 / 25 / 148 | ok | §10.7 主示例 |
| **ID.IDUL_FITRI** | 353 / 44 / 323 | 555 / 82 / 520 | ok | 同窗；ID 2c 仅 5.3% → **不触发 D2** |
| **TH.SONGKRAN** | 403 / 190 / 504 | 400 / 145 / 286 | ok | Agoda 3/20 **无 D1 命中** → 仅档案，不进该案 rubric |

### 10.8 与现有 Phase 关系

- **不替代** Phase 1 WoW / Phase 3b 查验订  
- **增强** 3d 当 2b 倾向 C 且 A/B 说不清时（**A/B 已强则不查 D**）  
- **工程状态（2026-08-18）：** seed + `02` + §10.7 示例 + D2 冒烟 ✅；gold Agoda 3d D1+D2 **已回归**

### 10.9 未来优化：节日窗对齐 **checkoutdate**（待实现）

> **讨论定稿方向（2026-08-18）：** 节日事件范围应对齐订单 **`checkoutdate`**（离店/消费发生），而非当前 MVP 的 **`channel_createdate`**（下单/create）。

| 维度 | 当前 MVP（`02`） | 目标 |
|------|------------------|------|
| 时间字段 | `channel_createdate::date` | **`checkoutdate::date`** |
| 与 Phase 1 关系 | 与 2c WoW **同口径**（create） | D2 **独立口径**；2c 仍可为 create |
| 业务含义 | 「节前下单 rush」 | 「节中/节后实际入住离店」更贴近节日消费 |
| 示例偏差 | MY 开斋节：create 见「节中凹陷」 | checkout 可能呈现不同 pre/during/post 形态（待 MCP 对比） |

**实现备忘（下一版）：**

1. 新增 `02-holiday-yoy-bks-checkout-lite.sql`（或 `{date_field}` 占位符版），**禁止**手改 WHERE 日期列。  
2. Rubric 流程不变；仅 D2 三节窗切分字段改为 checkout。  
3. 报告须标注 **「D2 checkout 口径」**，避免与 Phase 1 create WoW 混读。  
4. 可选敏感性：并列输出 `checkindate` 版（节前出发 vs 节中停留），默认 **仅 checkout**。  
5. Agoda MY gold **保留 create 版** 至 checkout 版跑通后再二选一或并列脚注。

**字段（MCP 已确认）：** `public.npd_booking_view.checkoutdate`（毫秒时间戳，用法同 `channel_createdate::date`）。
