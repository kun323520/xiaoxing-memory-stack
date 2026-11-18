-- SQLite 侧结构（任务 / 知识 / 点子），仅结构，无数据。
-- 字段名与表名随生成该库的插件版本变化；本文件为某一时点快照。
-- 用法：sqlite3 app.db < sqlite_schema.sql
PRAGMA foreign_keys = ON;

-- ---------- ai_session_registry ----------
CREATE TABLE ai_session_registry (
          scope_code       TEXT NOT NULL,
          anchor           TEXT NOT NULL,
          session_id       TEXT NOT NULL,
          workspace        TEXT,
          note             TEXT,
          created_at       TEXT NOT NULL,
          last_activity_at TEXT NOT NULL,
          PRIMARY KEY (scope_code, anchor)
        ) STRICT;

-- ---------- daily_plans ----------
CREATE TABLE daily_plans (
          id          TEXT PRIMARY KEY,
          plan_date   TEXT NOT NULL UNIQUE,
          summary     TEXT NOT NULL DEFAULT '',
          items_json  TEXT NOT NULL DEFAULT '[]',
          source_code TEXT NOT NULL DEFAULT 'ai',
          session_id  TEXT,
          created_at  TEXT NOT NULL,
          updated_at  TEXT NOT NULL
        ) STRICT;

-- ---------- dictionaries ----------
CREATE TABLE dictionaries (
  kind       TEXT NOT NULL,
  code       TEXT NOT NULL,
  name       TEXT NOT NULL,
  config     TEXT NOT NULL DEFAULT '{}',
  builtin    INTEGER NOT NULL DEFAULT 0,
  active     INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (kind, code)
) STRICT;

-- ---------- draft_notify_queue ----------
CREATE TABLE draft_notify_queue (
          id              TEXT PRIMARY KEY,
          draft_id        TEXT NOT NULL UNIQUE,
          kind_code       TEXT NOT NULL,
          title           TEXT NOT NULL,
          body            TEXT NOT NULL,
          priority_code   TEXT NOT NULL,
          attempts        INTEGER NOT NULL DEFAULT 0,
          next_attempt_at TEXT NOT NULL,
          last_error      TEXT,
          created_at      TEXT NOT NULL
        ) STRICT;

-- ---------- idea_clusters ----------
CREATE TABLE idea_clusters (
          id         TEXT PRIMARY KEY,
          title      TEXT NOT NULL,
          summary_md TEXT NOT NULL DEFAULT '',
          tags_json  TEXT NOT NULL DEFAULT '[]',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        ) STRICT;

-- ---------- idea_links ----------
CREATE TABLE idea_links (
          cluster_id TEXT NOT NULL REFERENCES idea_clusters(id) ON DELETE CASCADE,
          idea_id    TEXT NOT NULL REFERENCES ideas(id) ON DELETE CASCADE,
          note       TEXT,
          created_at TEXT NOT NULL,
          PRIMARY KEY (cluster_id, idea_id)
        ) STRICT;

-- ---------- ideas ----------
CREATE TABLE ideas (
          id               TEXT PRIMARY KEY,
          title            TEXT NOT NULL,
          content_md       TEXT NOT NULL DEFAULT '',
          kind_code        TEXT NOT NULL DEFAULT 'spark',
          tags_json        TEXT NOT NULL DEFAULT '[]',
          source_session_id TEXT,
          created_at       TEXT NOT NULL,
          updated_at       TEXT NOT NULL
        ) STRICT;

-- ---------- knowledge_entries ----------
CREATE TABLE knowledge_entries (
          id               TEXT PRIMARY KEY,
          kind_code        TEXT NOT NULL DEFAULT 'note',
          title            TEXT NOT NULL,
          content_md       TEXT NOT NULL DEFAULT '',
          tags_json        TEXT NOT NULL DEFAULT '[]',
          source_task_id   TEXT REFERENCES tasks(id) ON DELETE SET NULL,
          source_session_id TEXT,
          created_at       TEXT NOT NULL,
          updated_at       TEXT NOT NULL
        , source_review_id TEXT, file_link TEXT, superseded_by_id TEXT, valid_until TEXT) STRICT;

