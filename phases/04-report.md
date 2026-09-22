# Phase 4：报告收口

> 状态：✅ 可执行模板（2026-08-14）。**仅当已进入 Phase 2–3**（归因型门禁是，或完整型/gold）后合成。探查型或归因型门禁否停在 Phase 1，**不要**套本模板出空报告。  
> 金样例：[examples/gold-agoda-20260320.md](../examples/gold-agoda-20260320.md)（跌产/C/Dida）、[examples/gold-snaptravel2b-20260801.md](../examples/gold-snaptravel2b-20260801.md)（涨产/S 主因）、[examples/gold-hbgpkg-20260706.md](../examples/gold-hbgpkg-20260706.md)（正常波动/CS）、[examples/gold-hbgpkg-20260710.md](../examples/gold-hbgpkg-20260710.md)（CS 崩量）

## 目标

1. 合成 **Phase 1→3d** 完整归因报告（统一结构，可回归 diff）
2. 区分 **已确认 / 倾向 / 待验证 / 数据无法解释**
3. 对数据说不清的部分，给出 **后续动作**：查 [es-cause-catalog.md](../docs/es-cause-catalog.md)，写可能原因（非猜测、非已确认）

## 骨架锁定（#27）

成品 = 复制 [04-report-skeleton.md](04-report-skeleton.md) 后 **只填空**。验收：`python scripts/check-report-skeleton.py [报告.md]`。

报告必须长这样：

1. **H2 八节**与骨架逐字、同序。路径/✅/日期写进正文，不写进 H2。阶段名是 **报告收口**；报告里的跟进节叫 **后续动作**。**成品不要附录。**
2. **必填 H3**与骨架相同。只有两处可替换：`### 2b 定责 → **{结论}**`、`### 3a 配置（checklist **{N}/14** {✅/⚠️}，窗口 {w}）`。`### 2c 下钻` 无后缀。**2b=C/Dida 填 4_/6_ 单维；2b=S/CS 填 5_/7_/03 复合维**，只留一条路径。
3. **Executive Summary：** 先写 **业务导语 3～5 句**（[es-writing.md](../docs/es-writing.md)），再写 **六键**逐字、同序：`异动` / `结构` / `主因` / `并列` / `已排除` / `后续动作`。六键正文用人话，内部代号放括号。机构查价 `|WoW|>10%` 必须进导语或并列。后续动作末尾仍须目录编号。
4. **表头逐字**。3a = **7 列 14 行**（`#` / `Level` / `n` / `操作(枚举)` / `作用域` / `Δmargin / remark` / `信号`），**不写**来源 lite 文件。§4 责任修正四行 = `Phase 2b 初判` / `修正后主因` / `并列` / `非主因（已排除）`。证据对照表七行不变。
5. **在线时长、准确率先探测再按触发填。** 在线：必填 PPS/QPS WoW 与是否触发；\|WoW\|>10% 才填日均/异动≥1.5h。准确率：每案 `01-total`；\|Δpp\|≥5 才填「启动后下钻」，未启动行内 —。
6. 单元格和数据行可填可增；**标题和表头不可改**。MCP 500 写在对应节解读。SQL 原文仍须 Read 后执行，但路径不进成品报告。
7. 文末 **联系人：郑乾皓（Lumino）** 原样保留。不改名、不删、不另起 H2。

## Agent 执行清单

```
报告收口进度:
- [ ] 1. 确认 Phase 1–3 门禁已满足（见下「合成门禁」）
- [ ] 2. 复制 04-report-skeleton.md，只填空；填完跑 scripts/check-report-skeleton.py
- [ ] 3. 3d 综合判断：对照 evidence-synthesis-rules.md 输出置信度
- [ ] 3b. **3a 表为 7 列 14 行**（操作枚举+作用域，不写 SQL 路径）；**出门禁**写在 §4（通过 / 不通过+哪条）
- [ ] 4. 根因结论：主因 1 条写清楚 + 并列因素 + 非主因（已排除）
- [ ] 5. ES：Read [docs/es-writing.md](../docs/es-writing.md) 写导语+人话六键；Read [docs/es-cause-catalog.md](../docs/es-cause-catalog.md)，后续动作先问人、末尾 `目录 **B2**`（1–2 条）。D 组兑现 → 对内
- [ ] 6. （可选）写入 examples/ 作金样例
```

### 合成门禁（不满足则降级措辞）

