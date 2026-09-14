# Phase 3d 辅助：外部营销日历（证据线 D）

表：`ads.ads_marketing_calendar_event_wide_d_f`  
规则：[external-events-mapping.md](../../docs/external-events-mapping.md)

## 定位

- **Dida 全局**事件库（**无 client 维**）→ 仅作 C 侧 **外部需求并列假设**
- **禁止**与 client 产量交叉定责；`city_ttv` 只用于 **全局排序**

## 文件

| 文件 | 用途 |
|------|------|
| `00-max-dt.sql` | 最新 `dt` 快照（可选；近 30 天分区 + `CAST AS VARCHAR`） |
| `01-single-country-window.sql` | **一国一窗** D1（MCP 主文件） |
| `holiday-canonical-seed.csv` | D2 YoY 节窗 seed（**离线生成**，见 [holiday-canonical-seed.md](../../docs/holiday-canonical-seed.md)） |
| `02-holiday-yoy-bks-lite.sql` | D2 **主查询**（禁止手写替代；占位符见 [d2-params-template.md](./d2-params-template.md)） |
| `02-holiday-yoy-bks-daily-check.sql` | D2 **诊断**（按日分解，仅结果可疑时用） |
| `d2-params-template.md` | D2 占位符、输出列、实测示例 |

## D1 vs D2

| 步骤 | 数据源 | SQL |
|------|--------|-----|
| **D1** 当前窗 Top30 HOLIDAY | ads 营销日历 | `01-single-country-window.sql` |
| **D2** YoY 同节日产量（可选） | seed CSV + 订单 | `02-holiday-yoy-bks-lite.sql` |

ads 表仅 ~1 年快照 → **D2 必须用 seed**，不能靠 ads 找去年同名节。

## 使用顺序

```
Step 0  （可选）00-max-dt.sql → 确认快照。失败继续跑 01，禁止写成「无节日」
Step 1  取国：C/Dida=`4_Country` Top1–3；**S/CS=`5_SID+Country`**（锁定 SID，该 SID 内 Top1–3）
        A/B 已强 → **跳过**，不跑 01
Step 2  对每个 country × 窗口 跑 01-single-country-window.sql
        - 当前窗: {analysis_date} ~ {current_end}
        - 可选对比窗: {compare_start} ~ {compare_end}
Step 3  写入 Phase 3d 并列假设（强度上限：倾向/待验证）
Step 4  （可选 D2）D1 命中节 → seed 对齐 holiday_key
        → Read `02-holiday-yoy-bks-lite.sql` 原文 MCP（**禁止手写**；见 d2-params-template.md）
```

## D2 MCP

```json
{
  "tables": ["public.npd_booking_view", "content.dida_hotel_view"],
  "timeout_seconds": 90
}
```

**输出：** rubric 仅用 `country_*_bks`；`pre_bks` 等为 client 全量背景。冒烟结果见 [d2-params-template.md](./d2-params-template.md) 与 mapping **§10.7**。

**D2 触发：** D1 命中 + 该国 \|ΔBKS\| 占比 ≥10%（分母：C=client；S/CS=锁定 SID）。

## 触发（摘要）

- **先跳过：** A/B 已强（含 2b=S 且验证 B 平台共涨/跌已钉）→ 不查
- 2b 倾向 C/Dida + A 无强信号 + B inconclusive → **必查** Top 国（`4_Country`）
- 单国占变化 ≥10%，或涨产 Top 国 ≥70% → **查**（未命中跳过时）
- **S/CS 取国：** `5_SID+Country`，禁止用 `4_Country`
- **永久不查：** WEATHER、FAIR_EVENT、CONCERT_EVENT（归因 **仅 HOLIDAY**）

## 重要性过滤（SQL 已内置 · 2026-08-18）

| 类型 | 规则 |
|------|------|
| **HOLIDAY** | 唯一纳入；`city_rank_no <= 30` |
| FAIR_EVENT / CONCERT_EVENT / WEATHER | **不查**（不归因） |

## MCP（D1）

```json
{
  "tables": ["ads.ads_marketing_calendar_event_wide_d_f"],
  "timeout_seconds": 60
}
```

### 稳定性（2026-09-08 复测）

| 写法 | 结果 |
|------|------|
| 无 WHERE 的 `MAX(dt)` / 裸表 `LIMIT 3` | ❌ MCP 500 |
| `00-max-dt.sql`：`dt >= CURRENT_DATE - 30` + `CAST(MAX(dt) AS VARCHAR)` | ✅ 2026-09-07 |
| `01`：`dt = (SELECT MAX(dt) …)` + 单 country + 窗口重叠 | ✅（可 0 行） |
| `dt = CURRENT_DATE` | ❌ 常 0 行（当日分区常未就绪） |
| 多国 `IN (...)` 一次查 | ⚠️ 避免；**一国一调用** |

## 与 Phase 2c 对齐

| Phase 2c | 本目录 |
|----------|--------|
| C/Dida：`4_Country` → `country_code` | `01` 的 `{country_code}` |
| S/CS：`5_SID+Country` → `country_code` | 锁定 SID 后再取国 |
| params-template 日期窗 | `{window_start}` `{window_end}` |
