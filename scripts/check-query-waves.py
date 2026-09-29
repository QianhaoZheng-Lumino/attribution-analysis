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
    matrix = read("docs/mcp-permission-matrix.md")
    if "逐个 MCP" in matrix or "逐个跑" in matrix:
        errs.append("docs/mcp-permission-matrix.md 仍要求逐个发送 checklist")
    if "查数波次" not in matrix:
        errs.append("docs/mcp-permission-matrix.md 未指向查数波次")
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
