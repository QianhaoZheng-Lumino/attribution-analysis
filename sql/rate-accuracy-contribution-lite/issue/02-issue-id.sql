/* issue/02-issue-id | 3c 下钻：issue_id（可选 WHERE 外层再筛 issue_type = N） */
/* 数据源：rateaccuracy.rate_accuracy_channel（请求级明细）；无 issue_id_channel_cn */
/* 硬规则：报告/ES 中文只用 docs/accuracy-issue-mapping.md 码表映射 issue_id */
/* 禁止把 issue_desc 整段贴进报告或 ES；issue_desc 仅排障辅助 */
/* is_request_chain=True 用 _chain 字段；按请求计数；北京时间窗用 TIMESTAMPTZ +08 */

SELECT
    CASE WHEN t.is_request_chain = TRUE THEN t.issue_type_chain ELSE t.issue_type END AS issue_type,
    CASE WHEN t.is_request_chain = TRUE THEN t.issue_id_chain ELSE t.issue_id END AS issue_id,
    MAX(CASE WHEN t.is_request_chain = TRUE THEN t.issue_desc_chain ELSE t.issue_desc END) AS issue_desc,
    SUM(CASE WHEN t.log_time >= TIMESTAMPTZ '{analysis_date} 00:00:00+08'
              AND t.log_time <  TIMESTAMPTZ '{current_end} 00:00:00+08' + INTERVAL '1 day'
         THEN 1 ELSE 0 END) AS current_precheck,
    SUM(CASE WHEN t.log_time >= TIMESTAMPTZ '{compare_start} 00:00:00+08'
              AND t.log_time <  TIMESTAMPTZ '{compare_end} 00:00:00+08' + INTERVAL '1 day'
         THEN 1 ELSE 0 END) AS previous_precheck
FROM rateaccuracy.rate_accuracy_channel t
WHERE t.log_time >= TIMESTAMPTZ '{compare_start} 00:00:00+08'
    AND t.log_time <  TIMESTAMPTZ '{current_end} 00:00:00+08' + INTERVAL '1 day'
    AND t.client_id = '{client_id}'
GROUP BY 1, 2
HAVING SUM(CASE WHEN t.log_time >= TIMESTAMPTZ '{analysis_date} 00:00:00+08'
                 AND t.log_time <  TIMESTAMPTZ '{current_end} 00:00:00+08' + INTERVAL '1 day'
            THEN 1 ELSE 0 END) > 0
ORDER BY current_precheck DESC
LIMIT 30;
