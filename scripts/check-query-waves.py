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
