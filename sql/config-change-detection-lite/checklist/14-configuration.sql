/* 14 Configuration（14 key：PPS/QPS/timeout/映射，MCP 稳定） */

SELECT
    'Configuration' AS level,
    COUNT(*) AS event_count,
    MIN(created_at::date) AS first_dt,
    MAX(created_at::date) AS last_dt
FROM configuration.client_configuration_change_log
WHERE client_id = '{client_id}'
    AND created_at::date BETWEEN '{w_start}'::date AND '{w_end}'::date
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
    );
