# 归因分析数据表清单

**装完先测权限：** 探测 SQL 与缺表影响见 [README.md](README.md)「权限自测」。`search_meta_data` 搜不到仍可能有 `execute_sql` 权限。

## 使用方式

1. **MCP 指标平台有注册的** → 用 `analyse_query`
2. **MCP 元数据能搜到的** → `search_meta_data` + `execute_sql`
3. **元数据搜不到但已知表名的** → 直接 `execute_sql`（见下方清单）

`execute_sql` 调用格式：

```json
{
  "sql": "SELECT ... FROM schema.table WHERE ... LIMIT 1000",
  "tables": ["schema.table"],
  "timeout_seconds": 30
}
```

## 核心表

| 表名 | 用途 | 关键字段 | 备注 |
|------|------|---------|------|
| public.npd_booking_view | **Phase 1 异动 + Phase 2 贡献度** | clientid, parentclientid, sid, channel_createdate, **checkoutdate**, checkindate | Phase 1/2 默认 **create**；D2 未来改 **checkout**（见 external-events-mapping §10.9） |
| content.dida_hotel_view | Phase 2 酒店属性 | hotel_id, country_code, parent_chain_name | JOIN 用 |
| configuration.wolf_rateadjust_hotel_log | 酒店调价日志 | clientid, didahotelid, margin, level, status, updatedate, username | updatedate 为毫秒时间戳；元数据未收录 |

## 常用明细表（MCP 可搜到）

用 `search_meta_data` 按关键词检索，常见关键词：

| 关键词 | 预期表 |
|--------|--------|
| 渠道订单 | dwd.dwd_hotel_order_channel_supplier_booking_* |
| checkout | dwd_hotel_order_channel_supplier_booking_mf |
| 入住 | dwd_hotel_order_channel_supplier_booking_stay_date_m_f |

## 配置表（Phase 3 证据线 A → Dida）

主 SQL：`sql/config-change-detection.sql`（14 类 level + CDH/LCDH 酒店级产量）

| 表名 | 用途 | level |
|------|------|-------|
| configuration.wolf_rateadjust_log | CS/C/S/CSA/CBD/SBD 变更 | CS, C, S, CSA, CBD, SBD |
| configuration.wolf_rateadjust_hotel_log | 酒店批量变更 | CDH, SH, LCDH |
| configuration.wolfl2lclientlevelconfiglog | L2L 面纱 | L2L |
| configuration.wolfl2lconfiglog | 机构特殊配置 | CSLRC |
| configuration.bottom_margin_log | 兜底 margin | C Bottom, S Bottom |
| configuration.client_configuration_change_log | Wolf2.0 系统参数 | Configuration |
| （待建日志）机构供应商白名单 | client × supplier 供给开关 | **#23** | **现为当前配置快照，不是 log**。窗口内无法 before/after，**禁止**当 3a 证据。用户将与技术改日志表后再写入表名/字段 |
| crm.client_info_ods | client 范围 pid | — |
| public.clientsupplierhotelcallcountsummary | **CS 级查价（SS 层近似 CS 视角）** | clientid, supplierid, date, hotelcallamount（total_search）, availcallamount（avail_search） | 已嵌入 config SQL；请求量大于 DidaBiz |
| ads.ads_hotel_monitor_rate_search_statistic_by_client_id | **C 级 DidaBiz 查价** | client_id, **dt（text YYYY-MM-DD）**, client_pps, available_client_pps；另有 biz_type / qps。MCP：字符串滤 `dt`，勿 `stat_date`、勿 `dt::date` | 已嵌入 `00-client-total.sql` |

## 外部事件（Phase 3 证据线 D → C）

| 表名 | 用途 | 状态 |
|------|------|------|
| ads.ads_marketing_calendar_event_wide_d_f | 营销日历：**HOLIDAY only**（Top30 城） | ✅ MCP `execute_sql`；lite：`sql/external-events-lite/` |

**快照：** `dt = MAX(dt)`。**Dida 全局**，无 client 维；详见 [external-events-mapping.md](docs/external-events-mapping.md)。

## 查价 / 验价（Phase 3 证据线 B/C → 查验订）

