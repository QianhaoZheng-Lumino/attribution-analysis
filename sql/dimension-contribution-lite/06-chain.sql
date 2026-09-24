/* 06-chain.sql | 6_Chain — 2c C/Dida 路径 */
/* 2c 结构：两窗任一 ≥10（含新建/清零）；报告 Top3 按 |占总量|，含反向 */
/* 禁止 ORDER BY ABS(booking_change)（Hologres 对别名套 ABS 会 500） */

SELECT
    COALESCE(b.parent_chain_name, 'Independent') AS chain,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_bookings,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_bookings,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS booking_change
FROM public.npd_booking_view a
LEFT JOIN content.dida_hotel_view b ON a.didahotelid = b.hotel_id
WHERE a.channel_status IN ('Confirmed', 'Canceled')
    AND a.rebook_sequence = 1
    AND a.clientid = '{client_id}'
    AND a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
GROUP BY COALESCE(b.parent_chain_name, 'Independent')
HAVING SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) >= 10
    OR SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) >= 10
ORDER BY ABS(
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END)
) DESC
LIMIT 20;
