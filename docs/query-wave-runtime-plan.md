# 查数波次 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让一次完整归因按波次发出互不依赖的 lite 查询，同一轮最多 5 条 `execute_sql`，每条仍是一个文件。

**Architecture:** 总表只写在 `phases/02-dimension-drilldown.md`。`SKILL.md` 写五条硬规则并链接总表。Phase 3 和两份 lite README 删掉「逐条跑」并改指向总表。`scripts/check-query-waves.py` 锁住这些句子，防止以后写回串行。不改 SQL，不改定责公式。

**Tech Stack:** Markdown 技能文档，Python 3 标准库检查脚本，现有 `scripts/check-first-day.py` 与 `scripts/check-report-skeleton.py`。

## Global Constraints

- 工作区只用 `C:\Users\郑乾皓\.cursor\skills\attribution-analysis-query-waves`，分支 `perf/query-waves`。不要改 `C:\Users\郑乾皓\.cursor\skills\attribution-analysis` 里的 `docs/attribution-logic-handbook` 未提交文件。
- 不合并进 `main`，不推送。`main` 保持 `a94c945`。
- 一次 `execute_sql` = 一个 lite 文件。禁止 14 路或任何多表 UNION。
- 同一轮 `execute_sql` 最多 5 条。Read 不计入这 5 条。
- Phase 1 的 `01 → 02 → 03` 保持一条一条执行。失败重试禁止三步并行。
- 不改 SQL 文件，不改 `responsibility-model.md`，不改报告骨架。
- `examples/gold-agoda-20260320.md` 在基线上已经过不了骨架检查，不把它当作本改动的通过条件。
- 不新增自动计时脚本。

---

## 文件职责

- `scripts/check-query-waves.py`：只检查文档契约。不连 MCP，不计时。
- `SKILL.md`：入口五条硬规则。Phase 1 进度清单保持原句。
- `phases/02-dimension-drilldown.md`：W0–W4 总表。2c 文件集合不减少。
- `phases/03-evidence-verification.md`：发送方式改指向 W2/W4。14 行打勾、过线条件、S Bottom 禁止抄 C Bottom 保留。
- `sql/dimension-contribution-lite/README.md`：Step 2 之后指向 W2/W3。
- `sql/config-change-detection-lite/README.md`：Step 2 改为每批最多 5。打勾清单保留。
- `docs/query-wave-trial.md`：只在人工试跑之后写入。试跑前不要创建。

### Task 1: 入口硬规则与 Phase 2 总表

**Files:**
- Create: `scripts/check-query-waves.py`
- Modify: `SKILL.md`（`## Phase 2–4` 之后、`## 归因口径` 之前；文末验收那一行）
- Modify: `phases/02-dimension-drilldown.md`（`## 执行清单` 之前插入总表，并改清单）
- Test: `scripts/check-query-waves.py`

**Interfaces:**
- Consumes: `docs/query-wave-runtime-design.md` 的五条硬规则和 W0–W4。
- Produces: Phase 2 标题必须是 `## 查数波次`。SKILL 必须含句子 `同一轮 `execute_sql` 最多 5 条`。后续任务只链接这个标题，不另写第二份总表。

- [ ] **Step 1: 写只覆盖入口和 Phase 2 的失败检查**

把下面脚本写成 `scripts/check-query-waves.py`。Task 2 会整文件替换它。

