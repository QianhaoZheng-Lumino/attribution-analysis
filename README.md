# attribution-analysis

酒店 Overseas API 产量异动归因（Agent Skill，多 runtime）。  
仓库：<https://github.com/QianhaoZheng-Lumino/attribution-analysis>

**前提：** 你已有查数 MCP（`user-data-mcp`）和自己的 `agent_user_key`。本仓库不发 key、不开通权限。

## 给同事 Agent 的安装提示词（复制即用）

把下面整段发给你的 skills-aware agent（Cursor / Claude Code / Codex 等均可）：

```text
请把公开 GitHub 仓库 https://github.com/QianhaoZheng-Lumino/attribution-analysis 安装为 attribution-analysis Skill（Public，无需登录即可 clone）。
按当前 runtime 的 skills 目录克隆，根下必须直接有 SKILL.md（不要多套一层文件夹）：
- Cursor：$HOME/.cursor/skills/attribution-analysis/（Windows 为 %USERPROFILE%\.cursor\skills\attribution-analysis）
- Claude Code：$HOME/.claude/skills/attribution-analysis/
- Codex：$HOME/.agents/skills/attribution-analysis/
我已配置 user-data-mcp（自己的 key）。安装后用于酒店 Overseas API 产量异动归因；先读 README.md「使用前注意事项」并完成「权限自测」，再按 SKILL.md 执行模式跑。
```

当前 runtime 没有 skills 目录时：把本仓库 `SKILL.md` 作为参考资料贴进对话即可（MCP 仍要自备）。

也可自己执行（Cursor / Windows）。**不要**用 Customize → From GitHub Repository / Remote Rule：本仓没有 `.cursor-plugin/marketplace.json`，`SKILL.md` 在仓库根，UI 导入不会当成 Skill。

Git 常常不在 PATH。目录已存在时用 `pull`，不要再 `clone`。ZIP 解压不要多一层 `attribution-analysis-main`（最终必须是 `...\attribution-analysis\SKILL.md`）。

```powershell
$git = "C:\Program Files\Git\cmd\git.exe"
if (-not (Test-Path $git)) { $git = "git" }  # 已在 PATH 则用 git
$dest = "$env:USERPROFILE\.cursor\skills\attribution-analysis"
if (Test-Path (Join-Path $dest "SKILL.md")) {
  & $git -C $dest pull --ff-only
} else {
  & $git clone https://github.com/QianhaoZheng-Lumino/attribution-analysis.git $dest
}
```

MCP：Cursor Settings → MCP，或自己的 `~/.cursor/mcp.json`。URL / `agent_user_key` 向数据平台要；本仓只有占位符，不发 key。

装完请**新开一轮对话**（必要时重启 Cursor）。不要把本仓库当普通项目打开就指望自动生效。

## 使用前注意事项

1. MCP 必须已连上，且工具含 `execute_sql`（查数主入口）/ `analyse_query` 等。不可用或未认证 → **停**，禁止手写 SQL。`search_meta_data` **不是**查数，禁止用它代替 `execute_sql`。
2. 用**自己的** `agent_user_key`。不要把 `mcp.json` 或 key 写进本仓库。
3. 探查（「有没有掉」「看看本周」）**只跑 Phase 1**，问一句是否继续。
4. 「为什么掉 / 归因」且门禁过，**并且有 `client_id`**（或 parent 下已锁定 focus）才自动 Phase 2–4。大盘禁止自动 3a / 在线时长 / 限流。
5. 报告：复制 `phases/04-report-skeleton.md` 只填空。先跑 `python scripts/check-report-skeleton.py 报告.md`，通过后再跑 `python scripts/render-report-html.py 报告.md`，得到同名 HTML。检查或渲染失败则不写 HTML。ES 人话见 `docs/es-writing.md`；后续动作编号见 `docs/es-cause-catalog.md`。不要抄 gold 的旧 3a 表头。
6. `execute_sql` 只 Read lite 原文填占位符；一次调用一个文件。语句里不要出现 `--` 或 `#`（`/* */` 内部也不要）。禁止 14 路 UNION。SH / SS `01-ss-supplier` / 限流 `01-ss-supplier-window` **必填 `{sid_list}`**（结构 SID；禁止空 `IN ()`）。SH 禁止 `clientid`。禁止全表 LIMIT 50 写结构 SID「未覆盖/未返回」。
7. 未支持：#23 机构供应商白名单快照禁止当 3a 证据；#3 DidaBase 没有，CS 查价用 SS 近似。LCDH 叫击穿兜底名单，不是白名单。
8. 口径入口是 `SKILL.md`，不是 backlog。回归只用 `examples/gold-*.md`。
9. **装完先做「权限自测」**（下一节）。不同账号表权限不同；缺表就缺对应证据线，不要等跑到 Phase 3 才发现。

口径细节见 `SKILL.md`。表字段见 `tables.md`。分享包排除见 `.gitignore`（本机可留，不推 GitHub）。

## 权限自测（每人必做）

`execute_sql` 会按你的 `agent_user_key` 注入行级权限。能查表 ≠ 能看全量 client。用**自己的 key**测，不要借别人的。

