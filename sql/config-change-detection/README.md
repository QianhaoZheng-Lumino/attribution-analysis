# Phase 3 内部配置变更检测 SQL

## 文件

| 文件 | 用途 |
|------|------|
| `config-change-detection.sql` | 完整脚本：14 类配置变更 + 订单/查价 before-after + CDH/LCDH 酒店级产量 |
| `cdh-lcdh-hotel-bks.sql` | CDH/LCDH 酒店级对比片段（已嵌入主 SQL，单独文件便于 review） |

## 参数

| 参数 | 说明 |
|------|------|
| `analysis_date` | 异动锚点日 |
| `client_id` / `parent_client_id` | 分析范围（与 Phase 1/2 一致） |
| 时间窗口 | 配置检测：`analysis_date ± 1 day` |

## 14 类配置 level（均为 Dida 内部）

见 [phases/03-evidence-verification.md](../../phases/03-evidence-verification.md)。**Agent 必须先跑** [03-fourteen-level-checklist.sql](../config-change-detection-lite/03-fourteen-level-checklist.sql) **填满 14 行**，再跑本脚本取产量证据。

第 14 类 **Configuration** 来源：`configuration.client_configuration_change_log`（Wolf2.0 系统参数）。

## 输出过滤说明

末尾 `WHERE … before/after_bks > 0` 会**隐藏无产量行的配置**。清单以 checklist 为准；本 SQL 仅补 before/after bks、查价、hotel_bks。

## 查价字段（证据线 B）

| 配置粒度 | 表 | 字段 | 输出列 |
|---------|-----|------|--------|
| C | ads.ads_hotel_monitor_rate_search_statistic_by_client_id | client_pps / available_client_pps | before/after_didabiz_pps_* |
| CS | public.clientsupplierhotelcallcountsummary | hotelcallamount / availcallamount | before/after_ss_*（**SS 层近似 CS 视角**） |

验价（total_rp / success_rp）与查验比尚未嵌入本 SQL，待独立脚本补充。

## CDH / LCDH / SH 酒店级产量

- `before_bks_compare_window` / `after_bks_compare_window`：机构或 CS 全量对比（原逻辑）
- `before_hotel_bks` / `after_hotel_bks`：CDH/LCDH **仅 didahotelid**；SH **仅 supplierid+supplierhotelid 且本 client**
- SH MCP：`../config-change-detection-lite/detail/08-sh-hotel-bks-lite.sql`（n≥10 必跑）。完整 `config-change-detection.sql` 仍无 SH 酒店 join

## MCP 注意

- 完整 SQL 层数多，MCP 可能 500；Agent 应按 level 或日期拆步执行
- `configuration.*` 表：`search_meta_data` 常搜不到，直接 `execute_sql` + `tables` 填表名