```python
#!/usr/bin/env python3
"""Lock the query-wave sentences in SKILL.md and Phase 2."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def main() -> int:
    errs: list[str] = []
    skill = read("SKILL.md")
    phase2 = read("phases/02-dimension-drilldown.md")
    for needle in (
        "一次 `execute_sql` = 一个 lite 文件",
        "同一轮 `execute_sql` 最多 5 条",
        "禁止三步并行",
        "lite 三步 SQL 串行：01 → 02 → 03",
    ):
        if needle not in skill:
            errs.append(f"SKILL.md 缺：{needle}")
    if "phases/02-dimension-drilldown.md" not in skill or "查数波次" not in skill:
        errs.append("SKILL.md 未链接 Phase 2 查数波次")
    if "## 查数波次" not in phase2:
        errs.append("Phase 2 缺「## 查数波次」")
    for needle in (
        "### W0 Phase 1",
        "### W1 定责入口",
        "### W2",
        "### W3",
        "### W4",
        "14-sid-client-validation.sql",
        "禁止两个方向一起投机跑",
        "同一轮最多 5 条",
        "04-country.sql",
        "13-sid-nationality.sql",
    ):
        if needle not in phase2:
            errs.append(f"Phase 2 总表缺：{needle}")
    if errs:
        print("FAIL scripts/check-query-waves.py")
        for err in errs:
            print(f" - {err}")
        return 1
    print("PASS scripts/check-query-waves.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: 跑检查，确认现在失败**

Run: `python scripts/check-query-waves.py`  
Expected: FAIL，并指出 SKILL.md 与 Phase 2 缺「查数波次」。

- [ ] **Step 3: 在 SKILL.md 写入硬规则**

不要改 Phase 1 进度清单里的 `lite 三步 SQL 串行：01 → 02 → 03`。

在 `SH / SS ... Top3）。` 那段和 `## 归因口径（Phase 3–4 必读）` 之间插入：

```markdown
## 查数波次

总表在 [phases/02-dimension-drilldown.md](phases/02-dimension-drilldown.md)「查数波次」。Phase 1 的 `01 → 02 → 03` 仍一条一条执行。

1. 一次 `execute_sql` = 一个 lite 文件。SQL 必须来自刚 Read 的原文，只替换占位符。语句里不出现 `--` 或 `#`。
2. 同一轮 `execute_sql` 最多 5 条。Read 不计入这 5 条。一轮要么 Read 下一批最多 5 个文件，要么发送已经 Read 过的最多 5 条查询。
3. 某一条返回 500：只重试这一条。先按现有规则判断本轮是否已探活；探活成功则用同一文件原文、`timeout_seconds=30` 再跑一次。同批已经成功的结果保留，不重发。仍失败则这一条标「未验」，禁止写成 0。
4. `{sid_list}` 为空时，不发 SH checklist、`01-ss-supplier`、`rate-limit-lite/01-ss-supplier-window`。用现有规则补 SID（2b 锁定，或 `02-sid` 的 `|change|` Top3）。补不出来则这三条标「未验」，禁止空 `IN ()`。
5. Phase 1 失败重试必须 `01 → 02 → 03` 串行，禁止三步并行。
```

把文末 `改完验收：` 那一行改成：

```markdown
- 改完验收：`python scripts/check-first-day.py` + `python scripts/check-query-waves.py` + `python scripts/check-report-skeleton.py`
```

- [ ] **Step 4: 在 Phase 2 插入总表并改执行清单**

在 `## 执行清单` 之前插入下面全文：