-- ---------- knowledge_recall_log ----------
CREATE TABLE knowledge_recall_log (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id        TEXT,
          task_id           TEXT,
          trigger_code      TEXT NOT NULL,
          query             TEXT NOT NULL DEFAULT '',
          terms_json        TEXT NOT NULL DEFAULT '[]',
          hits_json         TEXT NOT NULL DEFAULT '[]',
          matched           INTEGER NOT NULL DEFAULT 0,
          dropped_by_score  INTEGER NOT NULL DEFAULT 0,
          dropped_by_limit  INTEGER NOT NULL DEFAULT 0,
          dropped_as_seen   INTEGER NOT NULL DEFAULT 0,
          injected          INTEGER NOT NULL DEFAULT 0,
          skipped_reason    TEXT,
          cited_ids_json    TEXT NOT NULL DEFAULT '[]',
          created_at        TEXT NOT NULL
        ) STRICT;

-- ---------- meta ----------
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) STRICT;

-- ---------- reminder_queue ----------
CREATE TABLE reminder_queue (
          id              TEXT PRIMARY KEY,
          reminder_id     TEXT,
          root_task_id    TEXT NOT NULL,
          task_id         TEXT NOT NULL,
          title           TEXT NOT NULL,
          body            TEXT NOT NULL,
          priority_code   TEXT NOT NULL,
          due_at          TEXT,
          attempts        INTEGER NOT NULL DEFAULT 0,
          next_attempt_at TEXT NOT NULL,
          last_error      TEXT,
          created_at      TEXT NOT NULL
        ) STRICT;

-- ---------- task_artifacts ----------
CREATE TABLE task_artifacts (
  id            TEXT PRIMARY KEY,
  task_id       TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  session_id    TEXT,
  kind_code     TEXT NOT NULL,
  title         TEXT NOT NULL,
  path          TEXT NOT NULL,
  category_code TEXT,
  meta_json     TEXT NOT NULL DEFAULT '{}',
  created_at    TEXT NOT NULL
) STRICT;

-- ---------- task_drafts ----------
CREATE TABLE task_drafts (
  id           TEXT PRIMARY KEY,
  kind_code    TEXT NOT NULL DEFAULT 'task',
  session_id   TEXT,
  payload_json TEXT NOT NULL,
  status_code  TEXT NOT NULL DEFAULT 'pending',
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
, deferred_at TEXT, defer_count INTEGER NOT NULL DEFAULT 0, notified_at TEXT) STRICT;

-- ---------- task_events ----------
CREATE TABLE task_events (
  id          TEXT PRIMARY KEY,
  task_id     TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  event_code  TEXT NOT NULL,
  before_json TEXT,
  after_json  TEXT,
  actor       TEXT NOT NULL DEFAULT 'user',
  note        TEXT,
  at          TEXT NOT NULL
) STRICT;

-- ---------- task_memories ----------
CREATE TABLE task_memories (
          id               TEXT PRIMARY KEY,
          root_task_id     TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
          task_id          TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
          kind             TEXT NOT NULL DEFAULT 'note',
          content          TEXT NOT NULL,
          source_session_id TEXT,
          created_at       TEXT NOT NULL,
          updated_at       TEXT NOT NULL
        ) STRICT;

-- ---------- task_reminders ----------
CREATE TABLE task_reminders (
  id             TEXT PRIMARY KEY,
  task_id        TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  offset_minutes INTEGER NOT NULL,
  method_code    TEXT NOT NULL DEFAULT 'browser',
  enabled        INTEGER NOT NULL DEFAULT 1,
  fired_at       TEXT,
  created_at     TEXT NOT NULL
, skipped_at TEXT, acknowledged_at TEXT) STRICT;

-- ---------- task_reports ----------
CREATE TABLE task_reports (
          id           TEXT PRIMARY KEY,
          period_code  TEXT NOT NULL,
          period_start TEXT NOT NULL,
          title        TEXT NOT NULL,
          summary_md   TEXT NOT NULL,
          stats_json   TEXT NOT NULL DEFAULT '{}',
          session_id   TEXT,
          created_at   TEXT NOT NULL,
          updated_at   TEXT NOT NULL,
          UNIQUE (period_code, period_start)
        ) STRICT;

