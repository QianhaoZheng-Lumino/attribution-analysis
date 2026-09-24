#!/usr/bin/env python3
"""Render a checked Phase 4 markdown report into one self-contained HTML file.

Content (headings, table headers, cells, prose) is copied from the markdown.
This script does not recompute numbers and does not rename headers.
The HTML shell is layout only. Case files are not read.
"""

from __future__ import annotations

import argparse
import html
import importlib.util
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHECKER_PATH = Path(__file__).with_name("check-report-skeleton.py")

A3_HEADER = ["#", "Level", "n", "操作(枚举)", "作用域", "Δmargin / remark", "信号"]


def load_checker():
    spec = importlib.util.spec_from_file_location("check_report_skeleton", CHECKER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"无法加载 {CHECKER_PATH}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def unescape_pipes(text: str) -> str:
    return text.replace(r"\|", "|")


def inline(text: str) -> str:
    """Render the small markdown used in reports. Visible words stay the same."""
    s = html.escape(unescape_pipes(text))
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    return s


def visible(fragment: str) -> str:
    text = re.sub(r"<[^>]+>", "", fragment)
    text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def cell_class(text: str) -> str:
    s = text.strip()
    if re.match(r"^[−-]\d", s):
        return "down"
    if re.match(r"^\+\d", s):
        return "up"
    return ""


def parse_blocks(text: str) -> list[dict]:
    lines = text.splitlines()
    blocks: list[dict] = []
    i = 0
    while i < len(lines):
        raw = lines[i]
        s = raw.strip()
        if not s:
            i += 1
            continue
        if s.startswith("```"):
            buf = [s]
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                buf.append(lines[i])
                i += 1
            if i < len(lines):
                buf.append(lines[i].strip())
                i += 1
            blocks.append({"kind": "pre", "text": "\n".join(buf)})
            continue
        m = re.match(r"^(#{1,4})\s+(.*)$", s)
        if m:
            blocks.append({"kind": f"h{len(m.group(1))}", "text": m.group(2).strip()})
            i += 1
            continue
        if s.startswith("|") and i + 1 < len(lines) and _is_sep(lines[i + 1]):
            header = _cells(s)
            i += 2
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                if not _is_sep(lines[i]):
                    rows.append(_cells(lines[i]))
                i += 1
            blocks.append({"kind": "table", "header": header, "rows": rows})
            continue
        if s.startswith(">"):
            quote = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(re.sub(r"^>\s?", "", lines[i].strip()))
                i += 1
            blocks.append({"kind": "quote", "text": " ".join(quote)})
            continue
        if re.fullmatch(r"-{3,}", s):
            blocks.append({"kind": "hr"})
            i += 1
            continue
        if s.startswith("- "):
            items = []
            while i < len(lines) and lines[i].strip().startswith("- "):
                items.append(lines[i].strip()[2:].strip())
                i += 1
            blocks.append({"kind": "ul", "items": items})
            continue
        para = [s]
        i += 1
        while i < len(lines):
            nxt = lines[i].strip()
            if (
                not nxt
                or nxt.startswith("#")
                or nxt.startswith("|")
                or nxt.startswith(">")
                or nxt.startswith("- ")
                or nxt.startswith("```")
                or re.fullmatch(r"-{3,}", nxt)
            ):
                break
            para.append(nxt)
            i += 1
        blocks.append({"kind": "p", "text": " ".join(para)})
    return blocks


def _cells(line: str) -> list[str]:
    raw = line.strip()
    if raw.startswith("|"):
        raw = raw[1:]
    if raw.endswith("|"):
        raw = raw[:-1]
    parts = re.split(r"(?<!\\)\|", raw)
    return [re.sub(r"\s+", " ", unescape_pipes(p.strip())) for p in parts]


def _is_sep(line: str) -> bool:
    cells = _cells(line)
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", c or "") for c in cells)


def lookup_row(table: dict, label: str) -> str:
    for row in table["rows"]:
        if not row:
            continue
        if re.sub(r"\*+", "", row[0]).strip() == label and len(row) > 1:
            return row[1]
    return ""


def plain(text: str) -> str:
    s = unescape_pipes(text)
    s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)
    s = s.replace("`", "")
    return re.sub(r"\s+", " ", s).strip()


