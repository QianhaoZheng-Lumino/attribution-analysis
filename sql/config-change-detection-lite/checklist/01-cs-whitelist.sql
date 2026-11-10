/* 1 CS 供应商白名单 | 与 checklist/01-cs.sql 同属 CS，不新开 Level */
/* 占位符: {client_id} {w_start} {w_end} */
/* 无 sid_list。只统计 I 与 D，不要统计 U */
/* 源数据 update_time 是毫秒。入库后本列是 timestamptz，用 update_time::date，禁止再除以 1000 */
/* event_count > 0 才跑 detail/01-cs-whitelist-detail.sql */

SELECT
    'CS' AS level,
    COUNT(*) AS event_count,
    COALESCE(SUM(CASE WHEN op_type = 'I' THEN 1 ELSE 0 END), 0) AS n_insert,
    COALESCE(SUM(CASE WHEN op_type = 'D' THEN 1 ELSE 0 END), 0) AS n_delete,
    COUNT(DISTINCT CASE WHEN op_type = 'I' THEN supplier_id END) AS n_sid_insert,
    COUNT(DISTINCT CASE WHEN op_type = 'D' THEN supplier_id END) AS n_sid_delete,
    MIN(update_time::date) AS first_dt,
    MAX(update_time::date) AS last_dt
FROM ods.ods_hotel_configuration_client_supplier_whitelist_log_d_i
WHERE client_id = '{client_id}'
    AND op_type IN ('I', 'D')
    AND update_time::date BETWEEN '{w_start}'::date AND '{w_end}'::date;
