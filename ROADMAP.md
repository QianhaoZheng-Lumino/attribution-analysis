# 归因分析 Skill 路线图

## 总体架构（业务版）

```
用户提问
  │
  ▼
Phase 1 异动识别（lite 三步）──→ 无异动 → 结束
  │ need_attribution = 是
  ▼
Phase 2a  维度贡献（MCP lite 分批 / BI 全量 1 次）
Phase 2b  C×S 定责
Phase 2c  自动下钻（BI 只过滤；MCP 按路径再跑 lite）
  │
  ▼
Phase 3  内部证据（配置/查价/验价 + 外部事件库待接）
  │
  ▼
Phase 4  报告收口（合成 1→3d；数据说不清 → 查 es-cause-catalog）
```

## 各阶段状态

| 阶段 | 状态 | 文件 | 核心能力 |
|------|------|------|---------|
| Phase 1 异动识别 | ✅ P0 | phases/01-anomaly-detection.md + sql/anomaly-detection-lite/ | lite 三步 + Agent 评分 |
| Phase 2a 维度贡献 | ✅ lite | sql/dimension-contribution-lite/ + sql/dimension-contribution.sql | MCP 分批 / BI 全量 |
| Phase 2b C×S 定责 | ✅ | cross-validation-b.sql + 2_SID | 仅供应轴交叉 |
| Phase 2c 自动下钻 | ✅ SOP | phases/02c-drilldown.md | BI 0 额外 SQL；MCP 必跑路径 lite |
| Phase 3a 配置 | ✅ lite | config-change-detection-lite/checklist/ | 14 类分批 |
| Phase 3b 查价 | ✅ lite | search-attribution-lite/ | 有价率+查验比 |
| Phase 3c 准确率 | ✅ lite | rate-accuracy-contribution-lite/ | 与配置分离 |
| Phase 3d 综合判断 | ✅ | docs/evidence-synthesis-rules.md | A×B×C 合成 |
| Phase 4 报告收口 | ✅ | phases/04-report.md | 可执行模板 + gold 样例 |

## 支撑文档

| 文件 | 内容 |
|------|------|
| methodology.md | Phase 1 判定 + MCP lite 路径 |
| responsibility-model.md | C/Dida/S/CS + 交叉验证决策树 |
| tables.md | 数据表清单 |
| sql/anomaly-detection.sql | Phase 1 完整版（非 MCP） |
| sql/anomaly-detection-lite/ | Phase 1 MCP 稳定版 |
| sql/dimension-contribution.sql | Phase 2a |
| sql/cross-validation-b.sql | Supplier 轴验证 B |

## 里程碑（已完成 · 勿当待办）

- Phase 1 lite、2a' 多维扫描 SOP（2026-07-28 P0）
- 外部事件 lite、Agoda gold（跌产/C/Dida）
- MCP 权限矩阵、在线时长开窗 SQL（#1/#20，Python 仅 fallback）、限流 lite + 出数规则（#2/#18）
- 涨产 2b + 3b 机构级必跑、报告收口模板 + gold

**未完成项只看 [docs/backlog.md](docs/backlog.md)。** 禁止在本文件再开 checkbox / #N 表（#21）。新想法追加 backlog「扩展项」。

## 已定方案（2026-07-28）

- 先 C×S 定责，再自动下钻；不全维度宽交叉
- C/Dida 下钻共用 Client 侧重维度
- Account 贡献 ≥10% 才报告
- 外部事件库 Phase 3 与配置一起

## 迭代记录

| 日期 | 变更 |
|------|------|
| 2026-07-28 | 初版 + 异动/贡献度 SQL 蒸馏 |
| 2026-07-28 | 交叉验证 B + C/Dida/S/CS 模型 |
| 2026-07-28 | **定稿**：先定责(C×S) → 自动下钻；取消全维度宽交叉 |
| 2026-08-14 | Agoda gold：`examples/gold-agoda-20260320.md`（跌产/C/Dida + 14/14 + D TH） |
| 2026-08-18 | **D 线仅 HOLIDAY**（Top30 城）；FAIR/CONCERT 退出归因；`01-single-country-window.sql` 已更新 |
| 2026-09-04 | 创建 [docs/backlog.md](docs/backlog.md)；记录在线时长/限流/DidaBase/SH/Phase4解释/封装权限等 #1–#6 |
| 2026-09-04 | **#13** 2c 叙事：BI 全量 1 次 / MCP lite 必跑路径；禁止「MCP 0 额外 SQL」 |
| 2026-09-05 | **#21** 待办只留 backlog；本文与 decisions-summary §8 不再另列清单 |
