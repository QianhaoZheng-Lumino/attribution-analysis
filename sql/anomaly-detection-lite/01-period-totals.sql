/* Step 1：当前期 vs 对比期总量 */
/* 替换 {current_start} {current_end} {compare_start} {compare_end} {current_days} */
/* 以及 {client_id} {parent_client_id} */

SELECT
    SUM(CASE
        WHEN a.channel_create_date >= '{current_start}'::date
         AND a.channel_create_date <= '{current_end}'::date + INTERVAL '1 day' - INTERVAL '1 second'
        THEN 1 ELSE 0
    END) AS current_total_bookings,
    SUM(CASE
        WHEN a.channel_create_date >= '{compare_start}'::date
         AND a.channel_create_date <= '{compare_end}'::date + INTERVAL '1 day' - INTERVAL '1 second'
        THEN 1 ELSE 0
    END) AS previous_total_bookings,
    SUM(CASE
        WHEN a.channel_create_date >= '{current_start}'::date
         AND a.channel_create_date <= '{current_end}'::date + INTERVAL '1 day' - INTERVAL '1 second'
        THEN 1 ELSE 0
    END)::float / {current_days} AS current_daily_avg,
    SUM(CASE
        WHEN a.channel_create_date >= '{compare_start}'::date
         AND a.channel_create_date <= '{compare_end}'::date + INTERVAL '1 day' - INTERVAL '1 second'
        THEN 1 ELSE 0
    END)::float / {current_days} AS previous_daily_avg
FROM dwd.dwd_hotel_order_channel_supplier_booking_mf a
WHERE a.channel_status_name_en IN ('Confirmed', 'Canceled')
    AND a.supplier_rebook_sequence = 1
    AND (
        CASE
            WHEN '{client_id}' <> '' THEN a.client_id = '{client_id}'
            WHEN '{parent_client_id}' <> '' THEN a.parent_client_id = '{parent_client_id}'
            ELSE a.client_group_name = 'Overseas API'
        END
    )
    AND a.channel_create_date >= '{compare_start}'::date
    AND a.channel_create_date <= '{current_end}'::date + INTERVAL '1 day' - INTERVAL '1 second'
