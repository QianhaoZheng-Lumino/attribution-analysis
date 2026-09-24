/* 13 S Bottom 明细（event_count > 0 时跑） */
/* 占位符: {w_start} {w_end} */
/* 与 C Bottom 同表：操作人都是 update_user。差别：item = 供应商号（不是 client） */
/* 禁止抄 detail/12-c-bottom-detail.sql（会把 item 当成 client_id） */
/* 口径仍为全局 Supplier（不加 clientid / 不加 {sid_list}） */
/* last_margin / last_is_remove：同一 item 更早的最近一条。空列写未验 */

SELECT
    t.update_time::date AS change_date,
    t.item AS supplier_id,
    t.margin,
    (
        SELECT p.margin
        FROM configuration.bottom_margin_log p
        WHERE p.level = 'Supplier'
            AND p.item = t.item
            AND p.update_time < t.update_time
        ORDER BY p.update_time DESC
        LIMIT 1
    ) AS last_margin,
    t.is_remove,
    (
        SELECT p.is_remove
        FROM configuration.bottom_margin_log p
        WHERE p.level = 'Supplier'
            AND p.item = t.item
            AND p.update_time < t.update_time
        ORDER BY p.update_time DESC
        LIMIT 1
    ) AS last_is_remove,
    t.update_user AS username
FROM configuration.bottom_margin_log t
WHERE t.level = 'Supplier'
    AND t.update_time::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY t.update_time
LIMIT 30;
