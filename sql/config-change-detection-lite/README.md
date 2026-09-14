# Phase 3 Lite：配置检测分批 SQL（MCP 稳定版）

完整版 `../config-change-detection.sql` 与 `03-fourteen-level-checklist.sql`（14 路 UNION）在 MCP 上易 **500**。

**MCP 一律走本目录：一次调用 = 一个文件。禁止 `execute_sql` 跑 `03-fourteen-level-checklist.sql`。** 该文件仅 BI；违反 = 配置结论作废。

参数说明见 [../params-template.md](../params-template.md)。

## 推荐流程

```
Step 0  填占位符（client_id, analysis_date, w_start/w_end, 产量窗口；**SH 另填 {sid_list}**）
Step 1  02-client-before-after-bks.sql     → 机构级 before/after（必做）
Step 2  checklist/01-cs.sql … 14-*.sql     → 14 行清单（逐条 MCP，含 0 也要跑；**Read 文件原文执行，禁止手写**）
Step 3  event_count > 0 的 level           → 按下表跑明细
Step 3' CDH/LCDH event_count > 0           → detail/07-cdh-hotel-bks-lite.sql / 09-lcdh-hotel-bks-lite.sql
        SH event_count ≥ 10                → detail/08-sh-hotel-bks-lite.sql（<10 不跑；>50000 → BI）
Step 4  search/01-didabiz-pps-daily.sql     → 查价（可选，按日）
Step 5  Agent 按 phases/03-evidence-verification.md 打信号强度
```

| COUNT 文件 | n>0 跑 |
|------------|--------|
| 01-cs | detail/01-cs-detail.sql |
| 02-c | detail/02-c-detail.sql |
| 03-s | detail/03-s-detail.sql（全局 LIMIT 30；默认弱/背景） |
| 04-csa | detail/04-csa-detail.sql |
| 05-cbd | detail/05-cbd-detail.sql（读 remark） |
| 06-sbd | detail/06-sbd-detail.sql（全局 LIMIT 30；n=0 则跳过） |
| 07-cdh | detail/07-cdh-hotel-bks-lite.sql（不是行 dump） |
| 08-sh | `detail/08-sh-hotel-bks-lite.sql`（不是行 dump）；event_count ≥ 10 必跑；<10 不解读；>50000 → BI |
| 09-lcdh | detail/09-lcdh-hotel-bks-lite.sql |
| 10-l2l | detail/10-l2l-detail.sql |
| 11-cslrc | detail/11-cslrc-detail.sql（按 SID 聚合；n_limit>0=限售；LIMIT 50 是 SID 数） |
| 12-c-bottom | detail/12-c-bottom-detail.sql |
| 13-s-bottom | detail/13-s-bottom-detail.sql（禁止抄 12） |
| 14-configuration | detail/14-configuration-detail.sql |

## 目录结构

| 路径 | 用途 |
|------|------|
| `00-resolve-clients.sql` | parent_client_id → client_id 列表 |
| `02-client-before-after-bks.sql` | 机构产量对比 |
| `checklist/01–14-*.sql` | **14 类逐项 COUNT**（简化，无 LAG） |
| `detail/` | 有条目时按 Step 3 表读取对应明细；并非每个 level 都有配对文件 |
| `detail/cs-supplier-bks.sql` | CS 链路 before/after 产量 |
| `search/01-didabiz-pps-daily.sql` | DidaBiz 查价按日 |
| `01-list-changes.sql` | Configuration 明细（同 detail/14） |

## checklist 执行顺序（Agent 打勾）

**执行纪律：** 每条 MCP 调用前 **Read 对应 `.sql` 文件**，仅替换占位符；500 时用 **同一文件原文** 重试 1 次后再标未验。详见 [phases/03-evidence-verification.md](../../phases/03-evidence-verification.md) 规则 5。

