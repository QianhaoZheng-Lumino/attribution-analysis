/* 客户 × 日 在线时长表（Hologres 批处理，可选） */
/* 22 已收口：归因走 MCP 单 client 开窗，不依赖本文件。本文件仅全客户落表时用。 */

/* 相对完整版的加速： */
/* 1. 用 channel_operation_time（毫秒）过滤，不先 to_timestamp 扫全表 */
/* 2. 窗前每个 client 只取 1 条，不对全部历史做 LAG */
/* 3. LAG/LEAD 只打在「窗前 1 条 ∪ 窗内日志」上 */
/* 4. 客户维限定 crm Overseas 生产客户（client_group_id=3），缩小扫描 */

/* 日期只改下面 params：start_date 含，end_date 不含（默认算到北京昨天） */
/* 无 rateaccuracy 写权限时，改表名 schema */

/* ========== 1) 建表：空库只跑一次。表已有数据时不要重跑 CALL ========== */
BEGIN;

CREATE TABLE IF NOT EXISTS rateaccuracy.channel_online_hours_daily (
    client_id     TEXT         NOT NULL,
    dt            DATE         NOT NULL,
    online_hours  NUMERIC(6,2) NOT NULL,
    online_pct    NUMERIC(5,1) NOT NULL,
    PRIMARY KEY (client_id, dt)
);

CALL set_table_property('rateaccuracy.channel_online_hours_daily', 'orientation', 'column');
CALL set_table_property('rateaccuracy.channel_online_hours_daily', 'distribution_key', 'client_id');
CALL set_table_property('rateaccuracy.channel_online_hours_daily', 'clustering_key', 'dt:asc');
CALL set_table_property('rateaccuracy.channel_online_hours_daily', 'bitmap_columns', 'client_id');

COMMIT;

/* ========== 2) 填数：可重复跑。只改这一处日期 ========== */
DROP TABLE IF EXISTS tmp_oh_params;
CREATE TEMP TABLE tmp_oh_params AS
SELECT
    DATE '2025-01-01' AS start_date,
    (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Shanghai')::date AS end_date;

DELETE FROM rateaccuracy.channel_online_hours_daily
WHERE dt >= (SELECT start_date FROM tmp_oh_params)
  AND dt <  (SELECT end_date   FROM tmp_oh_params);

INSERT INTO rateaccuracy.channel_online_hours_daily (client_id, dt, online_hours, online_pct)
WITH params AS (
    SELECT
        start_date,
        end_date,
        (EXTRACT(EPOCH FROM (start_date::timestamp AT TIME ZONE 'Asia/Shanghai')) * 1000)::bigint AS start_ms,
        (EXTRACT(EPOCH FROM (end_date::timestamp   AT TIME ZONE 'Asia/Shanghai')) * 1000)::bigint AS end_ms
    FROM tmp_oh_params
),
clients AS (
    SELECT client_id
    FROM crm.client_info_ods
    WHERE client_group_id = 3
      AND istest_account IS FALSE
      AND client_id IS NOT NULL
),
last_before AS (
    SELECT client_id, status, channel_operation_time, id
    FROM (
        SELECT
            s.client_id,
            s.status::int AS status,
            s.channel_operation_time,
            s.id,
            ROW_NUMBER() OVER (
                PARTITION BY s.client_id
                ORDER BY s.channel_operation_time DESC, s.id DESC
            ) AS rn
        FROM rateaccuracy.channel_online_states_new s
        INNER JOIN clients c ON c.client_id = s.client_id
        INNER JOIN params p ON TRUE
        WHERE s.channel_operation_time < p.start_ms
    ) t
    WHERE rn = 1
),
in_window AS (
    SELECT client_id, status, channel_operation_time, id
    FROM (
        SELECT
            s.client_id,
            s.status::int AS status,
            s.channel_operation_time,
            s.id,
            ROW_NUMBER() OVER (
                PARTITION BY s.client_id, s.channel_operation_time
                ORDER BY s.id DESC
            ) AS rn
        FROM rateaccuracy.channel_online_states_new s
        INNER JOIN clients c ON c.client_id = s.client_id
        INNER JOIN params p ON TRUE
        WHERE s.channel_operation_time >= p.start_ms
          AND s.channel_operation_time <  p.end_ms
    ) t
    WHERE rn = 1
),
unioned AS (
    SELECT client_id, status, channel_operation_time, id FROM last_before
    UNION ALL
    SELECT client_id, status, channel_operation_time, id FROM in_window
),
changes AS (
    SELECT client_id, status, channel_operation_time
    FROM (
        SELECT
            client_id,
            status,
            channel_operation_time,
            LAG(status) OVER (
                PARTITION BY client_id
                ORDER BY channel_operation_time, id
            ) AS prev_status
        FROM unioned
    ) t
    WHERE prev_status IS NULL
       OR status <> prev_status
),
spans AS (
    SELECT
        client_id,
        status,
        (to_timestamp(channel_operation_time / 1000.0) AT TIME ZONE 'Asia/Shanghai') AS span_start,
        LEAD(to_timestamp(channel_operation_time / 1000.0) AT TIME ZONE 'Asia/Shanghai') OVER (
            PARTITION BY client_id
            ORDER BY channel_operation_time
        ) AS next_op_ts
    FROM changes
),
clipped AS (
    SELECT
        s.client_id,
        GREATEST(s.span_start, p.start_date::timestamp) AS span_start,
        LEAST(COALESCE(s.next_op_ts, p.end_date::timestamp), p.end_date::timestamp) AS span_end
    FROM spans s
    INNER JOIN params p ON TRUE
    WHERE s.status = 1
      AND s.span_start < p.end_date::timestamp
      AND COALESCE(s.next_op_ts, p.end_date::timestamp) > p.start_date::timestamp
      AND LEAST(COALESCE(s.next_op_ts, p.end_date::timestamp), p.end_date::timestamp)
          > GREATEST(s.span_start, p.start_date::timestamp)
),
days AS (
    SELECT (p.start_date + g.i) AS dt
    FROM params p
    CROSS JOIN generate_series(
        0,
        (SELECT end_date - start_date - 1 FROM params)
    ) AS g(i)
),
grid AS (
    SELECT c.client_id, d.dt
    FROM clients c
    CROSS JOIN days d
)
SELECT
    g.client_id,
    g.dt,
    ROUND(LEAST(COALESCE(SUM(EXTRACT(EPOCH FROM (
        LEAST(c.span_end, g.dt + INTERVAL '1 day')
        - GREATEST(c.span_start, g.dt::timestamp)
    )) / 3600.0), 0), 24)::numeric, 2) AS online_hours,
    ROUND((LEAST(COALESCE(SUM(EXTRACT(EPOCH FROM (
        LEAST(c.span_end, g.dt + INTERVAL '1 day')
        - GREATEST(c.span_start, g.dt::timestamp)
    )) / 3600.0), 0), 24) / 24.0 * 100)::numeric, 1) AS online_pct
FROM grid g
LEFT JOIN clipped c
    ON c.client_id = g.client_id
   AND c.span_start < g.dt + INTERVAL '1 day'
   AND c.span_end > g.dt::timestamp
GROUP BY g.client_id, g.dt;
