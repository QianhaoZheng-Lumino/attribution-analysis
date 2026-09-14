-- #8 SH | 大表且无可用 clientid；必须填结构 SID，禁止全表、禁止 clientid
-- 占位符: {sid_list} {w_start} {w_end}
-- {sid_list} = 2b 锁定 SID，或占本案 |ΔBKS|≥10% 的 SID，逗号分隔整数，如 26, 95, 61
-- 无结构 SID 时填 02-sid |change| Top3。禁止 IN () 空列表
-- event_count ≥ 10 才跑 detail/08-sh-hotel-bks-lite.sql；<10 不解读；>50000 → BI

SELECT
    'SH' AS level,
    COUNT(*) AS event_count,
    MIN(updatedate::date) AS first_dt,
    MAX(updatedate::date) AS last_dt
FROM configuration.wolf_rateadjust_hotel_log
WHERE level = 'SH'
    AND supplierid IN ({sid_list})
    AND updatedate::date BETWEEN '{w_start}'::date AND '{w_end}'::date;
