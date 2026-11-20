/* 14-sid-client-validation.sql | cross-validation B lite */
/* {sid} 是整数 supplier_id，与 {sid_list} 里的同一个数。等号匹配，不用前缀 */
/* 占位符日期见 ../params-template.md */
/* 跌尾：ORDER BY booking_change ASC LIMIT 100。孪生涨尾见 14-sid-client-validation-rise.sql。 */
/* 门 1 过线 SID 须跌尾+涨尾各跑一次；两结果合并后仍不含 focus → 写「截断未覆盖」，禁止写「已验」。 */

SELECT
    a.client_id,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_bookings,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_bookings,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS booking_change
FROM dwd.dwd_hotel_order_channel_supplier_booking_mf a
WHERE a.channel_status_name_en IN ('Confirmed', 'Canceled')
    AND a.supplier_rebook_sequence = 1
    AND a.supplier_id = {sid}
    AND a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
GROUP BY a.client_id
HAVING SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) >= 5
ORDER BY booking_change ASC
LIMIT 100;
