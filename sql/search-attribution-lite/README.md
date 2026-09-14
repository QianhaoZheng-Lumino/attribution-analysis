# Phase 3b Lite：查价归因分批 SQL（用户 SQL1）

完整版 `../search-attribution.sql`（7 路 UNION + precheck join）在 MCP 上易 **500**。  
**MCP 一次调用 = 本目录一个文件。**

## 指标（Agent 解读）

| 字段 | 公式 | 含义 |
|------|------|------|
| `current_avail_rate_pct` | avail / total_search × 100 | **有价率** |
| `current_check_ratio` | avail / precheck | **查验比**（比率，非百分比） |
| WoW | current − previous | 同维对比 |

**注意：** DidaBiz QPS 与 SS 层 **不可跨层比绝对量**；同层内 WoW 有效。

## 术语：「funnel / 漏斗」指什么？

Skill 里 **funnel** 有两层含义，**不是业务方口头黑话**，来自 **表名 / 分析框架**：

| 说法 | 实际指什么 | 对应 SQL / 表 |
|------|------------|---------------|
| **funnel 表 / funnel 加总** | didamonitor 监控里的 **流量漏斗层** 汇总 | `data_ovs.didamonitor_funnel_client_country` 等；lite 文件 **`00a-funnel-search-total.sql`** |
| **转化链 / 查验订**（报告推荐写法） | 渠道请求链路：**查价 → 验价 → 产量** | `00-client-total`（查价）+ `00b`（验价）+ Phase 1 BKS |

**为何曾写 funnel：** ads 机构表 MCP 500 时，用 **`didamonitor_funnel_*` 按 country 加总** 作机构查价 fallback（`00a`+`00b`）。  
**对外报告建议写：**「机构查价 / 验价 / 产量」或「查验订」，少单独说「漏斗」，避免与 didamonitor 表名混淆。

## 使用顺序

```
Step 0  ../params-template.md 填占位符（含 **{sid_list}**）
Step 1  00-client-total.sql            机构总量（ads）
Step 1' ads 500 时 **分两查**（禁止合并 CTE/标量子查询）：
        00a-funnel-search-total.sql   funnel 查价 + 有价率
        00b-funnel-precheck-total.sql client 验价量 → Agent 本地算查验比
Step 2  01-ss-supplier.sql            【必跑】**必填 {sid_list}**（与 SH 同一套：2b 锁定或 \|ΔBKS\|≥10%；无则 02-sid \|change\| Top3）。禁止空 `IN ()`。禁止只跑全表 `ORDER BY`+`LIMIT 50` 就写「未覆盖涨尾」。**不可替代 Step 1/1'**
Step 3  02-country.sql 等       对齐 Phase 2c Top 维
```

## 2b 路径对照

| 2b | 优先跑 |
|----|--------|
| CS / S | `01-ss-supplier.sql`（**必填 `{sid_list}`**） |
| C/Dida | `00-client-total` + `02-country` / `03-chain` |
| 结构维 | `04-los` / `05-leadtime` / `06-nationality` |

## 文件清单

| 文件 | db_level | hierarchy |
|------|----------|-----------|
| 00-client-total.sql | DidaBiz PPS | Total | ads 主路径 |
| **00a-funnel-search-total.sql** | DidaBiz PPS (fallback A) | Total | ads 500 时 |
| **00b-funnel-precheck-total.sql** | precheck (fallback B) | Total | 与 00a 同窗 |
| ~~00-funnel-client-total.sql~~ | — | — | **已弃用**（合并版易 500） |
| 01-ss-supplier.sql | SS | Supplier |
| 02-didabiz-pps-country.sql | DidaBiz PPS | Country |
| 03-didabiz-pps-chain.sql | DidaBiz PPS | Chain |
| 04-didabiz-qps-los.sql | DidaBiz QPS | LOS |
| 05-didabiz-qps-leadtime.sql | DidaBiz QPS | LeadTime |
| 06-didabiz-qps-nationality.sql | DidaBiz QPS | Nationality |

## MCP 实测

| 案例 | 文件 | 结果 |
|------|------|------|
| HBGPKG 2026-07-06 | 01-ss-supplier | ✅ Meituan 224 / EPS 116 可查 |
| YandexTravel2C 2026-08-31 | 01-ss-supplier `{sid_list}=116, 26` | ✅ 结构 SID 必出（全表 ASC LIMIT 50 会截掉 116） |
| Agoda 2026-03-13~26 | 00-client-total（`dt` 字符串区间） | ✅ 机构 PPS 聚合 |
| CVCTrend 2026-07-10~23 | 00-client-total（`dt` 字符串区间） | ✅ 与 `dt::date` 口径一致 |
| Check24App / DidaOpaq | 同上 | ✅ |

**字段：** `dt` 是 **text（YYYY-MM-DD）**，勿写 `stat_date`。WHERE/CASE 用 `dt >= … AND dt <= …`，**不要 `dt::date`**（SELECT 时 MCP 把 date 序列化成毫秒；`pg_typeof` 与聚合混用会 500）。

## 与 config search 的关系

`config-change-detection-lite/search/01-didabiz-pps-daily.sql` 为 **按日** 机构查价，本目录为 **窗口聚合 + 维度 + precheck join**，Phase 3b 主用本目录。
