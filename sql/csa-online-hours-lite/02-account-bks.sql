/* 02-account-bks | CSA 自动上下线 · 对比窗账号 BKS（高产筛选，与时长 SQL 拆开） */
/* 表: dwd.dwd_hotel_order_channel_supplier_booking_mf */
/* 占位符: {client_id} {sid_list} {compare_start} {compare_end} {current_start} {current_end} */
/* {sid_list} 与限流 / SH / SS / 01-daily-account 同一套；禁止空 IN () */
/* 过渡高产：对比窗 BKS ≥ 5 的账号才参与 |Δh|≥3h 异动判定（Agent 本地筛，勿与 03 拼成一条） */
/* 禁止改回 JOIN wolf_rateadjust_log（曾 MCP 43019） */

SELECT
    a.supplier_id,
    a.supplier_account_id,
    SUM(CASE
        WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date
        THEN 1 ELSE 0
    END) AS compare_bks,
    SUM(CASE
        WHEN a.channel_create_date::date BETWEEN '{current_start}'::date AND '{current_end}'::date
        THEN 1 ELSE 0
    END) AS current_bks
FROM dwd.dwd_hotel_order_channel_supplier_booking_mf a
WHERE a.channel_status_name_en IN ('Confirmed', 'Canceled')
    AND a.supplier_rebook_sequence = 1
    AND a.client_id = '{client_id}'
    AND a.supplier_id IN ({sid_list})
    AND a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
GROUP BY a.supplier_id, a.supplier_account_id
HAVING SUM(CASE
        WHEN a.channel_create_date::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date
        THEN 1 ELSE 0
    END) >= 5
ORDER BY a.supplier_id, compare_bks DESC;
