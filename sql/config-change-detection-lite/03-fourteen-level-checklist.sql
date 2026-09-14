-- =============================================================================
-- MCP FORBIDDEN — 禁止 execute_sql 本文件
-- 14 路 UNION → 必 HTTP 500。仅 BI 参考。
-- MCP 必须逐条跑 checklist/01-cs.sql … 14-configuration.sql（一次一个文件）。
-- =============================================================================
-- 请改用 checklist/01-cs.sql … 14-configuration.sql 逐条执行，见 README.md「推荐流程」。
--
-- Phase 3：14 类配置「逐项必查」扫描（不含产量/查价 join，避免被 bks 过滤漏项）
-- 用途：BI 跑本脚本 → Agent 填满 14 行清单 → 再对有条目的 level 跑完整 config-change-detection.sql
-- 参数：改 params 即可

WITH params AS (
    SELECT
        '2026-02-06'::date AS analysis_date,
        'DidaOpaq'::text AS client_id,
        ''::text AS parent_client_id
),
pid AS (
    SELECT client_id
    FROM crm.client_info_ods
    WHERE (
        parent_client_id IN (SELECT parent_client_id FROM params WHERE parent_client_id <> '')
        OR client_id IN (SELECT client_id FROM params WHERE client_id <> '')
    )
    AND istest_account IS false
    AND client_group_id = 3
),
win AS (
    SELECT
        analysis_date,
        analysis_date - interval '1 days' AS w_start,
        analysis_date + interval '1 days' AS w_end
    FROM params
),

-- 1 CS
cs AS (
    SELECT 'CS'::text AS level, count(*) AS event_count,
           min(updatedate)::date AS first_dt, max(updatedate)::date AS last_dt,
           string_agg(DISTINCT clientid || '|S' || supplierid::text, '; ' ORDER BY clientid || '|S' || supplierid::text) AS keys_sample
    FROM (
        SELECT clientid, supplierid, updatedate, status,
               lag(status) OVER (PARTITION BY clientid, supplierid ORDER BY updatedate) AS ls
        FROM configuration.wolf_rateadjust_log
        WHERE level = 'CS' AND clientid IN (SELECT client_id FROM pid)
    ) t, win w
    WHERE updatedate::date BETWEEN w.w_start AND w.w_end
      AND ls IS NOT NULL AND status IS DISTINCT FROM ls
),

-- 2 C
c AS (
    SELECT 'C', count(*), min(updatedate)::date, max(updatedate)::date,
           string_agg(DISTINCT clientid, '; ')
    FROM (
        SELECT clientid, updatedate, status, margin,
               lag(status) OVER (PARTITION BY clientid ORDER BY updatedate) AS ls,
               lag(margin) OVER (PARTITION BY clientid ORDER BY updatedate) AS lm
        FROM configuration.wolf_rateadjust_log
        WHERE level = 'C' AND clientid IN (SELECT client_id FROM pid)
    ) t, win w
    WHERE updatedate::date BETWEEN w.w_start AND w.w_end
      AND ((ls IS NOT NULL AND status IS DISTINCT FROM ls) OR (lm IS NOT NULL AND margin IS DISTINCT FROM lm))
),

-- 3 S
s AS (
    SELECT 'S', count(*), min(updatedate)::date, max(updatedate)::date,
           string_agg(DISTINCT 'S' || supplierid::text, '; ')
    FROM (
        SELECT supplierid, updatedate, status, margin,
               lag(status) OVER (PARTITION BY supplierid ORDER BY updatedate) AS ls,
               lag(margin) OVER (PARTITION BY supplierid ORDER BY updatedate) AS lm
        FROM (
            SELECT level, supplierid, status, margin, updatedate,
                   row_number() OVER (PARTITION BY level, supplierid, updatedate::date ORDER BY updatedate DESC) AS rk
            FROM configuration.wolf_rateadjust_log
            WHERE level = 'S' AND username != 'JobAPI'
        ) x WHERE rk = 1
    ) t, win w
    WHERE updatedate::date BETWEEN w.w_start AND w.w_end
      AND ((ls IS NOT NULL AND status IS DISTINCT FROM ls) OR (lm IS NOT NULL AND margin IS DISTINCT FROM lm))
),