def first_table(blocks: list[dict], header: list[str]) -> dict | None:
    for block in blocks:
        if block["kind"] == "table" and block["header"] == header:
            return block
    return None


def phase1_table(blocks: list[dict]) -> dict | None:
    seen = False
    for block in blocks:
        if block["kind"] == "h2" and block["text"] == "1. Phase 1：异动识别":
            seen = True
            continue
        if seen and block["kind"] == "table":
            return block
        if seen and block["kind"] == "h2":
            return None
    return None


def paragraph_after(blocks: list[dict], heading: str) -> str:
    seen = False
    for block in blocks:
        if block["kind"] == "h3" and block["text"] == heading:
            seen = True
            continue
        if not seen:
            continue
        if block["kind"] == "p":
            return block["text"]
        if block["kind"] in ("h2", "h3"):
            return ""
    return ""


def window_phrase(current: str, previous: str) -> str:
    a = re.search(r"(\d{4})-(\d{2})-(\d{2})\s*[~～]\s*\d{4}-(\d{2})-(\d{2})", current)
    b = re.search(r"\d{4}-(\d{2})-(\d{2})\s*[~～]\s*\d{4}-(\d{2})-(\d{2})", previous)
    if not a or not b:
        return ""
    left = f"{a.group(1)}-{a.group(2)}-{a.group(3)} 至 {a.group(4)}-{a.group(5)}"
    right = f"{b.group(1)}-{b.group(2)} 至 {b.group(3)}-{b.group(4)}"
    return f"{left}，对照 {right}。"


def booking_pair(cell: str) -> str:
    """表内是当前 / 对比。页眉按对比 → 当前排，两个数原样搬。"""
    m = re.fullmatch(r"([0-9][0-9,]*(?:\.\d+)?)\s*/\s*([0-9][0-9,]*(?:\.\d+)?)", plain(cell))
    if not m:
        return plain(cell)
    return f"{m.group(2)} → {m.group(1)}"


def cause_short(cell: str) -> str:
    short = load_checker().main_cause_short(plain(cell))
    if not short:
        raise ValueError(
            "修正后主因不是「代号（短名）」或「代号（短名，细节）」，页眉主因无法生成"
        )
    return short


