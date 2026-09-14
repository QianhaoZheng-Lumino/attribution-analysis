-- C Bottom margin 明细
-- item = client_id；操作人列 = update_by
-- 禁止把本文件抄成 S Bottom。S Bottom 用 detail/13-s-bottom-detail.sql（item=供应商，update_user）

SELECT
    update_time::date AS change_date,
    item AS client_id,
    margin,
    update_by AS username
FROM configuration.bottom_margin_log
WHERE level = 'Client'
    AND item = '{client_id}'
    AND update_time::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY update_time
LIMIT 30;
