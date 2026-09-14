#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate holiday-canonical-seed.csv from Python `holidays` (offline).

Usage (from skill root):
    python scripts/generate-holiday-canonical-seed.py

Output:
    sql/external-events-lite/holiday-canonical-seed.csv

Requires: pip install holidays
"""

from __future__ import annotations

import csv
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path

import holidays

SKILL_ROOT = Path(__file__).resolve().parent.parent
OUT_CSV = SKILL_ROOT / "sql" / "external-events-lite" / "holiday-canonical-seed.csv"
YEARS = (2024, 2025, 2026)


@dataclass(frozen=True)
class HolidaySpec:
    holiday_key: str
    country_code: str
    library_country: str
    include_substrings: tuple[str, ...]
    exclude_substrings: tuple[str, ...] = ()
    ads_patterns: tuple[str, ...] = ()
    ads_exclude_patterns: tuple[str, ...] = ()
    notes: str = ""


# First batch (~15 keys). include_substrings matched against library holiday names (case-insensitive).
SPECS: list[HolidaySpec] = [
    HolidaySpec(
        "MY.HARI_RAYA_PUASA",
        "MY",
        "MY",
        ("hari raya puasa",),
        ("haji", "qurban", "kedua", "hari kedua"),
        ("%Hari Raya Puasa%",),
        ("%Haji%", "%Qurban%"),
        "Library 2026+ may suffix (anggaran); still included. ads: Puasa / Puasa Holiday.",
    ),
    HolidaySpec(
        "MY.HARI_RAYA_HAJI",
        "MY",
        "MY",
        ("hari raya qurban", "hari raya haji"),
        ("kedua",),
        ("%Hari Raya Haji%", "%Hari Raya Qurban%"),
        ("%Puasa%",),
        "Library name: Qurban; ads table often: Haji.",
    ),
    HolidaySpec(
        "ID.IDUL_FITRI",
        "ID",
        "ID",
        ("idul fitri", "hari raya idul fitri"),
        ("kedua", "day", "hari kedua"),
        ("%Idul Fitri%", "%Hari Raya Idul Fitri%"),
        ("Adha", "Waisak"),
    ),
    HolidaySpec(
        "ID.IDUL_ADHA",
        "ID",
        "ID",
        ("idul adha", "hari raya idul adha"),
        (),
        ("%Idul Adha%", "%Idul Adha%"),
        ("Fitri", "Waisak"),
    ),
    HolidaySpec(
        "SG.CHINESE_NEW_YEAR",
        "SG",
        "SG",
        ("chinese new year",),
        (),
        ("%Chinese New Year%", "%春节%"),
        (),
    ),
    HolidaySpec(
        "SG.HARI_RAYA_PUASA",
        "SG",
        "SG",
        ("hari raya puasa",),
        ("haji",),
        ("%Hari Raya Puasa%",),
        ("%Haji%",),
    ),
    HolidaySpec(
        "CN.SPRING_FESTIVAL",
        "CN",
        "CN",
        ("spring festival", "春节", "chun"),
        (),
        ("%Spring Festival%", "%春节%", "%Chun%"),
        (),
        "Library uses Chinese names; merge consecutive days.",
    ),
    HolidaySpec(
        "CN.NATIONAL_DAY",
        "CN",
        "CN",
        ("national day", "国庆节"),
        (),
        ("%National Day%", "%国庆%"),
        (),
    ),
    HolidaySpec(
        "US.THANKSGIVING",
        "US",
        "US",
        ("thanksgiving",),
        (),
        ("%Thanksgiving%",),
        (),
    ),
    HolidaySpec(
        "US.INDEPENDENCE_DAY",
        "US",
        "US",
        ("independence day",),
        ("juneteenth",),
        ("%Independence Day%",),
        ("Juneteenth",),
    ),
    HolidaySpec(
        "US.CHRISTMAS",
        "US",
        "US",
        ("christmas day",),
        (),
        ("%Christmas%",),
        (),
        "Optional background; weak signal for B2B API.",
    ),
    HolidaySpec(
        "TH.SONGKRAN",
        "TH",
        "TH",
        ("songkran", "สงกรานต์"),
        (),
        ("%Songkran%",),
        (),
    ),
    HolidaySpec(
        "TH.LOY_KRATHONG",
        "TH",
        "TH",
        ("loy krathong",),
        (),
        ("%Loy Krathong%",),
        (),
        "May not appear every year in library; row skipped if no match.",
    ),
    HolidaySpec(
        "VN.LUNAR_NEW_YEAR",
        "VN",
        "VN",
        ("tet", "lunar new year", "giỗ tổ"),
        (),
        ("%Tet%", "%Lunar New Year%", "%New Year%"),
        (),
    ),
    HolidaySpec(
        "JP.GOLDEN_WEEK",
        "JP",
        "JP",
        (),  # names matched by fixed window below
        (),
        ("%Golden Week%", "%Showa%", "%Constitution%", "%Greenery%", "%Children%"),
        (),
        "Apr 29–May 6 window: all JP public holidays in range merged.",
    ),
    HolidaySpec(
        "GB.MAY_DAY",
        "GB",
        "GB",
        ("may day",),
        (),
        ("%May Day%", "%Early May%", "%May Bank%"),
        (),
    ),
    HolidaySpec(
        "PH.HOLY_WEEK",
        "PH",
        "PH",
        ("maundy thursday", "good friday", "black saturday"),
        (),
        ("%Maundy%", "%Good Friday%", "%Holy Week%"),
        (),
        "Merge consecutive Easter-related days.",
    ),
    HolidaySpec(
        "AU.AUSTRALIA_DAY",
        "AU",
        "AU",
        ("australia day",),
        (),
        ("%Australia Day%",),
        (),
    ),
]


def _name_matches(name: str, spec: HolidaySpec) -> bool:
    n = name.lower()
    if not any(s in n for s in spec.include_substrings):
        return False
    if any(s in n for s in spec.exclude_substrings):
        return False
    return True


def _collect_dates(spec: HolidaySpec, year: int) -> list[date]:
    cal = holidays.country_holidays(spec.library_country, years=year)
    return sorted(d for d, name in cal.items() if _name_matches(name, spec))


def _merge_consecutive(dates: list[date]) -> list[tuple[date, date]]:
    if not dates:
        return []
    dates = sorted(set(dates))
    ranges: list[tuple[date, date]] = []
    start = prev = dates[0]
    for d in dates[1:]:
        if d == prev + timedelta(days=1):
            prev = d
            continue
        ranges.append((start, prev))
        start = prev = d
    ranges.append((start, prev))
    return ranges


def _golden_week_ranges(spec: HolidaySpec, year: int) -> list[tuple[date, date]]:
    """JP Golden Week: all public holidays in Apr 29 – May 6 merged."""
    cal = holidays.country_holidays(spec.library_country, years=year)
    window = [d for d in cal if (d.month == 4 and d.day >= 29) or (d.month == 5 and d.day <= 6)]
    if not window:
        return []
    return [(min(window), max(window))]


def ranges_for_spec(spec: HolidaySpec, year: int) -> list[tuple[date, date]]:
    if spec.holiday_key == "JP.GOLDEN_WEEK":
        return _golden_week_ranges(spec, year)
    return _merge_consecutive(_collect_dates(spec, year))


def generate_rows() -> list[dict]:
    rows: list[dict] = []
    for spec in SPECS:
        for year in YEARS:
            for start, end in ranges_for_spec(spec, year):
                rows.append(
                    {
                        "holiday_key": spec.holiday_key,
                        "country_code": spec.country_code,
                        "year": year,
                        "start_date": start.isoformat(),
                        "end_date": end.isoformat(),
                        "duration_days": (end - start).days + 1,
                        "source": f"holidays.{spec.library_country}",
                        "ads_patterns": "|".join(spec.ads_patterns),
                        "ads_exclude_patterns": "|".join(spec.ads_exclude_patterns),
                        "notes": spec.notes,
                    }
                )
    rows.sort(key=lambda r: (r["country_code"], r["holiday_key"], r["year"], r["start_date"]))
    return rows


def main() -> None:
    rows = generate_rows()
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "holiday_key",
        "country_code",
        "year",
        "start_date",
        "end_date",
        "duration_days",
        "source",
        "ads_patterns",
        "ads_exclude_patterns",
        "notes",
    ]
    with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {len(rows)} rows -> {OUT_CSV}")
    # Summary by key
    from collections import Counter

    c = Counter(r["holiday_key"] for r in rows)
    for k, n in sorted(c.items()):
        print(f"  {k}: {n} row(s)")


if __name__ == "__main__":
    main()
