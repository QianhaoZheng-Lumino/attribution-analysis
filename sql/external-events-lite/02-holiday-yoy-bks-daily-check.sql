-- 02-holiday-yoy-bks-daily-check | D2 诊断 — 国别按日 BKS（仅当主查询结果可疑时）
-- 禁止替代 02-holiday-yoy-bks-lite.sql 做 rubric；禁止手写变体
-- 占位符: {client_id} {country_code} {seg_start} {seg_end}
-- 例: Agoda MY y1_pre → seg 2025-03-24 ~ 2025-03-30

SELECT
    a.channel_createdate::date AS bk_date,
    COUNT(*) AS country_bks
FROM public.npd_booking_view a
LEFT JOIN content.dida_hotel_view h ON a.didahotelid = h.hotel_id
WHERE a.channel_status IN ('Confirmed', 'Canceled')
    AND a.rebook_sequence = 1
    AND a.clientid = '{client_id}'
    AND COALESCE(h.country_code, 'Unknown') = '{country_code}'
    AND a.channel_createdate::date BETWEEN '{seg_start}'::date AND '{seg_end}'::date
GROUP BY 1
ORDER BY 1;
