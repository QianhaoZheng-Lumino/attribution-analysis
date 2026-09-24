/* 12-nationality.sql | Phase 3c lite | hierarchy 12_Nationality */
/* within_contribution_pp: Agent 本地算（README） */

SELECT '12_Nationality' AS hierarchy_level,
    t.nationality::text AS nationality,

    SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END) AS current_precheck,
    SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END) AS previous_precheck,
    SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.success_precheck ELSE 0 END) AS current_success_precheck,
    SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.success_precheck ELSE 0 END) AS previous_success_precheck,
    SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.success_precheck ELSE 0 END)::numeric
        / NULLIF(SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END), 0) AS current_accuracy,
    SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.success_precheck ELSE 0 END)::numeric
        / NULLIF(SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END), 0) AS previous_accuracy,
    (SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.success_precheck ELSE 0 END)::numeric
        / NULLIF(SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END), 0)
     - SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.success_precheck ELSE 0 END)::numeric
        / NULLIF(SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END), 0)) * 100 AS item_accuracy_delta_pp,
    SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END)
      - SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END) AS precheck_change


FROM data_ovs.rate_accuracy_channel_multi_dimension t
WHERE t.dt = CURRENT_DATE
    AND t.log_date BETWEEN '{compare_start}'::date AND '{current_end}'::date
    AND t.client_id = '{client_id}'

GROUP BY t.nationality
HAVING SUM(CASE WHEN t.log_date BETWEEN '{analysis_date}'::date AND '{current_end}'::date THEN t.precheck ELSE 0 END) > 0
    OR SUM(CASE WHEN t.log_date BETWEEN '{compare_start}'::date AND '{compare_end}'::date THEN t.precheck ELSE 0 END) > 0
ORDER BY item_accuracy_delta_pp ASC NULLS LAST LIMIT 50;
