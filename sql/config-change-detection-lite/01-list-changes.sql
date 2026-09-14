-- Step 1a（MCP 可跑）：Configuration 类变更清单
-- Step 1b（BI）：完整 14 类见 ../config-change-detection.sql

WITH params AS (
    SELECT
        '2026-03-20'::date AS analysis_date,
        '' AS client_id,
        'Agoda' AS parent_client_id
)
, pid AS (
    SELECT client_id
    FROM crm.client_info_ods
    WHERE (
        parent_client_id IN (SELECT parent_client_id FROM params)
        OR client_id IN (SELECT client_id FROM params)
    )
    AND istest_account IS false
    AND client_group_id = 3
)
SELECT
    'Configuration' AS level,
    client_id AS clientid,
    0 AS supplierid,
    0 AS supplieraccountid,
    created_at AS updatedate,
    created_by AS username,
    configuration_key || ': ' || coalesce(old_value, 'null') || ' -> ' || coalesce(new_value, 'null') AS operation,
    'Wolf2.0配置改变' AS category
FROM configuration.client_configuration_change_log
WHERE client_id IN (SELECT client_id FROM pid)
  AND created_at::date >= (SELECT analysis_date FROM params) - interval '1 days'
  AND created_at::date <= (SELECT analysis_date FROM params) + interval '1 days'
  AND configuration_key IN (
      'MultiHotelPriceSearchRealTimePPS',
      'SingleHotelPriceSearchRealTimePPS',
      'PriceSearchCachePPS',
      'PriceConfirmQPS',
      'HotelSearchTimeout',
      'RatePlanSearchTimeout',
      'MultiHotelRealTimeSearchCount',
      'MultiHotelCacheSearchCount',
      'MappedRoomTypeTopCountForOptimalCancellationBreakfast',
      'UnmappedRoomTypeTopCountForOptimalCancellationBreakfast',
      'MappedRoomTypeTopCountForBreakfastCancellation',
      'UnmappedRoomTypeTopCountForBreakfastCancellation',
      'IgnoreChineseCode',
      'DidaHotelMandatoryFeesConfig'
  )
ORDER BY updatedate;
