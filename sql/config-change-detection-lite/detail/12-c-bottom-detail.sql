/* C Bottom margin 明细 */
/* item = client_id；操作人列 = update_user（与 S Bottom 同列，同表） */
/* 禁止把本文件抄成 S Bottom：S 的 item 是供应商号。S Bottom 用 detail/13-s-bottom-detail.sql */
/* last_margin / last_is_remove：同一 item 更早的最近一条。空列写未验 */

SELECT
    t.update_time::date AS change_date,
    t.item AS client_id,
    t.margin,
    (
        SELECT p.margin
        FROM configuration.bottom_margin_log p
        WHERE p.level = 'Client'
            AND p.item = t.item
            AND p.update_time < t.update_time
        ORDER BY p.update_time DESC
        LIMIT 1
    ) AS last_margin,
    t.is_remove,
    (
        SELECT p.is_remove
        FROM configuration.bottom_margin_log p
        WHERE p.level = 'Client'
            AND p.item = t.item
            AND p.update_time < t.update_time
        ORDER BY p.update_time DESC
        LIMIT 1
    ) AS last_is_remove,
    t.update_user AS username
FROM configuration.bottom_margin_log t
WHERE t.level = 'Client'
    AND t.item = '{client_id}'
    AND t.update_time::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY t.update_time
LIMIT 30;
