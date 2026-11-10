/* CDH 降价：变更酒店池兜底命中率 before/after（仅操作=降价时跑） */
/* 酒店集与 detail/07-cdh-hotel-bks-lite 相同：窗内 CDH 日志 DISTINCT didahotelid */
/* 池化：这些酒店命中单合计 / 这些酒店总单 */
/* 命中 = bottom_margin 非空且 <> 0；LEFT JOIN 无调价行算未命中 */
/* 窗口复用 Phase 1 compare / current */
/* 占位符: {client_id} {w_start} {w_end} {compare_start} {compare_end} {current_start} {current_end} */
/* MCP tables: configuration.wolf_rateadjust_hotel_log, dwd.dwd_hotel_order_channel_supplier_booking_mf, booking.channel_booking_reate_adjust */

WITH cdh_hotels AS (
    SELECT DISTINCT didahotelid
    FROM configuration.wolf_rateadjust_hotel_log
    WHERE level = 'CDH'
        AND clientid = '{client_id}'
        AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
),
hotel_n AS (
    SELECT
        1 AS k,
        COUNT(DISTINCT didahotelid) AS affected_hotel_count
    FROM cdh_hotels
),
hit AS (
    SELECT
        1 AS k,
        COALESCE(SUM(CASE WHEN b.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END), 0) AS before_total,
        COALESCE(SUM(CASE WHEN b.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date
            AND r.bottom_margin IS NOT NULL AND r.bottom_margin <> 0 THEN 1 ELSE 0 END), 0) AS before_hit,
        COALESCE(SUM(CASE WHEN b.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END), 0) AS after_total,
        COALESCE(SUM(CASE WHEN b.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date
            AND r.bottom_margin IS NOT NULL AND r.bottom_margin <> 0 THEN 1 ELSE 0 END), 0) AS after_hit
    FROM cdh_hotels h
    JOIN dwd.dwd_hotel_order_channel_supplier_booking_mf b
        ON b.dida_main_hotel_id = h.didahotelid
        AND b.client_id = '{client_id}'
        AND b.channel_status_name_en IN ('Confirmed', 'Canceled')
        AND b.supplier_rebook_sequence = 1
        AND b.channel_create_date::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
    LEFT JOIN booking.channel_booking_reate_adjust r
        ON r.channel_booking_number = b.channel_booking_number
)
SELECT
    'CDH' AS level,
    n.affected_hotel_count,
    COALESCE(h.before_total, 0) AS before_total,
    COALESCE(h.before_hit, 0) AS before_hit,
    COALESCE(h.after_total, 0) AS after_total,
    COALESCE(h.after_hit, 0) AS after_hit
FROM hotel_n n
LEFT JOIN hit h ON n.k = h.k;
