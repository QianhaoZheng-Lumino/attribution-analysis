# 查数波次：运行时长设计

日期：2026-09-28  
基线：`origin/main` `a94c945`（Draw comparison bars for every booking pair and accept signed accuracy deltas.）  
分支：`perf/query-waves`  
工作区：`C:\Users\郑乾皓\.cursor\skills\attribution-analysis-query-waves`

## 目的

缩短一次完整归因的墙钟时间。做法是让模型在一轮回复里同时发出多条互不依赖的 `execute_sql`。每条调用仍然是一个 lite 文件原文，只替换占位符。

这不增加模型能力。Cursor 只在同一次回复里出现多条工具调用时才会并行执行。一次只发一条调用的模型会保持现在的串行，分析仍能做完，时长几乎不降。

## 不做什么

- 不合并进 `main`。本分支不跟踪 `origin/main`。不合并、不把本分支推到 `main`，`main` 保持 `a94c945`。
- 不改动当前仓库里 `docs/attribution-logic-handbook` 上未提交的手册、案例和 `tmp/`。
- 不改定责公式、归因门禁、2b 双门、ES 写法、后续动作目录、checklist / detail 的 SQL 正文。
- 不把多条 SQL 拼进一次 `execute_sql`，禁止 14 路或任何多表 UNION。
- Phase 1 的 `01 → 02 → 03` 保持一条一条执行。失败后的重试也保持这个顺序。
- 不把口径文档改成按需打开，不把查数搬进模型外面的脚本。

## 时长预期（不是验收门禁）

上次审计假设：一轮模型思考约 12 秒，一次查数约 8 秒。完整 C 路径大约 14 分钟，其中约 35 次是查数来回。下面是同一假设下的估计，不是实测。

| 模型实际行为 | 大约时长 | 大约省下 |
|---|---|---|
| 一轮发出多条，数据库也并行 | 6–8 分钟 | 6–8 分钟 |
| 一轮发出多条，数据库仍排队 | 约 10 分钟 | 约 4 分钟 |
| 仍然一次只发一条 | 约 14 分钟 | 几乎为 0 |

大头是 14 条 checklist：串行大约 5 分钟；每批最多 5 条时变成 3 批，大约 1 分钟。C 路径 2c 的 5 个文件再省大约 1 分钟。SH、CDH 这类大表会拖住它所在的那一批，该批要等最慢的那条。Phase 1 三步和 `02-sid` 仍串行，这两段不缩短。

同一轮可以发送已经 Read 过的查询，并 Read 下一批文件。同一轮刚 Read 的文件，这一轮不能发。上一轮的 Read 结果还没回来时，不能发那一批 SQL。上表的分钟数是 2026-09-28 的估算，不是秒表。Traveloka 2026-09-11 的完整跑法超过 20 分钟。

时长缩短不是本设计的通过条件。通过条件是试跑没有破坏下面的硬规则。

## 硬规则（写进 `SKILL.md`，Phase 文档不得写相反的话）

1. 一次 `execute_sql` = 一个 lite 文件。SQL 必须来自上一轮已经返回的 Read 原文，只替换占位符。语句里不出现 `--` 或 `#`。
2. 同一轮 `execute_sql` 最多 5 条。Read 不计入这 5 条。同一轮可以发送已经 Read 过的查询，并 Read 下一批最多 5 个文件。同一轮刚 Read 的文件，这一轮不能发。
3. 某一条返回 500：只重试这一条。先按现有规则判断本轮是否已探活；探活成功则用同一文件原文、`timeout_seconds=30` 再跑一次。同批已经成功的结果保留，不重发。仍失败则这一条标「未验」，禁止写成 0。
4. `{sid_list}` 为空时，不发 SH checklist、`01-ss-supplier`、`rate-limit-lite/01-ss-supplier-window`。用现有规则补 SID（2b 锁定，或 `02-sid` 的 `|change|` Top3）。补不出来则这三条标「未验」，禁止空 `IN ()`。
5. Phase 1 失败重试必须 `01 → 02 → 03` 串行，禁止三步并行。

## 波次

总表放在 `phases/02-dimension-drilldown.md` 的新小节「查数波次」。`phases/03-evidence-verification.md`、`sql/dimension-contribution-lite/README.md`、`sql/config-change-detection-lite/README.md` 只保留指向这句话的链接，并删掉与总表冲突的「逐条串行」表述。14/14 打勾、`event_count` 过线才跑 detail、SH `n≥10` 等判定保持原样。

占位符在进入该波之前就要填好：`client_id`、`analysis_date`、产量窗口。`{sid_list}` 只在 W1 返回之后才算有值。

### W0 Phase 1

文件：`sql/anomaly-detection-lite/01-period-totals.sql`，然后 `02-historical-baseline.sql`，然后 `03-daily-series.sql`。

一条完成后再发下一条。失败重试走硬规则 5。

### W1 定责入口

只跑 `sql/dimension-contribution-lite/02-sid.sql`。

这一条回来之前，不发 W2、W3。

### W2 `02-sid` 已返回

先按现有规则填 `{sid_list}`（2b 锁定的 SID，或 `02-sid` 里 `|change|` Top3）。填完仍为空时，本波照样开始，只是不发下面点名的三条。

下列文件互不依赖。按优先级每批 5 条，直到发完：

