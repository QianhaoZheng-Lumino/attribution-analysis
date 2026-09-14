-- 维度贡献度分析 SQL（来源：用户脚本）
-- 在指定 client 范围内，按多维度 GROUPING SETS 计算贡献占比
-- 注意：本 SQL 不能判定 C/Dida/S/CS，需配合交叉验证（见 responsibility-model.md）

WITH params AS (
    SELECT
        '2026-03-20'::date AS analysis_date,
        'SnapEBK' AS client_id,
        'SnapTravel' AS parent_client_id,
        NULLIF('10', '')::int AS n_days
),
date_calculator AS (
    SELECT
        analysis_date,
        client_id,
        parent_client_id,
        n_days,
        (CURRENT_DATE - 1) AS max_date,
        LEAST(analysis_date + 6, CURRENT_DATE - 1) AS legacy_current_end,
        (LEAST(analysis_date + 6, CURRENT_DATE - 1) - analysis_date + 1) AS legacy_current_days,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
            THEN LEAST(analysis_date + n_days - 1, CURRENT_DATE - 1)
            ELSE NULL
        END AS new_current_end,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
            THEN LEAST(analysis_date + n_days - 1, CURRENT_DATE - 1) - analysis_date + 1
            ELSE NULL
        END AS new_current_days
    FROM params
),
decision AS (
    SELECT
        *,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN 1
            ELSE 0
        END AS use_new_logic,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN new_current_end
            ELSE legacy_current_end
        END AS current_end_date,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN new_current_days
            ELSE legacy_current_days
        END AS current_days,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN analysis_date - n_days
            ELSE analysis_date - 7
        END AS compare_start_date,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN analysis_date - 1
            ELSE (analysis_date - 7) + (LEAST(analysis_date + 6, CURRENT_DATE - 1) - analysis_date + 1) - 1
        END AS compare_end_date,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN 1
            WHEN legacy_current_days = 7 THEN 1
            ELSE 0
        END AS is_full_cycle_int,
        CASE
            WHEN n_days IS NOT NULL AND n_days >= 7
                 AND new_current_days IS NOT NULL
                 AND new_current_days >= n_days
            THEN n_days
            ELSE 7
        END AS expected_days,
        LEAST(analysis_date - GREATEST(14, COALESCE(n_days, 0)), analysis_date - 7) AS min_data_date,
        CASE
            WHEN client_id IS NOT NULL AND client_id != '' THEN 'Client ID'
            WHEN parent_client_id IS NOT NULL AND parent_client_id != '' THEN 'Parent Client ID'
            ELSE 'Overseas API (大盘)'
        END AS filter_type
    FROM date_calculator
    WHERE (LEAST(analysis_date + 6, CURRENT_DATE - 1) - analysis_date + 1) > 0
),
base_data AS (
    SELECT
        a.sid,
        a.supplieraccountid,
        b.country_code,
        COALESCE(b.parent_chain_name, 'Independent') AS chain,
        a.channel_nationality AS nationality,
        CASE
            WHEN a.length_of_stay = 1 THEN '1'
            WHEN a.length_of_stay = 2 THEN '2'
            WHEN a.length_of_stay = 3 THEN '3'
            WHEN a.length_of_stay BETWEEN 4 AND 7 THEN '4~7'
            WHEN a.length_of_stay BETWEEN 8 AND 14 THEN '8~14'
            WHEN a.length_of_stay BETWEEN 15 AND 28 THEN '15~28'
            WHEN a.length_of_stay > 28 THEN '>28'
        END AS los,
        CASE
            WHEN a.leading_date BETWEEN -1 AND 0 THEN '-1~0'
            WHEN a.leading_date = 1 THEN '1'
            WHEN a.leading_date = 2 THEN '2'
            WHEN a.leading_date = 3 THEN '3'
            WHEN a.leading_date BETWEEN 4 AND 7 THEN '4~7'
            WHEN a.leading_date BETWEEN 8 AND 14 THEN '8~14'
            WHEN a.leading_date BETWEEN 15 AND 28 THEN '15~28'
            WHEN a.leading_date BETWEEN 29 AND 42 THEN '29~42'
            WHEN a.leading_date BETWEEN 43 AND 70 THEN '43~70'
            WHEN a.leading_date > 70 THEN '>70'
        END AS lt,
        dc.is_full_cycle_int,
        dc.current_days,
        SUM(CASE
            WHEN a.channel_createdate BETWEEN dc.analysis_date AND dc.current_end_date
            THEN 1 ELSE 0
        END) AS current_period_bookings,
        SUM(CASE
            WHEN a.channel_createdate BETWEEN dc.compare_start_date AND dc.compare_end_date
            THEN 1 ELSE 0
        END) AS previous_period_bookings
    FROM public.npd_booking_view AS a
    LEFT JOIN content.dida_hotel_view AS b
        ON a.didahotelid = b.hotel_id
    CROSS JOIN decision dc
    WHERE a.channel_status IN ('Confirmed', 'Canceled')
        AND a.rebook_sequence = 1
        AND (
            CASE
                WHEN dc.client_id != '' AND dc.client_id IS NOT NULL THEN dc.client_id = a.clientid
                WHEN dc.parent_client_id != '' AND dc.parent_client_id IS NOT NULL THEN dc.parent_client_id = a.parentclientid
                ELSE a.clientgroup = 'Overseas API'
            END
        )
        AND a.channel_createdate BETWEEN dc.min_data_date AND dc.current_end_date
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
),
contribution_analysis AS (
    SELECT
        CASE
            WHEN GROUPING(sid) = 1 AND GROUPING(supplieraccountid) = 1
                 AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1
                 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '1_Total'
            WHEN GROUPING(supplieraccountid) = 1 AND GROUPING(country_code) = 1
                 AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1
                 AND GROUPING(lt) = 1 THEN '2_SID'
            WHEN GROUPING(country_code) = 1 AND GROUPING(chain) = 1
                 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '3_SID+Account'
            WHEN GROUPING(sid) = 1 AND GROUPING(supplieraccountid) = 1
                 AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1
                 AND GROUPING(lt) = 1 THEN '4_Country'
            WHEN GROUPING(supplieraccountid) = 1 AND GROUPING(chain) = 1
                 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '5_SID+Country'
            WHEN GROUPING(sid) = 1 AND GROUPING(supplieraccountid) = 1
                 AND GROUPING(country_code) = 1 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1
                 AND GROUPING(lt) = 1 THEN '6_Chain'
            WHEN GROUPING(supplieraccountid) = 1 AND GROUPING(country_code) = 1
                 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '7_SID+Chain'
            WHEN GROUPING(sid) = 1 AND GROUPING(supplieraccountid) = 1
                 AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1
                 AND GROUPING(nationality) = 1
                 AND GROUPING(lt) = 1 THEN '8_LT'
            WHEN GROUPING(supplieraccountid) = 1 AND GROUPING(country_code) = 1
                 AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                 AND GROUPING(lt) = 1 THEN '9_SID+LT'
            WHEN GROUPING(sid) = 1 AND GROUPING(supplieraccountid) = 1
                 AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1
                 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 THEN '10_LOS'
            WHEN GROUPING(supplieraccountid) = 1 AND GROUPING(country_code) = 1
                 AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                 AND GROUPING(los) = 1 THEN '11_SID+LOS'
            WHEN GROUPING(sid) = 1 AND GROUPING(supplieraccountid) = 1
                 AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1
                 AND GROUPING(los) = 1 AND GROUPING(lt) = 1
                 AND GROUPING(nationality) = 0 THEN '12_Nationality'
            WHEN GROUPING(sid) = 0 AND GROUPING(supplieraccountid) = 1 AND GROUPING(country_code) = 1
                 AND GROUPING(chain) = 1 AND GROUPING(los) = 1 AND GROUPING(lt) = 1
                 AND GROUPING(nationality) = 0 THEN '13_SID+Nationality'
            ELSE '其他'
        END AS hierarchy_level,
        CAST(SUBSTRING(
            CASE
                WHEN GROUPING(sid) = 1 AND GROUPING(supplieraccountid) = 1
                     AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1
                     AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '1'
                WHEN GROUPING(supplieraccountid) = 1 AND GROUPING(country_code) = 1
                     AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1
                     AND GROUPING(lt) = 1 THEN '2'
                WHEN GROUPING(country_code) = 1 AND GROUPING(chain) = 1
                     AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '3'
                WHEN GROUPING(sid) = 1 AND GROUPING(supplieraccountid) = 1
                     AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1
                     AND GROUPING(lt) = 1 THEN '4'
                WHEN GROUPING(supplieraccountid) = 1 AND GROUPING(chain) = 1
                     AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '5'
                WHEN GROUPING(sid) = 1 AND GROUPING(supplieraccountid) = 1
                     AND GROUPING(country_code) = 1 AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1
                     AND GROUPING(lt) = 1 THEN '6'
                WHEN GROUPING(supplieraccountid) = 1 AND GROUPING(country_code) = 1
                     AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 AND GROUPING(lt) = 1 THEN '7'
                WHEN GROUPING(sid) = 1 AND GROUPING(supplieraccountid) = 1
                     AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1
                     AND GROUPING(nationality) = 1
                     AND GROUPING(lt) = 1 THEN '8'
                WHEN GROUPING(supplieraccountid) = 1 AND GROUPING(country_code) = 1
                     AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                     AND GROUPING(lt) = 1 THEN '9'
                WHEN GROUPING(sid) = 1 AND GROUPING(supplieraccountid) = 1
                     AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1
                     AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 THEN '10'
                WHEN GROUPING(supplieraccountid) = 1 AND GROUPING(country_code) = 1
                     AND GROUPING(chain) = 1 AND GROUPING(nationality) = 1
                     AND GROUPING(los) = 1 THEN '11'
                WHEN GROUPING(sid) = 1 AND GROUPING(supplieraccountid) = 1
                     AND GROUPING(country_code) = 1 AND GROUPING(chain) = 1
                     AND GROUPING(los) = 1 AND GROUPING(lt) = 1
                     AND GROUPING(nationality) = 0 THEN '12'
                WHEN GROUPING(sid) = 0 AND GROUPING(supplieraccountid) = 1 AND GROUPING(country_code) = 1
                     AND GROUPING(chain) = 1 AND GROUPING(los) = 1 AND GROUPING(lt) = 1
                     AND GROUPING(nationality) = 0 THEN '13'
                ELSE '99'
            END FROM '^([0-9]+)'
        ) AS INTEGER) AS hierarchy_number,
        COALESCE(sid, 'ALL') AS sid,
        COALESCE(supplieraccountid::text, 'ALL') AS supplieraccountid,
        COALESCE(country_code, 'ALL') AS country_code,
        COALESCE(chain, 'ALL') AS chain,
        COALESCE(los, 'ALL') AS los,
        COALESCE(lt, 'ALL') AS lt,
        COALESCE(nationality::text, 'ALL') AS nationality,
        MAX(is_full_cycle_int) AS is_full_cycle_int,
        MAX(current_days) AS current_days_count,
        SUM(current_period_bookings) AS current_bookings,
        SUM(previous_period_bookings) AS previous_bookings,
        SUM(current_period_bookings) - SUM(previous_period_bookings) AS booking_change,
        CASE
            WHEN SUM(SUM(previous_period_bookings)) OVER() = 0 THEN 0
            ELSE (SUM(current_period_bookings) - SUM(previous_period_bookings)) * 100.0
                 / NULLIF(SUM(SUM(previous_period_bookings)) OVER(), 0)
        END AS contribution_percentage,
        CASE
            WHEN SUM(previous_period_bookings) = 0 THEN NULL
            ELSE (SUM(current_period_bookings) - SUM(previous_period_bookings)) * 100.0
                 / NULLIF(SUM(previous_period_bookings), 0)
        END AS change_rate_percentage
    FROM base_data
    GROUP BY GROUPING SETS (
        (),
        (sid),
        (sid, supplieraccountid),
        (country_code),
        (sid, country_code),
        (chain),
        (sid, chain),
        (los),
        (sid, los),
        (lt),
        (sid, lt),
        (nationality),
        (sid, nationality)
    )
    HAVING SUM(current_period_bookings) > 0 OR SUM(previous_period_bookings) > 0
)
SELECT
    dc.analysis_date,
    dc.client_id,
    dc.parent_client_id,
    dc.n_days,
    dc.filter_type,
    CASE WHEN dc.use_new_logic = 1 THEN '新逻辑（前后n天）' ELSE '原逻辑（上周同期）' END AS logic_type,
    ca.hierarchy_level,
    ca.sid,
    ca.supplieraccountid,
    ca.country_code,
    ca.chain,
    ca.los,
    ca.lt,
    ca.nationality,
    CASE
        WHEN ca.is_full_cycle_int = 1 THEN
            CONCAT('完整', dc.expected_days, '天环比对比')
        ELSE CONCAT('部分周期对比（', ca.current_days_count, '天）')
    END AS period_type,
    CONCAT(
        TO_CHAR(dc.analysis_date, 'YYYY-MM-DD'), ' 至 ', TO_CHAR(dc.current_end_date, 'YYYY-MM-DD'),
        ' (', ca.current_days_count, '天) vs ',
        TO_CHAR(dc.compare_start_date, 'YYYY-MM-DD'), ' 至 ', TO_CHAR(dc.compare_end_date, 'YYYY-MM-DD'),
        ' (', ca.current_days_count, '天)'
    ) AS comparison_range,
    ca.current_bookings,
    ca.previous_bookings,
    ca.booking_change,
    ROUND(ca.contribution_percentage::numeric, 2) AS contribution_percentage,
    ROUND(ca.change_rate_percentage::numeric, 2) AS change_rate_percentage,
    CASE
        WHEN ca.booking_change > 0 THEN '上升'
        WHEN ca.booking_change < 0 THEN '下降'
        ELSE '持平'
    END AS trend_direction
FROM contribution_analysis ca
CROSS JOIN (
    SELECT analysis_date, client_id, parent_client_id, n_days, filter_type, use_new_logic,
           current_end_date, compare_start_date, compare_end_date, expected_days
    FROM decision
) dc
WHERE ca.booking_change <> 0
ORDER BY
    ca.hierarchy_number,
    ABS(ca.contribution_percentage) DESC
