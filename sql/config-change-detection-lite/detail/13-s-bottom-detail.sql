/* 13 S Bottom 明细（event_count > 0 时跑） */
/* 占位符: {w_start} {w_end} */
/* 与 C Bottom 同表：操作人都是 update_user。差别：item = 供应商号（不是 client） */
/* 禁止抄 detail/12-c-bottom-detail.sql（会把 item 当成 client_id） */
/* 口径仍为全局 Supplier（不加 clientid / 不加 {sid_list}） */
/* last_margin / last_is_remove：同一 item 更早的最近一条。空列写未验 */
/* 先圈出窗口内的供应商，只扫这些供应商的历史，用 LAG 带上一条 */

WITH window_item AS (
    SELECT DISTINCT item
    FROM configuration.bottom_margin_log
    WHERE level = 'Supplier'
        AND update_time::date BETWEEN '{w_start}'::date AND '{w_end}'::date
),
s_bottom AS (
    SELECT
        update_time,
        item,
        margin,
        is_remove,
        update_user,
        LAG(margin) OVER (
            PARTITION BY item
            ORDER BY update_time
        ) AS last_margin,
        LAG(is_remove) OVER (
            PARTITION BY item
            ORDER BY update_time
        ) AS last_is_remove
    FROM configuration.bottom_margin_log
    WHERE level = 'Supplier'
        AND item IN (SELECT item FROM window_item)
)
SELECT
    update_time::date AS change_date,
    item AS supplier_id,
    margin,
    last_margin,
    is_remove,
    last_is_remove,
    update_user AS username
FROM s_bottom
WHERE update_time::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY update_time
LIMIT 30;
