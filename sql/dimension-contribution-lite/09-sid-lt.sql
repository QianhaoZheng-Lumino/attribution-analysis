-- 09-sid-lt.sql | 9_SID+LT — S/CS 结构

SELECT
    CASE
        WHEN a.leading_date BETWEEN 4 AND 7 THEN '4~7'
        WHEN a.leading_date BETWEEN 8 AND 14 THEN '8~14'
        WHEN a.leading_date BETWEEN 15 AND 28 THEN '15~28'
        WHEN a.leading_date BETWEEN 29 AND 42 THEN '29~42'
        ELSE 'other'
    END AS lt,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_bookings,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_bookings,
    SUM(CASE WHEN a.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS booking_change
FROM public.npd_booking_view a
WHERE a.channel_status IN ('Confirmed', 'Canceled')
    AND a.rebook_sequence = 1
    AND a.clientid = '{client_id}'
    AND a.sid = '{sid}'
    AND a.channel_createdate::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
GROUP BY 1
ORDER BY booking_change ASC;
