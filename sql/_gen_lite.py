"""Generate search-attribution-lite and rate-accuracy-contribution-lite SQL files."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent
shutil.copy2(ROOT / "_extract_sql2.sql", ROOT / "rate-accuracy-contribution.sql")

search_dir = ROOT / "search-attribution-lite"
acc_dir = ROOT / "rate-accuracy-contribution-lite"
issue_dir = acc_dir / "issue"
issue_dir.mkdir(parents=True, exist_ok=True)

SEARCH_JOIN_TAIL = """
    ROUND(100.0 * s.current_avail_search / NULLIF(s.current_total_search, 0), 2) AS current_avail_rate_pct,
    ROUND(100.0 * s.previous_avail_search / NULLIF(s.previous_total_search, 0), 2) AS previous_avail_rate_pct,
    ROUND(100.0 * s.current_avail_search / NULLIF(p.current_period_precheck, 0), 2) AS current_check_ratio_pct,
    ROUND(100.0 * s.previous_avail_search / NULLIF(p.previous_period_precheck, 0), 2) AS previous_check_ratio_pct
FROM search s
LEFT JOIN precheck p ON s.index = p.index
"""


def write_search(fn, body):
    hdr = f"""-- {fn} | Phase 3b lite | 占位符见 ../params-template.md
-- 完整版 ../search-attribution.sql（MCP 禁止 UNION）

"""
    (search_dir / fn).write_text(hdr + body.strip() + "\n", encoding="utf-8")


write_search(
    "02-didabiz-pps-country.sql",
    """
