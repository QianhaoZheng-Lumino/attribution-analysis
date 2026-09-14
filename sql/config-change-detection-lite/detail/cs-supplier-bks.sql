-- CS 链路产量 before/after（按 supplierid）
-- 替换 {supplierid} 为 detail 中关注的 supplier

SELECT
    {supplierid} AS supplierid,
    SUM(CASE WHEN channel_createdate >= '{analysis_date}'::date - interval '7 days'
              AND channel_createdate < '{analysis_date}'::date THEN 1 ELSE 0 END) AS before_bks,
    SUM(CASE WHEN channel_createdate >= '{analysis_date}'::date
              AND channel_createdate < '{analysis_date}'::date + interval '{compare_days} days' THEN 1 ELSE 0 END) AS after_bks
FROM public.npd_booking_view
WHERE clientid = '{client_id}'
    AND supplierid = {supplierid}
    AND channel_status IN ('Confirmed', 'Canceled')
    AND rebook_sequence = 1
    AND channel_createdate >= '{analysis_date}'::date - interval '10 days'
    AND channel_createdate <= '{analysis_date}'::date + interval '10 days';
