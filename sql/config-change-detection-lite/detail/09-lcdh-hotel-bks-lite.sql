/* 9 LCDH hotel_bks lite | event_count > 0 时必跑（MCP 单行聚合） */
/* WITH 击穿兜底名单变更酒店 join 订单；增/删语义见 checklist/09-lcdh.sql + BI 片段 */
/* 占位符: {client_id} {w_start} {w_end} {compare_start} {compare_end} {current_start} {current_end} */
/* MCP tables: configuration.wolf_rateadjust_hotel_log, public.npd_booking_view */
/* 仍 500 → BI cdh-lcdh-hotel-bks.sql */

WITH lcdh_hotels AS (
    SELECT DISTINCT didahotelid
    FROM configuration.wolf_rateadjust_hotel_log
    WHERE level = 'LCDH'
        AND clientid = '{client_id}'
        AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date
)
SELECT
    'LCDH' AS level,
    COUNT(DISTINCT h.didahotelid) AS affected_hotel_count,
    SUM(CASE WHEN b.channel_createdate::date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN 1 ELSE 0 END) AS before_hotel_bks,
    SUM(CASE WHEN b.channel_createdate::date BETWEEN '{current_start}'::date AND '{current_end}'::date THEN 1 ELSE 0 END) AS after_hotel_bks
FROM lcdh_hotels h
LEFT JOIN public.npd_booking_view b
    ON b.didahotelid = h.didahotelid
    AND b.clientid = '{client_id}'
    AND b.channel_status IN ('Confirmed', 'Canceled')
    AND b.rebook_sequence = 1
    AND b.channel_createdate::date BETWEEN '{compare_start}'::date AND '{current_end}'::date;
