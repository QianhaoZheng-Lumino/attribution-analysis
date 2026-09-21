#!/usr/bin/env python3
"""Phase 4（报告收口）skeleton checker (#27).

Compare a filled attribution report against the locked H2 / H3 / table-header
contract in phases/04-report.md. Filling cells is allowed; renaming or adding
sections is not.

Exit 0 if all files pass. Exit 1 if any fail.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

H2_LOCKED = [
    "Executive Summary",
    "0. 分析参数",
    "1. Phase 1：异动识别",
    "2. Phase 2：定责与下钻",
    "3. Phase 3：内部证据",
    "4. Phase 3d：综合判断",
    "5. 根因结论",
    "6. 后续动作",
]

# Exact H3 except 2b/3a slots. Trailing metadata in the title is a fail.
H3_REQUIRED = [
    (r"^### 2b 定责 → \*\*.+\*\*$", "### 2b 定责 → **{C/Dida | S | CS | …}**"),
    (r"^### 2c 下钻$", "### 2c 下钻"),
    (
        r"^### 3a 配置（checklist \*\*\d+/14\*\* (?:✅|⚠️)，窗口 .+\）$",
        "### 3a 配置（checklist **{N}/14** {✅/⚠️}，窗口 {w}）",
    ),
    (r"^### 3b 查价（B 线）$", "### 3b 查价（B 线）"),
    (r"^### 3c 准确率$", "### 3c 准确率"),
    (r"^### 3d 外部事件 D 线$", "### 3d 外部事件 D 线"),
    (r"^### 责任修正（相对 2b 初判）$", "### 责任修正（相对 2b 初判）"),
    (r"^### 证据对照表$", "### 证据对照表"),
    (r"^### 一句话结论$", "### 一句话结论"),
    (r"^### 已确认$", "### 已确认"),
    (r"^### 倾向（待后续动作或更多证据）$", "### 倾向（待后续动作或更多证据）"),
    (
        r"^### 数据无法解释 → 后续动作$",
        "### 数据无法解释 → 后续动作",
    ),
]

ES_KEYS = ["异动", "结构", "主因", "并列", "已排除", "后续动作"]

CORR_ROWS = ["Phase 2b 初判", "修正后主因", "并列", "非主因（已排除）"]

EVIDENCE_ROWS = [
    "A 配置",
    "B 机构",
    "B SS",
    "限流",
    "在线时长",
    "D 外部",
    "C 准确率",
]

TABLE_HEADERS = {
    "0. 分析参数": ["项", "值"],
    "1. Phase 1：异动识别": ["指标", "数值"],
    "2b 定责": ["验证", "结果"],
    "3a 配置": [
        "#",
        "Level",
        "n",
        "操作(枚举)",
        "作用域",
        "Δmargin / remark",
        "信号",
    ],
    "机构级": ["指标", "对比期 → 当前期", "WoW"],
    "限流/缓存": [
        "SID",
        "出数原因",
        "requests",
        "SS限流率 WoW",
        "缓存命中率 WoW",
        "SS通过率 WoW",
        "命中只吐缓存率 WoW",
        "解读",
    ],
    "在线时长": ["项", "值"],
    "3c 准确率": ["项", "值"],
    "责任修正": ["项", "结论", "置信度"],
    "证据对照表": ["线", "关键发现", "与 BKS 同向？", "强度"],
    "已确认": ["根因/结构", "责任方", "证据", "影响估算"],
    "倾向": ["假设", "责任方", "支撑证据", "缺什么"],
    "数据无法解释": ["现象", "可能方向", "建议运营动作"],
    "后续动作": ["优先级", "动作", "负责方", "预期效果"],
    "启动后下钻": ["维", "Δpp", "与 2c 同维？"],
}

PARAM_ROWS = [
    "client_id",
    "parent_client_id",
    "analysis_date",
    "当前期",
    "对比期",
    "指标",
    "大盘对照",
]

P1_ROWS = [
    "当前期 / 对比期总量",
    "日均",
    "WoW",
    "vs 历史 42 天均值",
    "Z-score",
    "below/above_normal_range",
    "综合评分",
    "异动等级",
    "need_attribution",
]

ONLINE_ROWS = [
    "探测 DidaBiz PPS/QPS WoW",
    "是否触发",
    "异动（日均少 ≥1.5h）",
]

ACC_ROWS = [
    "探测 `01-total`",
    "是否启动",
]


def norm_cells(line: str) -> list[str]:
    raw = line.strip()
    if not raw.startswith("|"):
        return []
    parts = [p.strip() for p in raw.strip("|").split("|")]
    return [re.sub(r"\s+", " ", p) for p in parts]


def is_sep(line: str) -> bool:
    cells = norm_cells(line)
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", c or "") for c in cells)


def headings(text: str, level: int) -> list[tuple[int, str]]:
    prefix = "#" * level + " "
    out = []
    for i, line in enumerate(text.splitlines(), 1):
        s = line.strip()
        if s.startswith(prefix) and not s.startswith("#" * (level + 1) + " "):
            out.append((i, s[len(prefix) :].strip()))
    return out


def h3_lines(text: str) -> list[str]:
    out = []
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("### ") and not s.startswith("#### "):
            out.append(s)
    return out


def section_after(text: str, heading: str) -> str:
    """Text from a heading (## or ###) until the next same-or-higher heading."""
    lines = text.splitlines()
    start = None
    start_level = None
    for i, line in enumerate(lines):
        s = line.strip()
        if s == heading or s.startswith(heading + " ") or s == heading.rstrip():
            start = i
            start_level = len(s) - len(s.lstrip("#"))
            break
        # allow heading with filled 2b/3a slot: match by prefix token
    if start is None:
        # prefix match on first tokens
        key = heading.split("（")[0].split("→")[0].strip()
        for i, line in enumerate(lines):
            s = line.strip()
            if s.startswith(key) and s.startswith("#"):
                start = i
                start_level = len(s) - len(s.lstrip("#"))
                break
    if start is None:
        return ""
    chunk = []
    for line in lines[start + 1 :]:
        s = line.strip()
        if s.startswith("#"):
            lvl = len(s) - len(s.lstrip("#"))
            if lvl <= start_level:
                break
        chunk.append(line)
    return "\n".join(chunk)


def first_table(section: str) -> tuple[list[str], list[list[str]]]:
    lines = section.splitlines()
    header = None
    rows: list[list[str]] = []
    i = 0
    while i < len(lines):
        cells = norm_cells(lines[i])
        if cells and i + 1 < len(lines) and is_sep(lines[i + 1]):
            header = cells
            i += 2
            while i < len(lines):
                r = norm_cells(lines[i])
                if not r:
                    break
                if is_sep(lines[i]):
                    i += 1
                    continue
                rows.append(r)
                i += 1
            break
        i += 1
    return header or [], rows


def find_heading_line(text: str, contains: str, level: int | None = None) -> str | None:
    for line in text.splitlines():
        s = line.strip()
        if contains in s and s.startswith("#"):
            if level is None or s.startswith("#" * level + " ") and not s.startswith(
                "#" * (level + 1) + " "
            ):
                return s
    return None


def col0(rows: list[list[str]]) -> list[str]:
    return [r[0] for r in rows if r]


def strip_md(s: str) -> str:
    s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)
    s = re.sub(r"`([^`]+)`", r"\1", s)
    return s.strip()


