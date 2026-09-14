# Phase 3b 辅助：SS限流率 + 缓存命中率 + 背景信号

表：`dws.dws_hotel_flow_didamonitor_supplier_csa_di`  
与 [config-search-precheck-mapping.md](../../docs/config-search-precheck-mapping.md) § SS 限流/缓存 配套。

## 定义

**SS限流：** 供应商对每秒放行请求有上限；超限的请求 **到不了 supplier**。

**只吐缓存：** SS 对部分渠道配置「只返回缓存、不真实请求 supplier」；与 **缓存命中率**（`fromcache/all`）**不同概念**。

| 指标 | 公式（窗口内 SUM，**不筛 biztype**，**SUM 全部 supplieraccountid**） | 用途 |
|------|---------------------------------------------------------------------|------|
| **SS限流率** | `SUM(limit_requests_num) / SUM(requests_num)` | 定责/解读 |
| **缓存命中率** | `SUM(fromcache_requests_num) / SUM(all_requests_num)` | 定责/解读 |
| **SS通过率** | `SUM(pass_requests_num) / SUM(requests_num)` | **背景信号**，不单定责 |
| **命中只吐缓存率** | `SUM(read_only_cache_requests_num) / SUM(requests_num)` | **背景信号**，不单定责 |

> **2026-09-04 定稿：** **SS限流率** = `limit/requests`；**废弃** `not_limit_requests_num` 及旧公式 `1 - not_limit/requests`。  
> **恒等式：** `limit + pass + read_only_cache ≈ requests`（与 `fromcache` 无关）。

### 字段（2026-09-04）

| 字段 | 含义 | 使用 |
|------|------|------|
| `requests_num` | 总请求 | SS限流率、SS通过率、只吐缓存率 **分母** |
| `limit_requests_num` | 限流请求量 | SS限流率 **分子** |
| `pass_requests_num` | SS 通过请求量（真实发往 supplier） | SS通过率 **分子** |
| `read_only_cache_requests_num` | 只吐缓存请求量 | 只吐缓存率 **分子** |
| `all_requests_num` | SS 监控总请求（缓存路径） | 缓存命中率 **分母** |
| `fromcache_requests_num` | 命中缓存的请求 | 缓存命中率 **分子** |
| ~~`not_limit_requests_num`~~ | **废弃，禁止使用** | — |

## 何时查（2026-09-04 #18 定稿）

**出数 SID（OR）：** 2b **锁定** SID，或 `02-sid` 占 client **\|ΔBKS\| ≥10%**。未锁定且 \<10% → 不查。SS 无行 → 「未查（SS 无行）」。

**SS 有价率 / 请求量 \|WoW\| > 10%：** 只决定解读档（涨跌双向），**不是**出数门。结构 SID 未过 10% **仍出表**，用于排除限流主因。

| 3b 异动（\|WoW\| > 10%） | 查 | 已定解读 |
|------------------------|-----|----------|
| **有价率** 涨或跌 | **SS限流率** WoW | 有价率↓ + SS限流率↑ → 倾向限流（非 wolf 关房） |
| **请求量** 涨或跌 | **缓存命中率** WoW | 请求量↓ + 缓存命中率↑ → 倾向缓存替代实发 |
| 结构 SID 但两项均未过 10% | 四列都报 | **排除用**，禁止写限流异动 |
| 任意已出表 | **SS通过率** / **命中只吐缓存率** WoW | **背景信号**，仅报数，不单定责 |

**解读待研究：** 涨方向、请求↓产量↑ 等组合 — 仅报数，不单定责（见 `decisions-summary.md` §5.10）。

**禁止：** 解释验价准确率 / issue 2005。

## 与 SS 查价表对齐

| 项 | SS 查价 | 本表 |
|----|---------|------|
| 表 | `clientsupplierhotelcallcountsummary` | `dws_hotel_flow_didamonitor_supplier_csa_di` |
| 粒度 | clientid × supplierid | clientid × supplierid（account 已 SUM） |
| 日期 | `date` | `log_date` |
| 窗口 | 同 `params-template.md` | **相同** current / compare 窗 |

**推荐顺序：** 先跑 `search-attribution-lite/01-ss-supplier.sql` → 对有价率或请求量 **\|WoW\| > 10%** 的 Top supplier 跑本文件。

## 文件

| 文件 | 用途 |
|------|------|
| `01-ss-supplier-window.sql` | client × supplier 三比率 + WoW |

## MCP

```json
{
  "tables": ["dws.dws_hotel_flow_didamonitor_supplier_csa_di"],
  "timeout_seconds": 90
}
```

### MCP 稳定性（2026-08-14 实测 SnapTravel2B）

| 写法 | 结果 |
|------|------|
| `log_date >= '…' AND log_date <= '…'` + `GROUP BY supplierid` | ✅ |
| `BETWEEN …::date` + `GROUP BY supplierid` | ❌ **500** |

**仍 500 时：** 对 Phase 2 Top SID **一次一个 supplier**，或 current / compare **分两窗**各跑一条简单 `SUM`。
