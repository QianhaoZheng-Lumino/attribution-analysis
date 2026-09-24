/* Phase 3 内部配置变更检测（14 类 level + CDH/LCDH 酒店级产量） */
/* 来源：用户脚本 + Configuration union + 酒店级 before/after */

WITH params AS (
    SELECT 
        '2026-04-29'::date as analysis_date,
        'NuiteeLMB' as client_id,
        '' as parent_client_id
/* NULLIF('10', '')::int as n_days */
)
, pid as (
select client_id 
from crm.client_info_ods
where (parent_client_id in (select parent_client_id from params) or client_id in (select client_id from params))
and istest_account is false and client_group_id = 3
)
, cs_operation as (
select level, clientid, supplierid, 0 as supplieraccountid, updatedate, username
, CONCAT_WS('; ', 
    supplierhoteldefaultstatus_operation, 
    status_operation, 
    margin_operation, 
    new_supplier
) as operation 
, case when supplierhoteldefaultstatus_operation is not null or status_operation is not null then '开关房'
        when margin_operation is not null then '调价'
        when new_supplier is not null then '新上线'
        end as category 
from (
select level, clientid, supplierid, supplierhoteldefaultstatus, status, margin, updatedate, username
, last_supplierhoteldefaultstatus, last_status, last_margin
, case when supplierhoteldefaultstatus != last_supplierhoteldefaultstatus 
        then 
                case when last_supplierhoteldefaultstatus = 0 and supplierhoteldefaultstatus = 1 then 'CS酒店默认状态：关->开'
                when last_supplierhoteldefaultstatus = 1 and supplierhoteldefaultstatus = 0 then 'CS酒店默认状态：开->关'
                end 
        else null end as supplierhoteldefaultstatus_operation 
, case when status != last_status 
        then 
                case when last_status = 0 and status = 1 then 'CS开关房：关->开'
                when last_status = 1 and status = 0 then 'CS开关房：开->关'
                end 
        else null end as status_operation 
, case when margin != last_margin then 'CS调价：'||round(last_margin,2)||'->'||round(margin,2) else null end as margin_operation
, case when last_status is null then '新供应商上线' else null end as new_supplier
from (
select level, clientid, supplierid, supplierhoteldefaultstatus, status, margin, updatedate, username
, lag(supplierhoteldefaultstatus) over(partition by level, clientid, supplierid order by updatedate) as last_supplierhoteldefaultstatus
, lag(status) over(partition by level, clientid, supplierid order by updatedate) as last_status 
, lag(margin) over(partition by level, clientid, supplierid order by updatedate) as last_margin
from configuration.wolf_rateadjust_log
where level = 'CS' 
/* and clientid = '$val{client_id}' */
/* and ( */
/* ((select client_id from params) != '' and (select client_id from params) is not null and clientid = (select client_id from params)) */
/* or */
/* (clientid in (select client_id from pid)) */
/* ) */
and clientid in (select client_id from pid)
order by clientid, supplierid, updatedate
) as a 
/* where updatedate >= now() - interval '$val{day_range} days' */
where updatedate::date >= (SELECT analysis_date FROM params) - interval '1 days' and updatedate::date <= (SELECT analysis_date FROM params) + interval '1 days'
) as a 
)
, c_operation as (
select level, clientid, 0 as supplierid, 0 as supplieraccountid, updatedate, username
, CONCAT_WS('; ', 
    didahoteldefaultstatus_operation, 
    status_operation, 
    margin_operation, 
    cutoffdays_operation, 
                cancellationcutoffdays_operation
) as operation 
, case when didahoteldefaultstatus_operation is not null or status_operation is not null then '开关房'
        when margin_operation is not null then '调价'
        when cutoffdays_operation is not null or cancellationcutoffdays_operation is not null then '提前天数'
        end as category 
from (
select level, clientid, didahoteldefaultstatus, status, margin, cutoffdays, cancellationcutoffdays, updatedate, username
, last_didahoteldefaultstatus, last_status, last_margin, last_cutoffdays, last_cancellationcutoffdays
, case when didahoteldefaultstatus != last_didahoteldefaultstatus 
        then 
                case when last_didahoteldefaultstatus = 0 and didahoteldefaultstatus = 1 then '机构酒店默认状态：关->开'
                when last_didahoteldefaultstatus = 1 and didahoteldefaultstatus = 0 then '机构酒店默认状态：开->关'
                end 
        else null end as didahoteldefaultstatus_operation 
, case when status != last_status 
        then 
                case when last_status = 0 and status = 1 then '机构开关房：关->开'
                when last_status = 1 and status = 0 then '机构开关房：开->关'
                end 
        else null end as status_operation 
, case when margin != last_margin then '机构调价：'||round(last_margin,2)||'->'||round(margin,2) else null end as margin_operation
, case when cutoffdays != last_cutoffdays then '机构可卖提前天数：'||last_cutoffdays||'->'||cutoffdays else null end as cutoffdays_operation 
, case when cancellationcutoffdays != last_cancellationcutoffdays then '机构可卖提前天数：'||last_cancellationcutoffdays||'->'||cancellationcutoffdays else null end as cancellationcutoffdays_operation 
from (
select level, clientid, didahoteldefaultstatus, status, margin, cutoffdays, cancellationcutoffdays, updatedate, username
, lag(didahoteldefaultstatus) over(partition by level, clientid order by updatedate) as last_didahoteldefaultstatus
, lag(status) over(partition by level, clientid order by updatedate) as last_status 
, lag(margin) over(partition by level, clientid order by updatedate) as last_margin
, lag(cutoffdays) over(partition by level, clientid order by updatedate) as last_cutoffdays
, lag(cancellationcutoffdays) over(partition by level, clientid order by updatedate) as last_cancellationcutoffdays
from configuration.wolf_rateadjust_log
where level = 'C' 
and clientid in (select client_id from pid)
) as a 
/* where updatedate >= now() - interval '$val{day_range} days' */
where updatedate::date >= (SELECT analysis_date FROM params) - interval '1 days' and updatedate::date <= (SELECT analysis_date FROM params) + interval '1 days'
) as a 
)
, s_operation as (
select level
, client_id as clientid
, supplierid, 0 as supplieraccountid, updatedate, username
, CONCAT_WS('; ', 
    supplierhoteldefaultstatus_operation, 
    status_operation, 
    margin_operation, 
    cutoffdays_operation, 
                cancellationcutoffdays_operation
) as operation 
, case when supplierhoteldefaultstatus_operation is not null or status_operation is not null then '开关房'
        when margin_operation is not null then '调价'
        when cutoffdays_operation is not null or cancellationcutoffdays_operation is not null then '提前天数'
        end as category 
from (
select level, supplierid, supplierhoteldefaultstatus, status, margin, cutoffdays, cancellationcutoffdays, updatedate, username
, last_supplierhoteldefaultstatus, last_status, last_margin, last_cutoffdays, last_cancellationcutoffdays
, case when supplierhoteldefaultstatus != last_supplierhoteldefaultstatus
        then 
                case when last_supplierhoteldefaultstatus = 0 and supplierhoteldefaultstatus = 1 then '供应商酒店默认状态：关->开'
                when last_supplierhoteldefaultstatus = 1 and supplierhoteldefaultstatus = 0 then '供应商酒店默认状态：开->关'
                end 
        else null end as supplierhoteldefaultstatus_operation 
, case when status != last_status 
        then 
                case when last_status = 0 and status = 1 then '供应商开关房：关->开'
                when last_status = 1 and status = 0 then '供应商开关房：开->关'
                end 
        else null end as status_operation 
, case when margin != last_margin then '供应商调价：'||round(last_margin,2)||'->'||round(margin,2) else null end as margin_operation
, case when cutoffdays != last_cutoffdays then '供应商可卖提前天数：'||last_cutoffdays||'->'||cutoffdays else null end as cutoffdays_operation 
, case when cancellationcutoffdays != last_cancellationcutoffdays then '供应商可卖提前天数：'||last_cancellationcutoffdays||'->'||cancellationcutoffdays else null end as cancellationcutoffdays_operation 
from (
select level, supplierid, supplierhoteldefaultstatus, status, margin, cutoffdays, cancellationcutoffdays, updatedate, username
, lag(supplierhoteldefaultstatus) over(partition by level, supplierid order by updatedate) as last_supplierhoteldefaultstatus
, lag(status) over(partition by level, supplierid order by updatedate) as last_status 
, lag(margin) over(partition by level, supplierid order by updatedate) as last_margin
, lag(cutoffdays) over(partition by level, supplierid order by updatedate) as last_cutoffdays
, lag(cancellationcutoffdays) over(partition by level, supplierid order by updatedate) as last_cancellationcutoffdays
from (
select level, supplierid, supplierhoteldefaultstatus, status, margin, cutoffdays, cancellationcutoffdays, updatedate, username
/* , remark */
, row_number() over(partition by level, supplierid, updatedate::date order by updatedate desc) as time_rank 
from configuration.wolf_rateadjust_log
where level = 'S' and username != 'JobAPI'
) as a 
where time_rank = 1
) as a 
/* where updatedate >= now() - interval '$val{day_range} days' */
where updatedate::date >= (SELECT analysis_date FROM params) - interval '1 days' and updatedate::date <= (SELECT analysis_date FROM params) + interval '1 days'
) as a 
cross join pid
)
, cbd_operation as (
select level, clientid, 0 as supplierid, 0 as supplieraccountid, bookingstartdate as updatedate, username 
, 'BookingDate操作：'||bookingstartdate::date||'~'||bookingenddate::date||case when status = 1 then '；开房；Margin=' else '；关房；Margin=' end||round(margin,2)||case when countrycode = '*' or countrycode is null then '；无指定国家' else '；有指定国家' end as operation
, '窗口期操作' as category
from configuration.wolf_rateadjust_log
where level = 'CBD' 
/* and clientid = '$val{client_id}' */
and clientid in (select client_id from pid)
/* and bookingstartdate >= now() - interval '$val{day_range} days' */
and bookingstartdate::date >= (SELECT analysis_date FROM params) - interval '1 days' and bookingstartdate::date <= (SELECT analysis_date FROM params) + interval '1 days'
)
, sbd_operation as (
select level, client_id as clientid, supplierid, supplieraccountid, bookingstartdate as updatedate, username 
, 'BookingDate操作：'||bookingstartdate::date||'~'||bookingenddate::date||case when status = 1 then '；开房；Margin=' else '；关房；Margin=' end||round(margin,2)||case when countrycode = '*' or countrycode is null then '；无指定国家' else '；有指定国家' end||'；操作日期：'||updatedate::date as operation
, '窗口期操作' as category
from configuration.wolf_rateadjust_log
cross join pid
where level = 'SBD' 
/* and bookingstartdate >= now() - interval '$val{day_range} days' */
and bookingstartdate::date >= (SELECT analysis_date FROM params) - interval '1 days' and bookingstartdate::date <= (SELECT analysis_date FROM params) + interval '1 days'
)
, csa_operation_base as (
select level, clientid, supplierid, supplieraccountid, supplierhoteldefaultstatus, status, margin, updatedate, username
, last_supplierhoteldefaultstatus, last_status, last_margin
from (
select level, clientid, supplierid, supplieraccountid, supplierhoteldefaultstatus, status, margin, updatedate, username
, lag(supplierhoteldefaultstatus) over(partition by level, clientid, supplierid, supplieraccountid order by updatedate) as last_supplierhoteldefaultstatus
, lag(status) over(partition by level, clientid, supplierid, supplieraccountid order by updatedate) as last_status 
, lag(margin) over(partition by level, clientid, supplierid, supplieraccountid order by updatedate) as last_margin
/* select * */
from configuration.wolf_rateadjust_log
where level = 'CSA' 
/* and clientid = '$val{client_id}' */
and clientid in (select client_id from pid)
order by clientid, supplierid, supplieraccountid, updatedate
) as a 
/* where updatedate >= now() - interval '$val{day_range} days' */
where updatedate::date >= (SELECT analysis_date FROM params) - interval '1 days' and updatedate::date <= (SELECT analysis_date FROM params) + interval '1 days'
) 
, csa_operation_by_user as (
select level, clientid, supplierid, supplieraccountid, updatedate, username
, CONCAT_WS('; ', 
    supplierhoteldefaultstatus_operation, 
    status_operation, 
    margin_operation, 
    new_supplier
) as operation 
, case when supplierhoteldefaultstatus_operation is not null or status_operation is not null then '开关房'
        when margin_operation is not null then '调价'
        when new_supplier is not null then '新上线'
        end as category 
from (
select level, clientid, supplierid, supplieraccountid, supplierhoteldefaultstatus, status, margin, updatedate, username
, last_supplierhoteldefaultstatus, last_status, last_margin
, case when supplierhoteldefaultstatus != last_supplierhoteldefaultstatus 
        then 
                case when last_supplierhoteldefaultstatus = 0 and supplierhoteldefaultstatus = 1 then 'CSA酒店默认状态：关->开'
                when last_supplierhoteldefaultstatus = 1 and supplierhoteldefaultstatus = 0 then 'CSA酒店默认状态：开->关'
                end 
        else null end as supplierhoteldefaultstatus_operation 
, case when status != last_status 
        then 
                case when last_status = 0 and status = 1 then 'CSA开关房：关->开'
                when last_status = 1 and status = 0 then 'CSA开关房：开->关'
                end 
        else null end as status_operation 
, case when margin != last_margin then 'CSA调价：'||round(last_margin,2)||'->'||round(margin,2) else null end as margin_operation
, case when last_status is null then '新供应商账号上线' else null end as new_supplier
from csa_operation_base
where username != 'JobAPI'
) as a 
)
, l2l as (
select 'L2L' as level, clientid, 0 as supplierid, 0 as supplieraccountid, updatetime as updatedate, username 
, 'L2L等级：'||last_level||'->'||level||'惩罚天数='||brgpunishmentday as operation 
, 'L2L配置' as category
from (
select clientid, level, updatetime, username, brgpunishmentday
, lag(level) over(partition by clientid order by updatetime) as last_level
from configuration.wolfl2lclientlevelconfiglog
/* where clientid = '$val{client_id}' */
where clientid in (select client_id from pid)
) as a 
/* where updatetime >= now() - interval '$val{day_range} days' and level != last_level */
where updatetime::date >= (SELECT analysis_date FROM params) - interval '1 days' and updatetime::date <= (SELECT analysis_date FROM params) + interval '1 days'
)
, cslrc as (
select level, clientid, supplierid, supplieraccountid, updatedate, username
, case when islimit = 1 then '特殊机构配置更改：售卖限制' 
        when islimit = 0 then '特殊机构配置更改：全部账号可卖(无限制)'
        end as operation 
, '特殊机构配置' as category
from (
select 'CSLRC' as level, clientid, supplierid, supplieraccountid, updatetime as updatedate, username, islimit
, row_number() over(partition by level, clientid, supplierid, supplieraccountid, updatetime::date order by updatetime desc) as time_rank 
from configuration.wolfl2lconfiglog
/* where clientid = '$val{client_id}' */
where clientid in (select client_id from pid)
and l2llevel = 'CSLRC'
/* and updatetime >= now() - interval '$val{day_range} days' */
and updatetime::date >= (SELECT analysis_date FROM params) - interval '1 days' and updatetime::date <= (SELECT analysis_date FROM params) + interval '1 days'
) as a 
where time_rank = 1
)
, s_bottom as (
select 'Bottom' as level 
, client_id as clientid 
, item::int as supplierid 
, 0 as supplieraccountid 
, update_time as updatedate 
, update_user as username 
, case when margin is null then '兜底配置：已移除' else '供应商兜底配置Margin：'||round(last_margin,2)||'->'||round(margin,2) end as operation 
, '兜底配置' as category 
from (
select level, item, margin, is_remove, update_time, update_user 
, lag(margin) over(partition by level, item order by update_time) as last_margin 
, lag(is_remove) over(partition by level, item order by update_time) as last_status 
from configuration.bottom_margin_log
where level = 'Supplier'
) as a 
cross join pid 
/* where update_time >= now() - interval '$val{day_range} days' */
where update_time::date >= (SELECT analysis_date FROM params) - interval '1 days' and update_time::date <= (SELECT analysis_date FROM params) + interval '1 days'
and margin != last_margin 
)
, c_bottom as (
select 'Bottom' as level 
, item as clientid 
, 0 as supplierid 
, 0 as supplieraccountid 
, update_time as updatedate 
, update_user as username 
, case when margin is null then '兜底配置：已移除' else '渠道兜底配置Margin：'||round(last_margin,2)||'->'||round(margin,2) end as operation 
, '兜底配置' as category 
from (
select level, item, margin, is_remove, update_time, update_user 
, lag(margin) over(partition by level, item order by update_time) as last_margin 
, lag(is_remove) over(partition by level, item order by update_time) as last_status 
from configuration.bottom_margin_log
/* where item = '$val{client_id}' */
where item in (select client_id from pid)
) as a 
/* where update_time >= now() - interval '$val{day_range} days' */
where update_time::date >= (SELECT analysis_date FROM params) - interval '1 days' and update_time::date <= (SELECT analysis_date FROM params) + interval '1 days'
and margin != last_margin 
) 
, cdh as (
select level, clientid, 0 as supplierid, 0 as supplieraccountid, updatedate, username
, case when status = 1 then 'CDH调整：开房；Margin='||round(margin,2)||'；酒店数量='||hotel_count 
        when status = 0 then 'CDH调整：关房；Margin='||round(margin,2)||'；酒店数量='||hotel_count 
        end as operation 
, 'CDH调整' as category 
from (
select level, clientid, status, margin, updatedate::date, username, uniq(didahotelid) as hotel_count 
from configuration.wolf_rateadjust_hotel_log
where level = 'CDH' 
/* and clientid = '$val{client_id}' */
and clientid in (select client_id from pid)
/* and updatedate >= now() - interval '$val{day_range} days' */
and updatedate::date >= (SELECT analysis_date FROM params) - interval '1 days' and updatedate::date <= (SELECT analysis_date FROM params) + interval '1 days'
group by 1,2,3,4,5,6
) as a 
) 
, sh as (
select level, client_id as clientid , supplierid, 0 as supplieraccountid, updatedate, username 
, case when status = 1 then 'SH调整：开房；Margin='||round(margin,2)||'；酒店数量='||hotel_count 
        when status = 0 then 'SH调整：关房；Margin='||round(margin,2)||'；酒店数量='||hotel_count 
        end as operation 
, 'SH调整' as category
from (
select level, supplierid, status, margin, updatedate::date, username, uniq(supplierhotelid) as hotel_count 
from configuration.wolf_rateadjust_hotel_log
where level = 'SH' 
and updatedate::date >= (SELECT analysis_date FROM params) - interval '1 days' and updatedate::date <= (SELECT analysis_date FROM params) + interval '1 days'
group by 1,2,3,4,5,6
) as a 
cross join pid 
where hotel_count >= 10 
)
, lcdh as (
select level, clientid, 0 as supplierid, 0 as supplieraccountid, updatedate, username 
, case when status = '新增' then '击穿兜底：新增；Margin='||round(margin,2)||'；酒店数量='||hotel_count 
        when status = '删除' then '击穿兜底：删除；酒店数量='||hotel_count 
        end as operation 
, '击穿兜底' as category 
from (
select level, clientid, margin, updatedate, username
, case when deletetime is not null or remark ilike '%删除%' then '删除' else '新增' end as status 
, uniq(didahotelid) as hotel_count 
from configuration.wolf_rateadjust_hotel_log 
where level = 'LCDH' 
/* and clientid = '$val{client_id}' */
and clientid in (select client_id from pid)
/* and updatedate::date >= now() - interval '$val{day_range} days' */
and updatedate::date >= (SELECT analysis_date FROM params) - interval '1 days' and updatedate::date <= (SELECT analysis_date FROM params) + interval '1 days'
group by 1,2,3,4,5,6
) as a 
)

