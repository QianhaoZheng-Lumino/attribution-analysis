-- Step 2：单 client 产量 before/after（信号强度测试用）
-- 窗口：变更日前 7 天 vs 变更日起 compare_days（与主 SQL 一致）
-- 改 params 中的 client_id / change_date 即可复用

WITH params AS (
    SELECT
        'Agoda'::text AS client_id,
        '2026-03-20'::date AS change_date,
        7::int AS compare_days
)
SELECT
    p.client_id,
    p.change_date,
    (p.change_date - interval '7 days')::date AS before_start,
    (p.change_date - interval '1 day')::date AS before_end,
    p.change_date AS after_start,
    (p.change_date + (p.compare_days - 1) * interval '1 day')::date AS after_end,
    sum(
        CASE
            WHEN b.channel_createdate >= p.change_date - interval '7 days'
             AND b.channel_createdate < p.change_date
            THEN 1 ELSE 0
        END
    ) AS before_bks,
    sum(
        CASE
            WHEN b.channel_createdate >= p.change_date
             AND b.channel_createdate < p.change_date + p.compare_days * interval '1 day'
            THEN 1 ELSE 0
        END
    ) AS after_bks,
    round(
        100.0 * (
            sum(CASE WHEN b.channel_createdate >= p.change_date AND b.channel_createdate < p.change_date + p.compare_days * interval '1 day' THEN 1 ELSE 0 END)
            - sum(CASE WHEN b.channel_createdate >= p.change_date - interval '7 days' AND b.channel_createdate < p.change_date THEN 1 ELSE 0 END)
        )
        / nullif(sum(CASE WHEN b.channel_createdate >= p.change_date - interval '7 days' AND b.channel_createdate < p.change_date THEN 1 ELSE 0 END), 0)
    , 1) AS bks_change_pct
FROM params AS p
CROSS JOIN public.npd_booking_view AS b
WHERE b.clientid = p.client_id
  AND b.channel_status IN ('Confirmed', 'Canceled')
  AND b.rebook_sequence = 1
  AND b.channel_createdate >= p.change_date - interval '10 days'
  AND b.channel_createdate <= p.change_date + interval '10 days'
GROUP BY p.client_id, p.change_date, p.compare_days;