def build_mast(blocks: list[dict], h1: str, quote: str) -> tuple[str, str, str]:
    params = first_table(blocks, ["项", "值"])
    phase1 = phase1_table(blocks)
    verdict_table = first_table(blocks, ["项", "结论", "置信度"])
    client = plain(lookup_row(params, "client_id")) if params else ""
    analysis_date = plain(lookup_row(params, "analysis_date")) if params else ""
    metric = plain(lookup_row(params, "指标")) if params else ""
    metric = metric.replace("（默认）", "").strip()
    day = ""
    dated = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", analysis_date)
    if dated:
        day = f"{int(dated.group(2))} 月 {int(dated.group(3))} 日"
    title = f"{client} · {day}" if client and day else (visible(inline(h1)) or "归因分析报告")

    kind = ""
    found = re.search(r"类型：\s*([^\s·]+)", quote)
    if found:
        kind = found.group(1)
    elif phase1:
        wow = plain(lookup_row(phase1, "WoW"))
        if re.match(r"^[−-]\d", wow):
            kind = "跌产"
        elif re.match(r"^\+\d", wow):
            kind = "涨产"
    bits = []
    if kind:
        bits.append(f'<span class="pill">{html.escape(kind)}</span>')
    if metric:
        bits.append(f"<span>{html.escape(metric)}</span>")
    if client:
        bits.append(f"<span>client {html.escape(client)}</span>")
    kicker = f'<div class="kicker">{"".join(bits)}</div>' if bits else ""

    current = plain(lookup_row(params, "当前期")) if params else ""
    previous = plain(lookup_row(params, "对比期")) if params else ""
    sentence = plain(paragraph_after(blocks, "一句话结论"))
    cut = re.match(r".+?。", sentence)
    if cut:
        sentence = cut.group(0)
    subtitle = window_phrase(current, previous) + sentence
    if not subtitle:
        subtitle = quote
    sub_html = f'<p class="sub">{html.escape(subtitle)}</p>' if subtitle else ""

    total = plain(lookup_row(phase1, "当前期 / 对比期总量")) if phase1 else ""
    wow = plain(lookup_row(phase1, "WoW")) if phase1 else ""
    score = plain(lookup_row(phase1, "综合评分")) if phase1 else ""
    if verdict_table is None:
        raise ValueError("综合判断里没有责任修正表，页眉主因无法生成")
    cause = cause_short(lookup_row(verdict_table, "修正后主因"))

    bookings = booking_pair(total) if total else "—"
    if re.match(r"^[−-]\d", wow):
        wow_html = f"<em>{html.escape(wow)}</em>"
    elif re.match(r"^\+\d", wow):
        wow_html = f'<em class="up">{html.escape(wow)}</em>'
    else:
        wow_html = html.escape(wow or "—")
    scored = re.match(r"(\d+)\s*/\s*100\b", score)
    if scored:
        score_html = f'{scored.group(1)}<span class="unit"> / 100</span>'
    else:
        score_html = html.escape(score or "—")
    stats = (
        f'<div class="stat"><span>预订量</span><strong>{html.escape(bookings)}</strong></div>'
        f'<div class="stat"><span>环比</span><strong>{wow_html}</strong></div>'
        f'<div class="stat"><span>异动</span><strong>{score_html}</strong></div>'
        f'<div class="stat"><span>主因</span><strong class="cause">{html.escape(cause or "—")}</strong></div>'
    )
    return kicker, html.escape(title), sub_html + f'<div class="stats">{stats}</div>'


TAG_COLUMNS = {"信号", "强度", "置信度"}
LEVEL_LABELS = {
    "CS": "机构供应商",
    "C": "机构",
    "S": "供应商",
    "CSA": "机构供应商账号",
    "CBD": "机构预定窗口",
    "SBD": "供应商预定窗口",
    "CDH": "机构酒店",
    "SH": "供应商酒店",
    "LCDH": "击穿兜底",
    "L2L": "面纱",
    "CSLRC": "机构特殊配置",
    "C Bottom": "机构兜底",
    "S Bottom": "供应商兜底",
    "Configuration": "Wolf2.0配置",
}
TAG_KIND = {
    "无": "ok",
    "已确认": "ok",
    "已排除": "ok",
    "弱": "mute",
    "不能用": "mute",
    "中": "mid",
    "强～中": "mid",
    "中～强": "mid",
    "弱～中": "mid",
    "倾向": "mid",
    "待验证": "mid",
    "倾向 / 中": "mid",
    "强": "",
}


def level_html(cell: str) -> str:
    code = re.sub(r"\*+|`", "", cell).strip()
    label = LEVEL_LABELS.get(code)
    if not label:
        return ""
    return f"{html.escape(label)} {inline(cell)}"


def signal_tag(cell: str) -> str:
    """信号、强度、置信度：无/已确认/已排除=绿，弱/不能用=灰，中/倾向=褐，强=红。"""
    word = re.sub(r"\*+|`", "", cell).strip()
    kind = TAG_KIND.get(word)
    if kind is None:
        return ""
    cls = "tag" if kind == "" else f"tag {kind}"
    return f'<span class="{cls}">{inline(cell)}</span>'


