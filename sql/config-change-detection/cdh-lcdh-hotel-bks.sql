/* CDH / LCDH 酒店级产量前后对比（片段） */
/* 酒店家数只数日志。产量和 TTV 用内连接单独汇总，再按同一组键拼回去。 */
/* 用途：机构级 before/after_bks 会被非变更酒店稀释；本片段仅统计「本次配置涉及的 didahotelid」上的订单。 */
/* 用法：嵌入 config-change-detection.sql，在最终 SELECT 中 left join cdh_lcdh_hotel_bks。 */
/* 暂不包含 SH（供应商酒店需 supplierhotelid 映射，另做）。 */

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

, cdh_lcdh_hotel_rows as (
    select
        e.*,
        least(
            7,
            greatest(0, ((current_date - interval '1 day')::date - e.change_date + 1))
        )::int as compare_days
    from cdh_lcdh_event_hotels as e
)

, cdh_lcdh_hotel_n as (
    select
        level,
        clientid,
        change_date,
        username,
        status,
        margin,
        lcdh_status,
        count(distinct didahotelid) as affected_hotel_count
    from cdh_lcdh_hotel_rows
    group by
        level,
        clientid,
        change_date,
        username,
        status,
        margin,
        lcdh_status
)

, cdh_lcdh_hotel_sum as (
    select
        a.level,
        a.clientid,
        a.change_date,
        a.username,
        a.status,
        a.margin,
        a.lcdh_status,
        sum(
            case
                when a.compare_days > 0
                     and b.channel_create_date >= a.change_date - interval '7 days'
                     and b.channel_create_date < a.change_date - interval '7 days' + a.compare_days * interval '1 day'
                then 1
                else 0
            end
        ) as before_hotel_bks,
        sum(
            case
                when a.compare_days > 0
                     and b.channel_create_date >= a.change_date
                     and b.channel_create_date < a.change_date + a.compare_days * interval '1 day'
                then 1
                else 0
            end
        ) as after_hotel_bks,
        sum(
            case
                when a.compare_days > 0
                     and b.channel_create_date >= a.change_date - interval '7 days'
                     and b.channel_create_date < a.change_date - interval '7 days' + a.compare_days * interval '1 day'
                then b.channel_price_cny
                else 0
            end
        ) as before_hotel_ttv,
        sum(
            case
                when a.compare_days > 0
                     and b.channel_create_date >= a.change_date
                     and b.channel_create_date < a.change_date + a.compare_days * interval '1 day'
                then b.channel_price_cny
                else 0
            end
        ) as after_hotel_ttv
    from cdh_lcdh_hotel_rows as a
    join dwd.dwd_hotel_order_channel_supplier_booking_mf as b
        on b.client_id = a.clientid
       and b.dida_main_hotel_id = a.didahotelid
       and b.channel_status_name_en in ('Confirmed', 'Canceled')
       and b.supplier_rebook_sequence = 1
       and b.channel_create_date >= (select analysis_date from params) - interval '10 days'
       and b.channel_create_date <= (select analysis_date from params) + interval '10 days'
    group by
        a.level,
        a.clientid,
        a.change_date,
        a.username,
        a.status,
        a.margin,
        a.lcdh_status
)

, cdh_lcdh_hotel_bks as (
    select
        n.level,
        n.clientid,
        n.change_date,
        n.username,
        n.status,
        n.margin,
        n.lcdh_status,
        n.affected_hotel_count,
        coalesce(s.before_hotel_bks, 0) as before_hotel_bks,
        coalesce(s.after_hotel_bks, 0) as after_hotel_bks,
        coalesce(s.before_hotel_ttv, 0) as before_hotel_ttv,
        coalesce(s.after_hotel_ttv, 0) as after_hotel_ttv
    from cdh_lcdh_hotel_n as n
    left join cdh_lcdh_hotel_sum as s
        on n.level = s.level
       and n.clientid = s.clientid
       and n.change_date = s.change_date
       and n.username is not distinct from s.username
       and n.status is not distinct from s.status
       and n.margin is not distinct from s.margin
       and n.lcdh_status is not distinct from s.lcdh_status
)
