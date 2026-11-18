# xiaoxing-memory-stack

一套「AI 长期记忆 + 任务工作台」的**数据库结构**。PostgreSQL 16 + pgvector 为主库，附一份 SQLite 侧的结构参考。

本仓库只包含**表结构、索引与建库脚本**，不含任何业务数据、示例记录或个人内容。

```
原文层   source / document / chunk        ← 文档切块、向量、全文索引
  ↓
结论层   memory / evidence                ← 一条条判断，带来源、有效期、被推翻记录
  ↓
关系层   entity / edge / alias            ← 谁和谁有关系
  ↑
审计层   retrieval_logs / audit_log / memory_review / cost_entry
```

## 一分钟起起来

```bash
git clone <this-repo> && cd xiaoxing-memory-stack
cp .env.example .env      # 改 POSTGRES_PASSWORD
docker compose up -d      # 起 pgvector/pgvector:pg16，首次自动执行建表脚本
docker compose exec db psql -U memory -d memory -c '\dt'
```

建表脚本：`sql/pg_schema.sql`（pg_dump --schema-only 导出，可直接 `psql -f`）。
SQLite 侧：`sql/sqlite_schema.sql`（`sqlite3 app.db < sql/sqlite_schema.sql`）。

## 两个库

| 库 | 引擎 | 放什么 | 结构文件 |
|---|---|---|---|
| 记忆库 | PostgreSQL 16 + pgvector | 文档、切块、记忆、实体、证据、检索日志 | `sql/pg_schema.sql` |
| 工作台库 | SQLite | 任务树、日历计划、知识条目、点子 | `sql/sqlite_schema.sql` |

两者**不共享外键**，靠脚本同步。工作台坏了不影响记忆库，反之亦然。

## 表分组（PostgreSQL 侧 24 张）

| 分组 | 表 | 做什么 |
|---|---|---|
| 原文 | `source` `document` `chunk` | 来源、正文、切块；`chunk.embedding` 向量 + `chunk.content_tsv` 全文 |
| 结论 | `memory` `memory_review` `memory_revision` `memory_link` | 一条记忆 = 一句判断 + 置信度 + 有效期 + 谁推翻了它 |
| 溯源 | `evidence` | 每条结论挂回原文 `quote` + `locator` |
| 关系 | `entity` `entity_alias` `edge` `predicate_dict` | 实体消歧 + 三元组，关系也有有效期 |
| 时间 | `timeline_event` | 什么时候发生了什么 |
| 项目 | `project` `run` `run_asset` `asset` | 项目、执行批次、产出物 |
| 治理 | `retrieval_logs` `audit_log` `merge_log` `license_entry` `cost_entry` | 检索留痕、变更审计、素材许可、成本 |
| 运维 | `schema_migrations` | 结构版本 |

字段级说明见 [docs/SCHEMA.md](docs/SCHEMA.md)；设计取舍见 [docs/DESIGN.md](docs/DESIGN.md)。

## 三个必须保留的设计

1. **双路索引**：`chunk` 上同时有 `hnsw (vector_cosine_ops)` 与 `gin (content_tsv)`。向量管"意思相近"，全文管"名字/编号精确"。少一路，另一类查询就会失效。
2. **记忆可被推翻**：`memory.superseded_by / supersedes_id / valid_from / valid_until`。只存"当时的结论"会丢掉"哪天、为什么改主意"。
3. **去重靠数据库**：`ux_memory_active_content_hash (scope, content_hash)` 与 `ux_memory_active_dedupe (dedupe_key)` 都带 `WHERE status='active'` —— 同一判断只能有一条"活着"，脚本重跑不会写重。

## 需要自己补的部分

本仓库**不含**采集与检索脚本。你要接自己的流程，最小链路是：

1. 写 `source` → 2. 写 `document` → 3. 切块写 `chunk`（`content` / `content_tsv` / `embedding` / `content_hash`）
4. 抽取结论写 `memory`（`status='candidate'`），用 `evidence` 挂回 `chunk_id` + `quote`
5. 人工确认 → `status='active'`
6. 检索：向量 + 全文各取 topK → 合并 → 回填 `access_count`、`retrieval_logs`

`content_tsv` 用 `to_tsvector('simple', content)`；中文没有内置分词，需在应用层切词后再写入。

## 已知限制

- 没有 API 层与权限模型（单人本地库，隔离靠操作系统账号）。
- 切块为固定长度 + 段落边界，非语义分段。
- 检索无 rerank 模型。
- `sqlite_schema.sql` 的结构随生成它的插件版本变化，本文件为某一时点的快照。

## License

MIT。数据库结构本身不受版权保护，保留出处即可。
