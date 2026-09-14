# 维度术语表

> 业务定义以本文档为准。Agent 归因时引用此处，勿自行推断。

## 单维度

| 字段 | 名称 | 含义 | 数据来源 |
|------|------|------|---------|
| `sid` | Supplier | 供应商 | npd_booking_view |
| `supplieraccountid` | Supplier Account | **供应商账号**（每个 supplier 下可有多个 account） | npd_booking_view |
| `country_code` | Country | **酒店所在国家** | dida_hotel_view |
| `chain` | Chain | 酒店集团（parent_chain_name，空则 Independent） | dida_hotel_view |
| `los` | LOS（Length of Stay） | **连住天数**分段 | length_of_stay |
| `lt` | LT（Lead Time） | **预订提前期**（下单→入住天数，leading_date 分段） | leading_date |
| `nationality` | Nationality | **渠道侧客源国籍**（channel_nationality） | npd_booking_view |

### 分桶（与 dimension-contribution.sql 一致）

**LOS：** 1 / 2 / 3 / 4~7 / 8~14 / 15~28 / >28

**LT：** -1~0 / 1 / 2 / 3 / 4~7 / 8~14 / 15~28 / 29~42 / 43~70 / >70

### 易混淆

| 对比 | 区别 |
|------|------|
| Country vs Nationality | Country = 酒店在哪；Nationality = 客人从哪来 |
| LT vs LOS | LT = 提前多久订；LOS = 住几晚 |

## 组合维度（贡献度 SQL 中的 hierarchy）

| hierarchy | 组合 | 回答的问题 |
|-----------|------|-----------|
| 2_SID | Supplier | 哪个供应商掉最多 |
| 3_SID+Account | Supplier + Account | S/CS 路径下钻；**贡献 ≥10% 才报告** |
| 4_Country | Country | 哪个**酒店国家**掉最多 |
| 5_SID+Country | Supplier + Country | 是否某供应商在**某国**出问题 |
| 6_Chain | Chain | 哪个集团掉最多 |
| 7_SID+Chain | Supplier + Chain | 是否某供应商与某集团组合问题 |
| 8_LT | Lead Time | 哪个预订窗口段掉最多 |
| 9_SID+LT | Supplier + LT | 是否某供应商在某提前期段出问题 |
| 10_LOS | Length of Stay | 哪个连住段掉最多 |
| 11_SID+LOS | Supplier + LOS | 是否某供应商在某连住段出问题 |
| 12_Nationality | Nationality | 哪国客源掉最多 |
| 13_SID+Nationality | Supplier + Nationality | 是否某供应商对某国籍客源出问题 |

## 查验订术语

| 术语 | 英文 | 含义 |
|------|------|------|
| BKS | Bookings | 订单（Phase 1/2 主指标） |
| 查价 | Search | 渠道询价；Dida 向多 supplier 要价后返回 |
| 验价 / precheck | Prebook / RP（RatePlan） | 同义；SQL 字段常叫 precheck |
| 查价有价率 | avail_search / total_search | 查价返回有价比例；**不**反映竞争力 |
| 验价准确率 | success_rp / total_rp | 验价返回准确比例；**不受配置影响**，见 accuracy-issue-mapping |
| 查验比 | avail_search / total_rp | 反映价格竞争力（同 scope） |
| issue_type | — | 验价失败粗分类（Timeout/NoRoom/PriceChanged/Other） |
| issue_id | — | 验价失败细因（比 issue_type 更细） |

didamonitor 三层：**DidaBiz**（C 视角）→ **DidaBase**（CS 视角）→ **SS**（S 视角）。CS 级查价分析暂用 SS 表近似，详见 [phases/03-evidence-verification.md](phases/03-evidence-verification.md)。

## 分析范围（固定）

贡献度 SQL 始终在 **指定 Client**（client_id / parent_client_id）范围内计算。
交叉验证时才**放宽** Client 或 Supplier 过滤，见 [cross-validation-design.md](cross-validation-design.md)。
