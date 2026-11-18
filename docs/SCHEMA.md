# 表结构速查（24 张表）

> 权威定义看 `sql/pg_schema.sql`；这里只解释「一张表一行是什么、关键字段管什么」。

## 原文层

### `source`（11 列）
一条**来源**：一个文件、一个网页、一段对话导出。
关键：`kind`（file / url / chat…）、`uri`、`checksum`（判重）、`published_at` / `imported_at`（区分"什么时候发生"和"什么时候入库"）。

### `document`（12 列）
`source` 解析出来的**正文**。
关键：`path`、`title`、`content_hash`、`version`。同一 source 可以有多版本 document（重解析/换解析器）。

### `chunk`（15 列）— 检索的主力
`document` 切出来的**块**（本机约 500–800 字一块，带章节路径）。
关键：
- `section_path ltree`：`wiki.检索.向量` 这种层级，支持 `<@` 查整章
- `content_tsv`：全文索引（中文在应用层用 jieba 切好再 `to_tsvector('simple', …)`）
- `embedding vector(1024)`：bge-m3
- `content_hash`：块级判重
- `char_start / char_end`：回原文定位

## 结论层

### `memory`（46 列）— 全库最核心
一条**判断**：一句话、可独立成立。
| 字段组 | 字段 | 说明 |
|---|---|---|
| 内容 | `statement` `object_text` | 主语在 `subject_entity_id`，谓语 `predicate`，宾语可文本或实体 |
| 类型 | `kind` | preference / fact / decision / rule / profile / summary / config / event / insight / question |
| 作用域 | `scope` `scope_project_id` | global / user / project / session |
| 生命周期 | `status` `valid_from` `valid_until` `expires_at` | candidate / active / disputed / superseded / merged / archived / forgotten |
| 版本 | `current_revision_id` `superseded_by` `supersedes_id` `canonical_id` `merged_into` `duplicate_of` | 谁取代了谁、谁和谁是同一条 |
| 权重 | `confidence` `importance` `decay_rate` `access_count` `last_accessed_at` | 检索排序 + 遗忘曲线 |
| 判重 | `content_hash` `dedupe_key` | 配合部分唯一索引，active 状态下不许重复 |
| 治理 | `sensitivity` `approved_by` `approved_at` `review_reason` `reviewed_at` | 人确认过没、为什么改 |

### `memory_revision`（13 列）
每次修改留一版：`version`、旧 `statement`、`change_reason`、`actor_id`。**推翻的历史不能删**。

### `memory_review`（11 列）
待办式复核队列：`candidate_ids` + `evidence` + `decision`（approve/reject/merge…），让"AI 提的候选"和"人确认"分开。

### `memory_link`（8 列）
记忆之间的关系：`rel`（supports / complements / contradicts）、`confidence`、`status`。

## 证据层

### `evidence`（18 列）
「凭什么这么说」：`quote`（原文片段）+ `locator`（行号/页码/字符区间）+ `extractor_kind`（rule / llm / user）。
约束 `num_nonnulls(memory_id, entity_id, edge_id, timeline_event_id, asset_id) <= 1`：一条证据只指向一个对象，避免"一证多用"糊在一起。

## 关系层

### `entity`（13 列）
实体：`type` + `name` + `norm_name`（归一化，唯一索引按 type+norm_name 建在 active 上）、`canonical_entity_id`（合并后指向规范实体）、`embedding`（实体级向量，用于模糊匹配）。

### `entity_alias`（5 列）
别名：`norm_alias` 上建了 `gin_trgm_ops`，支持错字/简称模糊匹配。

### `edge`（12 列）
三元组：`subject_entity_id` + `predicate` + `object_entity_id`，带 `valid_from/valid_until` 和 `status`（candidate/active/disputed/superseded/merged/archived）——**关系也有有效期**。

### `predicate_dict`（6 列）
谓语字典：`label_zh`、`inverse_predicate`（反向关系）、`subject_types`/`object_types`（类型约束，防止"人 位于 城市"这种乱连）。

## 时间与项目

| 表 | 一行是什么 |
|---|---|
| `timeline_event`（13 列） | 某个时间点发生的事：`occurred_at`、`type`、`summary`，可挂 project/entity/memory |
| `project`（11 列） | 项目：`path` 是 `ltree`（支持子项目层级）、`status`、`due_at` |
| `run`（14 列） | 一次执行（一次生成/一次批处理）：`model`、`params`、`metrics`、`cost_amount`、`error` |
| `run_asset`（5 列） | run ↔ asset 多对多：`role`（input/output/preview）、`ordinal` |
| `asset`（15 列） | 产出物/素材：`path`/`uri`、`checksum`、`mime`、`size_bytes`、`parent_asset_id`（派生关系）、`license_entry_id` |
| `task`（13 列） | 项目内的待办（注意：**工作台的任务在 SQLite 里**，这张是记忆库侧的轻量任务） |

## 治理与运维

| 表 | 一行是什么 |
|---|---|
| `retrieval_logs`（8 列） | 每次检索：`query`、`mode`、`filters`、`top_ids`、`latency_ms`。排查"为什么答错"的第一手证据 |
| `audit_log`（9 列） | 谁（`actor_id`）在什么时候改了什么（`target_type`/`target_id`/`before`/`after`/`reason`） |
| `merge_log`（8 列） | 合库/合并实体的记录：`winner_id` + `loser_ids` + `rationale` |
| `license_entry`（15 列） | 素材授权：`grantor`/`licensee`/`rights_summary`/`territory`/`valid_until`/`obligations`。做内容运营必须要这张表 |
| `cost_entry`（13 列） | 成本台账：`vendor`、`item`、`amount`、`currency`、`invoice_ref` |
| `schema_migrations`（3 列） | 结构版本：`version` / `description` / `applied_at` |

## 索引一览（36 个，挑关键的）

| 索引 | 类型 | 用途 |
|---|---|---|
| `idx_chunk_embedding` | HNSW (vector_cosine_ops) | 语义检索主力 |
| `idx_chunk_tsv` | GIN | 全文检索 |
| `idx_memory_embedding` | HNSW | 记忆级语义检索 |
| `idx_memory_tsv` | GIN | 记忆级全文检索 |
| `ux_memory_active_content_hash` | 部分唯一 (scope, content_hash) WHERE active | 防重复写入 |
| `ux_memory_active_dedupe` | 部分唯一 (dedupe_key) WHERE active | 业务键去重 |
| `idx_memory_status_active` | 部分 btree WHERE active | 检索只扫活着的 |
| `idx_entity_alias_trgm` | GIN (gin_trgm_ops) | 别名模糊匹配 |
| `ux_entity_type_norm_active` | 部分唯一 (type, norm_name) WHERE active | 实体消歧 |
| `idx_project_path` | GiST (ltree) | 子项目层级查询 |

## 工作台（SQLite，20 张表）

完整 DDL 见 `sql/sqlite_schema.sql`。分四块：

| 块 | 表 |
|---|---|
| 任务 | `tasks`（树形：`parent_id`）、`task_events`、`task_sessions`、`task_drafts`、`task_reminders`、`task_reports`、`task_reviews`、`task_artifacts`、`reminder_queue` |
| 知识 | `knowledge_entries`（含 `superseded_by_id` / `valid_until` / `file_link`）、`knowledge_recall_log` |
| 点子 | `ideas`、`idea_clusters`、`idea_links` |
| 基础 | `dictionaries`、`daily_plans`、`ai_session_registry`、`meta`、`draft_notify_queue` |

**注意**：工作台库是插件生成的，字段会随版本变；升级插件前先备份 `workbench.db`。