| 门禁 | 要求 | 不满足时的最高置信度 |
|------|------|---------------------|
| **3a** | checklist **14/14** | 配置相关：**「部分未验」**，禁止「已排除 Dida」 |
| **2c** | C/Dida：**5/5**（04+06+08+10+12）；S/CS：country+chain+lt+los+nat | 2c 最高 **「部分下钻」**；禁止写完整结构小结 |
| **3b 机构级** | 2b=C/Dida **或涨产待区分** → `00-client-total` 或 **`00a`+`00b` funnel 分两查** + precheck 合并 | B 线机构结论最高 **「倾向」** |
| **3b SS** | Top supplier 结构补充 | SS **不能替代**机构级 |
| **3c** | 每案 `01-total`；\|Δpp\|≥5 才维+issue | 未过 5pp 写「已探测、未启动」；禁止用验价量代替 |
| **3d D** | 2c Top country 有结构 + 触发条件见 external-events-mapping | D **并列背景**，禁止与 client 交叉定责 |
| **限流** | **结构 SID 必出数**（锁定或占 \|ΔBKS\|≥10%）；SS \|WoW\|>10% 只定解读档 | 未过 10% 仍出表作排除；涨产/请求↓产量↑：仅报数 |
| **在线时长** | DidaBiz QPS/PPS \|WoW\|>10% → 必查；异动：日均少 ≥1.5h | 只解释查价↓；产量看转化；数据库分析不得强定责 C 下线 |

---

## 成品从哪复制

**只复制** [04-report-skeleton.md](04-report-skeleton.md)，填空后跑 `python scripts/check-report-skeleton.py [报告.md]`。

禁止从本文再抄一份报告。gold / case 的 3a 表头可能是旧列，**成品以 skeleton 的 7 列为准**。

---

## 置信度定义（写入报告时统一用词）

| 等级 | 含义 | 何时使用 |
|------|------|---------|
| **已确认** | A 强配置 + B 同向 + 同维 BKS 显著 | 3a=14/14 + 机构级 B 完整 |
| **倾向** | 2–3 条证据同向，缺一项或缺后续动作 | **默认最高档**（多数案例） |
| **待验证** | 单线弱信号 | 3a 未满 14/14、缺机构级 B |
| **已排除** | 证据明确不支持该假设 | 如 SS限流率↓但产量↑ |
| **后续动作** | 内部数据均无法解释主因 | 必须列具体问题 |

---

## 外部跟进方法论

当 A/B/C/D **均无法解释**异动主因，或漏斗/结构需要对渠道提问时：查 [es-cause-catalog.md](../docs/es-cause-catalog.md)。

### 不应做

- 编造根因或把猜测写成「已确认」
- 用 D 线全局事件证明某 client 独有涨幅
- D 组（加价/关房/L2L）已兑现时再套 B2 去问渠道
- 把查价总量、有价率、查验比混成一句话

### 应做

1. Read `docs/es-writing.md`，先写业务导语和人话六键（禁止导语堆内部代号）
2. Read `docs/es-cause-catalog.md`，再写 ES「后续动作」：先问谁、问什么，末尾 `目录 **B2**（现象）→ 可能原因；禁止写成已确认`
3. `目录` + 编号，一案 1–2 条；3a 无对应配置才问渠道；节日（E1）只辅助
4. 机构查价 `|WoW|>10%` 必须出现在导语或并列，禁止为了好读删掉

---

## 涨产 vs 跌产：报告措辞差异

| 模块 | 跌产 | 涨产 |
|------|------|------|
| **2b** | 双门：≥10% 必跑 B；写死 C/Dida 须家数≥70% 且无单 SID≥50% | 同一套门；Top S 多 client 同涨 → **S**；本 client 增量最大 → **C 放大并列** |
| **3b** | 有价率↓→关房/限流；查验比↓→价劣 | **查价↓+验价↑+产量↑** → 转化跳升；禁止写「多查多产」 |
| **3d 主因** | 配置关房 / 限流 / C 需求收缩 | **S 平台共涨** 或 **C 放量**（需机构级 B + 后续动作） |
| **后续动作** | 按目录：B2 问渠道加价等看不见的操作 | 按目录：A4 拆查少原因 + 价优；C3 问为什么吃最多 |

---

## 相关文档

- 空壳对照：[04-report-skeleton.md](04-report-skeleton.md)
- 骨架验收：`scripts/check-report-skeleton.py`
- 合成规则：[docs/evidence-synthesis-rules.md](../docs/evidence-synthesis-rules.md)
- 外部事件 D：[docs/external-events-mapping.md](../docs/external-events-mapping.md)
- Phase 3 SOP：[phases/03-evidence-verification.md](03-evidence-verification.md)
- ES 人话：[docs/es-writing.md](../docs/es-writing.md)
- 数据现象目录（#5）：[docs/es-cause-catalog.md](../docs/es-cause-catalog.md)
