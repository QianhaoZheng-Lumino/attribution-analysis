/* 02-sid.sql | 2_SID — Phase 2b 验证 A（必跑） */
/* 占位符见 ../params-template.md */

SELECT
    a.sid,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_bookings,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_bookings,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS booking_change,
    CASE
        WHEN SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) = 0 THEN NULL
        ELSE ROUND(
            (SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
             - SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END)) * 100.0
            / NULLIF(SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END), 0)
        , 2)
    END AS change_rate_pct
FROM public.npd_booking_view a
WHERE a.channel_status IN ('Confirmed', 'Canceled')
    AND a.rebook_sequence = 1
    AND a.clientid = '{client_id}'
    AND a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
GROUP BY a.sid
HAVING SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) >= 5
ORDER BY booking_change ASC
LIMIT 50;
