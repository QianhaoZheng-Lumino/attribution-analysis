-- 03-window-avg | 单 client 两窗日均在线时长（Phase 3 默认）
-- MCP tables: ["rateaccuracy.channel_online_states_new"]
-- 一次调用出对比窗 / 当前窗日均。口径与 ../online-hours.sql 相同。
-- {client_id} 必填。原始日志不要加时间过滤。
-- {start_date} = compare_start（含）；{end_date} = current_end+1（不含）
-- {n_days} = end_date - start_date
-- 对比/当前窗止日均为含。

WITH params AS (
    SELECT
        TIMESTAMP '{start_date} 00:00:00' AS start_ts,
        TIMESTAMP '{end_date} 00:00:00' AS end_ts
),
days AS (
    SELECT (DATE '{start_date}' + i) AS dt
    FROM generate_series(0, {n_days} - 1) AS i
),
raw AS (
    SELECT
        s.client_id,
        s.status::int AS status,
        s.id,
        (s.channel_operation_time AT TIME ZONE 'Asia/Shanghai') AS op_ts
    FROM rateaccuracy.channel_online_states_new s
    WHERE s.client_id = '{client_id}'
),
dedup AS (
    SELECT client_id, status, op_ts, id
    FROM (
        SELECT
            client_id, status, op_ts, id,
            ROW_NUMBER() OVER (
                PARTITION BY client_id, op_ts
                ORDER BY id DESC
            ) AS rn
        FROM raw
    ) t
    WHERE rn = 1
),
ordered AS (
    SELECT
        client_id, status, op_ts, id,
        LAG(status) OVER (
            PARTITION BY client_id
            ORDER BY op_ts, id
        ) AS prev_status
    FROM dedup
),
changes AS (
    SELECT client_id, status, op_ts
    FROM ordered
    WHERE prev_status IS NULL
       OR status <> prev_status
),
spans AS (
    SELECT
        client_id,
        status,
        op_ts AS span_start,
        LEAD(op_ts) OVER (
            PARTITION BY client_id
            ORDER BY op_ts
        ) AS next_op_ts
    FROM changes
),
clipped AS (
    SELECT
        s.client_id,
        GREATEST(s.span_start, p.start_ts) AS span_start,
        LEAST(COALESCE(s.next_op_ts, p.end_ts), p.end_ts) AS span_end
    FROM spans s
    CROSS JOIN params p
    WHERE s.status = 1
      AND s.span_start < p.end_ts
      AND COALESCE(s.next_op_ts, p.end_ts) > p.start_ts
      AND LEAST(COALESCE(s.next_op_ts, p.end_ts), p.end_ts)
          > GREATEST(s.span_start, p.start_ts)
),
daily AS (
    SELECT
        d.dt,
        ROUND(LEAST(COALESCE(SUM(EXTRACT(EPOCH FROM (
            LEAST(c.span_end, d.dt + INTERVAL '1 day')
            - GREATEST(c.span_start, d.dt::timestamp)
        )) / 3600.0), 0), 24)::numeric, 2) AS online_hours
    FROM days d
    LEFT JOIN clipped c
        ON c.span_start < d.dt + INTERVAL '1 day'
       AND c.span_end > d.dt::timestamp
    GROUP BY d.dt
)
SELECT
    '{client_id}' AS client_id,
    ROUND(AVG(CASE WHEN dt >= DATE '{compare_start}' AND dt <= DATE '{compare_end}' THEN online_hours END)::numeric, 2) AS avg_online_hours_previous,
    ROUND(AVG(CASE WHEN dt >= DATE '{current_start}' AND dt <= DATE '{current_end}' THEN online_hours END)::numeric, 2) AS avg_online_hours_current,
    ROUND((
        AVG(CASE WHEN dt >= DATE '{current_start}' AND dt <= DATE '{current_end}' THEN online_hours END)
        - AVG(CASE WHEN dt >= DATE '{compare_start}' AND dt <= DATE '{compare_end}' THEN online_hours END)
    )::numeric, 2) AS delta_h
FROM daily;
