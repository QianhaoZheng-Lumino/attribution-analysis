/* Phase 3b 查价归因（有价率 + 查验比）— 用户 SQL1 完整版 */
/* BI 专用；MCP 请用 search-attribution-lite/ 分批 */
/* 参数块与 dimension-contribution.sql 一致 */

/* 定义参数 */
WITH params AS (
    SELECT 
        '2026-04-10'::date as analysis_date,
        'NuiteeLMB' as client_id,
        '' as parent_client_id,
        NULLIF('10', '')::int as n_days
),
/* 日期计算逻辑（保持不变） */
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
        LEAST(analysis_date - GREATEST(14, COALESCE(n_days, 0)), analysis_date - 7) as min_data_date,
        CASE 
            WHEN client_id IS NOT NULL AND client_id != '' THEN 'Client ID'
            WHEN parent_client_id IS NOT NULL AND parent_client_id != '' THEN 'Parent Client ID'
            ELSE ''
        END as filter_type
    FROM date_calculator
    WHERE (LEAST(analysis_date + 6, CURRENT_DATE - 1) - analysis_date + 1) > 0
),
rp_base as (
SELECT 
    supplier_id,
    country_code,
    chain,
    nationality,
    los,
    lt,
    SUM(CASE 
        WHEN a.log_date BETWEEN dc.analysis_date AND dc.current_end_date 
        THEN 1 ELSE 0 
    END) as current_period_precheck,
    SUM(CASE 
        WHEN a.log_date BETWEEN dc.compare_start_date AND dc.compare_end_date 
        THEN 1 ELSE 0 
    END) as previous_period_precheck
FROM data_ovs.rate_accuracy_channel_multi_dimension as a 
CROSS JOIN decision dc
WHERE a.dt = current_date
    AND a.log_date BETWEEN dc.min_data_date AND dc.current_end_date
    AND (
        (dc.client_id != '' AND dc.client_id IS NOT NULL AND a.client_id = dc.client_id)
        OR
        (dc.parent_client_id != '' AND dc.parent_client_id IS NOT NULL AND a.parent_client_id = dc.parent_client_id)
        OR
        ((dc.client_id IS NULL OR dc.client_id = '') 
         AND (dc.parent_client_id IS NULL OR dc.parent_client_id = ''))
    )
GROUP BY 1,2,3,4,5,6
),
precheck as (
select 'Supplier' AS hierarchy_level, supplier_id AS index
, sum(current_period_precheck) as current_period_precheck
, sum(previous_period_precheck) as previous_period_precheck
from rp_base 
WHERE supplier_id IS NOT NULL AND supplier_id != ''
GROUP BY supplier_id
union all
select 'Chain' AS hierarchy_level, chain AS index
, sum(current_period_precheck) as current_period_precheck
, sum(previous_period_precheck) as previous_period_precheck
from rp_base 
WHERE chain IS NOT NULL AND chain != ''
GROUP BY chain
union all
select 'Nationality' AS hierarchy_level, nationality AS index
, sum(current_period_precheck) as current_period_precheck
, sum(previous_period_precheck) as previous_period_precheck
from rp_base 
WHERE nationality IS NOT NULL AND nationality != ''
GROUP BY nationality
union all 
select 'Country' AS hierarchy_level, country_code AS index
, sum(current_period_precheck) as current_period_precheck
, sum(previous_period_precheck) as previous_period_precheck
from rp_base 
WHERE country_code IS NOT NULL AND country_code != ''
GROUP BY country_code
union all 
select 'LOS' AS hierarchy_level, los AS index
, sum(current_period_precheck) as current_period_precheck
, sum(previous_period_precheck) as previous_period_precheck
from rp_base 
WHERE los IS NOT NULL AND los != ''
GROUP BY los
union all 
select 'LeadTime' AS hierarchy_level, lt AS index
, sum(current_period_precheck) as current_period_precheck
, sum(previous_period_precheck) as previous_period_precheck
from rp_base 
WHERE lt IS NOT NULL AND lt != ''
GROUP BY lt
), 

