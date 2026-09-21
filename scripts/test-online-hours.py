#!/usr/bin/env python3
"""在线时长本地计算（与 sql/online-hours.sql 口径一致）。

Fallback：仅当 MCP 跑 03-window-avg.sql / online-hours.sql 仍 500 时使用。
默认归因路径是 MCP 开窗 SQL，不必先拉 log。

输入：MCP 01-fetch-logs 存盘的 JSON（{"rows":[...]} 或纯数组）。
JSON 里 channel_operation_time 是毫秒 epoch（MCP 序列化 timestamptz）。
可传多个文件（status=0/1、多页）。Windows 无 tzdata 时回退 UTC+8。
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from datetime import datetime, timedelta, date, timezone
from pathlib import Path

try:
    from zoneinfo import ZoneInfo
    BJ = ZoneInfo("Asia/Shanghai")
except Exception:
    BJ = timezone(timedelta(hours=8))


def load_rows(*paths: Path) -> list[dict]:
    rows: list[dict] = []
    for p in paths:
        data = json.loads(Path(p).read_text(encoding="utf-8"))
        if isinstance(data, list):
            rows.extend(data)
        elif isinstance(data, dict) and "rows" in data:
            rows.extend(data["rows"])
        else:
            raise SystemExit(f"无法解析 {p}：需要 {{\"rows\": [...]}} 或数组")
    return rows


def ms_to_bj(ms) -> datetime:
    return datetime.fromtimestamp(float(ms) / 1000.0, tz=timezone.utc).astimezone(BJ)


def dedup_and_changes(rows: list[dict]) -> list[dict]:
    by_ts: dict[tuple, dict] = {}
    for r in rows:
        key = (r["client_id"], r["channel_operation_time"])
        if key not in by_ts or int(r["id"]) > int(by_ts[key]["id"]):
            by_ts[key] = r
    deduped = sorted(by_ts.values(), key=lambda x: (x["channel_operation_time"], int(x["id"])))
    changes: list[dict] = []
    prev = None
    for r in deduped:
        st = int(r["status"])
        if prev is None or st != prev:
            changes.append({
                "status": st,
                "op_ts": ms_to_bj(r["channel_operation_time"]),
                "source": r.get("source") or "",
                "remark": r.get("remark") or "",
                "id": int(r["id"]),
                "client_id": r.get("client_id"),
            })
            prev = st
    return changes


def daily_online_hours(changes: list[dict], start_date: date, end_date: date) -> list[dict]:
    """start_date inclusive, end_date exclusive（同 SQL {end_date}）。"""
    start_ts = datetime(start_date.year, start_date.month, start_date.day, tzinfo=BJ)
    end_ts = datetime(end_date.year, end_date.month, end_date.day, tzinfo=BJ)

    spans = []
    for i, c in enumerate(changes):
        if c["status"] != 1:
            continue
        next_ts = changes[i + 1]["op_ts"] if i + 1 < len(changes) else end_ts
        span_start, span_end = c["op_ts"], next_ts
        if span_start >= end_ts or span_end <= start_ts:
            continue
        spans.append((max(span_start, start_ts), min(span_end, end_ts)))

    results = []
    n_days = (end_date - start_date).days
    for d in range(n_days):
        dt = start_date + timedelta(days=d)
        day_start = datetime(dt.year, dt.month, dt.day, tzinfo=BJ)
        day_end = day_start + timedelta(days=1)
        seconds = 0.0
        for s0, s1 in spans:
            a, b = max(s0, day_start), min(s1, day_end)
            if b > a:
                seconds += (b - a).total_seconds()
        hours = min(seconds / 3600.0, 24.0)
        results.append({
            "dt": str(dt),
            "online_hours": round(hours, 2),
            "online_pct": round(hours / 24 * 100, 1),
        })
    return results


def avg_hours(daily: list[dict], period_start: date, period_end: date) -> tuple[float, list[dict]]:
    """period_end inclusive。"""
    sel = [d for d in daily if period_start <= date.fromisoformat(d["dt"]) <= period_end]
    if not sel:
        return 0.0, []
    return round(sum(d["online_hours"] for d in sel) / len(sel), 2), sel


def dominant_source(src_cnt: Counter) -> str:
    if not src_cnt:
        return ""
    return src_cnt.most_common(1)[0][0]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="在线时长日表：MCP log JSON → 两窗日均")
    p.add_argument("--input", nargs="+", required=True, help="MCP 存盘 JSON（可多个分页）")
    p.add_argument("--compare-start", required=True, help="对比窗起日 YYYY-MM-DD（含）")
    p.add_argument("--compare-end", required=True, help="对比窗止日 YYYY-MM-DD（含）")
    p.add_argument("--current-start", required=True, help="当前窗起日 YYYY-MM-DD（含）")
    p.add_argument("--current-end", required=True, help="当前窗止日 YYYY-MM-DD（含）")
    p.add_argument("--client", default="", help="报告用 client_id（默认取第一行）")
    p.add_argument("--out", default="", help="可选：把日表 JSON 写到此路径")
    return p.parse_args()


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8")
        except Exception:
            pass
    args = parse_args()
    paths = [Path(x) for x in args.input]
    for p in paths:
        if not p.exists():
            raise SystemExit(f"文件不存在: {p}")

    compare_start = date.fromisoformat(args.compare_start)
    compare_end = date.fromisoformat(args.compare_end)
    current_start = date.fromisoformat(args.current_start)
    current_end = date.fromisoformat(args.current_end)
    calc_start = compare_start
    calc_end = current_end + timedelta(days=1)

    rows = load_rows(*paths)
    if not rows:
        raise SystemExit("无日志行")
    client_id = args.client or str(rows[0].get("client_id") or "")

    changes = dedup_and_changes(rows)
    daily = daily_online_hours(changes, calc_start, calc_end)
    cur_avg, _ = avg_hours(daily, current_start, current_end)
    prev_avg, _ = avg_hours(daily, compare_start, compare_end)
    diff = round(cur_avg - prev_avg, 2)
    wow = round(100.0 * diff / prev_avg, 1) if prev_avg else None
    anomaly = diff <= -1.5

    win_start = datetime(calc_start.year, calc_start.month, calc_start.day, tzinfo=BJ)
    win_end = datetime(calc_end.year, calc_end.month, calc_end.day, tzinfo=BJ)
    in_win = [c for c in changes if win_start <= c["op_ts"] < win_end]
    src_cnt = Counter(c["source"] for c in in_win if c["source"])
    remarks_off = sorted({
        c["remark"] for c in in_win
        if c["status"] == 0 and c["remark"]
    })
    dom = dominant_source(src_cnt)

    summary = {
        "client_id": client_id,
        "raw_rows": len(rows),
        "changes": len(changes),
        "compare": {"start": str(compare_start), "end": str(compare_end), "avg_hours": prev_avg},
        "current": {"start": str(current_start), "end": str(current_end), "avg_hours": cur_avg},
        "delta_h": diff,
        "wow_pct": wow,
        "anomaly_ge_1_5h": anomaly,
        "source_in_window": dict(src_cnt),
        "dominant_source": dom,
        "remarks_offline": remarks_off,
        "daily": daily,
    }

    print(f"client_id: {client_id}")
    print(f"raw_rows: {len(rows)} | changes: {len(changes)}")
    print(f"对比窗日均 ({compare_start}~{compare_end}): {prev_avg} h")
    print(f"当前窗日均 ({current_start}~{current_end}): {cur_avg} h")
    print(f"差值: {diff} h | WoW: {wow}%")
    print(f"异动 (少>=1.5h): {'YES' if anomaly else 'NO'}")
    print(f"窗口内 source: {dict(src_cnt)}")
    print(f"主导 source: {dom or '(无动作)'}")
    if remarks_off:
        print(f"下线 remark: {remarks_off}")
    print("daily:")
    for d in daily:
        print(f"  {d['dt']}  {d['online_hours']}h  {d['online_pct']}%")
    print("ONLINE_HOURS_JSON=" + json.dumps(summary, ensure_ascii=False))

    if args.out:
        Path(args.out).write_text(
            json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
