# 设计说明：为什么长这样

这份文档解释「为什么是这些表、这些字段、这些索引」。想改结构前先看这里，能少走一遍弯路。

## 1. 四层，而不是一张大表

最初最容易犯的错是「把聊天记录、笔记、结论全塞一张表」，结果：

- 检索时噪音太大（一句话结论和 20 页原文的权重没法比）；
- 改一条结论得改原文；
- 没法回答「这个结论是哪来的」。

所以拆四层：

| 层 | 表 | 一条记录是什么 |
|---|---|---|
| 原文层 | `source` / `document` / `chunk` | 不可变的原始材料，切块后进向量与全文索引 |
| 结论层 | `memory` | 一句可独立成立的话，带置信度、有效期、来源 |
| 关系层 | `entity` / `edge` | 结论之间的连接（通过 / 互补 / 矛盾） |
| 证据层 | `evidence` | 「凭什么这么说」：`quote` + `locator` 指回原文位置 |

这样检索可以逐层下钻：先命中 `memory`（快、准），需要细节再回 `chunk`（全、慢）。

## 2. 双路检索是必须的，不是优化

| 查询类型 | 谁负责 | 例子 |
|---|---|---|
| 意思相近，词不一样 | `hnsw(embedding vector_cosine_ops)` | "知识库和记忆有啥区别" → 命中"存/取、等/给、定/涨" |
| 名字、编号、专有词精确命中 | `gin(content_tsv)` | "B7-201"、"superseded_by" |

只做向量，专有词会被"语义上差不多"的噪音淹没；只做全文，同义不同词一律搜不到。两边都查完再合并排序（本机实现是 FTS + 向量各取 topK，按 RRF 式加权合并）。

**踩过的坑**：pgvector 的 HNSW 索引在数据量小（几千行）时，优化器会认为全表扫描更便宜，直接 `Seq Scan`。实测热缓存下 Seq Scan 43 ms vs 索引 6 ms。所以查询里显式写了：

```sql
SET LOCAL enable_seqscan = off;
SET LOCAL hnsw.ef_search = 60;
```

数据量上来后（4 万行以上）全表扫描会线性变慢到 430 ms，而索引仍是毫秒级——**索引真正的价值是不随数据量退化**，不是小库上快那几毫秒。

## 3. 记忆必须能被推翻

`knowledge` 只存"当时的结论"，`memory` 还要能回答三件事：

| 问题 | 字段 |
|---|---|
| 这条现在还成立吗 | `status` / `valid_from` / `valid_until` |
| 什么时候被哪条取代了 | `superseded_by` / `supersedes_id` |
| 为什么改主意 | `review_reason` / `memory_revision` |

实测教训：只记结论不记"为什么推翻"，三个月后自己都看不懂当初为什么改。所以 `memory_revision` 存历史版本，`merge_log` 存合库记录，冲突时两层都能回溯。

## 4. 去重交给数据库，不交给脚本

```sql
CREATE UNIQUE INDEX ux_memory_active_content_hash ON memory (scope, content_hash)
  WHERE status = 'active';
CREATE UNIQUE INDEX ux_memory_active_dedupe ON memory (dedupe_key)
  WHERE status = 'active' AND dedupe_key IS NOT NULL;
```

带 `WHERE status='active'` 的部分索引，好处是：历史版本（superseded/archived）不受唯一约束限制，同一句话可以有多条历史，但同时只能有一条"活着"。

脚本层面的去重迟早会被并发或重跑击穿。

## 5. 状态机统一成七个值

`candidate → active → (disputed) → superseded / merged / archived / forgotten`

同一套词用在 `memory`、`entity`、`edge`、`asset` 上，好处是查询、统计、UI 过滤器只写一次。`candidate` 这个状态很关键：AI 提取的结论默认是候选，人确认后才 `active`。

## 6. 为什么用 ltree 存章节路径

`chunk.section_path` 是 `ltree`，可以直接查"某章下面所有块"：

```sql
SELECT * FROM chunk WHERE section_path <@ 'wiki.检索';
```

用字符串存 `wiki/检索/第一段` 就只能 `LIKE`，且层级不确定。

## 7. 审计与成本单独成表

`retrieval_logs` 记录每次检索的 query、命中 id、耗时；`audit_log` 记录谁改了什么；`cost_entry` 记调用成本。

这三张表看着"没用"，但排查"为什么它答错了"时是唯一线索；没有它们，只能靠猜。

## 8. 没做的（以及为什么）

| 没做 | 原因 |
|---|---|
| 行级权限（RLS） | 单人本地库，隔离靠操作系统账号；多人用再加 |
| 语义分段切片 | 固定长度 + 段落边界够用，语义分段收益 < 复杂度 |
| rerank 模型 | 检索 topK=20 已经够准，加 rerank 是延迟换精度，本机不值得 |
| 图数据库 | `edge` 表 + 递归 CTE 能覆盖两跳；真需要再考虑 |

## 9. 如果要接自己的脚本

最小可用链路：

1. `source` 插一条（文件/网页）；
2. `document` 插一条（解析后的正文）；
3. 切块写 `chunk`（`content` + `content_tsv` + `embedding` + `content_hash`）；
4. 抽取结论写 `memory`（`status='candidate'`），用 `evidence` 挂回 `chunk_id` + `quote`；
5. 人确认 → `status='active'`；
6. 检索：向量 + 全文各取 topK → 合并 → 回填 `access_count` 与 `retrieval_logs`。

`content_tsv` 建议用 `to_tsvector('simple', content)`（中文没有内置分词，本机是在应用层用 jieba 切好后传入）。
