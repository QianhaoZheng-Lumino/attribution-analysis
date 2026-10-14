/* 01-total.sql | 1_Total 总量 */
/* 占位符见 ../params-template.md */

SELECT
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_bookings,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_bookings,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS booking_change
FROM dwd.dwd_hotel_order_channel_supplier_booking_mf a
WHERE a.channel_status_name_en IN ('Confirmed', 'Canceled')
    AND a.supplier_rebook_sequence = 1
    AND a.client_id = '{client_id}'
    AND a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{current_end}'::date;
