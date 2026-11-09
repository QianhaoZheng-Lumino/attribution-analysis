/* 01-daily-account | CSA 自动上下线 · 按日在线小时（client × supplier × account） */
/* 表: configuration.wolf_rateadjust_log（level = CSA，status=1 为在线） */
/* 占位符: {client_id} {sid_list} {series_start} {series_end} */
/* {sid_list} 与限流 / SH / SS 同一套：2b 锁定，或占本案 |ΔBKS|≥10%；无则 02-sid |change| Top3 */
/* 禁止空 IN ()。一次只填一个 {client_id}。止日 {series_end} 含当天。 */
/* 原始 CSA 行不要加时间过滤；用 LAG/LEAD 拼完整开闭区间后再按日裁切。 */
/* 未闭合的在线段：右端收到 {series_end}+1 日 00:00，禁止用 now()（归因窗必须可复现）。 */
/* Autoline 常记在 JobAPI 下：禁止 username != JobAPI（与 3a CSA detail 外层排除 JobAPI 相反）。 */

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
            EXTRACT(EPOCH FROM TIMESTAMP '{series_end} 00:00:00') + 86400.0
        ) AS span_end
    FROM changes
),
on_spans AS (
    SELECT
        clientid,
        supplierid,
        supplieraccountid,
        span_start,
        span_end
    FROM spans
    WHERE status = 1
        AND span_end > EXTRACT(EPOCH FROM TIMESTAMP '{series_start} 00:00:00')
),
accts AS (
    SELECT DISTINCT
        clientid,
        supplierid,
        supplieraccountid
    FROM raw
),
days AS (
    SELECT
        d::date AS dt,
        EXTRACT(EPOCH FROM d::timestamp) AS day_start
    FROM generate_series(
        '{series_start}'::date,
        '{series_end}'::date,
        '1 day'::interval
    ) AS d
)
SELECT
    a.clientid,
    a.supplierid,
    a.supplieraccountid,
    to_char(dy.dt, 'YYYY-MM-DD') AS dt,
    ROUND((COALESCE(SUM(
        CASE
            WHEN s.span_start IS NULL THEN 0.0
            ELSE GREATEST(
                0.0,
                LEAST(s.span_end, dy.day_start + 86400.0)
                    - GREATEST(s.span_start, dy.day_start)
            )
        END
    ), 0) / 3600.0)::numeric, 2) AS csa_online_hours
FROM accts a
CROSS JOIN days dy
LEFT JOIN on_spans s
    ON s.clientid = a.clientid
   AND s.supplierid = a.supplierid
   AND s.supplieraccountid = a.supplieraccountid
   AND s.span_start < dy.day_start + 86400.0
   AND s.span_end > dy.day_start
GROUP BY a.clientid, a.supplierid, a.supplieraccountid, dy.dt
ORDER BY a.clientid, a.supplierid, a.supplieraccountid, dy.dt;
