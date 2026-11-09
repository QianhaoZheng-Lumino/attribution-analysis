/* 03-window-avg | CSA 自动上下线 · 账号两窗日均在线小时 + Δh（Phase 3 主用） */
/* 表: configuration.wolf_rateadjust_log（level = CSA，status=1 为在线） */
/* 占位符: {client_id} {sid_list} {compare_start} {compare_end} {current_start} {current_end} {compare_n_days} {current_n_days} */
/* {sid_list} 与限流 / SH / SS 同一套；禁止空 IN ()。一次只填一个 {client_id} */
/* {compare_n_days}/{current_n_days} = 止日含天数，填整数（如 7） */
/* 原始 CSA 行不要加时间过滤；LAG/LEAD 拼完整开闭后再裁两窗 */
/* 未闭合右端 = {current_end}+1 日 00:00，禁止 now() */
/* Autoline 常记在 JobAPI 下：禁止 username != JobAPI */
/* 高产筛选用 02-account-bks，禁止本文件 JOIN 订单表 */

WITH raw AS (
    SELECT
        clientid,
        supplierid,
        supplieraccountid,
        status::int AS status,
        EXTRACT(EPOCH FROM updatedate::timestamp) AS op_epoch
    FROM configuration.wolf_rateadjust_log
    WHERE level = 'CSA'
        AND clientid = '{client_id}'
        AND supplierid IN ({sid_list})
),
ordered AS (
    SELECT
        clientid,
        supplierid,
        supplieraccountid,
        status,
        op_epoch,
        LAG(status) OVER (
            PARTITION BY clientid, supplierid, supplieraccountid
            ORDER BY op_epoch
        ) AS prev_status
    FROM raw
),
changes AS (
    SELECT
        clientid,
        supplierid,
        supplieraccountid,
        status,
        op_epoch
    FROM ordered
    WHERE prev_status IS NULL OR status <> prev_status
),
spans AS (
    SELECT
        clientid,
        supplierid,
        supplieraccountid,
        status,
        op_epoch AS span_start,
        COALESCE(
            LEAD(op_epoch) OVER (
                PARTITION BY clientid, supplierid, supplieraccountid
                ORDER BY op_epoch
            ),
            EXTRACT(EPOCH FROM TIMESTAMP '{current_end} 00:00:00') + 86400.0
        ) AS span_end
    FROM changes
),
clip AS (
    SELECT
        clientid,
        supplierid,
        supplieraccountid,
        CASE
            WHEN span_end <= EXTRACT(EPOCH FROM TIMESTAMP '{compare_start} 00:00:00') THEN 0.0
            WHEN span_start >= EXTRACT(EPOCH FROM TIMESTAMP '{compare_end} 00:00:00') + 86400.0 THEN 0.0
            ELSE
                (CASE
                    WHEN span_end < EXTRACT(EPOCH FROM TIMESTAMP '{compare_end} 00:00:00') + 86400.0
                    THEN span_end
                    ELSE EXTRACT(EPOCH FROM TIMESTAMP '{compare_end} 00:00:00') + 86400.0
                END)
              - (CASE
                    WHEN span_start > EXTRACT(EPOCH FROM TIMESTAMP '{compare_start} 00:00:00')
                    THEN span_start
                    ELSE EXTRACT(EPOCH FROM TIMESTAMP '{compare_start} 00:00:00')
                END)
        END AS prev_sec,
        CASE
            WHEN span_end <= EXTRACT(EPOCH FROM TIMESTAMP '{current_start} 00:00:00') THEN 0.0
            WHEN span_start >= EXTRACT(EPOCH FROM TIMESTAMP '{current_end} 00:00:00') + 86400.0 THEN 0.0
            ELSE
                (CASE
                    WHEN span_end < EXTRACT(EPOCH FROM TIMESTAMP '{current_end} 00:00:00') + 86400.0
                    THEN span_end
                    ELSE EXTRACT(EPOCH FROM TIMESTAMP '{current_end} 00:00:00') + 86400.0
                END)
              - (CASE
                    WHEN span_start > EXTRACT(EPOCH FROM TIMESTAMP '{current_start} 00:00:00')
                    THEN span_start
                    ELSE EXTRACT(EPOCH FROM TIMESTAMP '{current_start} 00:00:00')
                END)
        END AS curr_sec
    FROM spans
    WHERE status = 1
)
SELECT
    clientid,
    supplierid,
    supplieraccountid,
    ROUND((SUM(GREATEST(0.0, prev_sec)) / 3600.0 / {compare_n_days})::numeric, 2) AS avg_online_hours_previous,
    ROUND((SUM(GREATEST(0.0, curr_sec)) / 3600.0 / {current_n_days})::numeric, 2) AS avg_online_hours_current,
    ROUND((
        SUM(GREATEST(0.0, curr_sec)) / 3600.0 / {current_n_days}
      - SUM(GREATEST(0.0, prev_sec)) / 3600.0 / {compare_n_days}
    )::numeric, 2) AS delta_h
FROM clip
GROUP BY clientid, supplierid, supplieraccountid
ORDER BY supplierid, ABS(
    SUM(GREATEST(0.0, curr_sec)) / 3600.0 / {current_n_days}
  - SUM(GREATEST(0.0, prev_sec)) / 3600.0 / {compare_n_days}
) DESC;