1. `14-sid-client-validation.sql`：只对占 `|ΔBKS| ≥ 10%` 的 SID，每家一条。没有这样的 SID 就跳过，并写「无 SID≥10%，跳过」。这些验证 B 优先占用前面批次的名额，好让 W3 少等。
2. `sql/config-change-detection-lite/checklist/01-cs.sql` 到 `14-configuration.sql`，共 14 个文件，含结果为 0 的也要发。
3. 其余各一条：`02-client-before-after-bks.sql`、`sql/online-hours-lite/03-window-avg.sql`、`sql/rate-limit-lite/01-ss-supplier-window.sql`、`sql/search-attribution-lite/01-ss-supplier.sql`。

`{sid_list}` 仍空时，从本波拿掉 SH（`checklist/08-sh.sql`）、`01-ss-supplier`、限流那一条。其余 checklist 照发。

W2 不包含 2c 路径文件，也不包含任何 detail。

### W3 2b 方向已经写出

只跑该方向的文件，每批最多 5 条。`02-sid` 不重复跑。

| 方向 | 文件 |
|---|---|
| C/Dida | `04-country.sql`、`06-chain.sql`、`08-lt.sql`、`10-los.sql`、`12-nationality.sql` |
| S/CS | `05-sid-country.sql`、`07-sid-chain.sql`、`03-sid-account.sql`、`09-sid-lt.sql`、`11-sid-los.sql`、`13-sid-nationality.sql` |

方向还没写出时不发本波。禁止两个方向一起投机跑。

验证 B 的跳过条件、写死 C/Dida 的双门、S/CS 的 Account 过滤，仍以 `responsibility-model.md` 和 Phase 2 现有文字为准。本波只改变这些文件的发送批次。

### W4 checklist 已返回

只跑过线的 detail，每批最多 5 条。过线条件保持现有表，不放宽：

- 一般 level：`event_count > 0` 才跑配对 detail。
- SH：`event_count ≥ 10` 才跑 `detail/08-sh-hotel-bks-lite.sql`；`<10` 不跑；`>50000` 或 MCP 500 走现有 BI 兜底。
- CDH / LCDH：`event_count > 0` 才跑 `detail/07-cdh-hotel-bks-lite.sql` / `detail/09-lcdh-hotel-bks-lite.sql`。

`event_count = 0` 的 level 不发 detail。S Bottom 只用 `detail/13-s-bottom-detail.sql`，禁止抄 C Bottom。

### 其余查询

3b 里除 `01-ss-supplier` 以外的下钻、3c、3d、准确率 issue、在线时长的 500 兜底脚本，仍按现有触发条件决定发不发。同一时刻有多条、且谁也不用谁的结果时，同样每批最多 5 条，每条一个文件。触发条件没满足的不发。

## 改哪些文件

| 文件 | 改动 |
|---|---|
| `SKILL.md` | 在 Phase 2–4 附近增加上面五条硬规则，并链接到 Phase 2 的「查数波次」。Phase 1 串行清单保持原样。 |
| `phases/02-dimension-drilldown.md` | 新增「查数波次」总表（W0–W4）。执行清单里的「必跑」改成「按波次发」，文件集合不减。 |
| `phases/03-evidence-verification.md` | 把 checklist「逐条跑」改成「按 Phase 2 查数波次的 W2/W4」。保留一次调用一个文件、14/14、Read 原文、SH 必填 `{sid_list}`、500 重试这一条。 |
| `sql/dimension-contribution-lite/README.md` | Step 2 之后的文件改为指向 W2/W3，不再要求 2c 文件一条一条来。 |
| `sql/config-change-detection-lite/README.md` | Step 2 的「逐条 MCP」改为按 W2 分批，每批最多 5。打勾清单保留。 |

不改 SQL 文件，不改 `responsibility-model.md`，不改报告骨架。

## 验收

在本分支用一条已经对过的 C 路径案例试跑（默认 `examples/gold-agoda-20260320.md` 的 client 与日期：Agoda，2026-03-20）。若该日数据已不可用，改用用户指定的另一条已对过案例，并在试跑记录里写明替换原因。

比对下面四项。产量绝对值允许因数仓回补变化。

1. 发出的查询集合覆盖 W0–W4 里触发条件已满足的文件。缺文件必须标成「未验」，不能静默跳过。
2. checklist 进度仍是 14/14，或未验条目与 500 重试记录一致。
3. 进入 detail 的 level 集合与当次 `event_count` 过线规则一致。
4. 给定当次返回的数字，定责方向仍符合现有双门；后续动作编号仍来自 `docs/es-cause-catalog.md`。

查询集合与触发规则一致、只是定责方向因为产量数字变了而不同：记为数据漂移，不算波次失败。

出现下面任一条，算失败，本分支不合并：

- 一次 `execute_sql` 里有多于一个 lite 文件，或出现 UNION 拼接。
- `{sid_list}` 为空仍发了 SH、查价或限流。
- 500 或 0 行被写成业务 0，或同批成功结果被丢弃。
- 2b 方向未写出就发了 W3，或两个方向的 2c 文件一起发。
- `event_count` 未过线却发了 detail，或 S Bottom 抄了 C Bottom。

试跑由人看报告和当次工具调用。本设计不新增自动计时脚本。

## 实现顺序

1. 先改 `SKILL.md` 硬规则和 Phase 2 总表，让入口和总表一致。
2. 再改 Phase 3 和两份 lite README，删掉互相矛盾的「逐条」。
3. 跑 `python scripts/check-first-day.py` 和 `python scripts/check-report-skeleton.py --skeleton`。基线 `a94c945` 上这两条是通过的。`examples/gold-agoda-20260320.md` 在基线上已经过不了骨架检查，不把它当作本改动的通过条件。
4. 再按「验收」做一次人工试跑。试跑失败则停在本分支，不合并。
