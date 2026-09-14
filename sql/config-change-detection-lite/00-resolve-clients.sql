-- Step 0：parent_client_id → client_id 列表
-- 替换 {parent_client_id}；若已知 client_id 可跳过

SELECT client_id
FROM crm.client_info_ods
WHERE parent_client_id = '{parent_client_id}'
  AND istest_account IS false
  AND client_group_id = 3
ORDER BY client_id;