```markdown
## 查数波次

占位符在进入该波之前填好：`client_id`、`analysis_date`、产量窗口。`{sid_list}` 只在 W1 返回之后才算有值。每一批是两轮：先 Read 这批最多 5 个文件，下一轮再发已经 Read 过的查询。同一轮 `execute_sql` 最多 5 条。一次调用一个 lite 文件。某一条 500 只重试这一条，同批成功结果保留。

### W0 Phase 1

文件：`sql/anomaly-detection-lite/01-period-totals.sql`，然后 `02-historical-baseline.sql`，然后 `03-daily-series.sql`。一条完成后再发下一条。失败重试必须 `01 → 02 → 03` 串行，禁止三步并行。

### W1 定责入口

只跑 `sql/dimension-contribution-lite/02-sid.sql`。这一条回来之前，不发 W2、W3。

### W2 02-sid 已返回

先按现有规则填 `{sid_list}`（2b 锁定的 SID，或 `02-sid` 里 `|change|` Top3）。填完仍为空时，本波照样开始，只是不发 SH、`01-ss-supplier`、限流。

下列文件互不依赖。按优先级每批 5 条，直到发完。同一轮最多 5 条：

1. `14-sid-client-validation.sql`：只对占 `|ΔBKS| ≥ 10%` 的 SID，每家一条。没有这样的 SID 就跳过，并写「无 SID≥10%，跳过」。这些验证 B 优先占用前面批次的名额。
2. `sql/config-change-detection-lite/checklist/01-cs.sql` 到 `14-configuration.sql`，共 14 个文件，含结果为 0 的也要发。
3. 其余各一条：`02-client-before-after-bks.sql`、`sql/online-hours-lite/03-window-avg.sql`、`sql/rate-limit-lite/01-ss-supplier-window.sql`、`sql/search-attribution-lite/01-ss-supplier.sql`。

`{sid_list}` 仍空时，从本波拿掉 `checklist/08-sh.sql`、`01-ss-supplier`、`rate-limit-lite/01-ss-supplier-window.sql`。其余 checklist 照发。W2 不包含 2c 路径文件，也不包含任何 detail。`01-ss-supplier` 不等 `00-client-total`。`03-window-avg.sql` 在本波发送，不必等查价 WoW。

### W3 2b 方向已经写出

只跑该方向的文件，每批最多 5 条。`02-sid` 不重复跑。方向还没写出时不发本波。禁止两个方向一起投机跑。

| 方向 | 文件 |
|---|---|
| C/Dida | `04-country.sql`、`06-chain.sql`、`08-lt.sql`、`10-los.sql`、`12-nationality.sql` |
| S/CS | `05-sid-country.sql`、`07-sid-chain.sql`、`03-sid-account.sql`、`09-sid-lt.sql`、`11-sid-los.sql`、`13-sid-nationality.sql` |

验证 B 的跳过条件、写死 C/Dida 的双门、S/CS 的 Account 过滤，仍以 `responsibility-model.md` 为准。本波只改变发送批次。

### W4 checklist 已返回

只跑过线的 detail，每批最多 5 条。一般 level：`event_count > 0` 才跑配对 detail。SH：`event_count ≥ 10` 才跑 `detail/08-sh-hotel-bks-lite.sql`；`<10` 不跑；`>50000` 或 MCP 500 走现有 BI 兜底。CDH / LCDH：`event_count > 0` 才跑 `detail/07-cdh-hotel-bks-lite.sql` / `detail/09-lcdh-hotel-bks-lite.sql`。`event_count = 0` 不发 detail。S Bottom 只用 `detail/13-s-bottom-detail.sql`，禁止抄 C Bottom。

### 其余查询

3b 里除 `01-ss-supplier` 以外的下钻、3c、3d、准确率 issue、在线时长 500 兜底脚本，仍按 Phase 3 现有触发条件决定发不发。同一时刻有多条、且谁也不用谁的结果时，同样每批最多 5 条，每条一个文件。
```

把执行清单代码块换成：

```markdown
```
- [ ] W1：dimension-contribution-lite/02-sid.sql（回来之前不发 W2、W3）
- [ ] W2：验证 B（过线 SID 每家一次；无则写「无 SID≥10%，跳过」）+ checklist 与「查数波次」W2 其余文件
- [ ] W3：2b 方向写出后，只发该方向的 2c 文件（C/Dida 5 个或 S/CS 6 个）— 缺任一 → 2c_progress 未达标
- [ ] 2b-A 读 2_SID → 定责方向
- [ ] 2c 写入报告（Country+Chain 表；LT/LOS/Nationality 段落）
```
```

`### 2c MCP 必跑文件` 那张表的文件名保持不动。表后加一句：`这些文件按「查数波次」W3 发送。方向未写出不发。禁止两个方向一起发。`

- [ ] **Step 5: 跑检查，确认通过**

Run: `python scripts/check-query-waves.py`  
Expected: `PASS scripts/check-query-waves.py`

- [ ] **Step 6: Commit**

```bash
git add scripts/check-query-waves.py SKILL.md phases/02-dimension-drilldown.md
git commit -m "State the query-wave rules at the skill entry and in Phase 2."
```

### Task 2: 去掉 Phase 3 和 README 里的逐条发送

**Files:**
- Modify: `scripts/check-query-waves.py`（整文件替换）
- Modify: `phases/03-evidence-verification.md:84-86`、`:405-406`、`:413-414`、`:446`
- Modify: `sql/dimension-contribution-lite/README.md:12-18`
- Modify: `sql/config-change-detection-lite/README.md:14`、`:51-53`
- Test: `scripts/check-query-waves.py`

**Interfaces:**
- Consumes: Phase 2 标题 `## 查数波次`，以及 W2 包含 `01-ss-supplier` 与 `03-window-avg.sql`、W4 才发 detail。
- Produces: 这三个文件都含 `查数波次`。Phase 3 与 config README 不再含 `逐条跑`、`必须逐个跑`、`逐条 MCP`。Phase 3 仍含 `逐条打勾`。

