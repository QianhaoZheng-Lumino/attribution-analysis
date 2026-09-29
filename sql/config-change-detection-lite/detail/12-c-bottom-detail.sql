/* C Bottom margin 明细 */
/* item = client_id；操作人列 = update_user（与 S Bottom 同列，同表） */
/* 禁止把本文件抄成 S Bottom：S 的 item 是供应商号。S Bottom 用 detail/13-s-bottom-detail.sql */
/* last_margin / last_is_remove：同一 item 更早的最近一条。空列写未验 */
/* 先扫该客户全部兜底行，用 LAG 带出上一条，再裁到分析窗 */

WITH c_bottom AS (
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
    WHERE level = 'Client'
        AND item = '{client_id}'
)
SELECT
    update_time::date AS change_date,
    item AS client_id,
    margin,
    last_margin,
    is_remove,
    last_is_remove,
    update_user AS username
FROM c_bottom
WHERE update_time::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY update_time
LIMIT 30;
