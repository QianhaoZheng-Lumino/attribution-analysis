# 查数波次试跑

- 案例：Agoda / 2026-03-20
- 分支：perf/query-waves
- 结论：通过

## 查询集合

- W0：01-period-totals，02-historical-baseline，03-daily-series（三轮，每轮 1 条，串行）
- W1：02-sid（单独一轮，1 条）
- W2：共 5 轮，每轮条数 5 / 5 / 5 / 5 / 2，合计 22 条
  - 第 1 轮（5 条）：14-sid-client-validation（116-EPS），14-sid-client-validation（131-Traveloka），14-sid-client-validation（1835-DCshareIND），checklist/01-cs，checklist/02-c
  - 第 2 轮（5 条）：checklist/03-s，checklist/04-csa，checklist/05-cbd，checklist/06-sbd，checklist/07-cdh
  - 第 3 轮（5 条）：checklist/08-sh（sid_list=116, 131, 1835），checklist/09-lcdh，checklist/10-l2l，checklist/11-cslrc，checklist/12-c-bottom
  - 第 4 轮（5 条）：checklist/13-s-bottom，checklist/14-configuration，02-client-before-after-bks（MCP 500），online-hours-lite/03-window-avg，rate-limit-lite/01-ss-supplier-window（成功，0 行）
  - 第 5 轮（2 条）：02-client-before-after-bks 同文重试（仍 MCP 500，标未验），search-attribution-lite/01-ss-supplier（成功，0 行）
- W3：方向 C/Dida（门 2：同降 29/41=70.7%，最大单 SID 29.6%<50%），1 轮 5 条：04-country，06-chain，08-lt，10-los，12-nationality
- W4：过线 level 为 CS（n=4）、S（n=12）、CSA（n=3）、S Bottom（n=1）；SH n=3<10 不发 detail；其余 level n=0 不发。第 1 轮 4 条：detail/01-cs-detail（MCP 500），detail/03-s-detail，detail/04-csa-detail，detail/13-s-bottom-detail；第 2 轮 1 条：detail/01-cs-detail 同文重试（仍 MCP 500，标未验）
- 其余查询（Phase 3 现有触发条件）：第 1 轮 4 条：search-attribution-lite/00-client-total，search-attribution-lite/02-didabiz-pps-country（0 行），search-attribution-lite/03-didabiz-pps-chain（0 行），rate-accuracy-contribution-lite/01-total（1 行但各项为空）；第 2 轮 3 条：external-events-lite/01-single-country-window（TH），同文件（MY），同文件（VN）；第 3 轮 3 条（复核补发）：search-attribution-lite/04-didabiz-qps-los（7 行；查价 1,348,204,882 → 1,349,707,743，基本持平；各档验价为 0，查验比未验），search-attribution-lite/05-didabiz-qps-leadtime（10 行；4~7 天 152,051,113 → 143,756,071，15~28 天 220,170,454 → 205,258,668，43~70 天 149,046,134 → 143,369,696，>70 天 267,462,907 → 277,178,335；验价为 0，查验比未验），search-attribution-lite/06-didabiz-qps-nationality（16 行；各国查价仅数千次量级，TH 1,081 → 999；验价为 0，查验比未验）
- 全程 execute_sql 共 46 次（首轮 43 次 + 复核补发 3 次），单轮最多 5 次；未探活（首条即成功，后续 500 都发生在同批已有成功结果的轮次）

## 四项比对

1. 触发条件已满足的文件都发出了，或标了未验：是（2c 的 LT / LOS / Nationality 对应的 04/05/06-didabiz-qps 在复核时补发，三条均返回行）
2. checklist 进度：14/14
3. detail 集合与 event_count 过线规则一致：是
4. 定责方向符合当次数字下的双门：C/Dida（门 1 过线 116 / 131 / 1835 各跑一次验证 B，均为平台多 client 同跌，S 成分并列不翻主因；门 2 同降 70.7%≥70% 且最大单 SID 29.6%<50%）。后续动作编号来自 es-cause-catalog：B2

## 失败条件

- 一次调用多个文件或 UNION：否
- 空 sid_list 仍发了 SH、查价或限流：否
- 500 或 0 行写成业务 0：否
- 方向未写出就发了 W3，或两个方向一起发：否
- 未过线却发了 detail，或 S Bottom 抄了 C Bottom：否

## 说明

- 产量数字与旧 gold 一致（2,739 → 2,287，−16.5%），定责方向也一致（C/Dida），没有数据漂移。
- 成品主因写成「倾向 C/Dida（宽口径，CS 明细与验价未验）」，比 gold 的「C」宽：CS 明细两次 MCP 500，验价表当日分区没有 3 月数据，出门禁只能部分通过。这是证据缺口，不是方向变化。
- 未验项：02-client-before-after-bks、detail/01-cs-detail（均为同文重试后仍 500）；01-ss-supplier、rate-limit 01-ss-supplier-window、02/03-didabiz 维度（查询成功 0 行，按「有表权限、当前过滤下 0 行」记）；3c 01-total（各项为空）。
- 首轮记录曾把调用总数写成 45，按实际列出的调用应为 43，已更正；复核补发 3 条后共 46。
- 首轮的部分语句删掉了文件头部的 `/* */` 说明行，SQL 正文是文件原文、只替换了占位符；复核补发的 04/05/06 三条保留了文件里的全部注释，只替换了占位符。
- 04/05/06 结果：Agoda 按入住晚数、提前期拆开的查价量都没有随产量同步下降（总量持平），提前 4~7 天的查价少了约 5.5%，远小于该档产量 −44%；三张表的验价字段都是 0，查验比未验。客源维查价量太小，不能用于解读。
- 成品报告：examples/case-agoda-20260320.md 与同名 HTML，check-report-skeleton.py 通过后渲染。
