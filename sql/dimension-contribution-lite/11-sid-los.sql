/* 11-sid-los.sql | 11_SID+LOS — S/CS 结构 */
/* {sid} 是整数 supplier_id，与 {sid_list} 里的同一个数 */

SELECT
    CASE
        WHEN a.channel_los = 1 THEN '1'
        WHEN a.channel_los BETWEEN 2 AND 3 THEN '2~3'
        WHEN a.channel_los BETWEEN 4 AND 7 THEN '4~7'
        WHEN a.channel_los BETWEEN 8 AND 14 THEN '8~14'
        ELSE 'other'
    END AS los,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_bookings,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_bookings,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS booking_change
FROM dwd.dwd_hotel_order_channel_supplier_booking_mf a
WHERE a.channel_status_name_en IN ('Confirmed', 'Canceled')
    AND a.supplier_rebook_sequence = 1
    AND a.client_id = '{client_id}'
    AND a.supplier_id = {sid}
    AND a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
GROUP BY 1
ORDER BY booking_change ASC;
