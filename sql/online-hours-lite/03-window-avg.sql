/* 03-window-avg | 单 client 两窗日均在线时长（Phase 3 默认） */
/* MCP tables: ["rateaccuracy.channel_online_states_new"] */
/* 一次调用出对比窗 / 当前窗日均。口径与 scripts/test-online-hours.py 相同。 */
/* {client_id} 必填。原始日志不要加时间过滤。 */
/* {compare_start}/{compare_end}、{current_start}/{current_end} 止日均为含。 */
/* {compare_n_days} = compare_end - compare_start + 1（填整数，如 3） */
/* {current_n_days} = current_end - current_start + 1（填整数，如 3） */

/* MCP 禁区（2026-09-21 复测）： */
/* 对 channel_operation_time 写 AT TIME ZONE / 除以 1000 → 网关 500 */
/* params CTE CROSS JOIN、generate_series 按日切开、ROW_NUMBER 去重 CTE → 易 500 */
/* 本文件：EXTRACT(EPOCH FROM col) + CASE 裁窗 + TIMESTAMPTZ '...+08' */
/* 禁止 to_timestamp(col/1000)（那是 MCP JSON 毫秒的 Python 算法）。 */
/* 2026-09-21 复测：SnapEBK 24.0/22.07/−1.93；SnapTravel2B gold 23.45/20.9/−2.55。 */

WITH raw AS (
    SELECT
        status::int AS status,
        id,
        EXTRACT(EPOCH FROM channel_operation_time) AS op_epoch
    FROM rateaccuracy.channel_online_states_new
    WHERE client_id = '{client_id}'
),
ordered AS (
    SELECT
        status, op_epoch, id,
        LAG(status) OVER (ORDER BY op_epoch, id) AS prev_status
    FROM raw
),
changes AS (
    SELECT status, op_epoch
    FROM ordered
    WHERE prev_status IS NULL OR status <> prev_status
),
spans AS (
    SELECT
        status,
        op_epoch AS span_start,
        COALESCE(
            LEAD(op_epoch) OVER (ORDER BY op_epoch),
            EXTRACT(EPOCH FROM TIMESTAMPTZ '{current_end} 00:00:00+08') + 86400.0
        ) AS span_end
    FROM changes
),
clip AS (
    SELECT
        CASE
            WHEN span_end <= EXTRACT(EPOCH FROM TIMESTAMPTZ '{compare_start} 00:00:00+08') THEN 0
            WHEN span_start >= EXTRACT(EPOCH FROM TIMESTAMPTZ '{compare_end} 00:00:00+08') + 86400.0 THEN 0
            ELSE
                (CASE WHEN span_end < EXTRACT(EPOCH FROM TIMESTAMPTZ '{compare_end} 00:00:00+08') + 86400.0 THEN span_end ELSE EXTRACT(EPOCH FROM TIMESTAMPTZ '{compare_end} 00:00:00+08') + 86400.0 END)
              - (CASE WHEN span_start > EXTRACT(EPOCH FROM TIMESTAMPTZ '{compare_start} 00:00:00+08') THEN span_start ELSE EXTRACT(EPOCH FROM TIMESTAMPTZ '{compare_start} 00:00:00+08') END)
        END AS prev_sec,
        CASE
            WHEN span_end <= EXTRACT(EPOCH FROM TIMESTAMPTZ '{current_start} 00:00:00+08') THEN 0
            WHEN span_start >= EXTRACT(EPOCH FROM TIMESTAMPTZ '{current_end} 00:00:00+08') + 86400.0 THEN 0
            ELSE
                (CASE WHEN span_end < EXTRACT(EPOCH FROM TIMESTAMPTZ '{current_end} 00:00:00+08') + 86400.0 THEN span_end ELSE EXTRACT(EPOCH FROM TIMESTAMPTZ '{current_end} 00:00:00+08') + 86400.0 END)
              - (CASE WHEN span_start > EXTRACT(EPOCH FROM TIMESTAMPTZ '{current_start} 00:00:00+08') THEN span_start ELSE EXTRACT(EPOCH FROM TIMESTAMPTZ '{current_start} 00:00:00+08') END)
        END AS curr_sec
    FROM spans
    WHERE status = 1
)
SELECT
    '{client_id}' AS client_id,
    ROUND((SUM(GREATEST(0.0, prev_sec)) / 3600.0 / {compare_n_days})::numeric, 2) AS avg_online_hours_previous,
    ROUND((SUM(GREATEST(0.0, curr_sec)) / 3600.0 / {current_n_days})::numeric, 2) AS avg_online_hours_current,
    ROUND((
        SUM(GREATEST(0.0, curr_sec)) / 3600.0 / {current_n_days}
      - SUM(GREATEST(0.0, prev_sec)) / 3600.0 / {compare_n_days}
    )::numeric, 2) AS delta_h
FROM clip;