los as (
select 'DidaBiz QPS' as db_level 
, 'LOS' as hierarchy_level 
, case when los = 1 then '1'
    when los = 2 then '2'
    when los = 3 then '3'
    when los >= 4 and los <= 7 then '4~7'
    when los >= 8 and los <= 14 then '8~14'
    when los >= 15 and los <= 28 then '15~28'
    when los > 28 then '>28' end as index 
, SUM(CASE WHEN a.date BETWEEN (SELECT analysis_date FROM decision) AND (SELECT current_end_date FROM decision) THEN amount ELSE 0 END) as current_total_search 
, SUM(CASE WHEN a.date BETWEEN (SELECT compare_start_date FROM decision) AND (SELECT compare_end_date FROM decision) THEN amount ELSE 0 END) as previous_total_search
, SUM(CASE WHEN a.date BETWEEN (SELECT analysis_date FROM decision) AND (SELECT current_end_date FROM decision) THEN activeamount ELSE 0 END) as current_avail_search 
, SUM(CASE WHEN a.date BETWEEN (SELECT compare_start_date FROM decision) AND (SELECT compare_end_date FROM decision) THEN activeamount ELSE 0 END) as previous_avail_search
from public.clientloscallcount as a 
INNER JOIN crm.client_info_ods b ON a.clientid = b.client_id 
WHERE a.date BETWEEN (SELECT min_data_date FROM decision) AND (SELECT current_end_date FROM decision)
    AND b.client_group_id = 3
    AND a.biztype in ('HotelRateSearch_RealTime_MultiHotel', 'HotelRateSearch_RealTime_SingleHotel', 'HotelRateSearch_Cache_MultiHotel')
    AND (
        ((SELECT client_id FROM decision) != '' AND (SELECT client_id FROM decision) IS NOT NULL AND a.clientid = (SELECT client_id FROM decision))
        OR
        ((SELECT parent_client_id FROM decision) != '' AND (SELECT parent_client_id FROM decision) IS NOT NULL AND b.parent_client_id = (SELECT parent_client_id FROM decision))
        OR
        ((SELECT client_id FROM decision) IS NULL OR (SELECT client_id FROM decision) = '') 
        AND ((SELECT parent_client_id FROM decision) IS NULL OR (SELECT parent_client_id FROM decision) = ''))
    )
group by 1,2,3
),
nationlity as (
select 'DidaBiz QPS' as db_level  
, 'Nationality' as hierarchy_level 
, nationality as index
, SUM(CASE WHEN a.date BETWEEN (SELECT analysis_date FROM decision) AND (SELECT current_end_date FROM decision) THEN amount ELSE 0 END) as current_total_search 
, SUM(CASE WHEN a.date BETWEEN (SELECT compare_start_date FROM decision) AND (SELECT compare_end_date FROM decision) THEN amount ELSE 0 END) as previous_total_search
, SUM(CASE WHEN a.date BETWEEN (SELECT analysis_date FROM decision) AND (SELECT current_end_date FROM decision) THEN activeamount ELSE 0 END) as current_avail_search 
, SUM(CASE WHEN a.date BETWEEN (SELECT compare_start_date FROM decision) AND (SELECT compare_end_date FROM decision) THEN activeamount ELSE 0 END) as previous_avail_search
from public.clientnationalitycallcount as a 
INNER JOIN crm.client_info_ods b ON a.clientid = b.client_id 
WHERE a.date BETWEEN (SELECT min_data_date FROM decision) AND (SELECT current_end_date FROM decision)
    AND b.client_group_id = 3
    AND a.biztype in ('HotelRateSearch_RealTime_MultiHotel', 'HotelRateSearch_RealTime_SingleHotel', 'HotelRateSearch_Cache_MultiHotel')
    AND (
        ((SELECT client_id FROM decision) != '' AND (SELECT client_id FROM decision) IS NOT NULL AND a.clientid = (SELECT client_id FROM decision))
        OR
        ((SELECT parent_client_id FROM decision) != '' AND (SELECT parent_client_id FROM decision) IS NOT NULL AND b.parent_client_id = (SELECT parent_client_id FROM decision))
        OR
        ((SELECT client_id FROM decision) IS NULL OR (SELECT client_id FROM decision) = '') 
        AND ((SELECT parent_client_id FROM decision) IS NULL OR (SELECT parent_client_id FROM decision) = ''))
    )