, configuration_operation as (
select 'Configuration' as level, client_id as clientid, 0 as supplierid, 0 as supplieraccountid, created_at as updatedate, created_by as username
, configuration_key||': '||coalesce(old_value,'null') || ' -> '||coalesce(new_value,'null') as operation
, 'Wolf2.0配置改变' as category
from configuration.client_configuration_change_log
where client_id in (select client_id from pid)
and created_at::date >= (SELECT analysis_date FROM params) - interval '1 days'
and created_at::date <= (SELECT analysis_date FROM params) + interval '1 days'
and configuration_key in (
'MultiHotelPriceSearchRealTimePPS'
, 'SingleHotelPriceSearchRealTimePPS'
, 'PriceSearchCachePPS'
, 'PriceConfirmQPS'
, 'HotelSearchTimeout'
, 'RatePlanSearchTimeout'
, 'MultiHotelRealTimeSearchCount'
, 'MultiHotelCacheSearchCount'
, 'MappedRoomTypeTopCountForOptimalCancellationBreakfast'
, 'UnmappedRoomTypeTopCountForOptimalCancellationBreakfast'
, 'MappedRoomTypeTopCountForBreakfastCancellation'
, 'UnmappedRoomTypeTopCountForBreakfastCancellation'
, 'IgnoreChineseCode'
, 'DidaHotelMandatoryFeesConfig'
)
)
, config as (
select * from (
select * from cs_operation 
union all 
select * from csa_operation_by_user
union all 
select * from l2l
union all 
select * from cslrc 
union all 
select * from s_bottom
union all 
select * from c_bottom
union all 
select * from cdh
union all 
select * from sh 
union all 
select * from lcdh 
union all 
select * from c_operation 
union all 
select * from s_operation
union all
select * from cbd_operation
union all 
select * from sbd_operation
union all
select * from configuration_operation
) as a 
where category is not null 
order by updatedate
)
, cs_bks as (
select a.clientid, a.supplierid, a.updatedate
, sum(case when a.compare_days > 0
            and channel_createdate >= a.updatedate::date - interval '7 days'
            and channel_createdate < a.updatedate::date - interval '7 days' + a.compare_days * interval '1 day'
        then 1 else 0 end) as before_bks 
, sum(case when a.compare_days > 0
            and channel_createdate >= a.updatedate::date
            and channel_createdate < a.updatedate::date + a.compare_days * interval '1 day'
        then 1 else 0 end) as after_bks 
, sum(case when a.compare_days > 0
            and channel_createdate >= a.updatedate::date - interval '7 days'
            and channel_createdate < a.updatedate::date - interval '7 days' + a.compare_days * interval '1 day'
        then channel_pricecny else 0 end) as before_ttv 
, sum(case when a.compare_days > 0
            and channel_createdate >= a.updatedate::date
            and channel_createdate < a.updatedate::date + a.compare_days * interval '1 day'
        then channel_pricecny else 0 end) as after_ttv 
from (
select clientid, supplierid, updatedate
, least(7, greatest(0, ((current_date - interval '1 day')::date - updatedate::date + 1)))::int as compare_days
from config
where supplierid != 0 and supplieraccountid = 0 
) as a 
left join (select channel_bookingnumber, clientid, supplierid, channel_createdate, channel_pricecny from npd_booking_view where clientid in (select client_id from pid) and channel_status in ('Confirmed','Canceled') and rebook_sequence = 1 and channel_createdate >= (SELECT analysis_date FROM params) - interval '10 days' and channel_createdate <= (SELECT analysis_date FROM params) + interval '10 days') as b 
on a.supplierid = b.supplierid and a.clientid = b.clientid 
group by 1,2,3
/* order by 6 desc */
)
/* - */
, cs_search as (
select a.clientid, a.supplierid, a.updatedate
, sum(case when a.compare_days > 0
            and date >= a.updatedate::date - interval '7 days'
            and date < a.updatedate::date - interval '7 days' + a.compare_days * interval '1 day'
        then availcallamount else 0 end) as before_ss_avail_search
, sum(case when a.compare_days > 0
            and date >= a.updatedate::date
            and date < a.updatedate::date + a.compare_days * interval '1 day'
        then availcallamount else 0 end) as after_ss_avail_search
                                
, sum(case when a.compare_days > 0
            and date >= a.updatedate::date - interval '7 days'
            and date < a.updatedate::date - interval '7 days' + a.compare_days * interval '1 day'
        then hotelcallamount else 0 end) as before_ss_total_search
, sum(case when a.compare_days > 0
            and date >= a.updatedate::date
            and date < a.updatedate::date + a.compare_days * interval '1 day'
        then hotelcallamount else 0 end) as after_ss_total_search
from (
select clientid, supplierid, supplieraccountid, updatedate
, least(7, greatest(0, ((current_date - interval '1 day')::date - updatedate::date + 1)))::int as compare_days
from config
where supplierid != 0 and supplieraccountid = 0 
) as a 
left join (
select clientid, supplierid, hotelcallamount, availcallamount, date 
from public.clientsupplierhotelcallcountsummary
where clientid in (select client_id from pid)
and date >= (SELECT analysis_date FROM params) - interval '10 days' and date <= (SELECT analysis_date FROM params) + interval '10 days'
) as b 
on a.supplierid = b.supplierid and a.clientid = b.clientid 
group by 1,2,3
)

