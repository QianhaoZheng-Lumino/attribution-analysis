-- CDH / LCDH 酒店级产量前后对比（片段）
-- 用途：机构级 before/after_bks 会被非变更酒店稀释；本片段仅统计「本次配置涉及的 didahotelid」上的订单。
-- 用法：嵌入 config-change-detection.sql，在最终 SELECT 中 left join cdh_lcdh_hotel_bks。
-- 暂不包含 SH（供应商酒店需 supplierhotelid 映射，另做）。

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
