# 设计说明

解释「为什么是这些表、这些字段、这些索引」。改结构前先看这里。

## 1. 四层，而不是一张大表

把聊天记录、笔记、结论塞进一张表会立刻遇到三个问题：

- 检索噪音大：一句话结论和二十页原文在同一个池子里没有权重差别；
- 改一条结论得改原文；
- 无法回答「这个结论是哪来的」。

所以拆开：

| 层 | 表 | 一条记录是什么 |
|---|---|---|
| 原文层 | `source` / `document` / `chunk` | 不可变的原始材料，切块后进向量与全文索引 |
| 结论层 | `memory` | 一句可独立成立的话，带置信度、有效期、来源 |
| 关系层 | `entity` / `edge` | 结论与实体之间的连接 |
| 证据层 | `evidence` | 「凭什么这么说」：`quote` + `locator` 指回原文位置 |

检索因此可以逐层下钻：先命中 `memory`（快、准），需要细节再回 `chunk`（全、慢）。

## 2. 双路检索不是优化，是必需

| 查询类型 | 由谁负责 | 典型输入 |
|---|---|---|
| 意思相近、用词不同 | `hnsw (embedding vector_cosine_ops)` | 自然语言提问 |
| 名字、编号、专有词精确命中 | `gin (content_tsv)` | 产品型号、字段名、术语 |

只做向量：专有词会被"语义上差不多"的噪音淹没。
只做全文：同义不同词一律搜不到。
合理做法是两路各取 topK，再合并排序。

**注意**：pgvector 的 HNSW 索引在小数据量下，查询优化器常判定全表扫描更便宜，从而不走索引。若确认索引可用而未被使用，可在会话内：

```sql
SET LOCAL enable_seqscan = off;
SET LOCAL hnsw.ef_search = 60;
```

数据量越大，索引的价值越明显——它的意义是**不随数据量线性退化**。

## 3. 记忆必须能被推翻

只存"当时的结论"不够，还要能回答三件事：

| 问题 | 字段 |
|---|---|
| 这条现在还成立吗 | `status` / `valid_from` / `valid_until` |
| 什么时候被哪条取代了 | `superseded_by` / `supersedes_id` |
| 为什么改主意 | `review_reason` / `memory_revision` |

只记结论、不记"为什么推翻"，隔一段时间连自己都读不懂当初为什么改。`memory_revision` 存历史版本，`merge_log` 存合并记录，两层都能回溯。

## 4. 去重交给数据库

```sql
CREATE UNIQUE INDEX ux_memory_active_content_hash ON memory (scope, content_hash)
  WHERE status = 'active';
CREATE UNIQUE INDEX ux_memory_active_dedupe ON memory (dedupe_key)
  WHERE status = 'active' AND dedupe_key IS NOT NULL;
```

带 `WHERE status='active'` 的部分唯一索引：历史版本（superseded / archived）不受唯一约束限制，同一句话可以保留多条历史，但同时只能有一条"活着"。

脚本层去重迟早被并发或重跑击穿。

## 5. 状态机统一成一套词

`candidate → active → (disputed) → superseded / merged / archived / forgotten`

同一套词用在 `memory`、`entity`、`edge`、`asset` 上，查询、统计、界面过滤器只写一次。

`candidate` 是关键状态：机器抽取的结论默认候选，人确认后才 `active`。

## 6. 章节路径用 ltree

`chunk.section_path` 是 `ltree`，可直接查"某章下面所有块"：

```sql
SELECT * FROM chunk WHERE section_path <@ 'wiki.retrieval';
```

用字符串存 `wiki/retrieval/vector` 只能 `LIKE`，且层级不确定。

## 7. 审计与成本单独成表

`retrieval_logs`（每次检索的 query、命中 id、耗时）、`audit_log`（谁改了什么）、`cost_entry`（调用成本）。

排查"为什么它答错了"时，这三张表是唯一线索。

## 8. 有意没做的

| 没做 | 原因 |
|---|---|
| 行级权限（RLS） | 单人本地库，隔离靠操作系统账号；多人部署再加 |
| 语义分段切片 | 固定长度 + 段落边界够用，语义分段收益小于复杂度 |
| rerank 模型 | topK 取大一点已够用，加 rerank 是延迟换精度 |
| 图数据库 | `edge` 表 + 递归 CTE 能覆盖两跳，真需要再引入 |

## 9. 接自己的脚本

最小链路：

1. `source` 插一条（文件 / 网页 / 对话导出）；
2. `document` 插一条（解析后的正文）；
3. 切块写 `chunk`（`content` + `content_tsv` + `embedding` + `content_hash`）；
4. 抽取结论写 `memory`（`status='candidate'`），用 `evidence` 挂回 `chunk_id` + `quote`；
5. 人确认 → `status='active'`；
6. 检索：向量 + 全文各取 topK → 合并 → 回填 `access_count` 与 `retrieval_logs`。
