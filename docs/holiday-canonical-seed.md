# 节日 Canonical Seed（离线 · MVP）

> **定位：** D2「YoY 同节日」的**日期与 ads 对齐锚点**，替代「仅靠 ads 日历表找去年同名节」（ads 表仅 ~1 年快照，无法覆盖固定 2 年 YoY）。  
> **非 BI 维表** — Skill 仓库内 CSV + 年更脚本；长期可升格为 BI canonical 表。

## 文件

| 路径 | 说明 |
|------|------|
| `scripts/generate-holiday-canonical-seed.py` | 生成器（Python `holidays` 库，**离线**） |
| `sql/external-events-lite/holiday-canonical-seed.csv` | 输出 seed（当前 **2024–2026**） |

## 生成

```bash
# skill 根目录
pip install holidays   # 当前环境 0.68 已验证
python scripts/generate-holiday-canonical-seed.py
```

控制台会打印每个 `holiday_key` 的行数；**0 行**表示该库年无匹配（如 `TH.LOY_KRATHONG`），D2 对该 key 降级。

## CSV 字段

| 字段 | 含义 |
|------|------|
| `holiday_key` | 稳定分组键，如 `MY.HARI_RAYA_PUASA` |
| `country_code` | ISO 国别，与 Phase 2c / ads 表一致 |
| `year` | 公历节窗所在年 |
| `start_date` / `end_date` | 节窗起止（含首尾；连续公休已 merge） |
| `duration_days` | `(end - start) + 1` |
| `source` | `holidays.{CC}` |
| `ads_patterns` | 管道 `\|` 分隔的 ILIKE 模式，对齐 `ads_marketing_calendar_event_wide_d_f.event_name` |
| `ads_exclude_patterns` | 排除模式（如 Puasa vs Haji 互斥） |
| `notes` | 人工备注 |

**同一 `holiday_key` + `year` 可能多行**（如 CN 国庆若库拆成两段），D2 应对每段分别算 BKS 或合并为 union 窗 — 默认 **逐行**。

## 与 ads 表关系

| 用途 | 用哪个 |
|------|--------|
| **D1** 当前窗有没有 Top30 节日 | `01-single-country-window.sql` → **ads 表** |
| **D2** 去年/前年同节日期 + YoY BKS | **seed CSV** → `02-holiday-yoy-bks-lite.sql` |
| D1 命中后核对 event_name | seed 的 `ads_patterns` 应能 ILIKE 命中 ads 行；不一致时在 `notes` 或 SPECS 里补 pattern |

ads 表限制（实测）：单 `dt` 快照，`event_start_date` 约 2025-12-31 ~ 2026-12-30 → **不能**作为 2 年 YoY 日历源。

## 首批 holiday_key（17 个 spec，52 行 @ 2026-08-18）

MY / ID / SG / CN / US / TH / VN / JP / PH / GB / AU — 见 CSV。  
`JP.GOLDEN_WEEK` 固定 **Apr 29 – May 6** 窗口内所有公休 merge。  
`PH.HOLY_WEEK` merge 连续 Maundy/Good Friday/Black Saturday。

## D2 使用流程（Agent）

```
1. D1 命中 HOLIDAY + 国别来自 2c（C=`4_Country`；S/CS=`5_SID+Country`）
2. 在 seed CSV 筛 country_code + ads_patterns 对齐 D1 的 event_name
   → 得到 holiday_key
3. 取 holiday_key 在 {analysis_year} 与 {analysis_year-1}（目标固定 2 年）的行
   → years_found = 命中年数；<2 则 D2 最高「弱」
4. 按 duration 选 pre/post（默认各 7 天；单日节 3 天；duration≥5 可 7–10 天）
5. Read `02-holiday-yoy-bks-lite.sql` 原文 → 替换占位符（见 d2-params-template.md）→ MCP
6. 门槛：country_holiday_span_bks≥20；client 全窗≥100；否则 inconclusive
7. Rubric 只读 country_pre/during/post_bks — 禁止用 pre_bks（全球）当国别 pre
```

## 禁止手写（D2 事故复盘）

2026-08-18 探索性查询曾在 **pre 段漏 `country_code` 过滤**，把 Agoda 全球 pre（2653）误当泰国 pre，造成「节前节后差 5 倍」假象。  
**对策：** D2 **唯一**主文件 = `02-holiday-yoy-bks-lite.sql`；可疑时用 `02-holiday-yoy-bks-daily-check.sql` 按日核对。

## 未来优化：checkout 口径（§10.9）

当前 D2 用 **`channel_createdate`**（与 Phase 1/2c create 对齐）。  
**目标：** 节日 pre/during/post 改切 **`checkoutdate::date`** — 对齐实际离店/消费，而非下单日。  
待建 `02-holiday-yoy-bks-checkout-lite.sql`；详见 [external-events-mapping.md §10.9](external-events-mapping.md)。

## 年更 SOP

1. 每年 Q4 或分析跨年窗之前：把 `YEARS` 扩到所需年（如加 2027），重跑脚本。  
2.  diff CSV：新增 key/行、伊斯兰历漂移日期。  
3. 用 **Agoda × MY.HARI_RAYA_PUASA** 或已知 gold 案例 spot-check MCP。  
4. 若某国业务新增高频节：在 `SPECS` 加 `HolidaySpec`，勿手改 CSV。  
5. 长期：BI 维护 canonical 表，Skill 改为读表；seed 脚本退役。

## 定责上限（不变）

D / D2 仍 **并列 / 倾向**；禁止「节日导致 ±X%」。见 [external-events-mapping.md §10](external-events-mapping.md)（**§10.7** Agoda MY 完整 rubric 示例 + D2 冒烟表）。
