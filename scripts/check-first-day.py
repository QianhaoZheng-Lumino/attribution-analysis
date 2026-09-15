#!/usr/bin/env python3
"""First-day skill hygiene: install docs, GitHub links, MCP/SQL traps, ES/metadata rules.

Exit 0 if all checks pass. Exit 1 if any fail.
These are the colleague-install failures we actually hit.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Share-pack excludes (must not be linked from GitHub-facing docs).
PACK_EXCLUDE = [
    "docs/backlog.md",
    "docs/briefing/",
    "docs/superpowers/",
    "docs/mcp-config-tables-error-report.md",
    "docs/plan-26-config-operation-rating.md",
    "examples/hbgpkg-rerun-20260706.md",
    "examples/phase3-signal-test-agoda.md",
    "examples/phase3-fourteen-level-didaopaq-20260206.md",
]

GITHUB_FACING_MD = [
    "README.md",
    "SKILL.md",
    "examples.md",
    "ROADMAP.md",
    "tables.md",
    "phases/01-anomaly-detection.md",
    "phases/04-report.md",
    "sql/config-change-detection/README.md",
    "sql/anomaly-detection-lite/README.md",
    "sql/config-change-detection-lite/README.md",
]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def exists(rel: str) -> bool:
    return (ROOT / rel).exists()


def check() -> list[str]:
    errs: list[str] = []
    readme = read("README.md")
    skill = read("SKILL.md")
    tables = read("tables.md")
    lite = read("sql/anomaly-detection-lite/README.md")
    cfg = read("sql/config-change-detection/README.md")
    cfg_lite = read("sql/config-change-detection-lite/README.md")
    p1 = read("phases/01-anomaly-detection.md")
    sql02 = read("sql/anomaly-detection-lite/02-historical-baseline.sql")
    sql03 = read("sql/anomaly-detection-lite/03-daily-series.sql")
    examples = read("examples.md")

    # --- install (Windows / Cursor UI / existing dir) ---
    if "Program Files\\Git\\cmd\\git.exe" not in readme and "Program Files/Git/cmd/git.exe" not in readme:
        errs.append("README 缺 Windows Git 完整路径（git 常不在 PATH）")
    if "git pull" not in readme and "目录已存在" not in readme:
        errs.append("README 缺已存在目录 / git pull 重装说明")
    if "marketplace.json" not in readme and "From GitHub" not in readme:
        errs.append("README 缺 Cursor UI「From GitHub Repository」不可用的说明")
    if "不要把本仓库当普通项目打开" not in readme:
        errs.append("README 缺「不要当普通项目打开」")
    if "分享包排除" not in read(".gitignore"):
        errs.append(".gitignore 缺「分享包排除」")
    gitignore = read(".gitignore")
    for item in PACK_EXCLUDE:
        if item not in gitignore:
            errs.append(f".gitignore 分享包排除未列出 {item}")

    # --- metadata is not query ---
    if "不是查数" not in skill:
        errs.append("SKILL.md 未写 search_meta_data 不是查数")
    if "Phase 1–3 查明细的唯一入口" not in skill and "Phase 1-3 查明细的唯一入口" not in skill:
        errs.append("SKILL.md 未把 execute_sql 定为 Phase 1–3 唯一入口")
    if "元数据能搜到的" in tables and "search_meta_data` + `execute_sql" in tables:
        errs.append("tables.md 仍把 search_meta_data 当 SOP 查数入口")
    if "直接 `execute_sql`" not in tables and "直接 execute_sql" not in tables:
        errs.append("tables.md SOP 未要求直接 execute_sql")

    # --- ES follow-up ---
    if "es-cause-catalog.md" not in skill:
        errs.append("SKILL.md 未指向 es-cause-catalog.md")
    for gold in sorted((ROOT / "examples").glob("gold-*.md")):
        text = gold.read_text(encoding="utf-8")
        if re.search(r"^-\s+\*\*Phase 4 P0：\*\*", text, re.M):
            errs.append(f"{gold.name} 仍用 ES 键「Phase 4 P0」")
        if "目录 **" not in text and "es-cause-catalog" not in text:
            errs.append(f"{gold.name} ES 后续动作未引用目录编号")

    # --- fourteen-level trap ---
    union_sql = ROOT / "sql/config-change-detection-lite/03-fourteen-level-checklist.sql"
    if union_sql.exists():
        errs.append("应删除 03-fourteen-level-checklist.sql，不要留在仓里给 Agent 去跑")
    if re.search(r"必须先跑.*03-fourteen-level-checklist", cfg):
        errs.append("sql/config-change-detection/README.md 仍要求 MCP 先跑 fourteen-level-checklist")
    if "禁止" not in cfg_lite or "14 路" not in cfg_lite:
        errs.append("config-change-detection-lite/README.md 须禁止 14 路 UNION")

    # --- lite placeholders ---
    if re.search(r"替换[^\n]*\{hist_end\}", sql02) or re.search(
        r"channel_createdate[^\n]*\{hist_end\}", sql02
    ):
        errs.append("02-historical-baseline.sql 仍把 {hist_end} 当须替换占位符（应用 {analysis_date}）")
    if "{hist_end}" in lite and "02/03" not in lite and "02、03" not in lite:
        errs.append("anomaly-detection-lite/README.md 未说明 02/03 填 {analysis_date} 而非 {hist_end}")
    if "打乱" not in lite and "自行按" not in lite and "再按日期" not in lite:
        errs.append("anomaly-detection-lite/README.md 未说明 MCP 可能打乱 ORDER BY，须本地排序")

    # --- 本周 ---
    if "本周一" not in p1 and "本周一" not in skill:
        errs.append("SKILL.md / phases/01 未定义「本周」= 本周一～昨天（不是默认 7 天前）")

    # --- GitHub-facing broken links to pack-excludes ---
    link_re = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
    exclude_needles = [
        "docs/backlog.md",
        "hbgpkg-rerun-20260706.md",
        "phase3-signal-test-agoda.md",
        "phase3-fourteen-level-didaopaq-20260206.md",
    ]
    for rel in GITHUB_FACING_MD:
        text = read(rel)
        for m in link_re.finditer(text):
            href = m.group(1).split("#")[0].split(" ")[0]
            if not href or href.startswith("http"):
                continue
            for needle in exclude_needles:
                if needle in href:
                    errs.append(f"{rel} 链到分享包排除文件 {href}（GitHub clone 不存在）")
        # SKILL.md 可用纯文本提到 backlog；禁止 markdown 链接（上面已查）

    # --- examples.md must not markdown-link missing files ---
    for m in link_re.finditer(examples):
        href = m.group(1).split("#")[0]
        if href.startswith("http"):
            continue
        # examples.md lives at repo root
        target = (ROOT / href).resolve()
        if href.startswith("examples/") or href.startswith("phases/") or href.startswith("docs/"):
            if not target.exists():
                errs.append(f"examples.md 坏链 {href}")

    return errs


def main() -> int:
    errs = check()
    if errs:
        print("FAIL scripts/check-first-day.py")
        for e in errs:
            print(f"  - {e}")
        print(f"\n{len(errs)} failed")
        return 1
    print("PASS scripts/check-first-day.py")
    print("\n1 passed")
    return 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8")
        except Exception:
            pass
    sys.exit(main())
