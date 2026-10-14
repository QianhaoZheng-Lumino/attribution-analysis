/* 9 LCDH hotel_bks lite | event_count > 0 时必跑（MCP 单行聚合） */
/* 酒店家数只数日志。产量用内连接单独汇总，避免没有订单的酒店被行级权限滤掉 */
/* 酒店键：日志 didahotelid = 订单 dida_main_hotel_id */
/* 占位符: {client_id} {w_start} {w_end} {compare_start} {compare_end} {current_start} {current_end} */
/* MCP tables: configuration.wolf_rateadjust_hotel_log, dwd.dwd_hotel_order_channel_supplier_booking_mf */
/* 仍 500 → BI cdh-lcdh-hotel-bks.sql */

WITH lcdh_hotels AS (
    SELECT DISTINCT didahotelid
    FROM configuration.wolf_rateadjust_hotel_log
    WHERE level = 'LCDH'
        AND clientid = '{client_id}'
        AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
),
hotel_n AS (
    SELECT
        1 AS k,
        COUNT(DISTINCT didahotelid) AS affected_hotel_count
    FROM lcdh_hotels
),
bks AS (
    SELECT
        1 AS k,
        COALESCE(SUM(CASE WHEN b.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END), 0) AS before_hotel_bks,
        COALESCE(SUM(CASE WHEN b.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END), 0) AS after_hotel_bks
    FROM lcdh_hotels h
    JOIN dwd.dwd_hotel_order_channel_supplier_booking_mf b
        ON b.dida_main_hotel_id = h.didahotelid
        AND b.client_id = '{client_id}'
        AND b.channel_status_name_en IN ('Confirmed', 'Canceled')
        AND b.supplier_rebook_sequence = 1
        AND b.channel_create_date::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
)
SELECT
    'LCDH' AS level,
    n.affected_hotel_count,
    b.before_hotel_bks,
    b.after_hotel_bks
FROM hotel_n n
JOIN bks b ON n.k = b.k;