WITH search AS (
    SELECT a.country_code AS index,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.total_count ELSE 0 END) AS current_total_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.total_count ELSE 0 END) AS previous_total_search,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.availiblity_count ELSE 0 END) AS current_avail_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.availiblity_count ELSE 0 END) AS previous_avail_search
    FROM data_ovs.didamonitor_funnel_client_country a
    WHERE a.dt = CURRENT_DATE AND a.client_id = '{client_id}'
        AND a.date BETWEEN '{compare_start}'::date AND '{current_end}'::date AND a.country_code IS NOT NULL
    GROUP BY 1
),
precheck AS (
    SELECT a.country_code AS index,
        SUM(CASE WHEN a.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_period_precheck,
        SUM(CASE WHEN a.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_period_precheck
    FROM data_ovs.rate_accuracy_channel_multi_dimension a
    WHERE a.dt = CURRENT_DATE AND a.client_id = '{client_id}'
        AND a.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date AND a.country_code IS NOT NULL
    GROUP BY 1
)
SELECT 'DidaBiz PPS' AS db_level, 'Country' AS hierarchy_level, s.index,
    s.current_total_search, s.previous_total_search, s.current_avail_search, s.previous_avail_search,
    COALESCE(p.current_period_precheck, 0) AS current_period_precheck,
    COALESCE(p.previous_period_precheck, 0) AS previous_period_precheck,
"""
    + SEARCH_JOIN_TAIL
    + """
WHERE s.current_total_search > 0 OR s.previous_total_search > 0
ORDER BY (s.current_avail_search - s.previous_avail_search) ASC LIMIT 50;
""",
)

write_search(
    "03-didabiz-pps-chain.sql",
    """
WITH search AS (
    SELECT a.parent_chain_name AS index,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.total_count ELSE 0 END) AS current_total_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.total_count ELSE 0 END) AS previous_total_search,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.availiblity_count ELSE 0 END) AS current_avail_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.availiblity_count ELSE 0 END) AS previous_avail_search
    FROM data_ovs.didamonitor_funnel_client_chain a
    WHERE a.dt = CURRENT_DATE AND a.client_id = '{client_id}'
        AND a.date BETWEEN '{compare_start}'::date AND '{current_end}'::date
        AND a.parent_chain_name IS NOT NULL AND a.parent_chain_name != ''
    GROUP BY 1
),
precheck AS (
    SELECT COALESCE(a.chain, 'Independent') AS index,
        SUM(CASE WHEN a.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_period_precheck,
        SUM(CASE WHEN a.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_period_precheck
    FROM data_ovs.rate_accuracy_channel_multi_dimension a
    WHERE a.dt = CURRENT_DATE AND a.client_id = '{client_id}'
        AND a.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date AND a.chain IS NOT NULL
    GROUP BY 1
)
SELECT 'DidaBiz PPS' AS db_level, 'Chain' AS hierarchy_level, s.index,
    s.current_total_search, s.previous_total_search, s.current_avail_search, s.previous_avail_search,
    COALESCE(p.current_period_precheck, 0) AS current_period_precheck,
    COALESCE(p.previous_period_precheck, 0) AS previous_period_precheck,
"""
    + SEARCH_JOIN_TAIL
    + """
WHERE s.current_total_search > 0 OR s.previous_total_search > 0
ORDER BY (s.current_avail_search - s.previous_avail_search) ASC LIMIT 50;
""",
)

write_search(
    "04-didabiz-qps-los.sql",
    """
WITH search AS (
    SELECT CASE WHEN a.los = 1 THEN '1' WHEN a.los = 2 THEN '2' WHEN a.los = 3 THEN '3'
             WHEN a.los BETWEEN 4 AND 7 THEN '4~7' WHEN a.los BETWEEN 8 AND 14 THEN '8~14'
             WHEN a.los BETWEEN 15 AND 28 THEN '15~28' WHEN a.los > 28 THEN '>28' END AS index,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.amount ELSE 0 END) AS current_total_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.amount ELSE 0 END) AS previous_total_search,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.activeamount ELSE 0 END) AS current_avail_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.activeamount ELSE 0 END) AS previous_avail_search
    FROM public.clientloscallcount a
    WHERE a.clientid = '{client_id}' AND a.date BETWEEN '{compare_start}'::date AND '{current_end}'::date
        AND a.biztype IN ('HotelRateSearch_RealTime_MultiHotel', 'HotelRateSearch_RealTime_SingleHotel', 'HotelRateSearch_Cache_MultiHotel')
    GROUP BY 1
),
precheck AS (
    SELECT a.los AS index,
        SUM(CASE WHEN a.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_period_precheck,
        SUM(CASE WHEN a.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_period_precheck
    FROM data_ovs.rate_accuracy_channel_multi_dimension a
    WHERE a.dt = CURRENT_DATE AND a.client_id = '{client_id}'
        AND a.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date AND a.los IS NOT NULL
    GROUP BY 1
)
SELECT 'DidaBiz QPS' AS db_level, 'LOS' AS hierarchy_level, s.index,
    s.current_total_search, s.previous_total_search, s.current_avail_search, s.previous_avail_search,
    COALESCE(p.current_period_precheck, 0) AS current_period_precheck,
    COALESCE(p.previous_period_precheck, 0) AS previous_period_precheck,
"""
    + SEARCH_JOIN_TAIL
    + """
WHERE s.index IS NOT NULL
ORDER BY (s.current_avail_search - s.previous_avail_search) ASC LIMIT 30;
""",
)

write_search(
    "05-didabiz-qps-leadtime.sql",
    """
WITH search AS (
    SELECT CASE WHEN a.leadtime BETWEEN -1 AND 0 THEN '-1~0' WHEN a.leadtime = 1 THEN '1'
             WHEN a.leadtime = 2 THEN '2' WHEN a.leadtime = 3 THEN '3'
             WHEN a.leadtime BETWEEN 4 AND 7 THEN '4~7' WHEN a.leadtime BETWEEN 8 AND 14 THEN '8~14'
             WHEN a.leadtime BETWEEN 15 AND 28 THEN '15~28' WHEN a.leadtime BETWEEN 29 AND 42 THEN '29~42'
             WHEN a.leadtime BETWEEN 43 AND 70 THEN '43~70' WHEN a.leadtime > 70 THEN '>70' END AS index,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.amount ELSE 0 END) AS current_total_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.amount ELSE 0 END) AS previous_total_search,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.activeamount ELSE 0 END) AS current_avail_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.activeamount ELSE 0 END) AS previous_avail_search
    FROM public.clientleadtimecallcount a
    WHERE a.clientid = '{client_id}' AND a.leadtime >= -1
        AND a.date BETWEEN '{compare_start}'::date AND '{current_end}'::date
        AND a.biztype IN ('HotelRateSearch_RealTime_MultiHotel', 'HotelRateSearch_RealTime_SingleHotel', 'HotelRateSearch_Cache_MultiHotel')
    GROUP BY 1
),
precheck AS (
    SELECT a.lt AS index,
        SUM(CASE WHEN a.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_period_precheck,
        SUM(CASE WHEN a.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_period_precheck
    FROM data_ovs.rate_accuracy_channel_multi_dimension a
    WHERE a.dt = CURRENT_DATE AND a.client_id = '{client_id}'
        AND a.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date AND a.lt IS NOT NULL
    GROUP BY 1
)
SELECT 'DidaBiz QPS' AS db_level, 'LeadTime' AS hierarchy_level, s.index,
    s.current_total_search, s.previous_total_search, s.current_avail_search, s.previous_avail_search,
    COALESCE(p.current_period_precheck, 0) AS current_period_precheck,
    COALESCE(p.previous_period_precheck, 0) AS previous_period_precheck,
"""
    + SEARCH_JOIN_TAIL
    + """
WHERE s.index IS NOT NULL
ORDER BY (s.current_avail_search - s.previous_avail_search) ASC LIMIT 30;
""",
)

write_search(
    "06-didabiz-qps-nationality.sql",
    """
WITH search AS (
    SELECT a.nationality AS index,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.amount ELSE 0 END) AS current_total_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.amount ELSE 0 END) AS previous_total_search,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.activeamount ELSE 0 END) AS current_avail_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.activeamount ELSE 0 END) AS previous_avail_search
    FROM public.clientnationalitycallcount a
    WHERE a.clientid = '{client_id}' AND a.date BETWEEN '{compare_start}'::date AND '{current_end}'::date
        AND a.biztype IN ('HotelRateSearch_RealTime_MultiHotel', 'HotelRateSearch_RealTime_SingleHotel', 'HotelRateSearch_Cache_MultiHotel')
        AND a.nationality IS NOT NULL
    GROUP BY 1
),
precheck AS (
    SELECT a.nationality::text AS index,
        SUM(CASE WHEN a.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_period_precheck,
        SUM(CASE WHEN a.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_period_precheck
    FROM data_ovs.rate_accuracy_channel_multi_dimension a
    WHERE a.dt = CURRENT_DATE AND a.client_id = '{client_id}'
        AND a.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date AND a.nationality IS NOT NULL
    GROUP BY 1
)
SELECT 'DidaBiz QPS' AS db_level, 'Nationality' AS hierarchy_level, s.index,
    s.current_total_search, s.previous_total_search, s.current_avail_search, s.previous_avail_search,
    COALESCE(p.current_period_precheck, 0) AS current_period_precheck,
    COALESCE(p.previous_period_precheck, 0) AS previous_period_precheck,
"""
    + SEARCH_JOIN_TAIL
    + """
ORDER BY (s.current_avail_search - s.previous_avail_search) ASC LIMIT 30;
""",
)

ACC_METRICS = """
    SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END) AS current_precheck,
    SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END) AS previous_precheck,
    SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.success_precheck ELSE 0 END) AS current_success_precheck,
    SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.success_precheck ELSE 0 END) AS previous_success_precheck,
    SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.success_precheck ELSE 0 END)::numeric
        / NULLIF(SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END), 0) AS current_accuracy,
    SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.success_precheck ELSE 0 END)::numeric
        / NULLIF(SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END), 0) AS previous_accuracy,
    (SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.success_precheck ELSE 0 END)::numeric
        / NULLIF(SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END), 0)
     - SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.success_precheck ELSE 0 END)::numeric
        / NULLIF(SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END), 0)) * 100 AS item_accuracy_delta_pp,
    SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END)
      - SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END) AS precheck_change
