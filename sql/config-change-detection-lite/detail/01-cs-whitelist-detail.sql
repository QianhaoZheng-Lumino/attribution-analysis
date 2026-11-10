/* CS 供应商白名单明细 | checklist event_count > 0 时跑，只列 I 与 D */
/* 占位符: {client_id} {w_start} {w_end} */
/* 只列 I 与 D，不查 U。条数以 checklist 的 n_insert / n_delete 为准 */
/* 随后用 supplier_id 跑 detail/cs-supplier-bks.sql；不在已查 sid_list 里的再跑 01-ss-supplier.sql */

SELECT
    update_time::date AS update_date,
    op_type,
    client_id,
    supplier_id
FROM ods.ods_hotel_configuration_client_supplier_whitelist_log_d_i
WHERE client_id = '{client_id}'
    AND op_type IN ('I', 'D')
    AND update_time::date BETWEEN '{w_start}'::date AND '{w_end}'::date
ORDER BY update_time, supplier_id
LIMIT 30;
