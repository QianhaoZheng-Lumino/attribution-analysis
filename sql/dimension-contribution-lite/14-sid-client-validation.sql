/* 14-sid-client-validation.sql | cross-validation B lite */
/* 替换 {sid} 为 2a Top 下降 supplier 的 sid 前缀（如 116-EPS%）或完整 sid */
/* 占位符日期见 ../params-template.md */

SELECT
    a.clientid,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_bookings,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_bookings,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS booking_change
FROM public.npd_booking_view a
WHERE a.channel_status IN ('Confirmed', 'Canceled')
    AND a.rebook_sequence = 1
    AND a.sid = '{sid}'
    AND a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
GROUP BY a.clientid
HAVING SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) >= 5
ORDER BY booking_change ASC
LIMIT 30;
