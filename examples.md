# 示例（意图，不是把 gold 当 SOP）

成品报告复制 [phases/04-report-skeleton.md](phases/04-report-skeleton.md) 只填空。gold / case 用来回归定责口径；其中 3a 表头可能是旧列，**不要抄表头**。

## 示例 1：探查（只 Phase 1）

**用户：**「最近产量是不是掉了？帮我看看」

**判定：** 探查型 → **只跑 Phase 1** → 问是否继续。禁止自动 2–4。禁止用「环比 >10%」代替三维评分。

## 示例 2：归因（须 client_id）

**用户：**「Agoda 为什么掉产？帮我归因」

**判定：** 归因型。先 Phase 1；门禁 **是** 且已有 `client_id`（或 parent 下锁定 focus）→ 自动 2–4。仍是大盘 → 列出异动，**问指定 client**，禁止自动 3a / 在线 / 限流。

## 示例 3：门禁否

**用户：**「看看本周有没有问题」

**判定：** 探查型，只 Phase 1。若 `need_attribution=否` → 结束；用户再说「完整归因 / 按 gold」才进 2–4。

## 示例 4：完整归因金样例

| 案例 | 类型 | 文件 | 要点 |
|------|------|------|------|
| **HBGPKG @ 2026-07-06** | 正常波动/CS | [examples/gold-hbgpkg-20260706.md](examples/gold-hbgpkg-20260706.md) | 门禁否；**完整型/gold 才跑 2–4** |
| **HBGPKG @ 2026-07-10** | 正常波动/CS 崩量 | [examples/gold-hbgpkg-20260710.md](examples/gold-hbgpkg-20260710.md) | 门禁否；2c=`5_SID+Country` |
| **Agoda @ 2026-03-20** | 跌产 | [examples/gold-agoda-20260320.md](examples/gold-agoda-20260320.md) | 门禁否；2b 双门写死 C/Dida（70.7% 且无 SID≥50%） |
| **SnapTravel2B @ 2026-08-01** | 涨产 | [examples/gold-snaptravel2b-20260801.md](examples/gold-snaptravel2b-20260801.md) | S 主因 + C 放大 |

旧稿不要当 SOP（分享包可排除）：

- [examples/hbgpkg-rerun-20260706.md](examples/hbgpkg-rerun-20260706.md)
- [examples/phase3-signal-test-agoda.md](examples/phase3-signal-test-agoda.md)
- [examples/phase3-fourteen-level-didaopaq-20260206.md](examples/phase3-fourteen-level-didaopaq-20260206.md)