def render_kv(table: dict) -> str:
    body = []
    for row in table["rows"]:
        label = inline(row[0]) if row else ""
        value = row[1] if len(row) > 1 else ""
        tone = cell_class(re.sub(r"\*+|`", "", value))
        attr = f' class="{tone}"' if tone else ""
        body.append(f"<tr><th>{label}</th><td{attr}>{inline(value)}</td></tr>")
    return '<table class="kv"><tbody>' + "".join(body) + "</tbody></table>"


def render_table(table: dict) -> str:
    header_plain = [re.sub(r"\*+|`", "", cell).strip() for cell in table["header"]]
    first_label = ""
    if table["rows"] and table["rows"][0]:
        first_label = re.sub(r"\*+|`", "", table["rows"][0][0]).strip()
    if header_plain == ["项", "值"] and first_label == "client_id":
        return render_kv(table)
    if header_plain == ["指标", "数值"]:
        return render_kv(table)
    signal_at = {
        i
        for i, cell in enumerate(table["header"])
        if re.sub(r"\*+|`", "", cell).strip() in TAG_COLUMNS
    }
    level_at = next(
        (i for i, cell in enumerate(table["header"]) if re.sub(r"\*+|`", "", cell).strip() == "Level"),
        None,
    )
    header_plain = [re.sub(r"\*+|`", "", cell).strip() for cell in table["header"]]
    scope_at = header_plain.index("作用域") if level_at is not None and "作用域" in header_plain else None
    fit_at = set(signal_at)
    fit_at.update(i for i, name in enumerate(header_plain) if name == "线")
    head = "".join(
        f'<th class="fit">{inline(c)}</th>' if i in fit_at else f"<th>{inline(c)}</th>"
        for i, c in enumerate(table["header"])
        if i != scope_at
    )
    body = []
    for row in table["rows"]:
        tds = []
        for i, cell in enumerate(row):
            if i == scope_at:
                continue
            tag = signal_tag(cell) if i in signal_at else ""
            if i in signal_at:
                tds.append(f'<td class="fit">{tag or inline(cell)}</td>')
                continue
            level = level_html(cell) if level_at is not None and i == level_at else ""
            if level:
                tds.append(f"<td>{level}</td>")
                continue
            plain = re.sub(r"\*+", "", cell).replace("`", "")
            classes = []
            if i in fit_at:
                classes.append("fit")
            tone = cell_class(plain)
            if tone:
                classes.append(tone)
            attr = f' class="{" ".join(classes)}"' if classes else ""
            tds.append(f"<td{attr}>{inline(cell)}</td>")
        body.append("<tr>" + "".join(tds) + "</tr>")
    return "<table><thead><tr>" + head + "</tr></thead><tbody>" + "".join(body) + "</tbody></table>"


def render_blocks(blocks: list[dict]) -> str:
    parts = []
    for block in blocks:
        kind = block["kind"]
        if kind == "h3":
            parts.append(f"<h3>{inline(h3_label(block['text']))}</h3>")
        elif kind == "h4":
            parts.append(f"<h4>{inline(block['text'])}</h4>")
        elif kind == "p":
            parts.append(f"<p>{inline(block['text'])}</p>")
        elif kind == "quote":
            parts.append(f"<blockquote><p>{inline(block['text'])}</p></blockquote>")
        elif kind == "ul":
            items = "".join(f"<li>{inline(item)}</li>" for item in block["items"])
            parts.append(f"<ul>{items}</ul>")
        elif kind == "table":
            parts.append(render_table(block))
        elif kind == "hr":
            parts.append("<hr>")
        elif kind == "pre":
            parts.append(f"<pre>{html.escape(block['text'])}</pre>")
    return "\n".join(parts)


