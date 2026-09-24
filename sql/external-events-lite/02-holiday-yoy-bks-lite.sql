/* 02-holiday-yoy-bks-lite | Phase 3d D2 — YoY 同节日 client×国别 BKS */

/* ⚠️ 硬规则（2026-08-18 · TH Songkran 手写 pre 漏国别过滤事故）： */
/* 1. Agent 必须 Read 本文件原文执行，禁止手写 D2 SQL */
/* 2. Rubric 仅用 country_*_bks；pre_bks/during_bks/post_bks 为 client 全量，不可混读 */
/* 3. 占位符说明见 d2-params-template.md */

/* 日期来自 holiday-canonical-seed.csv（非 ads 表） */
/* 占位符: */
/* {client_id} {country_code} */
/* {y1_holiday_start} {y1_holiday_end}     较早年节窗（如 2024-03-31） */
/* {y2_holiday_start} {y2_holiday_end}     较新年节窗（如 2025-03-31） */
/* {pre_days} {post_days}                    默认 7；单日节可 3 */
/* {client_window_start} {client_window_end}    Phase 1 分析全窗（client 门槛 ≥100） */

/* MCP tables: public.npd_booking_view, content.dida_hotel_view */
/* 口径（MVP）: channel_createdate::date — 与 Phase 1/2c create 口径对齐 */
/* 未来优化（讨论 2026-08-18）: 节日 pre/during/post 应对齐 checkoutdate::date（离店/消费发生）， */
/* 而非下单日；需单独 02-checkout 版 SQL + 与 Phase 1 WoW 窗解耦说明（见 external-events-mapping §10.9） */
/* 门槛（讨论定稿）: 国别 during+post 合并窗 BKS≥20；client 全窗≥100 → 否则 inconclusive */
/* 输出: 两年 pre/during/post + client 全窗 + 国别 holiday 覆盖窗合计 */

WITH params AS (
    SELECT
        {pre_days}::int AS pre_days,
        {post_days}::int AS post_days
),
windows AS (
    SELECT
        'y1' AS cohort,
        '{y1_holiday_start}'::date AS h_start,
        '{y1_holiday_end}'::date AS h_end,
        '{y1_holiday_start}'::date - (SELECT pre_days FROM params) * INTERVAL '1 day' AS pre_start,
        '{y1_holiday_start}'::date - INTERVAL '1 day' AS pre_end,
        '{y1_holiday_end}'::date + INTERVAL '1 day' AS post_start,
        '{y1_holiday_end}'::date + (SELECT post_days FROM params) * INTERVAL '1 day' AS post_end
    UNION ALL
    SELECT
        'y2',
        '{y2_holiday_start}'::date,
        '{y2_holiday_end}'::date,
        '{y2_holiday_start}'::date - (SELECT pre_days FROM params) * INTERVAL '1 day',
        '{y2_holiday_start}'::date - INTERVAL '1 day',
        '{y2_holiday_end}'::date + INTERVAL '1 day',
        '{y2_holiday_end}'::date + (SELECT post_days FROM params) * INTERVAL '1 day'
),
bookings AS (
    SELECT
        a.channel_createdate::date AS bk_date,
        COALESCE(h.country_code, 'Unknown') AS country_code
    FROM public.npd_booking_view a
    LEFT JOIN content.dida_hotel_view h ON a.didahotelid = h.hotel_id
    WHERE a.channel_status IN ('Confirmed', 'Canceled')
        AND a.rebook_sequence = 1
        AND a.clientid = '{client_id}'
        AND a.channel_createdate::date >= LEAST(
            (SELECT MIN(pre_start) FROM windows),
            '{client_window_start}'::date
        )
        AND a.channel_createdate::date <= GREATEST(
            (SELECT MAX(post_end) FROM windows),
            '{client_window_end}'::date
        )
),
segment_bks AS (
    SELECT
        w.cohort,
        SUM(CASE WHEN b.bk_date BETWEEN w.pre_start AND w.pre_end THEN 1 ELSE 0 END) AS pre_bks,
        SUM(CASE WHEN b.bk_date BETWEEN w.h_start AND w.h_end THEN 1 ELSE 0 END) AS during_bks,
        SUM(CASE WHEN b.bk_date BETWEEN w.post_start AND w.post_end THEN 1 ELSE 0 END) AS post_bks,
        SUM(CASE WHEN b.bk_date BETWEEN w.pre_start AND w.pre_end
                  AND b.country_code = '{country_code}' THEN 1 ELSE 0 END) AS country_pre_bks,
        SUM(CASE WHEN b.bk_date BETWEEN w.h_start AND w.h_end
                  AND b.country_code = '{country_code}' THEN 1 ELSE 0 END) AS country_during_bks,
        SUM(CASE WHEN b.bk_date BETWEEN w.post_start AND w.post_end
                  AND b.country_code = '{country_code}' THEN 1 ELSE 0 END) AS country_post_bks,
        SUM(CASE WHEN b.bk_date BETWEEN w.pre_start AND w.post_end
                  AND b.country_code = '{country_code}' THEN 1 ELSE 0 END) AS country_holiday_span_bks
    FROM windows w
    LEFT JOIN bookings b
        ON b.bk_date BETWEEN w.pre_start AND w.post_end
    GROUP BY w.cohort
)
SELECT
    s.cohort,
    s.pre_bks,
    s.during_bks,
    s.post_bks,
    s.country_pre_bks,
    s.country_during_bks,
    s.country_post_bks,
    s.country_holiday_span_bks,
    (SELECT COUNT(*) FROM bookings b
     WHERE b.bk_date BETWEEN '{client_window_start}'::date AND '{client_window_end}'::date) AS client_window_bks,
    CASE
        WHEN (SELECT COUNT(*) FROM bookings b
              WHERE b.bk_date BETWEEN '{client_window_start}'::date AND '{client_window_end}'::date) < 100
            THEN 'inconclusive_client_lt100'
        WHEN s.country_holiday_span_bks < 20
            THEN 'inconclusive_country_lt20'
        ELSE 'ok'
    END AS gate_status
FROM segment_bks s
ORDER BY s.cohort;