, csa_bks as (
select a.clientid, a.supplierid, a.supplieraccountid, a.updatedate
, sum(case when a.compare_days > 0
            and channel_createdate >= a.updatedate::date - interval '7 days'
            and channel_createdate < a.updatedate::date - interval '7 days' + a.compare_days * interval '1 day'
        then 1 else 0 end) as before_bks 
, sum(case when a.compare_days > 0
            and channel_createdate >= a.updatedate::date
            and channel_createdate < a.updatedate::date + a.compare_days * interval '1 day'
        then 1 else 0 end) as after_bks 
, sum(case when a.compare_days > 0
            and channel_createdate >= a.updatedate::date - interval '7 days'
            and channel_createdate < a.updatedate::date - interval '7 days' + a.compare_days * interval '1 day'
        then channel_pricecny else 0 end) as before_ttv 
, sum(case when a.compare_days > 0
            and channel_createdate >= a.updatedate::date
            and channel_createdate < a.updatedate::date + a.compare_days * interval '1 day'
        then channel_pricecny else 0 end) as after_ttv 
from (
select clientid, supplierid, supplieraccountid, updatedate
, least(7, greatest(0, ((current_date - interval '1 day')::date - updatedate::date + 1)))::int as compare_days
from config
where supplierid != 0 and supplieraccountid != 0 
) as a 
left join (select channel_bookingnumber, clientid, supplierid, supplieraccountid, channel_createdate, channel_pricecny from npd_booking_view where clientid in (select client_id from pid) and channel_status in ('Confirmed','Canceled') and rebook_sequence = 1 and channel_createdate >= (SELECT analysis_date FROM params) - interval '10 days' and channel_createdate <= (SELECT analysis_date FROM params) + interval '10 days') as b on a.supplierid = b.supplierid and a.supplieraccountid = b.supplieraccountid and a.clientid = b.clientid 
group by 1,2,3,4
/* order by 1,2,3 */
)
, c_bks as (
select a.clientid, a.updatedate
, sum(case when a.compare_days > 0
            and channel_createdate >= a.updatedate::date - interval '7 days'
            and channel_createdate < a.updatedate::date - interval '7 days' + a.compare_days * interval '1 day'
        then 1 else 0 end) as before_bks 
, sum(case when a.compare_days > 0
            and channel_createdate >= a.updatedate::date
            and channel_createdate < a.updatedate::date + a.compare_days * interval '1 day'
        then 1 else 0 end) as after_bks 
, sum(case when a.compare_days > 0
            and channel_createdate >= a.updatedate::date - interval '7 days'
            and channel_createdate < a.updatedate::date - interval '7 days' + a.compare_days * interval '1 day'
        then channel_pricecny else 0 end) as before_ttv 
, sum(case when a.compare_days > 0
            and channel_createdate >= a.updatedate::date
            and channel_createdate < a.updatedate::date + a.compare_days * interval '1 day'
        then channel_pricecny else 0 end) as after_ttv 
from (
select clientid, updatedate
, least(7, greatest(0, ((current_date - interval '1 day')::date - updatedate::date + 1)))::int as compare_days
from config
where supplierid = 0 and supplieraccountid = 0 
) as a 
left join (select clientid, channel_bookingnumber, channel_createdate, channel_pricecny from npd_booking_view where clientid in (select client_id from pid) and channel_status in ('Confirmed','Canceled') and rebook_sequence = 1 and channel_createdate >= (SELECT analysis_date FROM params) - interval '10 days' and channel_createdate <= (SELECT analysis_date FROM params) + interval '10 days') as b on a.clientid = b.clientid 
group by 1,2
/* order by 1,2,3 */
)
/* - */

