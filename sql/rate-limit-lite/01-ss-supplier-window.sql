-- 01-ss-supplier-window | SS限流率 + 缓存命中率 + 背景信号（SS通过率 / 命中只吐缓存率）
-- 占位符与 search-attribution-lite / params-template 一致：
--   {client_id} {sid_list} {analysis_date} {current_end} {compare_start} {compare_end}
-- {sid_list} = 2b 锁定 SID，或占本案 |ΔBKS|≥10% 的 SID，逗号分隔整数，如 26, 95, 61
-- 无结构 SID 时填 02-sid |change| Top3。禁止 IN () 空列表
-- 全表 ORDER BY ss_rate_limit_pct_delta_pp DESC LIMIT 50 会截掉涨尾 SID，禁止据此写「未返回」
-- 表：dws.dws_hotel_flow_didamonitor_supplier_csa_di（log_date 对齐 SS 查价 date 窗口）
-- 不筛 biztype；SUM 全部 supplieraccountid
-- SS限流率 = limit/requests；SS通过率 = pass/requests（背景）；废弃 not_limit_requests_num
-- 恒等式：limit + pass + read_only_cache ≈ requests

SELECT
    supplierid::text AS supplier_id,
    -- 当前窗原始量
    SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN all_requests_num ELSE 0 END) AS current_all_requests,
    SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN requests_num ELSE 0 END) AS current_requests_num,
    SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN limit_requests_num ELSE 0 END) AS current_limit_requests,
    SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN pass_requests_num ELSE 0 END) AS current_pass_requests,
    SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN read_only_cache_requests_num ELSE 0 END) AS current_read_only_cache_requests,
    SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN fromcache_requests_num ELSE 0 END) AS current_fromcache_requests,
    -- 当前窗比率
    ROUND(
        100.0 * SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN limit_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN requests_num ELSE 0 END), 0),
        2
    ) AS current_ss_rate_limit_pct,
    ROUND(
        100.0 * SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN pass_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN requests_num ELSE 0 END), 0),
        2
    ) AS current_ss_pass_pct,
    ROUND(
        100.0 * SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN fromcache_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN all_requests_num ELSE 0 END), 0),
        2
    ) AS current_cache_hit_pct,
    ROUND(
        100.0 * SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN read_only_cache_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN requests_num ELSE 0 END), 0),
        2
    ) AS current_read_only_cache_pct,
    -- 对比窗原始量
    SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN all_requests_num ELSE 0 END) AS previous_all_requests,
    SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN requests_num ELSE 0 END) AS previous_requests_num,
    SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN limit_requests_num ELSE 0 END) AS previous_limit_requests,
    SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN pass_requests_num ELSE 0 END) AS previous_pass_requests,
    SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN read_only_cache_requests_num ELSE 0 END) AS previous_read_only_cache_requests,
    SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN fromcache_requests_num ELSE 0 END) AS previous_fromcache_requests,
    -- 对比窗比率
    ROUND(
        100.0 * SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN limit_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN requests_num ELSE 0 END), 0),
        2
    ) AS previous_ss_rate_limit_pct,
    ROUND(
        100.0 * SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN pass_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN requests_num ELSE 0 END), 0),
        2
    ) AS previous_ss_pass_pct,
    ROUND(
        100.0 * SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN fromcache_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN all_requests_num ELSE 0 END), 0),
        2
    ) AS previous_cache_hit_pct,
    ROUND(
        100.0 * SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN read_only_cache_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN requests_num ELSE 0 END), 0),
        2
    ) AS previous_read_only_cache_pct,
    -- WoW 变化（百分点）
    ROUND(
        (100.0 * SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN limit_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN requests_num ELSE 0 END), 0))
        - (100.0 * SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN limit_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN requests_num ELSE 0 END), 0)),
        2
    ) AS ss_rate_limit_pct_delta_pp,
    ROUND(
        (100.0 * SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN pass_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN requests_num ELSE 0 END), 0))
        - (100.0 * SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN pass_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN requests_num ELSE 0 END), 0)),
        2
    ) AS ss_pass_pct_delta_pp,
    ROUND(
        (100.0 * SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN fromcache_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN all_requests_num ELSE 0 END), 0))
        - (100.0 * SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN fromcache_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN all_requests_num ELSE 0 END), 0)),
        2
    ) AS cache_hit_pct_delta_pp,
    ROUND(
        (100.0 * SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN read_only_cache_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN requests_num ELSE 0 END), 0))
        - (100.0 * SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN read_only_cache_requests_num ELSE 0 END)
            / NULLIF(SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN requests_num ELSE 0 END), 0)),
        2
    ) AS read_only_cache_pct_delta_pp
FROM dws.dws_hotel_flow_didamonitor_supplier_csa_di
WHERE clientid = '{client_id}'
    AND supplierid IN ({sid_list})
    AND log_date >= '{compare_start}' AND log_date <= '{current_end}'
GROUP BY supplierid
HAVING SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN requests_num ELSE 0 END) > 0
    OR SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN requests_num ELSE 0 END) > 0
    OR SUM(CASE WHEN log_date >= '{analysis_date}' AND log_date <= '{current_end}' THEN all_requests_num ELSE 0 END) > 0
    OR SUM(CASE WHEN log_date >= '{compare_start}' AND log_date <= '{compare_end}' THEN all_requests_num ELSE 0 END) > 0
ORDER BY ss_rate_limit_pct_delta_pp DESC NULLS LAST
LIMIT 50;
