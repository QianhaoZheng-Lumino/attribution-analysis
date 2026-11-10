/* C 降价：机构级兜底命中率 before/after（仅操作=降价时跑） */
/* 命中 = booking.channel_booking_reate_adjust.bottom_margin 非空且 <> 0 */
/* 命中率 = 命中订单 / 总订单（LEFT JOIN，无调价行算未命中） */
/* 窗口复用 Phase 1 compare / current */
/* 占位符: {client_id} {compare_start} {compare_end} {current_start} {current_end} */
/* MCP tables: dwd.dwd_hotel_order_channel_supplier_booking_mf, booking.channel_booking_reate_adjust */

SELECT
    'C' AS level,
    COALESCE(SUM(CASE WHEN b.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END), 0) AS before_total,
    COALESCE(SUM(CASE WHEN b.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date
        AND r.bottom_margin IS NOT NULL AND r.bottom_margin <> 0 THEN 1 ELSE 0 END), 0) AS before_hit,
    COALESCE(SUM(CASE WHEN b.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END), 0) AS after_total,
    COALESCE(SUM(CASE WHEN b.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date
        AND r.bottom_margin IS NOT NULL AND r.bottom_margin <> 0 THEN 1 ELSE 0 END), 0) AS after_hit
FROM dwd.dwd_hotel_order_channel_supplier_booking_mf b
LEFT JOIN booking.channel_booking_reate_adjust r
    ON r.channel_booking_number = b.channel_booking_number
WHERE b.client_id = '{client_id}'
    AND b.channel_status_name_en IN ('Confirmed', 'Canceled')
    AND b.supplier_rebook_sequence = 1
    AND b.channel_create_date::date BETWEEN '{compare_start}'::date AND '{current_end}'::date;
