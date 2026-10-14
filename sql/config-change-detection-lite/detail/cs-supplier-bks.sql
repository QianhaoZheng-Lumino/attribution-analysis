/* CS 链路产量 before/after（按 supplierid） */
/* 替换 {supplierid} 为 detail 中关注的 supplier */

SELECT
    {supplierid} AS supplier_id,
    SUM(CASE WHEN channel_create_date >= '{analysis_date}'::date - interval '7 days'
              AND channel_create_date < '{analysis_date}'::date THEN 1 ELSE 0 END) AS before_bks,
    SUM(CASE WHEN channel_create_date >= '{analysis_date}'::date
              AND channel_create_date < '{analysis_date}'::date + interval '{compare_days} days' THEN 1 ELSE 0 END) AS after_bks
FROM dwd.dwd_hotel_order_channel_supplier_booking_mf
WHERE client_id = '{client_id}'
    AND supplier_id = {supplierid}
    AND channel_status_name_en IN ('Confirmed', 'Canceled')
    AND supplier_rebook_sequence = 1
    AND channel_create_date >= '{analysis_date}'::date - interval '10 days'
    AND channel_create_date <= '{analysis_date}'::date + interval '10 days';