, c_search as (
select a.clientid, a.updatedate
, sum(case when a.compare_days > 0
            and dt >= a.updatedate::date - interval '7 days'
            and dt < a.updatedate::date - interval '7 days' + a.compare_days * interval '1 day'
        then available_client_pps else 0 end) as before_didabiz_pps_avail_search
, sum(case when a.compare_days > 0
            and dt >= a.updatedate::date
            and dt < a.updatedate::date + a.compare_days * interval '1 day'
        then available_client_pps else 0 end) as after_didabiz_pps_avail_search
                                
, sum(case when a.compare_days > 0
            and dt >= a.updatedate::date - interval '7 days'
            and dt < a.updatedate::date - interval '7 days' + a.compare_days * interval '1 day'
        then client_pps else 0 end) as before_didabiz_pps_total_search
, sum(case when a.compare_days > 0
            and dt >= a.updatedate::date
            and dt < a.updatedate::date + a.compare_days * interval '1 day'
        then client_pps else 0 end) as after_didabiz_pps_total_search
from (
select clientid, updatedate
, least(7, greatest(0, ((current_date - interval '1 day')::date - updatedate::date + 1)))::int as compare_days
from config
where supplierid = 0 and supplieraccountid = 0 
) as a 
left join (
select client_id, dt::date, client_pps, available_client_pps
from ads.ads_hotel_monitor_rate_search_statistic_by_client_id 
where client_id in (select client_id from pid)
and dt::date >= (SELECT analysis_date FROM params) - interval '10 days' and dt::date <= (SELECT analysis_date FROM params) + interval '10 days'
) as b on a.clientid = b.client_id 
group by 1,2
)

