/* 7 CDH hotel_bks lite | event_count > 0 时必跑（MCP 单行聚合） */
/* WITH 调价酒店清单 join 订单，仅统计本次 CDH 涉及 didahotelid 上的产量 */
/* 占位符: {client_id} {w_start} {w_end} {compare_start} {compare_end} {current_start} {current_end} */
/* MCP tables: configuration.wolf_rateadjust_hotel_log, public.npd_booking_view */
/* 窗口: before = compare 期, after = current 期（对齐 Phase 1） */
/* 仍 500 或 event_count > 50000 → BI cdh-lcdh-hotel-bks.sql */

WITH cdh_hotels AS (
    SELECT DISTINCT didahotelid
    FROM configuration.wolf_rateadjust_hotel_log
    WHERE level = 'CDH'
        AND clientid = '{client_id}'
        AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
)
SELECT
    'CDH' AS level,
    COUNT(DISTINCT h.didahotelid) AS affected_hotel_count,
    SUM(CASE WHEN b.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS before_hotel_bks,
    SUM(CASE WHEN b.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS after_hotel_bks
FROM cdh_hotels h
LEFT JOIN public.npd_booking_view b
    ON b.didahotelid = h.didahotelid
    AND b.clientid = '{client_id}'
    AND b.channel_status IN ('Confirmed', 'Canceled')
    AND b.rebook_sequence = 1
    AND b.channel_createdate::date BETWEEN '{compare_start}'::date AND '{current_end}'::date;
