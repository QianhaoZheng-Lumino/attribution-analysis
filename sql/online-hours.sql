-- 渠道每日在线时长（单 client 开窗日表）
-- 表: rateaccuracy.channel_online_states_new
-- MCP 与 Hologres 均可跑本文件（须等值 client_id）。禁止无 WHERE 扫全客户。
-- 全客户 × 日批处理见 channel_daily_online_hours.sql（仅 Hologres）。
-- MCP 500 时 fallback：online-hours-lite/ 拉 log + scripts/test-online-hours.py
--
-- 口径:
--   status=1 上线动作, status=0 下线动作
--   用 channel_operation_time（库内 timestamptz），不用 log_time
--   同一毫秒保留 id 最大；连续相同 status 忽略
--   区间 [本次动作, 下次动作)：本次=1 计入在线
--   按北京时间自然日切开，单日上限 24h
--   窗口开始前最后一次有效动作决定起点状态
-- 原始日志不要加时间过滤
--
-- 占位符:
--   {client_id}   必填
--   {start_date}  窗口起日（含），默认 compare_start
--   {end_date}    窗口止日（不含），默认 current_end+1
--   {n_days}      = end_date - start_date
-- 两窗日均优先用 online-hours-lite/03-window-avg.sql（一次出 prev/curr/delta）。
-- MCP 返回的 dt 可能是毫秒 epoch，Agent 须转北京日期。

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
)
SELECT
    '{client_id}' AS client_id,
    d.dt,
    ROUND(LEAST(COALESCE(SUM(EXTRACT(EPOCH FROM (
        LEAST(c.span_end, d.dt + INTERVAL '1 day')
        - GREATEST(c.span_start, d.dt::timestamp)
    )) / 3600.0), 0), 24)::numeric, 2) AS online_hours,
    ROUND((LEAST(COALESCE(SUM(EXTRACT(EPOCH FROM (
        LEAST(c.span_end, d.dt + INTERVAL '1 day')
        - GREATEST(c.span_start, d.dt::timestamp)
    )) / 3600.0), 0), 24) / 24.0 * 100)::numeric, 1) AS online_pct
FROM days d
LEFT JOIN clipped c
    ON c.span_start < d.dt + INTERVAL '1 day'
   AND c.span_end > d.dt::timestamp
GROUP BY d.dt
ORDER BY d.dt;