, cdh_lcdh_event_hotels as (
    select
        h.level,
        h.clientid,
        h.status,
        h.margin,
        h.updatedate::date as change_date,
        h.username,
        h.didahotelid,
        case
            when h.level = 'LCDH'
                 and (h.deletetime is not null or h.remark ilike '%删除%')
            then '删除'
            when h.level = 'LCDH'
            then '新增'
            else null
        end as lcdh_status
    from configuration.wolf_rateadjust_hotel_log as h
    where h.level in ('CDH', 'LCDH')
      and h.clientid in (select client_id from pid)
      and h.updatedate::date >= (select analysis_date from params) - interval '1 days'
      and h.updatedate::date <= (select analysis_date from params) + interval '1 days'
)

, cdh_lcdh_hotel_bks as (
    select
        a.level,
        a.clientid,
        a.change_date,
        a.username,
        a.status,
        a.margin,
        a.lcdh_status,
        count(distinct a.didahotelid) as affected_hotel_count,
        sum(
            case
                when a.compare_days > 0
                     and b.channel_createdate >= a.change_date - interval '7 days'
                     and b.channel_createdate < a.change_date - interval '7 days' + a.compare_days * interval '1 day'
                then 1
                else 0
            end
        ) as before_hotel_bks,
        sum(
            case
                when a.compare_days > 0
                     and b.channel_createdate >= a.change_date
                     and b.channel_createdate < a.change_date + a.compare_days * interval '1 day'
                then 1
                else 0
            end
        ) as after_hotel_bks,
        sum(
            case
                when a.compare_days > 0
                     and b.channel_createdate >= a.change_date - interval '7 days'
                     and b.channel_createdate < a.change_date - interval '7 days' + a.compare_days * interval '1 day'
                then b.channel_pricecny
                else 0
            end
        ) as before_hotel_ttv,
        sum(
            case
                when a.compare_days > 0
                     and b.channel_createdate >= a.change_date
                     and b.channel_createdate < a.change_date + a.compare_days * interval '1 day'
                then b.channel_pricecny
                else 0
            end
        ) as after_hotel_ttv
    from (
        select
            e.*,
            least(
                7,
                greatest(0, ((current_date - interval '1 day')::date - e.change_date + 1))
            )::int as compare_days
        from cdh_lcdh_event_hotels as e
    ) as a
    left join (
        select
            clientid,
            didahotelid,
            channel_createdate,
            channel_pricecny
        from public.npd_booking_view
        where clientid in (select client_id from pid)
          and channel_status in ('Confirmed', 'Canceled')
          and rebook_sequence = 1
          and channel_createdate >= (select analysis_date from params) - interval '10 days'
          and channel_createdate <= (select analysis_date from params) + interval '10 days'
    ) as b
        on a.clientid = b.clientid
       and a.didahotelid = b.didahotelid
    group by
        a.level,
        a.clientid,
        a.change_date,
        a.username,
        a.status,
        a.margin,
        a.lcdh_status
)

