/* Step 2：历史 42 天基准（日均均值 + 标准差） */
/* 替换 {hist_start} {analysis_date} {client_id} {parent_client_id} */
/* 上界是 {analysis_date} 开区间（= hist_end 次日）；不要填 {hist_end} */

SELECT
    ROUND(AVG(daily_cnt)::numeric, 2) AS historical_avg_daily,
    ROUND(STDDEV(daily_cnt)::numeric, 2) AS historical_std_daily,
    COUNT(*) AS historical_days
FROM (
    SELECT
        DATE(a.channel_create_date) AS booking_date,
        COUNT(*) AS daily_cnt
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
) daily_stats