group by 1,2,3
), 
leadtime as (
select 'DidaBiz QPS' as db_level  
, 'LeadTime' as hierarchy_level 
, case when leadtime >= -1 and leadtime <= 0 then '-1~0'
    when leadtime = 1 then '1'
    when leadtime = 2 then '2'
    when leadtime = 3 then '3'
    when leadtime >= 4 and leadtime <= 7 then '4~7'
    when leadtime >= 8 and leadtime <= 14 then '8~14'
    when leadtime >= 15 and leadtime <= 28 then '15~28'
    when leadtime >= 29 and leadtime <= 42 then '29~42'
    when leadtime >= 43 and leadtime <= 70 then '43~70'
    when leadtime > 70 then '>70' end as index
, SUM(CASE WHEN a.date BETWEEN (SELECT analysis_date FROM decision) AND (SELECT current_end_date FROM decision) THEN amount ELSE 0 END) as current_total_search 
, SUM(CASE WHEN a.date BETWEEN (SELECT compare_start_date FROM decision) AND (SELECT compare_end_date FROM decision) THEN amount ELSE 0 END) as previous_total_search
, SUM(CASE WHEN a.date BETWEEN (SELECT analysis_date FROM decision) AND (SELECT current_end_date FROM decision) THEN activeamount ELSE 0 END) as current_avail_search 
, SUM(CASE WHEN a.date BETWEEN (SELECT compare_start_date FROM decision) AND (SELECT compare_end_date FROM decision) THEN activeamount ELSE 0 END) as previous_avail_search
from public.clientleadtimecallcount as a 
INNER JOIN crm.client_info_ods b ON a.clientid = b.client_id 
WHERE a.date BETWEEN (SELECT min_data_date FROM decision) AND (SELECT current_end_date FROM decision)
    AND b.client_group_id = 3
    AND a.biztype in ('HotelRateSearch_RealTime_MultiHotel', 'HotelRateSearch_RealTime_SingleHotel', 'HotelRateSearch_Cache_MultiHotel')
    AND (
        ((SELECT client_id FROM decision) != '' AND (SELECT client_id FROM decision) IS NOT NULL AND a.clientid = (SELECT client_id FROM decision))
        OR
        ((SELECT parent_client_id FROM decision) != '' AND (SELECT parent_client_id FROM decision) IS NOT NULL AND b.parent_client_id = (SELECT parent_client_id FROM decision))
        OR
        ((SELECT client_id FROM decision) IS NULL OR (SELECT client_id FROM decision) = '') 
        AND ((SELECT parent_client_id FROM decision) IS NULL OR (SELECT parent_client_id FROM decision) = ''))
    )
    AND leadtime >= -1
group by 1,2,3
),
country as (
select 'DidaBiz PPS' as db_level 
, 'Country' as hierarchy_level 
, country_code as index
, SUM(CASE WHEN a.date BETWEEN (SELECT analysis_date FROM decision) AND (SELECT current_end_date FROM decision) THEN total_count ELSE 0 END) as current_total_search 
, SUM(CASE WHEN a.date BETWEEN (SELECT compare_start_date FROM decision) AND (SELECT compare_end_date FROM decision) THEN total_count ELSE 0 END) as previous_total_search
, SUM(CASE WHEN a.date BETWEEN (SELECT analysis_date FROM decision) AND (SELECT current_end_date FROM decision) THEN availiblity_count ELSE 0 END) as current_avail_search 
, SUM(CASE WHEN a.date BETWEEN (SELECT compare_start_date FROM decision) AND (SELECT compare_end_date FROM decision) THEN availiblity_count ELSE 0 END) as previous_avail_search
from data_ovs.didamonitor_funnel_client_country as a 
WHERE a.date BETWEEN (SELECT min_data_date FROM decision) AND (SELECT current_end_date FROM decision)
    AND (
        ((SELECT client_id FROM decision) != '' AND (SELECT client_id FROM decision) IS NOT NULL AND a.client_id = (SELECT client_id FROM decision))
        OR
        ((SELECT parent_client_id FROM decision) != '' AND (SELECT parent_client_id FROM decision) IS NOT NULL AND a.parent_client_id = (SELECT parent_client_id FROM decision))
        OR
        ((SELECT client_id FROM decision) IS NULL OR (SELECT client_id FROM decision) = '') 
        AND ((SELECT parent_client_id FROM decision) IS NULL OR (SELECT parent_client_id FROM decision) = ''))
    )
    AND a.dt = current_date 