CSS = """
:root {
  --paper: #f4f0e8; --card: #fffcf7; --ink: #1c1814; --muted: #6e655c;
  --line: #e3dacd; --drop: #9c342c; --drop-bg: #f8ebe8; --rise: #1f6b45; --rise-bg: #e7f3ec;
  --brass: #8a6432; --header: #241c16;
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body {
  margin: 0; background: var(--paper); color: var(--ink);
  font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
  font-size: 15px; line-height: 1.65;
}
a { color: inherit; }
.wrap {
  display: grid; grid-template-columns: 196px minmax(0, 920px); gap: 36px;
  max-width: 1180px; margin: 0 auto; padding: 28px 28px 80px;
}
nav { position: sticky; top: 20px; align-self: start; }
nav p { margin: 0 0 10px; font-size: 11px; letter-spacing: 0.14em; text-transform: uppercase; color: var(--muted); }
nav a { display: block; text-decoration: none; font-size: 13px; color: var(--muted); padding: 6px 0 6px 12px; border-left: 2px solid var(--line); }
nav a:hover { color: var(--ink); border-left-color: var(--brass); }
header.mast { background: var(--header); color: #f6f1e8; padding: 28px 32px 26px; border-radius: 16px; }
.kicker { display: flex; gap: 10px; align-items: center; font-size: 12px; letter-spacing: 0.08em; color: #cbbba6; margin-bottom: 10px; }
.pill { display: inline-block; border: 1px solid rgba(246,241,232,.25); border-radius: 999px; padding: 2px 8px; letter-spacing: 0; }
header.mast h1 { margin: 0 0 6px; font-family: "Palatino Linotype", "Songti SC", "SimSun", serif; font-weight: 500; font-size: 34px; letter-spacing: -0.02em; }
header.mast .sub { margin: 0; color: #d9cbb8; font-size: 14px; }
.stats { display: grid; grid-template-columns: 1.4fr repeat(3, 1fr); gap: 12px; margin-top: 22px; }
.stat { background: rgba(255,252,247,.06); border: 1px solid rgba(246,241,232,.08); border-radius: 12px; padding: 14px 16px 12px; }
.stat span { display: block; font-size: 12px; color: #cbbba6; margin-bottom: 4px; }
.stat strong { font-variant-numeric: tabular-nums; font-size: 26px; font-weight: 600; letter-spacing: -0.03em; }
.stat strong.cause { font-size: 18px; letter-spacing: 0; line-height: 1.25; }
.stat em { font-style: normal; color: #e7b2ac; }
.stat em.up { color: #b7d7c4; }
.stat .unit { font-size: 16px; color: #cbbba6; font-weight: 600; }
section, article.lead { margin-top: 18px; background: var(--card); border-radius: 16px; padding: 22px 26px 18px; }
h2 { margin: 0 0 14px; font-family: "Palatino Linotype", "Songti SC", "SimSun", serif; font-weight: 500; font-size: 22px; }
h3 {
  margin: 22px 0 10px; padding: 0 0 0 12px;
  border-left: 3px solid var(--brass);
  font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
  font-size: 18px; font-weight: 650; line-height: 1.45;
}
h4 {
  margin: 18px 0 8px;
  font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
  font-size: 13px; font-weight: 650; color: var(--muted);
}
.keys div { display: grid; grid-template-columns: 88px 1fr; gap: 12px; padding: 10px 0; border-top: 1px solid var(--line); }
.keys dt { color: var(--brass); font-weight: 650; }
.keys dd { margin: 0; }
.bars { display: grid; gap: 8px; margin: 8px 0 4px; }
.bar-row { display: grid; grid-template-columns: 72px 1fr 72px; gap: 10px; align-items: center; font-size: 13px; }
.track { height: 10px; background: #efe8dc; border-radius: 99px; overflow: hidden; }
.fill { height: 100%; border-radius: 99px; }
.fill.prev { background: #c4b49a; }
.fill.now { background: var(--drop); }
table { width: 100%; border-collapse: collapse; font-size: 13.5px; margin: 8px 0 14px; }
th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid var(--line); vertical-align: top; }
th { font-size: 12px; color: var(--muted); background: #faf7f2; }
table.kv th { font-size: 13.5px; font-weight: 650; white-space: nowrap; width: 1%; }
td.down { color: var(--drop); font-variant-numeric: tabular-nums; }
td.up { color: var(--rise); font-variant-numeric: tabular-nums; }
.tag { display: inline-block; font-size: 12px; line-height: 1.4; padding: 1px 7px; border-radius: 999px; background: var(--drop-bg); color: var(--drop); white-space: nowrap; }
.tag.ok { background: var(--rise-bg); color: var(--rise); }
.tag.mid { background: #f3ead8; color: #7a5a28; }
.tag.mute { background: #eeeae3; color: var(--muted); }
th.fit, td.fit { white-space: nowrap; width: 1%; }
blockquote { margin: 0 0 12px; color: var(--muted); }
hr { border: 0; border-top: 1px solid var(--line); margin: 16px 0; }
@media (max-width: 860px) {
  .wrap { grid-template-columns: 1fr; padding: 16px; }
  nav { position: static; }
  .stats { grid-template-columns: 1fr 1fr; }
  .keys div { grid-template-columns: 1fr; gap: 2px; }
}
"""