"""

ACC_WHERE = """
FROM data_ovs.rate_accuracy_channel_multi_dimension t
WHERE t.dt = CURRENT_DATE
    AND t.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date
    AND t.client_id = '{client_id}'
"""


def write_acc(fn, hier, select_cols, group_cols, order="ORDER BY item_accuracy_delta_pp ASC NULLS LAST LIMIT 50"):
    gb = ", ".join(group_cols) if group_cols else ""
    grp = f"GROUP BY {gb}" if group_cols else ""
    body = f"""
SELECT '{hier}' AS hierarchy_level,
    {select_cols},
{ACC_METRICS}
{ACC_WHERE}
{grp}
HAVING SUM(CASE WHEN t.log_date BETWEEN '{{analysis_date}}'::date AND '{{current_end}}'::date THEN t.precheck ELSE 0 END) > 0
    OR SUM(CASE WHEN t.log_date BETWEEN '{{compare_start}}'::date AND '{{compare_end}}'::date THEN t.precheck ELSE 0 END) > 0
{order};
"""
    hdr = f"-- {fn} | Phase 3c lite | hierarchy {hier}\n-- within_contribution_pp: Agent 本地算（README）\n\n"
    (acc_dir / fn).write_text(hdr + body.strip() + "\n", encoding="utf-8")


write_acc("01-total.sql", "1_Total", "'ALL' AS index", [], order=";")
(acc_dir / "01-total.sql").write_text(
    (acc_dir / "01-total.sql").read_text(encoding="utf-8").replace("ORDER BY item_accuracy_delta_pp ASC NULLS LAST LIMIT 50;", "").replace("GROUP BY \nHAVING", "HAVING"),
    encoding="utf-8",
)

specs = [
    ("02-sid.sql", "2_SID", "t.supplier_id::text AS supplier_id", ["t.supplier_id"]),
    ("03-sid-account.sql", "3_SID+Account", "t.supplier_id::text AS supplier_id, t.supplier_account_id::text AS supplier_account_id", ["t.supplier_id", "t.supplier_account_id"]),
    ("04-country.sql", "4_Country", "t.country_code", ["t.country_code"]),
    ("05-sid-country.sql", "5_SID+Country", "t.supplier_id::text AS supplier_id, t.country_code", ["t.supplier_id", "t.country_code"]),
    ("06-chain.sql", "6_Chain", "COALESCE(t.chain, 'Independent') AS chain", ["COALESCE(t.chain, 'Independent')"]),
    ("07-sid-chain.sql", "7_SID+Chain", "t.supplier_id::text AS supplier_id, COALESCE(t.chain, 'Independent') AS chain", ["t.supplier_id", "COALESCE(t.chain, 'Independent')"]),
    ("08-lt.sql", "8_LT", "t.lt", ["t.lt"]),
    ("09-sid-lt.sql", "9_SID+LT", "t.supplier_id::text AS supplier_id, t.lt", ["t.supplier_id", "t.lt"]),
    ("10-los.sql", "10_LOS", "t.los", ["t.los"]),
    ("11-sid-los.sql", "11_SID+LOS", "t.supplier_id::text AS supplier_id, t.los", ["t.supplier_id", "t.los"]),
    ("12-nationality.sql", "12_Nationality", "t.nationality::text AS nationality", ["t.nationality"]),
    ("13-sid-nationality.sql", "13_SID+Nationality", "t.supplier_id::text AS supplier_id, t.nationality::text AS nationality", ["t.supplier_id", "t.nationality"]),
]
for fn, hier, sel, gb in specs:
    write_acc(fn, hier, sel, gb)

(issue_dir / "01-issue-type.sql").write_text(
    """-- issue/01-issue-type | 3c 下钻：issue_type 占比 current vs previous
