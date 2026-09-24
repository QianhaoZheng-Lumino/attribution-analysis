/* 01-ss-supplier | Phase 3b 查价归因 lite — 【必跑】CS/S 路径优先 */
/* 占位符: {client_id} {sid_list} {analysis_date} {current_end} {compare_start} {compare_end} */
/* {sid_list} = 2b 锁定 SID，或占本案 |ΔBKS|≥10% 的 SID，逗号分隔整数，如 26, 95, 61 */
/* 无结构 SID 时填 02-sid |change| Top3。禁止 IN () 空列表 */
/* 全表 ORDER BY avail_change ASC LIMIT 50 会截掉涨尾 SID，禁止据此写「未覆盖涨尾」 */

WITH search AS (
    SELECT
        a.supplierid::text AS index,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.hotelcallamount ELSE 0 END) AS current_total_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.hotelcallamount ELSE 0 END) AS previous_total_search,
        SUM(CASE WHEN a.date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN a.availcallamount ELSE 0 END) AS current_avail_search,
        SUM(CASE WHEN a.date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN a.availcallamount ELSE 0 END) AS previous_avail_search
    FROM public.clientsupplierhotelcallcountsummary a
    WHERE a.clientid = '{client_id}'
        AND a.supplierid IN ({sid_list})
        AND a.date BETWEEN '{compare_start}'::date AND '{current_end}'::date
    GROUP BY 1
),
precheck AS (
    SELECT
        a.supplier_id::text AS index,
        SUM(CASE WHEN a.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_period_precheck,
        SUM(CASE WHEN a.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_period_precheck
    FROM data_ovs.rate_accuracy_channel_multi_dimension a
    WHERE a.dt = CURRENT_DATE
        AND a.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date
        AND a.client_id = '{client_id}'
        AND a.supplier_id IS NOT NULL
        /* precheck.supplier_id 多为 text；CAST AS INTEGER 会 MCP 500。用 string_to_array 对齐整数 {sid_list} */
        AND a.supplier_id::text = ANY (string_to_array(replace('{sid_list}', ' ', ''), ','))
    GROUP BY 1
)
SELECT
    'SS' AS db_level,
    'Supplier' AS hierarchy_level,
    s.index,
    s.current_total_search,
    s.previous_total_search,
    s.current_avail_search,
    s.previous_avail_search,
    COALESCE(p.current_period_precheck, 0) AS current_period_precheck,
    COALESCE(p.previous_period_precheck, 0) AS previous_period_precheck,
    ROUND(100.0 * s.current_avail_search / NULLIF(s.current_total_search, 0), 2) AS current_avail_rate_pct,
    ROUND(100.0 * s.previous_avail_search / NULLIF(s.previous_total_search, 0), 2) AS previous_avail_rate_pct,
    ROUND(s.current_avail_search::numeric / NULLIF(p.current_period_precheck, 0), 2) AS current_check_ratio,
    ROUND(s.previous_avail_search::numeric / NULLIF(p.previous_period_precheck, 0), 2) AS previous_check_ratio
FROM search s
LEFT JOIN precheck p ON s.index = p.index
WHERE s.current_total_search > 0 OR s.previous_total_search > 0
ORDER BY (s.current_avail_search - s.previous_avail_search) ASC
LIMIT 50;