group by 1,2,3
),
chain as (
select 'DidaBiz PPS' as db_level 
, 'Chain' as hierarchy_level 
, parent_chain_name as index
, SUM(CASE WHEN a.date BETWEEN (SELECT analysis_date FROM decision) AND (SELECT current_end_date FROM decision) THEN total_count ELSE 0 END) as current_total_search 
, SUM(CASE WHEN a.date BETWEEN (SELECT compare_start_date FROM decision) AND (SELECT compare_end_date FROM decision) THEN total_count ELSE 0 END) as previous_total_search
, SUM(CASE WHEN a.date BETWEEN (SELECT analysis_date FROM decision) AND (SELECT current_end_date FROM decision) THEN availiblity_count ELSE 0 END) as current_avail_search 
, SUM(CASE WHEN a.date BETWEEN (SELECT compare_start_date FROM decision) AND (SELECT compare_end_date FROM decision) THEN availiblity_count ELSE 0 END) as previous_avail_search
from data_ovs.didamonitor_funnel_client_chain as a 
WHERE a.date BETWEEN (SELECT min_data_date FROM decision) AND (SELECT current_end_date FROM decision)
    AND (
        ((SELECT client_id FROM decision) != '' AND (SELECT client_id FROM decision) IS NOT NULL AND a.client_id = (SELECT client_id FROM decision))
        OR
        ((SELECT parent_client_id FROM decision) != '' AND (SELECT parent_client_id FROM decision) IS NOT NULL AND a.parent_client_id = (SELECT parent_client_id FROM decision))
        OR
        ((SELECT client_id FROM decision) IS NULL OR (SELECT client_id FROM decision) = '') 
        AND ((SELECT parent_client_id FROM decision) IS NULL OR (SELECT parent_client_id FROM decision) = ''))
    )
    AND a.dt = current_date 
group by 1,2,3
),
supplier as (
select 'SS' as db_level  
, 'Supplier' as hierarchy_level 
, supplierid::text as index
, SUM(CASE WHEN a.date BETWEEN (SELECT analysis_date FROM decision) AND (SELECT current_end_date FROM decision) THEN hotelcallamount ELSE 0 END) as current_total_search 
, SUM(CASE WHEN a.date BETWEEN (SELECT compare_start_date FROM decision) AND (SELECT compare_end_date FROM decision) THEN hotelcallamount ELSE 0 END) as previous_total_search
, SUM(CASE WHEN a.date BETWEEN (SELECT analysis_date FROM decision) AND (SELECT current_end_date FROM decision) THEN availcallamount ELSE 0 END) as current_avail_search 
, SUM(CASE WHEN a.date BETWEEN (SELECT compare_start_date FROM decision) AND (SELECT compare_end_date FROM decision) THEN availcallamount ELSE 0 END) as previous_avail_search
from public.clientsupplierhotelcallcountsummary as a 
INNER JOIN crm.client_info_ods b ON a.clientid = b.client_id 
WHERE a.date BETWEEN (SELECT min_data_date FROM decision) AND (SELECT current_end_date FROM decision)
    AND (
        ((SELECT client_id FROM decision) != '' AND (SELECT client_id FROM decision) IS NOT NULL AND a.clientid = (SELECT client_id FROM decision))
        OR
        ((SELECT parent_client_id FROM decision) != '' AND (SELECT parent_client_id FROM decision) IS NOT NULL AND b.parent_client_id = (SELECT parent_client_id FROM decision))
        OR
        ((SELECT client_id FROM decision) IS NULL OR (SELECT client_id FROM decision) = '') 
        AND ((SELECT parent_client_id FROM decision) IS NULL OR (SELECT parent_client_id FROM decision) = ''))
    )
group by 1,2,3
)
SELECT 
    (SELECT analysis_date FROM decision) as analysis_date,
    (SELECT client_id FROM decision) as client_id,
    (SELECT parent_client_id FROM decision) as parent_client_id,
    (SELECT n_days FROM decision) as n_days,
    (SELECT filter_type FROM decision) as filter_type,
    CASE WHEN (SELECT use_new_logic FROM decision) = 1 THEN '新逻辑（前后n天）' ELSE '原逻辑（上周同期）' END as logic_type,
    (SELECT current_end_date FROM decision) as current_end_date,
    (SELECT compare_start_date FROM decision) as compare_start_date,
    (SELECT compare_end_date FROM decision) as compare_end_date,
    (SELECT current_days FROM decision) as current_days,
    t.db_level,
    t.hierarchy_level,
    t.index,
    t.current_total_search,
    t.previous_total_search,
    t.current_avail_search,
    t.previous_avail_search,
    coalesce(p.current_period_precheck,0) current_period_precheck,
    coalesce(p.previous_period_precheck,0) previous_period_precheck
FROM (
    select * from nationlity 
    union all select * from los 
    union all select * from leadtime
    union all select * from country 
    union all select * from chain 
    union all select * from supplier
) as t
left join precheck as p on t.hierarchy_level = p.hierarchy_level and t.index = p.index;