- [ ] **Step 1: 把检查脚本换成完整契约**

用下面全文覆盖 `scripts/check-query-waves.py`：

```python
#!/usr/bin/env python3
"""Lock the query-wave contract across the skill entry, Phase 2, Phase 3, and lite READMEs."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def main() -> int:
    errs: list[str] = []
    skill = read("SKILL.md")
    phase2 = read("phases/02-dimension-drilldown.md")
    phase3 = read("phases/03-evidence-verification.md")
    dim = read("sql/dimension-contribution-lite/README.md")
    cfg = read("sql/config-change-detection-lite/README.md")

    for needle in (
        "一次 `execute_sql` = 一个 lite 文件",
        "同一轮 `execute_sql` 最多 5 条",
        "禁止三步并行",
        "lite 三步 SQL 串行：01 → 02 → 03",
    ):
        if needle not in skill:
            errs.append(f"SKILL.md 缺：{needle}")
    if "查数波次" not in skill:
        errs.append("SKILL.md 未指向查数波次")

    if "## 查数波次" not in phase2:
        errs.append("Phase 2 缺「## 查数波次」")
    for needle in (
        "### W0 Phase 1",
        "### W1 定责入口",
        "### W2",
        "### W3",
        "### W4",
        "14-sid-client-validation.sql",
        "禁止两个方向一起投机跑",
        "同一轮最多 5 条",
    ):
        if needle not in phase2:
            errs.append(f"Phase 2 总表缺：{needle}")

    for rel, text in (
        ("phases/03-evidence-verification.md", phase3),
        ("sql/config-change-detection-lite/README.md", cfg),
    ):
        if "逐条跑" in text or "必须逐个跑" in text or "逐条 MCP" in text:
            errs.append(f"{rel} 仍要求逐条发送 checklist")
        if "查数波次" not in text:
            errs.append(f"{rel} 未指向查数波次")
    if "逐条打勾" not in phase3:
        errs.append("Phase 3 丢了「逐条打勾」（14 行输出要保留）")
    if "禁止抄 C Bottom" not in phase3 and "禁止抄" not in phase3:
        errs.append("Phase 3 丢了 S Bottom 禁止抄 C Bottom")
    if "W2" not in dim or "W3" not in dim:
        errs.append("dimension-contribution-lite/README.md 未指向 W2/W3")
    if "一条一条" in dim:
        errs.append("dimension README 仍要求 2c 一条一条来")
    if "14 路" not in cfg or "一次调用 = 一个文件" not in cfg:
        errs.append("config lite README 丢掉了一次调用一个文件或禁止 14 路")
    if "最多 5" not in cfg:
        errs.append("config lite README 未写每批最多 5")

    if errs:
        print("FAIL scripts/check-query-waves.py")
        for err in errs:
            print(f" - {err}")
        return 1
    print("PASS scripts/check-query-waves.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: 跑检查，确认现在失败**

Run: `python scripts/check-query-waves.py`  
Expected: FAIL，指出 Phase 3 或 README 仍有「逐条跑 / 逐条 MCP / 必须逐个跑」，或未指向查数波次。

- [ ] **Step 3: 改 Phase 3 的发送句，保留判定句**

`phases/03-evidence-verification.md` 里只改下面几处。

规则 2 的 Step A 换成：

```markdown
   - **Step A** 按 [02-dimension-drilldown.md](02-dimension-drilldown.md)「查数波次」W2 发送 `sql/config-change-detection-lite/checklist/01-cs.sql` … `14-configuration.sql`（**禁止** 14 路 UNION；一次调用一个文件；同一轮最多 5 条）
```

Step A' 换成：

```markdown
   - **Step A'** `02-client-before-after-bks.sql` 与 Step A 同属 W2，不等 Step A 全部结束
```

Step B 整行换成：

```markdown
   - **Step B** checklist 已返回后，按查数波次 W4 发送过线 detail。对 `event_count > 0` 的 level，按 `sql/config-change-detection-lite/README.md` Step 3 表跑列出的 detail 路径（**CBD 必跑** `detail/05-cbd-detail.sql`，**必须读 `remark` + 比 last_margin**；**S Bottom 必跑** `detail/13-s-bottom-detail.sql`，**禁止抄 C Bottom**）。10/11/04 必须 Read `detail/10-l2l-detail.sql`、`detail/11-cslrc-detail.sql`、`detail/04-csa-detail.sql`；禁止手写 last_level 列。同一轮最多 5 条。