/* - */
select a.*
, replace(split_part(e.op_user_name,'[',2),']','') op
, least(7, greatest(0, ((current_date - interval '1 day')::date - a.updatedate::date + 1)))::int as compare_days
, (a.updatedate::date - interval '7 days')::date as before_window_start_date
, (a.updatedate::date - interval '7 days' + (least(7, greatest(0, ((current_date - interval '1 day')::date - a.updatedate::date + 1)))::int - 1) * interval '1 day')::date as before_window_end_date
, a.updatedate::date as after_window_start_date
, (a.updatedate::date + (least(7, greatest(0, ((current_date - interval '1 day')::date - a.updatedate::date + 1)))::int - 1) * interval '1 day')::date as after_window_end_date
, coalesce(d.before_bks, b.before_bks, c.before_bks, 0) as before_bks_compare_window 
, coalesce(d.after_bks, b.after_bks, c.after_bks, 0) as after_bks_compare_window
, coalesce(d.before_ttv, b.before_ttv, c.before_ttv, 0) as before_ttv_compare_window 
, coalesce(d.after_ttv, b.after_ttv, c.after_ttv, 0) as after_ttv_compare_window
, case when a.supplierid != 0 and a.supplieraccountid = 0 then before_ss_avail_search 
        when a.supplierid = 0 and a.supplieraccountid = 0 then before_didabiz_pps_avail_search else null end as before_avail_search 
