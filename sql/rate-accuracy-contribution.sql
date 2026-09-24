/* Phase 3c 验价准确率贡献（用户 SQL2 完整版） */
/* BI 专用；MCP 请用 rate-accuracy-contribution-lite/ 分批 */
/* 参数块与 dimension-contribution.sql 一致 */

/* 定义参数 */
WITH params AS (
    SELECT 
        '2026-03-20'::date as analysis_date,
        'SnapEBK' as client_id,
        'SnapTravel' as parent_client_id,
        NULLIF('10', '')::int as n_days
),
/* 计算智能日期范围（排除今天） */
date_calculator AS (
    SELECT 
        analysis_date,
        client_id,
        parent_client_id,
        n_days,
        (CURRENT_DATE - 1) as max_date,
        LEAST(analysis_date + 6, CURRENT_DATE - 1) as legacy_current_end,
        (LEAST(analysis_date + 6, CURRENT_DATE - 1) - analysis_date + 1) as legacy_current_days,
        CASE 
            WHEN n_days IS NOT NULL AND n_days >= 7 
            THEN LEAST(analysis_date + n_days - 1, CURRENT_DATE - 1)
            ELSE NULL
        END as new_current_end,
        CASE 
            WHEN n_days IS NOT NULL AND n_days >= 7 
            THEN LEAST(analysis_date + n_days - 1, CURRENT_DATE - 1) - analysis_date + 1
            ELSE NULL
        END as new_current_days
    FROM params
),
/* 决策：使用哪种逻辑 */
decision AS (
    SELECT 
        *,
        CASE 
            WHEN n_days IS NOT NULL AND n_days >= 7 
                 AND new_current_days IS NOT NULL 
                 AND new_current_days >= n_days
            THEN 1
            ELSE 0
        END as use_new_logic,
        CASE 
            WHEN n_days IS NOT NULL AND n_days >= 7 
                 AND new_current_days IS NOT NULL 
                 AND new_current_days >= n_days
            THEN new_current_end
            ELSE legacy_current_end
        END as current_end_date,
        CASE 
            WHEN n_days IS NOT NULL AND n_days >= 7 
                 AND new_current_days IS NOT NULL 
                 AND new_current_days >= n_days
            THEN new_current_days
            ELSE legacy_current_days
        END as current_days,
        CASE 
            WHEN n_days IS NOT NULL AND n_days >= 7 
                 AND new_current_days IS NOT NULL 
                 AND new_current_days >= n_days
            THEN analysis_date - n_days
            ELSE analysis_date - 7
        END as compare_start_date,
        CASE 
            WHEN n_days IS NOT NULL AND n_days >= 7 
                 AND new_current_days IS NOT NULL 
                 AND new_current_days >= n_days
            THEN analysis_date - 1
            ELSE (analysis_date - 7) + (LEAST(analysis_date + 6, CURRENT_DATE - 1) - analysis_date + 1) - 1
        END as compare_end_date,
        CASE 
            WHEN n_days IS NOT NULL AND n_days >= 7 
                 AND new_current_days IS NOT NULL 
                 AND new_current_days >= n_days
            THEN 1
            WHEN legacy_current_days = 7 THEN 1
            ELSE 0
        END as is_full_cycle_int,
        CASE 
            WHEN n_days IS NOT NULL AND n_days >= 7 
                 AND new_current_days IS NOT NULL 
                 AND new_current_days >= n_days
            THEN n_days
            ELSE 7
        END as expected_days,
        LEAST(analysis_date - GREATEST(14, COALESCE(n_days, 0)), analysis_date - 7) as min_data_date,
        /* 新增：过滤维度类型 */
        CASE 
            WHEN client_id IS NOT NULL AND client_id != '' THEN 'Client ID'
            WHEN parent_client_id IS NOT NULL AND parent_client_id != '' THEN 'Parent Client ID'
            ELSE 'Overseas API (大盘)'
        END as filter_type
    FROM date_calculator
    WHERE (LEAST(analysis_date + 6, CURRENT_DATE - 1) - analysis_date + 1) > 0
),
/* 基础数据：data_ovs.rate_accuracy_channel_multi_dimension */
/* dt=同步分区日；log_date=业务日；los/lt 已为分桶字段，不再 CASE */
base_data AS (
    SELECT 
        t.supplier_id,
        t.supplier_account_id,
        t.country_code,
        COALESCE(t.chain, 'Independent') as chain,
        t.nationality,
        t.los,
        t.lt,
        dc.is_full_cycle_int,
        dc.current_days,
        SUM(CASE 
            WHEN t.log_date BETWEEN dc.analysis_date AND dc.current_end_date 
            THEN t.precheck ELSE 0 
        END) as current_precheck,
        SUM(CASE 
            WHEN t.log_date BETWEEN dc.compare_start_date AND dc.compare_end_date 
            THEN t.precheck ELSE 0 
        END) as previous_precheck,
        SUM(CASE 
            WHEN t.log_date BETWEEN dc.analysis_date AND dc.current_end_date 
            THEN t.success_precheck ELSE 0 
        END) as current_success_precheck,
        SUM(CASE 
            WHEN t.log_date BETWEEN dc.compare_start_date AND dc.compare_end_date 
            THEN t.success_precheck ELSE 0 
        END) as previous_success_precheck
    FROM data_ovs.rate_accuracy_channel_multi_dimension t
    CROSS JOIN decision dc
    WHERE t.dt = CURRENT_DATE
        AND t.log_date BETWEEN dc.min_data_date AND dc.current_end_date
        AND (
            (dc.client_id IS NOT NULL AND dc.client_id != '' AND t.client_id = dc.client_id)
            OR
            ((dc.client_id IS NULL OR dc.client_id = '') AND dc.parent_client_id IS NOT NULL AND dc.parent_client_id != '' AND t.parent_client_id = dc.parent_client_id)
        )
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
),
contribution_analysis AS (
    SELECT 
        CASE 
            WHEN GROUPING(supplier_id) = 1 AND GROUPING(supplier_account_id) = 1 
                 AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1 
                 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '1_Total'
            WHEN GROUPING(supplier_account_id) = 1 AND GROUPING(country_code) = 1 
                 AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 
                 AND GROUPING(lt) = 1 THEN '2_SID'
            WHEN GROUPING(country_code) = 1 AND GROUPING(chain) = 1 
                 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '3_SID+Account'
            WHEN GROUPING(supplier_id) = 1 AND GROUPING(supplier_account_id) = 1 
                 AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 
                 AND GROUPING(lt) = 1 THEN '4_Country'
            WHEN GROUPING(supplier_account_id) = 1 AND GROUPING(chain) = 1 
                 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '5_SID+Country'
            WHEN GROUPING(supplier_id) = 1 AND GROUPING(supplier_account_id) = 1 
                 AND GROUPING(country_code) = 1 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 
                 AND GROUPING(lt) = 1 THEN '6_Chain'
            WHEN GROUPING(supplier_account_id) = 1 AND GROUPING(country_code) = 1 
                 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '7_SID+Chain'
            WHEN GROUPING(supplier_id) = 1 AND GROUPING(supplier_account_id) = 1 
                 AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1 
                 AND GROUPING(nationality) = 1
                 AND GROUPING(lt) = 1 THEN '8_LT'
            WHEN GROUPING(supplier_account_id) = 1 AND GROUPING(country_code) = 1 
                 AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                 AND GROUPING(lt) = 1 THEN '9_SID+LT'
            WHEN GROUPING(supplier_id) = 1 AND GROUPING(supplier_account_id) = 1 
                 AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1 
                 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 THEN '10_LOS'
            WHEN GROUPING(supplier_account_id) = 1 AND GROUPING(country_code) = 1 
                 AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 THEN '11_SID+LOS'
            WHEN GROUPING(supplier_id) = 1 AND GROUPING(supplier_account_id) = 1 
                 AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1 
                 AND GROUPING(los) = 1 AND GROUPING(lt) = 1 
                 AND GROUPING(nationality) = 0 THEN '12_Nationality'
            WHEN GROUPING(supplier_id) = 0 AND GROUPING(supplier_account_id) = 1 AND GROUPING(country_code) = 1 
                 AND GROUPING(chain) = 1 AND GROUPING(los) = 1 AND GROUPING(lt) = 1 
                 AND GROUPING(nationality) = 0 THEN '13_SID+Nationality'
            ELSE '其他'
        END as hierarchy_level,
        CAST(SUBSTRING(
            CASE 
                WHEN GROUPING(supplier_id) = 1 AND GROUPING(supplier_account_id) = 1 
                     AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1 
                     AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '1'
                WHEN GROUPING(supplier_account_id) = 1 AND GROUPING(country_code) = 1 
                     AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 
                     AND GROUPING(lt) = 1 THEN '2'
                WHEN GROUPING(country_code) = 1 AND GROUPING(chain) = 1 
                     AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '3'
                WHEN GROUPING(supplier_id) = 1 AND GROUPING(supplier_account_id) = 1 
                     AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 
                     AND GROUPING(lt) = 1 THEN '4'
                WHEN GROUPING(supplier_account_id) = 1 AND GROUPING(chain) = 1 
                     AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '5'
                WHEN GROUPING(supplier_id) = 1 AND GROUPING(supplier_account_id) = 1 
                     AND GROUPING(country_code) = 1 AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 
                     AND GROUPING(lt) = 1 THEN '6'
                WHEN GROUPING(supplier_account_id) = 1 AND GROUPING(country_code) = 1 
                     AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '7'
                WHEN GROUPING(supplier_id) = 1 AND GROUPING(supplier_account_id) = 1 
                     AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1 
                     AND GROUPING(nationality) = 1
                     AND GROUPING(lt) = 1 THEN '8'
                WHEN GROUPING(supplier_account_id) = 1 AND GROUPING(country_code) = 1 
                     AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                     AND GROUPING(lt) = 1 THEN '9'
                WHEN GROUPING(supplier_id) = 1 AND GROUPING(supplier_account_id) = 1 
                     AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1 
                     AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 THEN '10'
                WHEN GROUPING(supplier_account_id) = 1 AND GROUPING(country_code) = 1 
                     AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 THEN '11'
                WHEN GROUPING(supplier_id) = 1 AND GROUPING(supplier_account_id) = 1 
                     AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1 
                     AND GROUPING(los) = 1 AND GROUPING(lt) = 1 
                     AND GROUPING(nationality) = 0 THEN '12'
                WHEN GROUPING(supplier_id) = 0 AND GROUPING(supplier_account_id) = 1 AND GROUPING(country_code) = 1 
                     AND GROUPING(chain) = 1 AND GROUPING(los) = 1 AND GROUPING(lt) = 1 
                     AND GROUPING(nationality) = 0 THEN '13'
                ELSE '99'
            END FROM '^([0-9]+)'
        ) AS INTEGER) as hierarchy_number,
        COALESCE(supplier_id::text, 'ALL') as supplier_id,
        COALESCE(supplier_account_id::text, 'ALL') as supplier_account_id,
        COALESCE(country_code, 'ALL') as country_code,
        COALESCE(chain, 'ALL') as chain,
        COALESCE(los, 'ALL') as los,
        COALESCE(lt, 'ALL') as lt,
        COALESCE(nationality::text, 'ALL') as nationality,
        MAX(is_full_cycle_int) as is_full_cycle_int,
        MAX(current_days) as current_days_count,
        SUM(current_precheck) as current_precheck,
        SUM(previous_precheck) as previous_precheck,
        SUM(current_success_precheck) as current_success_precheck,
        SUM(previous_success_precheck) as previous_success_precheck
    FROM base_data
    GROUP BY GROUPING SETS (
        (),
        (supplier_id),
        (supplier_id, supplier_account_id),
        (country_code),
        (supplier_id, country_code),
        (chain),
        (supplier_id, chain),
        (los),
        (supplier_id, los),
        (lt),
        (supplier_id, lt),
        (nationality),
        (supplier_id, nationality)
    )
    HAVING SUM(current_precheck) > 0 OR SUM(previous_precheck) > 0
        OR SUM(current_success_precheck) > 0 OR SUM(previous_success_precheck) > 0
)
,
final_base AS (
    SELECT 
        dc.analysis_date,
        dc.client_id,
        dc.parent_client_id,
        dc.n_days,
        dc.filter_type,
        CASE WHEN dc.use_new_logic = 1 THEN '新逻辑（前后n天）' ELSE '原逻辑（上周同期）' END as logic_type,
        ca.hierarchy_level,
        ca.hierarchy_number,
        ca.supplier_id,
        ca.supplier_account_id,
        ca.country_code,
        ca.chain,
        ca.los,
        ca.lt,
        ca.nationality,
        CASE 
            WHEN ca.is_full_cycle_int = 1 THEN 
                CONCAT('完整', dc.expected_days, '天环比对比')
            ELSE CONCAT('部分周期对比（', ca.current_days_count, '天）')
        END as period_type,
        CONCAT(
            TO_CHAR(dc.analysis_date, 'YYYY-MM-DD'), ' 至 ', TO_CHAR(dc.current_end_date, 'YYYY-MM-DD'),
            ' (', ca.current_days_count, '天) vs ',
            TO_CHAR(dc.compare_start_date, 'YYYY-MM-DD'), ' 至 ', TO_CHAR(dc.compare_end_date, 'YYYY-MM-DD'),
            ' (', ca.current_days_count, '天)'
        ) as comparison_range,
        ca.current_precheck,
        ca.previous_precheck,
        ca.current_success_precheck,
        ca.previous_success_precheck,
        ca.current_success_precheck::numeric / NULLIF(ca.current_precheck, 0) as current_accuracy,
        ca.previous_success_precheck::numeric / NULLIF(ca.previous_precheck, 0) as previous_accuracy
    FROM contribution_analysis ca
    CROSS JOIN (
        SELECT analysis_date, client_id, parent_client_id, n_days, filter_type, use_new_logic,
               current_end_date, compare_start_date, compare_end_date, expected_days
        FROM decision
    ) dc
),
final_calc AS (
    SELECT
        fb.*,
        (fb.current_precheck - fb.previous_precheck) as precheck_change,
        (fb.current_accuracy - fb.previous_accuracy) * 100 as item_accuracy_delta_pp,
        /* 层内分解（within 口径）：上期权重 * 子项准确率变化 */
        (fb.previous_precheck::numeric
            / NULLIF(SUM(fb.previous_precheck) OVER (PARTITION BY fb.hierarchy_level), 0))
        * ((fb.current_accuracy - fb.previous_accuracy) * 100) as within_contribution_pp,
        (
            (SUM(fb.current_success_precheck) OVER (PARTITION BY fb.hierarchy_level)::numeric
                / NULLIF(SUM(fb.current_precheck) OVER (PARTITION BY fb.hierarchy_level), 0))
            -
            (SUM(fb.previous_success_precheck) OVER (PARTITION BY fb.hierarchy_level)::numeric
                / NULLIF(SUM(fb.previous_precheck) OVER (PARTITION BY fb.hierarchy_level), 0))
        ) * 100 as layer_accuracy_delta_pp
    FROM final_base fb
)
SELECT
    fc.*,
    /* precheck 贡献度（按你的口径：本行变化 / Total变化） */
    fc.precheck_change::numeric
        / NULLIF(
            MAX(CASE WHEN fc.hierarchy_level = '1_Total' THEN fc.precheck_change END) OVER (),
            0
        )
        as contribution_pct_precheck,
    fc.within_contribution_pp
        / NULLIF(SUM(fc.within_contribution_pp) OVER (PARTITION BY fc.hierarchy_level), 0)
        as within_contribution_ratio
FROM final_calc fc
ORDER BY 
    fc.hierarchy_number,
    fc.current_precheck DESC;
</user_query>