-- 4 CSA
csa AS (
    SELECT 'CSA', count(*), min(updatedate)::date, max(updatedate)::date,
           string_agg(DISTINCT clientid || '|S' || supplierid::text || '|A' || supplieraccountid::text, '; ')
    FROM (
        SELECT clientid, supplierid, supplieraccountid, updatedate, status, margin,
               lag(status) OVER (PARTITION BY clientid, supplierid, supplieraccountid ORDER BY updatedate) AS ls,
               lag(margin) OVER (PARTITION BY clientid, supplierid, supplieraccountid ORDER BY updatedate) AS lm
        FROM configuration.wolf_rateadjust_log
        WHERE level = 'CSA' AND clientid IN (SELECT client_id FROM pid) AND username != 'JobAPI'
    ) t, win w
    WHERE updatedate::date BETWEEN w.w_start AND w.w_end
      AND ((ls IS NOT NULL AND status IS DISTINCT FROM ls) OR (lm IS NOT NULL AND margin IS DISTINCT FROM lm))
),

-- 5 CBD
cbd AS (
    SELECT 'CBD', count(*), min(bookingstartdate)::date, max(bookingstartdate)::date,
           string_agg(DISTINCT clientid, '; ')
    FROM configuration.wolf_rateadjust_log, win w
    WHERE level = 'CBD' AND clientid IN (SELECT client_id FROM pid)
      AND bookingstartdate::date BETWEEN w.w_start AND w.w_end
),

-- 6 SBD
sbd AS (
    SELECT 'SBD', count(*), min(bookingstartdate)::date, max(bookingstartdate)::date,
           string_agg(DISTINCT 'S' || supplierid::text, '; ')
    FROM configuration.wolf_rateadjust_log, win w
    WHERE level = 'SBD'
      AND bookingstartdate::date BETWEEN w.w_start AND w.w_end
),

-- 7 CDH
cdh AS (
    SELECT 'CDH', count(*), min(updatedate)::date, max(updatedate)::date,
           string_agg(DISTINCT clientid || '|' || CASE WHEN status = 1 THEN '开' ELSE '关' END || '|' || hotel_cnt::text, '; ')
    FROM (
        SELECT clientid, status, updatedate::date, uniq(didahotelid) AS hotel_cnt
        FROM configuration.wolf_rateadjust_hotel_log, win w
        WHERE level = 'CDH' AND clientid IN (SELECT client_id FROM pid)
          AND updatedate::date BETWEEN w.w_start AND w.w_end
        GROUP BY 1, 2, 3
    ) t
),

-- 8 SH
sh AS (
    SELECT 'SH', count(*), min(updatedate)::date, max(updatedate)::date,
           string_agg(DISTINCT 'S' || supplierid::text || '|' || hotel_cnt::text, '; ')
    FROM (
        SELECT supplierid, updatedate::date, uniq(supplierhotelid) AS hotel_cnt
        FROM configuration.wolf_rateadjust_hotel_log, win w
        WHERE level = 'SH' AND updatedate::date BETWEEN w.w_start AND w.w_end
        GROUP BY 1, 2
        HAVING uniq(supplierhotelid) >= 10
    ) t
),

-- 9 LCDH
lcdh AS (
    SELECT 'LCDH', count(*), min(updatedate)::date, max(updatedate)::date,
           string_agg(DISTINCT clientid || '|' || op || '|' || hotel_cnt::text, '; ')
    FROM (
        SELECT clientid, updatedate::date,
               CASE WHEN deletetime IS NOT NULL OR remark ILIKE '%删除%' THEN '删' ELSE '增' END AS op,
               uniq(didahotelid) AS hotel_cnt
        FROM configuration.wolf_rateadjust_hotel_log, win w
        WHERE level = 'LCDH' AND clientid IN (SELECT client_id FROM pid)
          AND updatedate::date BETWEEN w.w_start AND w.w_end
        GROUP BY 1, 2, 3
    ) t
),

-- 10 L2L
l2l AS (
    SELECT 'L2L', count(*), min(updatetime)::date, max(updatetime)::date,
           string_agg(DISTINCT clientid || ':' || coalesce(last_level::text, '?') || '->' || level::text, '; ')
    FROM (
        SELECT clientid, level, updatetime,
               lag(level) OVER (PARTITION BY clientid ORDER BY updatetime) AS last_level
        FROM configuration.wolfl2lclientlevelconfiglog
        WHERE clientid IN (SELECT client_id FROM pid)
    ) t, win w
    WHERE updatetime::date BETWEEN w.w_start AND w.w_end
),

