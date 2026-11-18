# xiaoxing-memory-stack

一套「AI 长期记忆 + 个人工作台」的数据库结构，跑在 PostgreSQL 16 + pgvector 上，配一个 SQLite 的工作台库。

这个仓库只放**结构与用法**，不含任何个人数据。你可以用它在自己的机器上搭出一套一样的库，然后接自己的采集/检索脚本。

```
原文层   document / chunk        ← 文档切块、向量、全文索引
  ↓
结论层   memory / evidence       ← 一条条「判断」，带来源、有效期、被推翻记录
  ↓
关系层   entity / edge / alias   ← 谁和谁有关系（通过 / 互补 / 矛盾）
  ↑
审计层   retrieval_logs / audit_log / memory_review / cost_entry
```

## 一分钟起起来

```bash
git clone <this-repo> && cd xiaoxing-memory-stack
cp .env.example .env      # 改成你自己的密码
docker compose up -d      # 起 pgvector/pgvector:pg16，首次自动建表
docker compose exec db psql -U memory -d memory -c '\dt'
```

建表脚本在 `sql/pg_schema.sql`（pg_dump 导出，可直接 `psql -f`）。

## 两个库是什么关系

| 库 | 引擎 | 放什么 | 谁生成 |
|---|---|---|---|
| `memory`（记忆库） | PostgreSQL 16 + pgvector | 文档、切块、记忆、实体、证据、检索日志 | 本仓库 `sql/pg_schema.sql` |
| `workbench.db`（工作台） | SQLite | 任务、日历、知识卡片、点子的个人工作台 | DSH 插件 `@dely0/dsh-personal-workbench` 自动建，结构见 `sql/sqlite_schema.sql` |

两者**不共享外键**，靠人工/脚本同步（例如把工作台里确认过的知识卡片提炼成 `memory` 一条）。这样做的好处是工作台坏了不影响记忆库，反之亦然。

## 表分组（24 张）

| 分组 | 表 | 干什么 |
|---|---|---|
| 原文 | `source` `document` `chunk` | 文件/网页/对话的原文、切块；`chunk.embedding` 1024 维、`chunk.content_tsv` 全文索引 |
| 结论 | `memory` `memory_review` `memory_revision` `memory_link` | 一条记忆 = 一句话判断 + 置信度 + 有效期 + 谁推翻了它 |
| 溯源 | `evidence` | 每条记忆挂到具体 `quote` + `locator`（原文位置），不是"我记得" |
| 关系 | `entity` `entity_alias` `edge` `predicate_dict` | 实体消歧（别名/归一化）+ 主语-谓语-宾语三元组 |
| 时间 | `timeline_event` | 什么时候发生了什么 |
| 项目 | `project` `run` `run_asset` `asset` | 项目、执行批次、产出物 |
| 治理 | `retrieval_logs` `audit_log` `merge_log` `license_entry` `cost_entry` | 每次检索留痕、变更审计、合库记录、素材许可、成本 |
| 运维 | `schema_migrations` | 结构版本 |

字段级说明见 [docs/SCHEMA.md](docs/SCHEMA.md)，设计取舍见 [docs/DESIGN.md](docs/DESIGN.md)。

## 三个关键设计（复制时别省）

1. **双路检索**：`chunk` 同时有 `hnsw (vector_cosine_ops)` 和 `gin (content_tsv)`。向量管"意思相近"，全文管"名字/编号精确"。只留一种，另一类查询就会瞎。
2. **记忆要能被推翻**：`memory.superseded_by / supersedes_id / valid_from / valid_until`。知识库存"当时的结论"，记忆必须知道"哪天、为什么改了主意"。
3. **唯一索引防重复**：`ux_memory_active_content_hash (scope, content_hash)`、`ux_memory_active_dedupe (dedupe_key)` 都带 `WHERE status='active'` —— 同一条判断重复写入会被数据库挡掉，不靠脚本自觉。

## 实测（2026-11 在一台 Windows 笔记本上）

| 项 | 数值 |
|---|---|
| 库大小 | 85 MB（3,926 个 chunk，73 MB） |
| 向量检索（HNSW，ef_search=60，热缓存） | 6 ms |
| 向量检索（默认走 Seq Scan，热缓存） | 43 ms |
| 全文检索（GIN） | 5.4 ms |
| 端到端一次检索（含 Python 冷启动） | 2.98 s → 进程常驻时 0.57 s |

`embedding` 用的是本地 **bge-m3**（1024 维，Ollama 托管，权重 1.13 GB 在显存里，热态 0.256 s/次）。

## 已知限制（别当成能直接上生产）

- 没有 API 层，也没有权限模型（单人本地库，靠操作系统账号隔离）。
- `chunk` 的切片是固定长度 + 段落边界，没有语义分段。
- 检索结果没有重排（rerank）模型。
- 采集/检索脚本（`memory_db.py`）目前**没有**放进本仓库——它和本机路径绑死，需要脱敏才能开源。如果你要，可以提 issue。
- `workbench.db` 的结构随插件版本变，本仓库对应 1.17.2。

## License

MIT。数据库结构本身不受版权保护，但请保留出处。