-- ---------- task_reviews ----------
CREATE TABLE task_reviews (
  id           TEXT PRIMARY KEY,
  task_id      TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  session_id   TEXT,
  summary_md   TEXT NOT NULL,
  lessons_json TEXT NOT NULL DEFAULT '[]',
  created_at   TEXT NOT NULL
) STRICT;

-- ---------- task_sessions ----------
CREATE TABLE task_sessions (
  task_id          TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  session_id       TEXT NOT NULL,
  role_code        TEXT NOT NULL,
  workspace        TEXT,
  note             TEXT,
  created_at       TEXT NOT NULL,
  last_activity_at TEXT,
  PRIMARY KEY (task_id, session_id, role_code)
) STRICT;

-- ---------- tasks ----------
CREATE TABLE tasks (
  id                TEXT PRIMARY KEY,
  parent_id         TEXT REFERENCES tasks(id) ON DELETE SET NULL,
  title             TEXT NOT NULL,
  description       TEXT NOT NULL DEFAULT '',
  type_code         TEXT NOT NULL,
  status_code       TEXT NOT NULL,
  priority_code     TEXT NOT NULL,
  ai_policy_code    TEXT NOT NULL DEFAULT 'consult',
  due_at            TEXT,
  all_day           INTEGER NOT NULL DEFAULT 0,
  estimated_minutes INTEGER,
  source            TEXT NOT NULL DEFAULT 'manual',
  archived          INTEGER NOT NULL DEFAULT 0,
  extra             TEXT NOT NULL DEFAULT '{}',
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL,
  completed_at      TEXT,
  cancelled_at      TEXT
, workspace_path TEXT, recurrence_code TEXT, recurrence_rule TEXT NOT NULL DEFAULT '{}', recurrence_master_id TEXT REFERENCES tasks(id) ON DELETE CASCADE, recurrence_last_generated TEXT, progress_percent INTEGER NOT NULL DEFAULT 0 CHECK(progress_percent BETWEEN 0 AND 99)) STRICT;

-- ---------- 索引 ----------
CREATE INDEX idx_ai_session_registry_session ON ai_session_registry(session_id);
CREATE INDEX idx_draft_notify_next ON draft_notify_queue(next_attempt_at, created_at);
CREATE INDEX idx_idea_links_idea ON idea_links(idea_id);
CREATE INDEX idx_ideas_kind ON ideas(kind_code, updated_at DESC);
CREATE INDEX idx_knowledge_kind ON knowledge_entries(kind_code, updated_at DESC);
CREATE INDEX idx_knowledge_recall_created ON knowledge_recall_log(created_at DESC);
CREATE INDEX idx_knowledge_recall_session ON knowledge_recall_log(session_id, id DESC);
CREATE INDEX idx_knowledge_source ON knowledge_entries(source_task_id);
CREATE INDEX idx_knowledge_superseded ON knowledge_entries(superseded_by_id);
CREATE INDEX idx_reminder_queue_next ON reminder_queue(next_attempt_at, created_at);
CREATE INDEX idx_reminder_queue_root ON reminder_queue(root_task_id, created_at DESC);
CREATE INDEX idx_task_drafts_session ON task_drafts(session_id);
CREATE INDEX idx_task_drafts_status ON task_drafts(status_code);
CREATE INDEX idx_task_events_task ON task_events(task_id, at);
CREATE INDEX idx_task_memories_root ON task_memories(root_task_id, updated_at DESC);
CREATE INDEX idx_task_memories_task ON task_memories(task_id, updated_at DESC);
CREATE INDEX idx_task_reminders_task ON task_reminders(task_id);
CREATE INDEX idx_task_reports_period ON task_reports(period_code, period_start DESC);
CREATE INDEX idx_task_sessions_session ON task_sessions(session_id);
CREATE INDEX idx_tasks_due ON tasks(due_at);
CREATE INDEX idx_tasks_parent ON tasks(parent_id);
CREATE INDEX idx_tasks_priority ON tasks(priority_code);
CREATE INDEX idx_tasks_recurrence_code ON tasks(recurrence_code);
CREATE INDEX idx_tasks_recurrence_master ON tasks(recurrence_master_id);
CREATE INDEX idx_tasks_status ON tasks(status_code);
CREATE INDEX idx_tasks_type ON tasks(type_code);