H2_LABELS = {
    "Executive Summary": "先看这段",
    "0. 分析参数": "分析参数",
    "1. Phase 1：异动识别": "异动识别",
    "2. Phase 2：定责与下钻": "定责与下钻",
    "3. Phase 3：内部证据": "内部证据",
    "4. Phase 3d：综合判断": "综合判断",
    "5. 根因结论": "根因结论",
    "6. 后续动作": "后续动作",
}
H2_TITLES = {
    "Executive Summary": "先看这段",
    "0. 分析参数": "分析参数",
    "1. Phase 1：异动识别": "1. 异动识别",
    "2. Phase 2：定责与下钻": "2. 定责与下钻",
    "3. Phase 3：内部证据": "3. 内部证据",
    "4. Phase 3d：综合判断": "4. 综合判断",
    "5. 根因结论": "5. 根因结论",
    "6. 后续动作": "6. 后续动作",
}


def h3_label(text: str) -> str:
    """页面上去掉 2c / 3a 这类编号，Markdown 标题保持原样。"""
    return re.sub(r"^\d+[a-z]\s+", "", text)


def plain(text: str) -> str:
    return re.sub(r"\*+|`", "", text).strip()


def daily_chart(table: dict) -> str:
    raw = ""
    for row in table["rows"]:
        if row and plain(row[0]) == "日均" and len(row) > 1:
            raw = plain(row[1])
            break
    match = re.fullmatch(r"(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)", raw)
    if not match:
        return ""
    current = float(match.group(1))
    previous = float(match.group(2))
    scale = max(current, previous, 1.0)
    current_width = f"{current / scale * 100:.1f}%"
    previous_width = f"{previous / scale * 100:.1f}%"
    return (
        '<div class="bars" aria-label="日均预订对比">'
        f'<div class="bar-row"><span>对比期</span><div class="track"><div class="fill prev" style="width:{previous_width}"></div></div><span>{html.escape(match.group(2))}</span></div>'
        f'<div class="bar-row"><span>当前期</span><div class="track"><div class="fill now" style="width:{current_width}"></div></div><span>{html.escape(match.group(1))}</span></div>'
        "</div>"
    )


def render_keys(items: list[str]) -> str:
    rows = []
    for item in items:
        match = re.match(r"^\*\*(.+?)：\*\*\s*(.*)$", item)
        if not match:
            return "<ul>" + "".join(f"<li>{inline(one)}</li>" for one in items) + "</ul>"
        rows.append(
            f"<div><dt>{html.escape(match.group(1))}</dt><dd>{inline(match.group(2))}</dd></div>"
        )
    return f'<dl class="keys">{"".join(rows)}</dl>'