```

规则 4 的「按下面 14 行表逐条打勾」不要删。

Agent 执行 SOP 的第 2、3 条换成：

```markdown
2. 【3a 配置】按 Phase 2「查数波次」W2 发送 02-client-before-after-bks + checklist/01–14 → **必须 14/14 行**（一次调用一个文件，同一轮最多 5 条）
3. 【3a】checklist 已返回后按 W4：event_count>0 → 按 lite README Step 3 表跑列出的 detail；对照 config-search-precheck-mapping 预期指标
```

SOP 第 4 步改成下面四行，去掉「先 00 再 01」：

```markdown
4. 【3b 查价】
   a. `01-ss-supplier` 属于 W2（**必填 `{sid_list}`**；禁止全表 LIMIT 50 写「未覆盖涨尾」）。它不等 `00-client-total`。
   b. **2b = C/Dida 或涨产待区分** → `00-client-total`（机构 **查价**，ads 表）；仍 500 → **`00a`+`00b`**。这不是 W2 的门。
   c. 对齐 2c Top 维 → `02-didabiz-pps-country` 等
   d. 机构级 precheck 总量：rate_accuracy client 聚合（与 00 同窗，手算查验比）
```

SOP 第 6 步整行换成：

```markdown
6. 辅助（限流/缓存）：**结构 SID 必出数**（2b 锁定或占 \|ΔBKS\|≥10%）→ `rate-limit-lite/01-ss-supplier-window.sql` **必填 `{sid_list}`**。`{sid_list}` 已填时该文件属于查数波次 W2。禁止全表 `ORDER BY`+`LIMIT 50` 代替结构 SID。SS 有价/请求 \|WoW\|>10% 只决定解读档。见 §5.10（涨方向/请求↓产量↑ **待研究**，仅报数；未过 10% 仍出表作排除）
```

SOP 第 6b 步整行换成：

```markdown
6b. 辅助（在线时长）：`online-hours-lite/03-window-avg.sql` 在查数波次 W2 发送，不必等查价 WoW（**必填 client_id**；窗口 = Phase 1；**禁止 `AT TIME ZONE`**）。禁止手算。MCP 500 才 fallback 拉 log + `scripts/test-online-hours.py`。**异动：日均少 ≥1.5h**。source/remark 用 `04-window-source.sql`（`TIMESTAMPTZ '...+08'` 直接比较）。**邮件解析** 可信；**数据库分析** 仅辅助。**因果：在线↓→查价↓ only**。见 [online-hours-mapping.md](../docs/online-hours-mapping.md)
```

MCP 注意里这条：

```markdown
- **14/14 必须逐个跑** checklist/01–14；禁止 UNION 批量；**禁止手写替代**；未验 level 计入 `checklist_progress`（如 11/14）
```

换成：

```markdown
- **14/14 必须按查数波次 W2 发完** checklist/01–14（同一轮最多 5 条，一次调用一个文件）；禁止 UNION 批量；**禁止手写替代**；未验 level 计入 `checklist_progress`（如 11/14）
```

- [ ] **Step 4: 改两份 lite README**

`sql/dimension-contribution-lite/README.md` 的使用顺序代码块换成：

```markdown
```
Step 0  按 ../params-template.md 计算日期 → 填入占位符
Step 1  01-total.sql           → 总量变化（可选，不挡 W1）
Step 2  02-sid.sql             → 【必做】W1。回来之前不发 W2、W3
Step 2b 14-sid-client-validation.sql → W2：门 1，过线 SID（≥10%）每家一次，优先占批次名额
Step 3  2b 方向写出后按 W3 发送该方向文件（C/Dida 或 S/CS，禁止两个方向一起发）
Step 4  Agent 本地算贡献%（分母见下，禁止一律 / total_change）
```
```

在该代码块下加一句：`发送批次以 [phases/02-dimension-drilldown.md](../../phases/02-dimension-drilldown.md)「查数波次」为准。同一轮最多 5 条。`

`sql/config-change-detection-lite/README.md` 的 Step 2 那一行换成：

```markdown
Step 2  checklist/01-cs.sql … 14-*.sql     → 14 行清单（按查数波次 W2，同一轮最多 5 条，含 0 也要跑；**Read 文件原文执行，禁止手写**）
```

「checklist 执行顺序」的执行纪律换成：

```markdown
**执行纪律：** 按 [phases/02-dimension-drilldown.md](../../phases/02-dimension-drilldown.md)「查数波次」W2 发送。每批先 Read 最多 5 个文件，下一轮再发这最多 5 条；一次调用一个文件。500 时只重试这一条，用同一文件原文再跑 1 次后仍失败才标未验。打勾清单保留。
```

下面的 14 行打勾代码块不要删、不要改文件名。

- [ ] **Step 5: 跑文档契约和基线检查**

Run: `python scripts/check-query-waves.py`  
Expected: `PASS scripts/check-query-waves.py`

Run: `python scripts/check-first-day.py`  
Expected: `PASS scripts/check-first-day.py`

Run: `python scripts/check-report-skeleton.py --skeleton`  
Expected: `PASS phases/04-report-skeleton.md` 或等价的 1 passed。

不要跑 `python scripts/check-report-skeleton.py examples/gold-agoda-20260320.md`。基线上它已经失败。

- [ ] **Step 6: Commit**

```bash
git add scripts/check-query-waves.py phases/03-evidence-verification.md sql/dimension-contribution-lite/README.md sql/config-change-detection-lite/README.md
git commit -m "Point Phase 3 and the lite READMEs at the query-wave table."
```

### Task 3: 人工试跑并写下记录

**Files:**
- Create: `docs/query-wave-trial.md`（只有真人看完一次运行之后才写）
- Test: 当次工具调用与成品报告，对照下面四项

**Interfaces:**
- Consumes: Task 2 已提交，且三个检查脚本都通过。
- Produces: `docs/query-wave-trial.md` 里有「通过」或「失败」四字之一，并列出实际发出的文件名。失败则不要合并。

- [ ] **Step 1: 停下来，等用户同意再查数**

不要在用户没有说「开始试跑」时调用 `execute_sql`。默认案例是 Agoda，`analysis_date` 2026-03-20，`client_id` Agoda，按完整归因跑 Phase 1–4。用户若改案例，用用户给的 client 和日期。

- [ ] **Step 2: 按总表跑，并留住工具调用**

W0 三条一条一条发。W1 只发 `02-sid`。W2 起每轮最多 5 条 `execute_sql`，每条一个 lite 原文。方向没写出不发 W3。`event_count` 没过线不发 detail。

- [ ] **Step 3: 把结果写成试跑记录**

`docs/query-wave-trial.md` 使用下面结构，空着的格子填实际值，不要留尖括号：

```markdown
# 查数波次试跑

