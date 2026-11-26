/* issue/01-issue-type | 3c 下钻：issue_type 占比 current vs previous */
/* 数据源：rateaccuracy.rate_accuracy_channel（请求级明细）；汇总表无 issue 字段 */
/* is_request_chain=True 用 _chain 字段；按请求计数；北京时间窗用 TIMESTAMPTZ +08 */

SELECT
    CASE WHEN t.is_request_chain = TRUE THEN t.issue_type_chain ELSE t.issue_type END AS issue_type,
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
GROUP BY 1
ORDER BY current_precheck DESC;