```
Phase 3 checklist 进度:
- [ ] 01 CS          checklist/01-cs.sql
- [ ] 02 C           checklist/02-c.sql
- [ ] 03 S           checklist/03-s.sql
- [ ] 04 CSA         checklist/04-csa.sql
- [ ] 05 CBD         checklist/05-cbd.sql
- [ ] 06 SBD         checklist/06-sbd.sql
- [ ] 07 CDH         checklist/07-cdh.sql      ⚠️ 大表
- [ ] 08 SH          checklist/08-sh.sql         ⚠️ 大表；必填 {sid_list}；n≥10 跑 08-sh-hotel-bks-lite
- [ ] 09 LCDH        checklist/09-lcdh.sql       ⚠️ 大表
- [ ] 10 L2L         checklist/10-l2l.sql
- [ ] 11 CSLRC       checklist/11-cslrc.sql
- [ ] 12 C Bottom    checklist/12-c-bottom.sql
- [ ] 13 S Bottom    checklist/13-s-bottom.sql
- [ ] 14 Configuration checklist/14-configuration.sql
```

## 简化 vs 完整 SQL 差异

| 项 | lite（MCP） | 完整 SQL（BI） |
|----|------------|---------------|
| 变更检测 | 窗口内**记录数** | LAG() 检测 status/margin **变化** |
| 14 类 | 14 次独立查询 | 单次 UNION |
| before/after | 机构级 + CS supplier 级 | 全 level join 产量/查价 |
| CDH hotel_bks | **`detail/07-cdh-hotel-bks-lite.sql`** | cdh-lcdh-hotel-bks.sql |
| LCDH hotel_bks | **`detail/09-lcdh-hotel-bks-lite.sql`** | 同上 |
| SH hotel_bks | **`detail/08-sh-hotel-bks-lite.sql`**（n≥10 必跑） | n>50000 或 MCP 500 → 人跑 Hologres |

lite 的 `event_count` 可能**略高于**真实变更数（含重复快照）；有条目时以 detail 明细 + 产量验证为准。

**C Bottom 注意：** 过滤字段为 **`item`**（= client_id），勿写 `clientid`（会 500 或查错）。操作人列 **`update_by`**。

**S Bottom 注意：** `event_count > 0` 跑 **`detail/13-s-bottom-detail.sql`**。`item` = 供应商号；操作人列 **`update_user`**。禁止抄 C Bottom（`update_by` → 500）。

## MCP 稳定性

**完整矩阵（14/14 + 3b + fallback + 案例）：** [docs/mcp-permission-matrix.md](../../docs/mcp-permission-matrix.md)

摘要（2026-09-08 复测：CVCTrend / SnapEBK / DidaOpaq）：

| 查询 | 结果 |
|------|------|
| checklist/01-cs.sql（单 level COUNT） | ✅ |
| checklist/12-c-bottom.sql（`item`=client_id） | ✅ CVCTrend n=0；手写 `clientid` 才会 500 |
| checklist/14-configuration.sql（`created_at` + **14 key**） | ✅ CVCTrend n=0；AgodaEBK 09-01 **CachePPS 1 条**；手写 `updatedate` 才会 500；mandatory fees 必须是 **`DidaHotelMandatoryFeesConfig`** |
| checklist/10-l2l.sql | ✅ COUNT；明细 `detail/10-l2l-detail.sql` |
| checklist/11-cslrc.sql | ✅ COUNT；明细按 SID 聚合（DidaOpaq 7 SID 全出） |
| checklist/07-cdh.sql（hotel_log + clientid） | ⚠️ 条件可用（CVCTrend 7/17 n=92,485 ✅；1 行=1 酒店） |
| search/01 按日 | ✅ CVCTrend 07-16～18 |
| **03-fourteen-level-checklist.sql（UNION 14）** | ❌ **禁止** |
| **多表 UNION 批量（L2L～Configuration）** | ❌ **禁止** |

## 信号强度速查

| category | 产量 after 明显低于 before | 信号 |
|----------|---------------------------|------|
| 开关房（CS/C/CSA） | 是 | **强** → Dida |
| **C/CBD 加价** + 查验比↑ | 是 | **强** → Dida 价劣；detail 读 `remark` |
| Configuration（PPS 等） | 查价结构也变 | **强** |
| C Bottom margin + 机构产量同向 | 是 | **强～中** |
| 小幅调价 **且** B 不同向 | 产量无明显变化 | **弱** |
| MCP 500 / 无数据 | — | 标「BI 补查」，不单定责 |

## 测试案例

见 `examples/phase3-signal-test-agoda.md`（用本目录分批流程更新）。
