/* Step 2：历史 42 天基准（日均均值 + 标准差） */
/* 替换 {hist_start} {analysis_date} {client_id} {parent_client_id} */
/* 上界是 {analysis_date} 开区间（= hist_end 次日）；不要填 {hist_end} */

SELECT
    ROUND(AVG(daily_cnt)::numeric, 2) AS historical_avg_daily,
    ROUND(STDDEV(daily_cnt)::numeric, 2) AS historical_std_daily,
    COUNT(*) AS historical_days
FROM (
    SELECT
        DATE(a.channel_createdate) AS booking_date,
        COUNT(*) AS daily_cnt
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
) daily_stats
