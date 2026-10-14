/* 05-sid-country.sql | 5_SID+Country — S/CS 路径 */
/* {sid} 是整数 supplier_id，与 {sid_list} 里的同一个数 */
/* 2c 结构：两窗任一 ≥3（含新建/清零）；报告 Top3 按 |占 SID 变化|，含反向 */
/* 禁止 ORDER BY ABS(booking_change)（Hologres 对别名套 ABS 会 500） */

SELECT
    COALESCE(b.country_code, 'Unknown') AS country_code,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_bookings,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_bookings,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS booking_change
FROM dwd.dwd_hotel_order_channel_supplier_booking_mf a
LEFT JOIN content.dida_hotel_view b ON a.dida_main_hotel_id = b.hotel_id
WHERE a.channel_status_name_en IN ('Confirmed', 'Canceled')
    AND a.supplier_rebook_sequence = 1
    AND a.client_id = '{client_id}'
    AND a.supplier_id = {sid}
    AND a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
GROUP BY COALESCE(b.country_code, 'Unknown')
HAVING SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) >= 3
    OR SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) >= 3
ORDER BY ABS(
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END)
) DESC
LIMIT 20;
