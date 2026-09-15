-- #13 S Bottom 明细（event_count > 0 时跑）
-- 占位符: {w_start} {w_end}
-- 与 C Bottom 同表：操作人都是 update_user。差别：item = 供应商号（不是 client）
-- 禁止抄 detail/12-c-bottom-detail.sql（会把 item 当成 client_id）
-- 口径仍为全局 Supplier（不加 clientid / 不加 {sid_list}）

SELECT
    update_time::date AS change_date,
    item AS supplier_id,
    margin,
    update_user AS username,
    is_remove
FROM configuration.bottom_margin_log
WHERE level = 'Supplier'
    AND update_time::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY update_time
LIMIT 30;