def render_section_body(blocks: list[dict], h2_title: str) -> str:
    parts: list[str] = []
    chart_pending = h2_title == "1. Phase 1：异动识别"
    for block in blocks:
        kind = block["kind"]
        if chart_pending and kind == "table":
            chart = daily_chart(block)
            if chart:
                parts.append(chart)
            chart_pending = False
        if h2_title == "Executive Summary" and kind == "ul":
            parts.append(render_keys(block["items"]))
            continue
        if kind == "h3":
            parts.append(f"<h3>{inline(h3_label(block['text']))}</h3>")
        elif kind == "h4":
            parts.append(f"<h4>{inline(block['text'])}</h4>")
        elif kind == "p":
            parts.append(f"<p>{inline(block['text'])}</p>")
        elif kind == "quote":
            parts.append(f"<blockquote><p>{inline(block['text'])}</p></blockquote>")
        elif kind == "ul":
            items = "".join(f"<li>{inline(item)}</li>" for item in block["items"])
            parts.append(f"<ul>{items}</ul>")
        elif kind == "table":
            parts.append(render_table(block))
        elif kind == "hr":
            parts.append("<hr>")
        elif kind == "pre":
            parts.append(f"<pre>{html.escape(block['text'])}</pre>")
    return "\n".join(parts)


def render_html(text: str) -> str:
    blocks = parse_blocks(text)
    h1 = next((b["text"] for b in blocks if b["kind"] == "h1"), "")
    quote = ""
    seen_h1 = False
    for block in blocks:
        if block["kind"] == "h1":
            seen_h1 = True
            continue
        if seen_h1 and block["kind"] == "quote":
            quote = block["text"]
            break
        if seen_h1 and block["kind"] == "h2":
            break
    h2s = [(i, b["text"]) for i, b in enumerate(blocks) if b["kind"] == "h2"]
    unknown = [title for _, title in h2s if title not in H2_TITLES]
    if unknown:
        raise ValueError("章节不在显示对照表里：" + "、".join(unknown))
    nav = "".join(
        f'<a href="#s{n}">{html.escape(H2_LABELS[title])}</a>'
        for n, (_, title) in enumerate(h2s)
    )
    kicker, mast_title, mast_body = build_mast(blocks, h1, quote)
    sections = []
    for n, (start, title) in enumerate(h2s):
        end = h2s[n + 1][0] if n + 1 < len(h2s) else len(blocks)
        body = render_section_body(blocks[start + 1 : end], title)
        tag = "article" if title == "Executive Summary" else "section"
        klass = ' class="lead"' if tag == "article" else ""
        sections.append(
            f'<{tag}{klass} id="s{n}"><h2>{html.escape(H2_TITLES[title])}</h2>\n{body}\n</{tag}>'
        )
    title = visible(inline(h1)) or mast_title
    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<style>{CSS}</style>