-- 11 CSLRC
cslrc AS (
    SELECT 'CSLRC', count(*), min(updatetime)::date, max(updatetime)::date,
           string_agg(DISTINCT 'S' || supplierid::text || '|limit=' || islimit::text, '; ')
    FROM (
        SELECT clientid, supplierid, islimit, updatetime,
               row_number() OVER (PARTITION BY clientid, supplierid, supplieraccountid, updatetime::date ORDER BY updatetime DESC) AS rk
        FROM configuration.wolfl2lconfiglog
        WHERE clientid IN (SELECT client_id FROM pid) AND l2llevel = 'CSLRC'
    ) t, win w
    WHERE rk = 1 AND updatetime::date BETWEEN w.w_start AND w.w_end
),

-- 12 C Bottom
c_bottom AS (
    SELECT 'C Bottom', count(*), min(update_time)::date, max(update_time)::date,
           string_agg(DISTINCT item || ':' || round(lm::numeric, 2)::text || '->' || round(margin::numeric, 2)::text, '; ')
    FROM (
        SELECT item, margin, update_time,
               lag(margin) OVER (PARTITION BY level, item ORDER BY update_time) AS lm
        FROM configuration.bottom_margin_log
        WHERE level = 'Client' AND item IN (SELECT client_id FROM pid)
    ) t, win w
    WHERE update_time::date BETWEEN w.w_start AND w.w_end
      AND margin IS DISTINCT FROM lm
),

-- 13 S Bottom
s_bottom AS (
    SELECT 'S Bottom', count(*), min(update_time)::date, max(update_time)::date,
           string_agg(DISTINCT 'S' || item || ':' || round(lm::numeric, 2)::text || '->' || round(margin::numeric, 2)::text, '; ')
    FROM (
        SELECT item, margin, update_time,
               lag(margin) OVER (PARTITION BY level, item ORDER BY update_time) AS lm
        FROM configuration.bottom_margin_log
        WHERE level = 'Supplier'
    ) t, win w
    WHERE update_time::date BETWEEN w.w_start AND w.w_end
      AND margin IS DISTINCT FROM lm
),

-- 14 Configuration
cfg AS (
    SELECT 'Configuration', count(*), min(created_at)::date, max(created_at)::date,
           string_agg(DISTINCT configuration_key, '; ')
    FROM configuration.client_configuration_change_log, win w
    WHERE client_id IN (SELECT client_id FROM pid)
      AND created_at::date BETWEEN w.w_start AND w.w_end
      AND configuration_key IN (
          'MultiHotelPriceSearchRealTimePPS', 'SingleHotelPriceSearchRealTimePPS',
          'PriceSearchCachePPS', 'PriceConfirmQPS',
          'HotelSearchTimeout', 'RatePlanSearchTimeout',
          'MultiHotelRealTimeSearchCount', 'MultiHotelCacheSearchCount',
          'MappedRoomTypeTopCountForOptimalCancellationBreakfast',
          'UnmappedRoomTypeTopCountForOptimalCancellationBreakfast',
          'MappedRoomTypeTopCountForBreakfastCancellation',
          'UnmappedRoomTypeTopCountForBreakfastCancellation',
          'IgnoreChineseCode', 'DidaHotelMandatoryFeesConfig'
      )
)

SELECT
    level,
    event_count,
    first_dt,
    last_dt,
    keys_sample AS detail_sample,
    CASE WHEN event_count = 0 THEN '无记录（仍需在清单标注✓）' ELSE '有条目→跑完整 SQL 取 before/after' END AS next_step
FROM (
    SELECT * FROM cs UNION ALL SELECT * FROM c UNION ALL SELECT * FROM s UNION ALL SELECT * FROM csa
    UNION ALL SELECT * FROM cbd UNION ALL SELECT * FROM sbd UNION ALL SELECT * FROM cdh UNION ALL SELECT * FROM sh
    UNION ALL SELECT * FROM lcdh UNION ALL SELECT * FROM l2l UNION ALL SELECT * FROM cslrc
    UNION ALL SELECT * FROM c_bottom UNION ALL SELECT * FROM s_bottom UNION ALL SELECT * FROM cfg
) all_levels
ORDER BY
    CASE level
        WHEN 'C' THEN 1 WHEN 'C Bottom' THEN 2 WHEN 'L2L' THEN 3 WHEN 'CSLRC' THEN 4
        WHEN 'Configuration' THEN 5 WHEN 'LCDH' THEN 6 WHEN 'CDH' THEN 7
        WHEN 'CS' THEN 8 WHEN 'CSA' THEN 9 WHEN 'S' THEN 10 WHEN 'S Bottom' THEN 11
        WHEN 'SH' THEN 12 WHEN 'CBD' THEN 13 WHEN 'SBD' THEN 14
    END;
