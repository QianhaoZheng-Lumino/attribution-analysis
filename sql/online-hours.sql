-- 渠道每日在线时长（单 client 开窗日表）
-- 表: rateaccuracy.channel_online_states_new
-- 日表优先 Hologres。MCP 两窗日均用 online-hours-lite/03-window-avg.sql。
-- MCP 跑本文件（generate_series 日切）易 500 → 改 fetch + scripts/test-online-hours.py。
-- 禁止无 WHERE 扫全客户。全客户 × 日批处理见 channel_daily_online_hours.sql（仅 Hologres）。
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
-- MCP 禁区（2026-09-21）：对 channel_operation_time 写 AT TIME ZONE / 除以 1000
-- 会网关 500。用 EXTRACT(EPOCH FROM col) + TIMESTAMPTZ '...+08' 边界。
-- 禁止 to_timestamp(col/1000)（那是 MCP JSON 毫秒的 Python 算法）。
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
        EXTRACT(EPOCH FROM TIMESTAMPTZ '{start_date} 00:00:00+08') AS start_epoch,
        EXTRACT(EPOCH FROM TIMESTAMPTZ '{end_date} 00:00:00+08') AS end_epoch
),
days AS (
    SELECT
        (DATE '{start_date}' + i) AS dt,
        EXTRACT(EPOCH FROM TIMESTAMPTZ '{start_date} 00:00:00+08') + i * 86400.0 AS day_start_epoch
    FROM generate_series(0, {n_days} - 1) AS i
),
raw AS (
    SELECT
        s.client_id,
        s.status::int AS status,
        s.id,
        EXTRACT(EPOCH FROM s.channel_operation_time) AS op_epoch
    FROM rateaccuracy.channel_online_states_new s
    WHERE s.client_id = '{client_id}'
),
dedup AS (
    SELECT client_id, status, op_epoch, id
    FROM (
        SELECT
            client_id, status, op_epoch, id,
            ROW_NUMBER() OVER (
                PARTITION BY client_id, op_epoch
                ORDER BY id DESC
            ) AS rn
        FROM raw
    ) t
    WHERE rn = 1
),
ordered AS (
    SELECT
        client_id, status, op_epoch, id,
        LAG(status) OVER (
            PARTITION BY client_id
            ORDER BY op_epoch, id
        ) AS prev_status
    FROM dedup
),
changes AS (
    SELECT client_id, status, op_epoch
    FROM ordered
    WHERE prev_status IS NULL
       OR status <> prev_status
),
spans AS (
    SELECT
        client_id,
        status,
        op_epoch AS span_start,
        LEAD(op_epoch) OVER (
            PARTITION BY client_id
            ORDER BY op_epoch
        ) AS next_op_epoch
    FROM changes
),
clipped AS (
    SELECT
        s.client_id,
        GREATEST(s.span_start, p.start_epoch) AS span_start,
        LEAST(COALESCE(s.next_op_epoch, p.end_epoch), p.end_epoch) AS span_end
    FROM spans s
    CROSS JOIN params p
    WHERE s.status = 1
      AND s.span_start < p.end_epoch
      AND COALESCE(s.next_op_epoch, p.end_epoch) > p.start_epoch
      AND LEAST(COALESCE(s.next_op_epoch, p.end_epoch), p.end_epoch)
          > GREATEST(s.span_start, p.start_epoch)
)
SELECT
    '{client_id}' AS client_id,
    d.dt,
    ROUND(LEAST(COALESCE(SUM(
        (LEAST(c.span_end, d.day_start_epoch + 86400.0)
         - GREATEST(c.span_start, d.day_start_epoch)) / 3600.0
    ), 0), 24)::numeric, 2) AS online_hours,
    ROUND((LEAST(COALESCE(SUM(
        (LEAST(c.span_end, d.day_start_epoch + 86400.0)
         - GREATEST(c.span_start, d.day_start_epoch)) / 3600.0
    ), 0), 24) / 24.0 * 100)::numeric, 1) AS online_pct
FROM days d
LEFT JOIN clipped c
    ON c.span_start < d.day_start_epoch + 86400.0
   AND c.span_end > d.day_start_epoch
GROUP BY d.dt
ORDER BY d.dt;
