-- 01-single-country-window | Phase 3d 证据线 D — 单国家 × 单窗口
-- 占位符: {country_code} {window_start} {window_end}
-- 可选: {max_dt} — 若空则子查询 MAX(dt)
--
-- 表：ads.ads_marketing_calendar_event_wide_d_f
-- 规则见 docs/external-events-mapping.md（全局表、仅 HOLIDAY、排除 WEATHER/展会/演唱会）

SELECT
    event_type,
    event_source,
    event_name,
    country_code,
    country_name_cn,
    city_name_cn,
    city_code,
    event_start_date,
    event_end_date,
    city_ttv,
    city_rank_no,
    opportunity_score
FROM ads.ads_marketing_calendar_event_wide_d_f
WHERE dt = (SELECT MAX(dt) FROM ads.ads_marketing_calendar_event_wide_d_f)
    AND country_code = '{country_code}'
    AND event_start_date <= '{window_end}'
    AND event_end_date >= '{window_start}'
    AND event_type = 'HOLIDAY'
    AND city_rank_no <= 30
ORDER BY
    city_ttv DESC NULLS LAST,
    event_start_date
LIMIT 30;
