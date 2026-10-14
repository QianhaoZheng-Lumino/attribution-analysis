/* Step 3：历史 42 天日序列（用于 Agent 计算 Q1/Q3） */
/* 替换 {hist_start} {analysis_date} {client_id} {parent_client_id} */

SELECT
    TO_CHAR(DATE(a.channel_create_date), 'YYYY-MM-DD') AS booking_date,
    COUNT(*) AS daily_bookings
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
    AND a.channel_create_date >= '{hist_start}'::date
    AND a.channel_create_date < '{analysis_date}'::date
GROUP BY DATE(a.channel_create_date)
ORDER BY booking_date
