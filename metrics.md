# 常用指标速查

Agent 可用 `search_metrics` 搜索更多指标。以下为归因分析高频指标，**以 search_metrics 返回的 desc 为准**。

## GP 类

| 编码 | 名称 | 统计周期 | 场景 |
|------|------|---------|------|
| ORD_0001 | GP(*checkout-CNY) | 离店 checkout | **默认 GP 指标**，财务口径 |
| ORD_0171 | GP(*checkin-CNY) | 入住 checkin | 运营口径 |
| ORD_0198 | GP(*create-CNY) | 创建 create | 预订口径 |
| ORD_0003 | GP(%) | 离店 checkout | 毛利率 |
| ORD_0004 | KPI_GP(*KPI-CNY) | 离店 checkout | KPI 口径（不含返佣/VCC） |

## 产量类

用 `search_metrics` 搜索「订单数」「TTV」「间夜」获取最新编码。常见模式：

| 模式 | 说明 |
|------|------|
| 订单数(*checkout) | 离店口径订单量 |
| 订单数(*create) | 创建口径订单量 |
| TTV(*checkout-CNY) | 交易总额 |

## 选择原则

1. **掉产分析**：create 口径订单数 + TTV → 看是量跌还是价跌
2. **GP 归因**：checkout 口径 GP + GP(%) → 看绝对值和率的变化
3. **用户指定口径时**：严格按用户要求，不擅自替换
4. **不确定时**：列出 checkout/checkin/create 三个版本让用户选

## 时间粒度

大多数指标 `timeGranularities` 支持：2(天)、3(周)、4(月)、6(年)。

异动识别默认用 **按天（2）**，周期 ≥ 90 天时改用 **按周（3）**。

---

## 查验订指标（Phase 3 证据线 B/C）

> BKS = 订单（Bookings）；Search = 查价；Prebook / RP = 验价。流程与层级见 [phases/03-evidence-verification.md](phases/03-evidence-verification.md)。

| 指标 | 分子 | 分母 | 反映什么 |
|------|------|------|---------|
| 查价有价率 | avail_search | total_search | 查价能否返回有价（**不能**反映竞争力） |
| 验价准确率 | success_rp | total_rp | 验价结果是否准确 |
| **查验比** | avail_search | total_rp | **价格竞争力**（渠道看到价后是否愿意验价） |

**字段对照（现有表）：**

| 层 | 表 | total_search | avail_search |
|----|-----|-------------|-------------|
| DidaBiz（C） | ads.ads_hotel_monitor_rate_search_statistic_by_client_id | client_pps | available_client_pps |
| SS（CS 近似） | public.clientsupplierhotelcallcountsummary | hotelcallamount | availcallamount |

**规则：**

- 分子分母须同一 scope（client + supplier + 时间窗 + 层）。
- `total_rp` 各层相同（验价 1:1）；查验比用同 scope 的 avail_search 与 total_rp。
- CS 级查价暂用 **SS 表近似 CS 视角**；DidaBase 表与验价 SQL 待业务方补充。
- 天维度 WoW 对比即可，无需 Search→Prebook 滞后。
- **配置变更不影响验价准确率**；有价率/查验比见 [config-search-precheck-mapping.md](docs/config-search-precheck-mapping.md)，准确率见 [accuracy-issue-mapping.md](docs/accuracy-issue-mapping.md)。
