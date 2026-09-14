-- Step 3：历史 42 天日序列（用于 Agent 计算 Q1/Q3）
-- 替换 {hist_start} {analysis_date} {client_id} {parent_client_id}

SELECT
    TO_CHAR(DATE(a.channel_createdate), 'YYYY-MM-DD') AS booking_date,
    COUNT(*) AS daily_bookings
FROM public.npd_booking_view a
WHERE a.channel_status IN ('Confirmed', 'Canceled')
    AND a.rebook_sequence = 1
    AND (
        CASE
            WHEN '{client_id}' <> '' THEN a.clientid = '{client_id}'
            WHEN '{parent_client_id}' <> '' THEN a.parentclientid = '{parent_client_id}'
            ELSE a.clientgroup = 'Overseas API'
        END
    )
    AND a.channel_createdate >= '{hist_start}'::date
    AND a.channel_createdate < '{analysis_date}'::date
GROUP BY DATE(a.channel_createdate)
ORDER BY booking_date
