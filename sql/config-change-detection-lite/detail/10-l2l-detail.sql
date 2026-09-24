/* 10 L2L 明细（event_count > 0 时跑） */
/* 占位符: {client_id} {w_start} {w_end} {lag_start} */
/* {lag_start} = w_start 往前 30 天，只给 LAG 用，不要写进 COUNT */
/* last_level 是 LAG 别名，表里没有这列。禁止 SELECT last_level 无窗口函数 */
/* MCP tables: configuration.wolfl2lclientlevelconfiglog */
/* Agent：只解读 updatetime 落在 w_start～w_end 的行 */
/* last_level IS NULL → 操作写「未验」，禁止写成「其他」或「无」 */

SELECT
    username,
    level,
    LAG(level) OVER (PARTITION BY clientid ORDER BY updatetime) AS last_level,
    brgpunishmentday,
    updatetime
FROM configuration.wolfl2lclientlevelconfiglog
WHERE clientid = '{client_id}'
    AND updatetime::date BETWEEN '{lag_start}'::date AND '{w_end}'::date;
