-- 12-nationality.sql | 12_Nationality — 结构下钻

SELECT
    COALESCE(a.channel_nationality::text, '(empty)') AS nationality,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_bookings,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_bookings,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS booking_change
FROM public.npd_booking_view a
WHERE a.channel_status IN ('Confirmed', 'Canceled')
    AND a.rebook_sequence = 1
    AND a.clientid = '{client_id}'
    AND a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
GROUP BY COALESCE(a.channel_nationality::text, '(empty)')
HAVING SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) > 10
ORDER BY booking_change ASC
LIMIT 20;
