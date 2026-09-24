/* Configuration 14 key 明细（PPS/QPS/timeout/映射） */

SELECT
    created_at::date AS change_date,
    client_id,
    configuration_key,
    old_value,
    new_value,
    created_by AS username
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
    )
ORDER BY created_at
LIMIT 50;