def check_file(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    errs: list[str] = []

    # H2 sequence (ignore H1)
    h2 = [t for _, t in headings(text, 2)]
    if h2 != H2_LOCKED:
        errs.append(f"H2 与骨架不一致\n    期望: {H2_LOCKED}\n    实际: {h2}")

    # H3 required present; extras fail（成品无附录 / 无 lite 审计节）
    actual_h3 = h3_lines(text)
    used = [False] * len(actual_h3)
    for rx, label in H3_REQUIRED:
        found = False
        for i, line in enumerate(actual_h3):
            if re.fullmatch(rx, line):
                used[i] = True
                found = True
                break
        if not found:
            errs.append(f"缺 H3：{label}")
            # hint closest
            needle = label.split("（")[0].replace("#", "").strip()
            close = [x for x in actual_h3 if needle[:8] in x]
            if close:
                errs.append(f"    接近: {close[0]}")

    extra = [actual_h3[i] for i, u in enumerate(used) if not u]
    if extra:
        errs.append("多余 H3（禁止自拟章节名）: " + " | ".join(extra))

    # Executive Summary 六键，键名逐字，顺序不乱
    es = section_after(text, "## Executive Summary")
    es_keys_found: list[str] = []
    for line in es.splitlines():
        m = re.match(r"^-\s+\*\*(.+?)：\*\*", line.strip())
        if m:
            es_keys_found.append(m.group(1))
    if es_keys_found[: len(ES_KEYS)] != ES_KEYS:
        errs.append(
            f"ES 六键须逐字且按序 {ES_KEYS}，实际 {es_keys_found}"
        )
    extra_es = es_keys_found[len(ES_KEYS) :]
    if extra_es:
                errs.append(f"ES 多余键（禁止改成「并列 S」「后续动作 P0」等）: {extra_es}")

    # #5：ES 后续动作须目录编号；skeleton 占位符豁免
    es_follow = ""
    for line in es.splitlines():
        m = re.match(r"^-\s+\*\*后续动作：\*\*\s*(.*)$", line.strip())
        if m:
            es_follow = m.group(1).strip()
            break
    if not es_follow:
        errs.append("ES 缺「后续动作」内容")
    elif re.search(r"\{A#", es_follow):
        pass
    elif not re.search(
        r"目录\s+\*?\*?(?:A[1-7]|B[1-4]|C[1-3]|D[1-5]|E1)\*?\*?",
        es_follow,
    ):
        errs.append(
            "ES 后续动作须含「目录」+ 编号（A1–A7 / B1–B4 / C1–C3 / D1–D5 / E1）；"
            "先 Read docs/es-cause-catalog.md"
        )

    # Table headers + required row labels
    def expect_header(section_heading: str, key: str) -> list[list[str]]:
        sec = section_after(text, section_heading)
        header, rows = first_table(sec)
        want = TABLE_HEADERS[key]
        if header != want:
            errs.append(f"表头 [{key}] 期望 {want}，实际 {header}")
        return rows

    rows0 = expect_header("## 0. 分析参数", "0. 分析参数")
    got0 = [strip_md(x) for x in col0(rows0)]
    for req in PARAM_ROWS:
        if req not in got0:
            errs.append(f"分析参数缺行：{req}")

    rows1 = expect_header("## 1. Phase 1：异动识别", "1. Phase 1：异动识别")
    got1 = [strip_md(x) for x in col0(rows1)]
    for req in P1_ROWS:
        if req not in got1:
            errs.append(f"Phase 1 缺行：{req}")

    h2b = find_heading_line(text, "### 2b 定责", 3) or "### 2b 定责"
    expect_header(h2b, "2b 定责")

    # Top supplier 贡献% 表：在 2b 节内找第二张表
    sec2b = section_after(text, h2b)
    tables = []
    lines = sec2b.splitlines()
    i = 0
    while i < len(lines):
        cells = norm_cells(lines[i])
        if cells and i + 1 < len(lines) and is_sep(lines[i + 1]):
            tables.append(cells)
            i += 2
            while i < len(lines) and norm_cells(lines[i]):
                i += 1
            continue
        i += 1
    if len(tables) >= 2:
        want_sid = ["Supplier", "prev → cur", "change", "贡献%"]
        if tables[1] != want_sid:
            errs.append(f"表头 [Top supplier] 期望 {want_sid}，实际 {tables[1]}")

    h3a = find_heading_line(text, "### 3a 配置", 3) or "### 3a 配置"
    rows3a = expect_header(h3a, "3a 配置")
    if len(rows3a) != 14:
        errs.append(f"3a 表须 14 行，实际 {len(rows3a)}")

    h_org = find_heading_line(text, "#### 机构级", 4)
    if not h_org:
        errs.append("缺 H4：#### 机构级（必跑：2b=C/Dida 或涨产待区分）")
    else:
        expect_header(h_org, "机构级")

    if not find_heading_line(text, "#### SS 层 Top supplier", 4):
        errs.append("缺 H4：#### SS 层 Top supplier（结构补充，不替代机构级）")

    h_rl = find_heading_line(text, "#### 限流/缓存", 4)
    if not h_rl:
        errs.append("缺 H4：#### 限流/缓存（结构 SID 必出数；§5.10）")
    else:
        expect_header(h_rl, "限流/缓存")

    h_oh = find_heading_line(text, "#### 在线时长", 4)
    if not h_oh:
        errs.append("缺 H4：#### 在线时长（先探测 PPS/QPS）")
    else:
        rows_oh = expect_header(h_oh, "在线时长")
        got_oh = [strip_md(x) for x in col0(rows_oh)]
        for req in ONLINE_ROWS:
            if strip_md(req) not in got_oh:
                errs.append(f"在线时长缺行：{req}")

    rows3c = expect_header("### 3c 准确率", "3c 准确率")
    got3c = [strip_md(x) for x in col0(rows3c)]
    for req in ACC_ROWS:
        if strip_md(req) not in got3c:
            errs.append(f"3c 缺行：{req}")

    h_acc = find_heading_line(text, "#### 启动后下钻", 4)
    if not h_acc:
        errs.append("缺 H4：#### 启动后下钻（|Δpp|≥5 才填数；未启动行内 —）")
    else:
        expect_header(h_acc, "启动后下钻")

    rows_corr = expect_header("### 责任修正（相对 2b 初判）", "责任修正")
    got_corr = [strip_md(x) for x in col0(rows_corr)]
    if got_corr != CORR_ROWS:
        errs.append(f"责任修正四行须 {CORR_ROWS}，实际 {got_corr}")

    rows_ev = expect_header("### 证据对照表", "证据对照表")
    got_ev = [strip_md(x) for x in col0(rows_ev)]
    for req in EVIDENCE_ROWS:
        if req not in got_ev:
            errs.append(f"证据对照表缺行：{req}")

    expect_header("### 已确认", "已确认")
    expect_header("### 倾向（待后续动作或更多证据）", "倾向")
    expect_header("### 数据无法解释 → 后续动作", "数据无法解释")
    expect_header("## 6. 后续动作", "后续动作")

    # 2c：C/Dida 单维或 S/CS 复合维，标题都叫 主结构 · Country/Chain
    if not find_heading_line(text, "#### 主结构 · Country", 4):
        errs.append("缺 H4：#### 主结构 · Country（4_Country 或 5_SID+Country）")
    if not find_heading_line(text, "#### 主结构 · Chain", 4):
        errs.append("缺 H4：#### 主结构 · Chain（6_Chain 或 7_SID+Chain）")
    if not find_heading_line(text, "#### 结构补充", 4):
        errs.append("缺 H4：#### 结构补充（描述性 · 段落）")

    return errs


def default_targets() -> list[Path]:
    return sorted((ROOT / "examples").glob("case-*.md"))


def main() -> int:
    ap = argparse.ArgumentParser(description="Check Phase 4（报告收口）skeleton (#27)")
    ap.add_argument("files", nargs="*", type=Path, help="Markdown reports to check")
    ap.add_argument(
        "--skeleton",
        action="store_true",
        help="Check phases/04-report-skeleton.md (alone if no files given)",
    )
    args = ap.parse_args()
    files = list(args.files)
    if args.skeleton or not files:
        if args.skeleton and not files:
            files = [ROOT / "phases" / "04-report-skeleton.md"]
        elif not files:
            files = default_targets()
            if args.skeleton:
                files.append(ROOT / "phases" / "04-report-skeleton.md")

    failed = 0
    for f in files:
        path = f if f.is_absolute() else ROOT / f
        if not path.exists():
            print(f"FAIL {path}: file not found")
            failed += 1
            continue
        errs = check_file(path)
        rel = path.relative_to(ROOT) if ROOT in path.parents or path.parent == ROOT else path
        if errs:
            failed += 1
            print(f"FAIL {rel}")
            for e in errs:
                print(f"  - {e}")
        else:
            print(f"PASS {rel}")
    if failed:
        print(f"\n{failed}/{len(files)} failed")
        return 1
    print(f"\n{len(files)} passed")
    return 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8")
        except Exception:
            pass
    sys.exit(main())