, case when a.supplierid != 0 and a.supplieraccountid = 0 then after_ss_avail_search 
        when a.supplierid = 0 and a.supplieraccountid = 0 then after_didabiz_pps_avail_search else null end as after_avail_search 
        
, case when a.supplierid != 0 and a.supplieraccountid = 0 then before_ss_total_search 
        when a.supplierid = 0 and a.supplieraccountid = 0 then before_didabiz_pps_total_search else null end as before_total_search 
, case when a.supplierid != 0 and a.supplieraccountid = 0 then after_ss_total_search 
        when a.supplierid = 0 and a.supplieraccountid = 0 then after_didabiz_pps_total_search else null end as after_total_search 
, hb.affected_hotel_count
, hb.before_hotel_bks
, hb.after_hotel_bks
, hb.before_hotel_ttv
, hb.after_hotel_ttv
from config as a 
left join cs_bks as b on a.supplierid = b.supplierid and a.updatedate = b.updatedate and a.clientid = b.clientid 
left join csa_bks as c on a.supplierid = c.supplierid and a.supplieraccountid = c.supplieraccountid and a.updatedate = c.updatedate and a.clientid = c.clientid 
left join c_bks as d on a.clientid = d.clientid and a.updatedate = d.updatedate 
left join crm.client_info_ods as e on a.clientid = e.client_id 
left join cs_search as f on a.supplierid = f.supplierid and a.updatedate = f.updatedate and a.clientid = f.clientid 
left join c_search as g on a.clientid = g.clientid and a.updatedate = g.updatedate 
left join cdh_lcdh_hotel_bks as hb
    on a.level = hb.level
   and a.clientid = hb.clientid
   and a.updatedate::date = hb.change_date
   and a.username = hb.username
   and a.level in ('CDH', 'LCDH')
   and (
       (a.level = 'CDH' and hb.lcdh_status is null
        and ((a.operation like '%开房%' and hb.status = 1) or (a.operation like '%关房%' and hb.status = 0)))
       or
       (a.level = 'LCDH' and hb.lcdh_status is not null
        and ((a.operation like '%新增%' and hb.lcdh_status = '新增') or (a.operation like '%删除%' and hb.lcdh_status = '删除')))
   )
where (select analysis_date from params) <= (current_date - interval '1 day')::date
and (coalesce(d.before_bks, b.before_bks, c.before_bks, 0) > 0 or coalesce(d.after_bks, b.after_bks, c.after_bks, 0) > 0)
order by clientid,updatedate