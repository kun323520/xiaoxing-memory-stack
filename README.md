# xiaoxing-memory-stack

Database schema for an **AI long-term memory + task workbench**: PostgreSQL 16 + pgvector as the main store, plus a SQLite schema for the task/workbench side.

> 中文说明见 [README.zh.md](README.zh.md)

This repository contains **schema, indexes and bootstrap scripts only** — no business data, no sample records, no personal content.

```
raw layer        source / document / chunk        ← documents, chunks, vectors, full-text
  ↓
conclusion layer memory / evidence                ← one judgement each: source, validity, superseded-by
  ↓
relation layer   entity / edge / alias            ← who relates to whom
  ↑
audit layer      retrieval_logs / audit_log / memory_review / cost_entry
```

## Quick start

```bash
git clone <this-repo> && cd xiaoxing-memory-stack
cp .env.example .env      # set POSTGRES_PASSWORD
docker compose up -d      # starts pgvector/pgvector:pg16, runs the schema on first boot
docker compose exec db psql -U memory -d memory -c '\dt'
```

Schema: `sql/pg_schema.sql` (from `pg_dump --schema-only`, safe to `psql -f`).
SQLite side: `sql/sqlite_schema.sql` (`sqlite3 app.db < sql/sqlite_schema.sql`).

Load one demo record end-to-end:

```bash
pip install "psycopg[binary]"
python demo_ingest.py --dsn postgresql://memory:memory@127.0.0.1:5432/memory
```

## Two databases

| DB | Engine | Holds | Schema file |
|---|---|---|---|
| Memory | PostgreSQL 16 + pgvector | documents, chunks, memories, entities, evidence, retrieval logs | `sql/pg_schema.sql` |
| Workbench | SQLite | task tree, daily plans, knowledge entries, ideas | `sql/sqlite_schema.sql` |

No shared foreign keys; they sync through scripts. A broken workbench DB never takes the memory DB down.

## Table groups (24 tables, PostgreSQL side)

| Group | Tables | Purpose |
|---|---|---|
| Raw | `source` `document` `chunk` | source, body, chunk; `chunk.embedding` + `chunk.content_tsv` |
| Conclusion | `memory` `memory_review` `memory_revision` `memory_link` | a memory = one statement + confidence + validity + who superseded it |
| Evidence | `evidence` | `quote` + `locator` pointing back into the original text |
| Relation | `entity` `entity_alias` `edge` `predicate_dict` | entity resolution + triples, relationships also expire |
| Time | `timeline_event` | what happened when |
| Project | `project` `run` `run_asset` `asset` | projects, runs, artefacts |
| Governance | `retrieval_logs` `audit_log` `merge_log` `license_entry` `cost_entry` | retrieval traces, audit trail, asset licences, cost |
| Ops | `schema_migrations` | schema version |

Field-level notes: [docs/SCHEMA.md](docs/SCHEMA.md). Design rationale: [docs/DESIGN.md](docs/DESIGN.md).

## Three load-bearing design decisions

1. **Dual index.** `chunk` carries both `hnsw (vector_cosine_ops)` and `gin (content_tsv)`. Vector handles "similar meaning", full-text handles "exact name or id". Drop one and the other class of queries starts failing.
2. **Memories can be overturned.** `memory.superseded_by / supersedes_id / valid_from / valid_until`. Storing only the current conclusion loses *when* and *why* you changed your mind.
3. **Dedupe lives in the database.** `ux_memory_active_content_hash (scope, content_hash)` and `ux_memory_active_dedupe (dedupe_key)` are both `WHERE status='active'` — exactly one live copy per judgement, safe to re-run.

## What you have to build yourself

No ingestion or retrieval code is included. Minimum loop:

1. write `source` → 2. write `document` → 3. chunk into `chunk` (`content` / `content_tsv` / `embedding` / `content_hash`)
4. extract a statement into `memory` (`status='candidate'`), attach `evidence` pointing at `chunk_id` + `quote`
5. human confirms → `status='active'`
6. retrieve: vector top-K + full-text top-K → merge → bump `access_count`, write `retrieval_logs`

`content_tsv` is `to_tsvector('simple', content)`; Chinese has no built-in tokenizer, so tokenise in the application layer first.

## Known limitations

- No API layer, no permission model (single-user local DB; isolation is the OS account).
- Chunking is fixed-length with paragraph boundaries, not semantic segmentation.
- No rerank model.
- `sqlite_schema.sql` follows the plugin version that generated it; the file is a point-in-time snapshot.

## License

MIT. Schema itself is not copyrightable; attribution appreciated.

中文说明见 [README.zh.md](README.zh.md)。