-- is_request_chain=True 用 _chain 字段

SELECT
    CASE WHEN t.is_request_chain = TRUE THEN t.issue_type_chain ELSE t.issue_type END AS issue_type,
    SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END) AS current_precheck,
    SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END) AS previous_precheck
FROM data_ovs.rate_accuracy_channel_multi_dimension t
WHERE t.dt = CURRENT_DATE
    AND t.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date
    AND t.client_id = '{client_id}'
GROUP BY 1
ORDER BY current_precheck DESC;
""",
    encoding="utf-8",
)

(issue_dir / "02-issue-id.sql").write_text(
    """-- issue/02-issue-id | 3c 下钻：issue_id（可选 WHERE issue_type = N）

SELECT
    CASE WHEN t.is_request_chain = TRUE THEN t.issue_type_chain ELSE t.issue_type END AS issue_type,
    CASE WHEN t.is_request_chain = TRUE THEN t.issue_id_chain ELSE t.issue_id END AS issue_id,
    MAX(t.issue_id_channel_cn) AS issue_id_channel_cn,
    SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END) AS current_precheck,
    SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END) AS previous_precheck
FROM data_ovs.rate_accuracy_channel_multi_dimension t
WHERE t.dt = CURRENT_DATE
    AND t.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date
    AND t.client_id = '{client_id}'
GROUP BY 1, 2
HAVING SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END) > 0
ORDER BY current_precheck DESC
LIMIT 30;
""",
    encoding="utf-8",
)

# fix 01-total - no GROUP BY
(acc_dir / "01-total.sql").write_text(
    """-- 01-total.sql | Phase 3c lite | hierarchy 1_Total

SELECT '1_Total' AS hierarchy_level, 'ALL' AS index,
"""
    + ACC_METRICS
    + ACC_WHERE
    + ";\n",
    encoding="utf-8",
)

print("search", len(list(search_dir.glob("*.sql"))))
print("accuracy", len(list(acc_dir.glob("*.sql"))), "issue", len(list(issue_dir.glob("*.sql"))))