**三种失败不要混：**

| 现象 | 含义 | 怎么处理 |
|------|------|----------|
| `permission denied` / 无权限 / access denied | **没表权限** | 找数据平台开该 `schema.table` 的 SELECT |
| MCP 500 / 超时 | **≠ 没权限**（SQL 太重或网关超时） | 必须用下面的轻量探测；仍 500 再报平台 |
| 查询成功但 0 行 | 表权限多半有，行级过滤把 client 滤掉了 | 换一个你有权限的 client 再试 |

`search_meta_data` 搜不到 ≠ 没权限。`configuration.wolf_rateadjust_hotel_log`、`rateaccuracy.channel_online_states_new` 元数据常为 0 条，以 `execute_sql` 为准。

**探测 SQL（每张表只跑这一句）：**

```sql
SELECT 1 AS ok FROM <schema.table> LIMIT 1
```

`execute_sql` 的 `tables` 填同一张表，`timeout_seconds` 用 30。返回 1 行 = 有表权限。禁止用 14 路 UNION、完整归因 SQL 或扫全表来测权限。

**最低可用（只能看有没有掉产）：** `public.npd_booking_view`

**完整归因建议一次测完（P0+P1，17 张）：**

| 优先级 | 表 | 缺了会怎样 |
|--------|-----|------------|
| P0 | `public.npd_booking_view` | **整条归因停**（Phase 1/2 BKS） |
| P0 | `content.dida_hotel_view` | 国家/连锁下钻、节假日同比 BKS 做不了 |
| P1 | `crm.client_info_ods` | 配 parent 时 3a 展开 client 失败 |
| P1 | `configuration.wolf_rateadjust_log` | CS/C/S/CSA/CBD/SBD 配置未验 |
| P1 | `configuration.wolf_rateadjust_hotel_log` | CDH/SH/LCDH 未验 |
| P1 | `configuration.wolfl2lclientlevelconfiglog` | L2L 未验 |
| P1 | `configuration.wolfl2lconfiglog` | CSLRC 未验 |
| P1 | `configuration.bottom_margin_log` | C/S Bottom 未验 |
| P1 | `configuration.client_configuration_change_log` | Configuration 未验 |
| P1 | `ads.ads_hotel_monitor_rate_search_statistic_by_client_id` | 机构级 DidaBiz 查价走 funnel fallback |
| P1 | `public.clientsupplierhotelcallcountsummary` | SS 查价（CS 近似）看不了 |
| P1 | `data_ovs.didamonitor_funnel_client_country` | ads 失败时国家 PPS 没退路 |
| P1 | `data_ovs.didamonitor_funnel_client_chain` | 连锁查价下钻失败 |
| P1 | `data_ovs.rate_accuracy_channel_multi_dimension` | **验价准确率整条断** |
| P1 | `public.clientloscallcount` | QPS × LOS 次要下钻 |
| P1 | `public.clientleadtimecallcount` | QPS × leadtime 次要下钻 |
| P1 | `public.clientnationalitycallcount` | QPS × nationality 次要下钻 |

三张 QPS 表是次要下钻，可后测。核心不要漏：P0 两张 + 配置 7 张 + 查验订 5 张（共 14 张）。

**覆盖在线 / 限流 / 节假日再加 3 张（P2）：**

| 表 | 缺了会怎样 |
|----|------------|
| `rateaccuracy.channel_online_states_new` | 渠道上下线 / 在线时长做不了 |
| `dws.dws_hotel_flow_didamonitor_supplier_csa_di` | SS 限流 / 缓存做不了 |
| `ads.ads_marketing_calendar_event_wide_d_f` | Phase 3d 节假日外部事件做不了 |

**一次性复制（20 张）：**

```
public.npd_booking_view
content.dida_hotel_view
crm.client_info_ods
configuration.wolf_rateadjust_log
configuration.wolf_rateadjust_hotel_log
configuration.wolfl2lclientlevelconfiglog
configuration.wolfl2lconfiglog
configuration.bottom_margin_log
configuration.client_configuration_change_log
ads.ads_hotel_monitor_rate_search_statistic_by_client_id
public.clientsupplierhotelcallcountsummary
data_ovs.didamonitor_funnel_client_country
data_ovs.didamonitor_funnel_client_chain
data_ovs.rate_accuracy_channel_multi_dimension
public.clientloscallcount
public.clientleadtimecallcount
public.clientnationalitycallcount
rateaccuracy.channel_online_states_new
dws.dws_hotel_flow_didamonitor_supplier_csa_di
ads.ads_marketing_calendar_event_wide_d_f
```

3a 缺表只能标「未验」，**不能写成 event_count=0，不能写「已排除 Dida」**。MCP 500 的处置见 `docs/mcp-permission-matrix.md`。

**可选：** `search_metrics` 能搜到 `ORD_0231`（BKs*create）或 `ORD_0001`（GP*checkout）；`analyse_query` 任意 7 天、指标 `ORD_0001` 能出数。指标底层会打 `dwd.dwd_hotel_order_channel_supplier_booking_mf`，同样受行级权限限制。Phase 1 SOP 默认仍走 `npd_booking_view`。
