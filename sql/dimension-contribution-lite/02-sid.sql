/* 02-sid.sql | 2_SID — Phase 2b 验证 A（必跑） */
/* 占位符见 ../params-template.md */

SELECT
    a.supplier_id,
    MAX(a.supplier_name) AS supplier_name,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS current_bookings,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS previous_bookings,
    SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
      - SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS booking_change,
    CASE
        WHEN SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) = 0 THEN NULL
        ELSE ROUND(
            (SUM(CASE WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END)
             - SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END)) * 100.0
            / NULLIF(SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END), 0)
        , 2)
    END AS change_rate_pct
FROM dwd.dwd_hotel_order_channel_supplier_booking_mf a
WHERE a.channel_status_name_en IN ('Confirmed', 'Canceled')
    AND a.supplier_rebook_sequence = 1
    AND a.client_id = '{client_id}'
    AND a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
GROUP BY a.supplier_id
HAVING SUM(CASE WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) >= 5
ORDER BY booking_change ASC
LIMIT 50;
