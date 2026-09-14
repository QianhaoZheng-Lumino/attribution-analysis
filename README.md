# attribution-analysis

酒店 Overseas API 产量异动归因（Cursor / Claude Code / Codex Skill）。  
仓库：<https://github.com/QianhaoZheng-Lumino/attribution-analysis>

**前提：** 你已有查数 MCP（`user-data-mcp`）和自己的 `agent_user_key`。本仓库不发 key、不开通权限。

## 给同事 Agent 的安装提示词（复制即用）

把下面整段发给你的 Cursor / Claude Code / Codex Agent：

```text
请把 GitHub 仓库 https://github.com/QianhaoZheng-Lumino/attribution-analysis 安装为 attribution-analysis Skill。
- Cursor：克隆到 ~/.cursor/skills/attribution-analysis/（Windows 为 %USERPROFILE%\.cursor\skills\attribution-analysis）
- Claude Code：克隆到 ~/.claude/skills/attribution-analysis/
- Codex：克隆到 ~/.agents/skills/attribution-analysis/
要求该目录根下直接有 SKILL.md（不要多套一层文件夹）。仓库是 Private，如 clone 失败请用已登录 gh/git 的账号。
我已配置 user-data-mcp（自己的 key）。安装后用于酒店 Overseas API 产量异动归因；先读 README.md「使用前注意事项」，再按 SKILL.md 执行模式跑。
```

也可自己执行（Cursor 示例）：

```powershell
git clone https://github.com/QianhaoZheng-Lumino/attribution-analysis.git "$env:USERPROFILE\.cursor\skills\attribution-analysis"
```

装完请**新开一轮对话**。不要把本仓库当普通项目打开就指望自动生效。

## 使用前注意事项

1. MCP 必须已连上，且工具含 `execute_sql` / `analyse_query` / `search_meta_data` 等。不可用或未认证 → **停**，禁止手写 SQL。
2. 用**自己的** `agent_user_key`。不要把 `mcp.json` 或 key 写进本仓库。
3. 探查（「有没有掉」「看看本周」）**只跑 Phase 1**，问一句是否继续。
4. 「为什么掉 / 归因」且门禁过，**并且有 `client_id`**（或 parent 下已锁定 focus）才自动 Phase 2–4。大盘禁止自动 3a / 在线时长 / 限流。
5. 报告：复制 `phases/04-report-skeleton.md` 只填空，跑 `python scripts/check-report-skeleton.py 报告.md`。不要抄 gold 的旧 3a 表头。
6. `execute_sql` 只 Read lite 原文填占位符；一次调用一个文件。禁止 MCP 跑 `03-fourteen-level-checklist.sql`。SH / SS `01-ss-supplier` / 限流 `01-ss-supplier-window` **必填 `{sid_list}`**（结构 SID；禁止空 `IN ()`）。SH 禁止 `clientid`。禁止全表 LIMIT 50 写结构 SID「未覆盖/未返回」。
7. 未支持：#23 机构供应商白名单快照禁止当 3a 证据；#3 DidaBase 没有，CS 查价用 SS 近似。LCDH 叫击穿兜底名单，不是白名单。
8. 口径入口是 `SKILL.md`，不是 backlog。回归只用 `examples/gold-*.md`。

口径细节见 `SKILL.md`。
