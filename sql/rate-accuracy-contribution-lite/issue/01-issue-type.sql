/* issue/01-issue-type | 3c 下钻：issue_type 占比 current vs previous */
/* is_request_chain=True 用 _chain 字段 */

SELECT
    CASE WHEN t.is_request_chain = TRUE THEN t.issue_type_chain ELSE t.issue_type END AS issue_type,
    SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END) AS current_precheck,
    SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END) AS previous_precheck
FROM data_ovs.rate_accuracy_channel_multi_dimension t
WHERE t.dt = CURRENT_DATE
    AND t.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date
    AND t.client_id = '{client_id}'
GROUP BY 1
ORDER BY current_precheck DESC;
