/* 02-holiday-yoy-bks-daily-check | D2 诊断 — 国别按日 BKS（仅当主查询结果可疑时） */
/* 禁止替代 02-holiday-yoy-bks-lite.sql 做 rubric；禁止手写变体 */
/* 占位符: {client_id} {country_code} {seg_start} {seg_end} */
/* 例: Agoda MY y1_pre → seg 2025-03-24 ~ 2025-03-30 */

SELECT
    a.channel_create_date::date AS bk_date,
    COUNT(*) AS country_bks
FROM dwd.dwd_hotel_order_channel_supplier_booking_mf a
LEFT JOIN content.dida_hotel_view h ON a.dida_main_hotel_id = h.hotel_id
WHERE a.channel_status_name_en IN ('Confirmed', 'Canceled')
    AND a.supplier_rebook_sequence = 1
    AND a.client_id = '{client_id}'
    AND COALESCE(h.country_code, 'Unknown') = '{country_code}'
    AND a.channel_create_date::date BETWEEN '{seg_start}'::date AND '{seg_end}'::date
GROUP BY 1
ORDER BY 1;