业务术语：**BKS** = 订单；**Search** = 查价；**Prebook / RP** = 验价。详见 [phases/03-evidence-verification.md](phases/03-evidence-verification.md#证据线-bc查价与验价查验订)。

### didamonitor 三层

| 层 | 视角 | 配置对应 | 查价表（当前） |
|----|------|---------|---------------|
| DidaBiz | 渠道侧 | C | `ads.ads_hotel_monitor_rate_search_statistic_by_client_id` |
| DidaBase | Client×Supplier | CS | 🔲 专用表待补充 |
| SS | 供应商侧 | S | `public.clientsupplierhotelcallcountsummary`（**CS 分析时暂用 SS 近似**） |

各层请求绝对量不可跨层对比；`total_rp`（验价）各层数值相同（1:1）。

### 核心比率

| 比率 | 公式 | 含义 |
|------|------|------|
| 查价有价率 | avail_search / total_search | 查价返回有价比例（**不**反映竞争力） |
| 验价准确率 | success_rp / total_rp | 验价返回准确比例 |
| 查验比 | avail_search / total_rp | 反映价格竞争力（同 scope） |

### 验价 / 准确率（证据线 C）

| 表名 | 用途 | 关键字段 |
|------|------|---------|
| `data_ovs.rate_accuracy_channel_multi_dimension` | 验价多维 + issue 下钻 | precheck, success_precheck, issue_type, issue_id, supplier_id, log_date, dt |
| `sql/rate-accuracy-contribution.sql` | BI 完整版 | within_contribution_pp |
| `sql/rate-accuracy-contribution-lite/` | MCP 分批 | 见目录 README |

验价 1:1 supplier，**无单独 supplier 验价表**。issue 映射见 [docs/accuracy-issue-mapping.md](docs/accuracy-issue-mapping.md)。

### 查价归因（证据线 B，SQL1）

| 资源 | db_level | 说明 |
|------|----------|------|
| `sql/search-attribution.sql` | 全部 | BI 完整 UNION 版 |
| `sql/search-attribution-lite/` | 分批 | MCP 用 |
| `public.clientloscallcount` 等 | DidaBiz QPS | amount, activeamount |
| `data_ovs.didamonitor_funnel_client_country/chain` | DidaBiz PPS | total_count, availiblity_count |
| `public.clientsupplierhotelcallcountsummary` | SS | hotelcallamount, availcallamount |

### 辅助表（仅 3a/3b，不用于准确率）

| 表名 | 用途 | 关键字段 | 备注 |
|------|------|---------|------|
| `rateaccuracy.channel_online_states_new` | 渠道上下线原始日志 | `client_id, status, channel_operation_time, source, remark` | **status：0=下线，1=上线**；见 [online-hours-mapping.md](docs/online-hours-mapping.md) |
| （复用结果表）`online_hours_daily` | 每日在线时长 | `client_id, dt, online_hours, online_pct` | 现行：MCP `03-window-avg.sql` / `online-hours.sql`。#22 已收口，不强制物化 |
| `dws.dws_hotel_flow_didamonitor_supplier_csa_di` | SS 限流 + 缓存 | 见下表 | lite：`sql/rate-limit-lite/` |

**SS 限流表字段与公式**（`clientid × supplierid`，窗口内 **SUM 全部 supplieraccountid**，**不筛 biztype**；`log_date` 与 `clientsupplierhotelcallcountsummary.date` 对齐）：

| 字段 | 含义 |
|------|------|
| `requests_num` | 总请求 |
| `limit_requests_num` | 限流请求量 |
| `pass_requests_num` | SS 通过请求量（真实发往 supplier） |
| `read_only_cache_requests_num` | 只吐缓存请求量（不真实打 supplier；≠ fromcache） |
| `all_requests_num` | SS 监控总请求（缓存路径 biztype） |
| `fromcache_requests_num` | 命中缓存的请求 |
| ~~`not_limit_requests_num`~~ | **废弃，禁止使用** |

| 指标 | 公式 | 用途 |
|------|------|------|
| **SS限流率** | `SUM(limit_requests_num) / SUM(requests_num)` | 定责/解读 |
| **缓存命中率** | `SUM(fromcache_requests_num) / SUM(all_requests_num)` | 定责/解读 |
| **SS通过率** | `SUM(pass_requests_num) / SUM(requests_num)` | **背景信号**，不单定责 |
| **命中只吐缓存率** | `SUM(read_only_cache_requests_num) / SUM(requests_num)` | **背景信号**，不单定责 |

> **2026-09-04 定稿：** **SS限流率** = `limit/requests`；**废弃** `1 - not_limit/requests`。恒等式：`limit + pass + read_only_cache ≈ requests`。

**何时查：** **结构 SID 必出数**（2b 锁定或占 client \|ΔBKS\|≥10%）。SS 有价/请求 \|WoW\|>10% 只决定解读档。详见 [config-search-precheck-mapping.md](docs/config-search-precheck-mapping.md) 与 decisions-summary §5.10。

## 添加新表

发现 MCP 搜不到但有权限的表时，按类别追加到上表。
