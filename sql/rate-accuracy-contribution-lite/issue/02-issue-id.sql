-- issue/02-issue-id | 3c 下钻：issue_id（可选 WHERE issue_type = N）

SELECT
    CASE WHEN t.is_request_chain = TRUE THEN t.issue_type_chain ELSE t.issue_type END AS issue_type,
    CASE WHEN t.is_request_chain = TRUE THEN t.issue_id_chain ELSE t.issue_id END AS issue_id,
    MAX(t.issue_id_channel_cn) AS issue_id_channel_cn,
    SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END) AS current_precheck,
    SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END) AS previous_precheck
FROM data_ovs.rate_accuracy_channel_multi_dimension t
WHERE t.dt = CURRENT_DATE
    AND t.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date
    AND t.client_id = '{client_id}'
GROUP BY 1, 2
HAVING SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END) > 0
ORDER BY current_precheck DESC
LIMIT 30;