</head>
<body>
<div class="wrap">
<nav><p>目录</p>{nav}</nav>
<main>
<header class="mast">
{kicker}
<h1>{mast_title}</h1>
{mast_body}
</header>
{''.join(sections)}
</main>
</div>
</body>
</html>
"""


def markdown_tables(text: str) -> list[list[list[str]]]:
    tables = []
    for block in parse_blocks(text):
        if block["kind"] != "table":
            continue
        rows = [block["header"], *block["rows"]]
        tables.append([[re.sub(r"\*+|`", "", c).strip() for c in row] for row in rows])
    return tables


def html_tables(page: str) -> list[list[list[str]]]:
    tables = []
    for raw in re.findall(r"<table\b[^>]*>(.*?)</table>", page, flags=re.S):
        rows = []
        for tr in re.findall(r"<tr>(.*?)</tr>", raw, flags=re.S):
            cells = [visible(c) for c in re.findall(r"<t[hd][^>]*>(.*?)</t[hd]>", tr, flags=re.S)]
            rows.append(cells)
        tables.append(rows)
    return tables


def without_level_labels(rows: list[list[str]]) -> list[list[str]]:
    if not rows:
        return rows
    try:
        col = rows[0].index("Level")
    except ValueError:
        return rows
    labels = sorted(LEVEL_LABELS.items(), key=lambda item: len(item[1]), reverse=True)
    out = [rows[0]]
    for row in rows[1:]:
        copied = list(row)
        if col < len(copied):
            text = copied[col]
            for code, label in labels:
                prefix = f"{label} "
                if text.startswith(prefix) and text[len(prefix):] == code:
                    copied[col] = code
                    break
        out.append(copied)
    return out


def without_scope(rows: list[list[str]]) -> list[list[str]]:
    """页面不展示 3a 的作用域。对照时从 markdown 侧去掉这一列。"""
    if not rows or "作用域" not in rows[0] or "Level" not in rows[0]:
        return rows
    col = rows[0].index("作用域")
    return [[cell for i, cell in enumerate(row) if i != col] for row in rows]


def without_kv_header(rows: list[list[str]]) -> list[list[str]]:
    """分析参数、异动识别在页面上不显示表头行。对照时从 markdown 侧去掉。"""
    if not rows or len(rows) < 2:
        return rows
    if rows[0] == ["项", "值"] and rows[1] and rows[1][0] == "client_id":
        return rows[1:]
    if rows[0] == ["指标", "数值"]:
        return rows[1:]
    return rows


def compare_tables(md_text: str, page: str) -> list[str]:
    left = markdown_tables(md_text)
    right = [without_level_labels(rows) for rows in html_tables(page)]
    errs = []
    if len(left) != len(right):
        errs.append(f"表格数量不一致：markdown {len(left)}，html {len(right)}")
    for i, (a, b) in enumerate(zip(left, right), 1):
        if without_kv_header(without_scope(a)) != b:
            errs.append(f"第 {i} 张表不一致\n    md: {a[:2]}\n    html: {b[:2]}")
    a3 = None
    for block in parse_blocks(md_text):
        if block["kind"] == "h3" and block["text"].startswith("3a 配置"):
            a3 = "seek"
            continue
        if a3 == "seek" and block["kind"] == "table":
            a3 = block
            break
    for n, table in enumerate(left, 1):
        if not table:
            continue
        width = len(table[0])
        for row in table[1:]:
            if len(row) != width:
                errs.append(f"第 {n} 张表有一行不是 {width} 列：{row}")
    if not isinstance(a3, dict):
        errs.append("markdown 里没有 3a 表")
    else:
        if a3["header"] != A3_HEADER:
            errs.append(f"3a 表头不是锁定的 7 列：{a3['header']}")
        if len(a3["rows"]) != 14:
            errs.append(f"3a 不是 14 行：{len(a3['rows'])}")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser(description="Render a checked report markdown to HTML")
    ap.add_argument("markdown", type=Path)
    ap.add_argument("-o", "--output", type=Path, help="默认与 markdown 同名 .html")
    args = ap.parse_args()
    path = args.markdown if args.markdown.is_absolute() else ROOT / args.markdown
    if not path.exists():
        print(f"FAIL 找不到 {path}")
        return 1
    checker = load_checker()
    skeleton_errs = checker.check_file(path)
    if skeleton_errs:
        print(f"FAIL 骨架未过，不生成 HTML：{path.name}")
        for err in skeleton_errs:
            print(f"  - {err}")
        return 1
    text = path.read_text(encoding="utf-8")
    try:
        page = render_html(text)
    except ValueError as exc:
        print(f"FAIL {exc}")
        return 1
    errs = compare_tables(text, page)
    out = args.output or path.with_suffix(".html")
    if errs:
        print("FAIL 单元格对照未过，不写出 HTML")
        for err in errs:
            print(f"  - {err}")
        return 1
    out.write_text(page, encoding="utf-8")
    print(f"PASS 骨架")
    print(f"PASS 表头与单元格对照（{len(markdown_tables(text))} 张表）")
    print("PASS 3a 为 7 列 14 行")
    print(f"WROTE {out}")
    return 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8")
        except Exception:
            pass
    sys.exit(main())
