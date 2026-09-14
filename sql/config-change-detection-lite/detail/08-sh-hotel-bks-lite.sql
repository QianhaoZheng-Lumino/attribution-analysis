-- #8 SH hotel_bks lite | checklist/08 event_count ≥ 10 且已填 {sid_list} 时必跑
-- SH 日志 didahotelid 恒为 0，禁止抄 07-cdh-hotel-bks-lite 用 didahotelid
-- 映射：supplierid + supplierhotelid = npd_booking_view 同名字段；产量限定本 client
-- 占位符: {client_id} {sid_list} {w_start} {w_end} {compare_start} {compare_end} {current_start} {current_end}
-- MCP tables: configuration.wolf_rateadjust_hotel_log, public.npd_booking_view
-- 禁止用 clientid 滤 SH 日志；禁止 IN () 空 sid_list
-- event_count < 10 → 不跑本文件、不解读
-- after_hotel_bks ≈ 0 且机构 BKS 大涨/大跌 → 弱，禁止写「SH 定责」
-- 仍 500 或 checklist n>50000 → BI
-- MCP 冒烟 2026-09-08（COUNT 与 hotel_bks 均未 500）:
--   CVCTrend  07-17 | SID 26           | COUNT=145 = hotel 145 | bks 0→0
--   SnapEBK   07-11 | SID 26,116       | COUNT=1 仅 116；hotel 1 | bks 0→0 | n<10 不解读
--   DidaOpaq  09-01 | SID 116,565      | COUNT=0 → hotel_bks 空行 | 跳过 3b
--   Check24App 08-04 | SID 116,95,141,591 | COUNT=6082 全在 591 | hotel 6082 | bks 0→0

WITH sh_hotels AS (
    SELECT DISTINCT
        supplierid,
        supplierhotelid
    FROM configuration.wolf_rateadjust_hotel_log
    WHERE level = 'SH'
        AND supplierid IN ({sid_list})
        AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
        AND supplierhotelid IS NOT NULL
        AND supplierhotelid <> ''
)
SELECT
    'SH' AS level,
    h.supplierid,
    COUNT(DISTINCT h.supplierhotelid) AS affected_hotel_count,
    SUM(CASE WHEN b.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS before_hotel_bks,
    SUM(CASE WHEN b.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS after_hotel_bks
FROM sh_hotels h
LEFT JOIN public.npd_booking_view b
    ON b.supplierid = h.supplierid
    AND b.supplierhotelid = h.supplierhotelid
    AND b.clientid = '{client_id}'
    AND b.channel_status IN ('Confirmed', 'Canceled')
    AND b.rebook_sequence = 1
    AND b.channel_createdate::date BETWEEN '{compare_start}'::date AND '{current_end}'::date
GROUP BY h.supplierid
ORDER BY affected_hotel_count DESC
LIMIT 20;