- 案例：Agoda / 2026-03-20
- 分支：perf/query-waves
- 结论：通过

## 查询集合

- W0：01-period-totals，02-historical-baseline，03-daily-series
- W1：02-sid
- W2：列出实际发出的文件名，并写每轮条数
- W3：方向，以及该方向的文件名
- W4：过线 level 与 detail 文件名

## 四项比对

1. 触发条件已满足的文件都发出了，或标了未验：是
2. checklist 进度：14/14
3. detail 集合与 event_count 过线规则一致：是
4. 定责方向符合当次数字下的双门：写出方向。后续动作编号来自 es-cause-catalog：写出编号

## 失败条件

- 一次调用多个文件或 UNION：否
- 空 sid_list 仍发了 SH、查价或限流：否
- 500 或 0 行写成业务 0：否
- 方向未写出就发了 W3，或两个方向一起发：否
- 未过线却发了 detail，或 S Bottom 抄了 C Bottom：否
```

产量数字和旧 gold 不同，但查询集合和触发规则一致：结论仍写「通过」，并加一句「定责方向变化来自数据漂移」。任一失败条件为「是」：结论写「失败」，不要合并。

- [ ] **Step 4: Commit**

只有记录已经写完才提交。失败的记录也提交，方便停在本分支。

```bash
git add docs/query-wave-trial.md
git commit -m "Record the query-wave trial against the Agoda gold case."
```

不要 `git push`。不要合并到 `main`。
