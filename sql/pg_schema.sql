--
-- PostgreSQL database dump
--


-- Dumped from database version 16.16 (Debian 16.16-1.pgdg12+1)
-- Dumped by pg_dump version 16.16 (Debian 16.16-1.pgdg12+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: ltree; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS ltree WITH SCHEMA public;


--
-- Name: EXTENSION ltree; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION ltree IS 'data type for hierarchical tree-like structures';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: asset; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asset (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid,
    kind text NOT NULL,
    path text NOT NULL,
    uri text,
    checksum text NOT NULL,
    mime text,
    size_bytes bigint,
    duration_sec numeric,
    status text DEFAULT 'active'::text NOT NULL,
    parent_asset_id uuid,
    license_entry_id uuid,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT asset_kind_check CHECK ((kind = ANY (ARRAY['image'::text, 'video'::text, 'audio'::text, 'document'::text, 'model'::text, 'design'::text, 'license_file'::text, 'other'::text])))
);


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    actor_id uuid,
    action text NOT NULL,
    target_type text NOT NULL,
    target_id uuid,
    at timestamp with time zone DEFAULT now() NOT NULL,
    reason text,
    before jsonb,
    after jsonb
);


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_log_id_seq OWNED BY public.audit_log.id;


--
-- Name: chunk; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chunk (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_id uuid NOT NULL,
    ordinal integer NOT NULL,
    section_path public.ltree,
    content text NOT NULL,
    content_tsv tsvector NOT NULL,
    content_hash text NOT NULL,
    token_count integer,
    char_start integer,
    char_end integer,
    embedding public.vector(1024),
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    embedding_model text,
    embedding_dim integer
);


--
-- Name: cost_entry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cost_entry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid,
    run_id uuid,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    vendor text NOT NULL,
    item text,
    amount numeric NOT NULL,
    currency text DEFAULT 'CNY'::text NOT NULL,
    tax_amount numeric,
    status text DEFAULT 'paid'::text NOT NULL,
    invoice_ref text,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT cost_entry_status_check CHECK ((status = ANY (ARRAY['paid'::text, 'unpaid'::text, 'refunded'::text, 'reimbursed'::text])))
);


--
-- Name: document; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source_id uuid NOT NULL,
    asset_id uuid,
    path text,
    mime text,
    lang text DEFAULT 'zh'::text NOT NULL,
    title text,
    content_hash text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: edge; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.edge (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    subject_entity_id uuid NOT NULL,
    predicate text NOT NULL,
    object_entity_id uuid NOT NULL,
    valid_from timestamp with time zone,
    valid_until timestamp with time zone,
    status text DEFAULT 'candidate'::text NOT NULL,
    confidence real DEFAULT 0.5 NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT edge_confidence_check CHECK (((confidence >= (0)::double precision) AND (confidence <= (1)::double precision))),
    CONSTRAINT edge_status_check CHECK ((status = ANY (ARRAY['candidate'::text, 'active'::text, 'disputed'::text, 'superseded'::text, 'merged'::text, 'archived'::text])))
);


--
-- Name: entity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type text NOT NULL,
    name text NOT NULL,
    norm_name text NOT NULL,
    name_tsv tsvector,
    description text,
    status text DEFAULT 'active'::text NOT NULL,
    canonical_entity_id uuid,
    embedding public.vector(1024),
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT entity_status_check CHECK ((status = ANY (ARRAY['active'::text, 'merged'::text, 'archived'::text])))
);


--
-- Name: entity_alias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_alias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_id uuid NOT NULL,
    alias text NOT NULL,
    norm_alias text NOT NULL,
    source text
);


--
-- Name: evidence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evidence (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source_id uuid,
    chunk_id uuid,
    memory_id uuid,
    entity_id uuid,
    edge_id uuid,
    timeline_event_id uuid,
    asset_id uuid,
    quote text,
    locator jsonb DEFAULT '{}'::jsonb NOT NULL,
    confidence real DEFAULT 0.5 NOT NULL,
    extractor_kind text DEFAULT 'rule'::text NOT NULL,
    extractor_model text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT evidence_check CHECK ((num_nonnulls(memory_id, entity_id, edge_id, timeline_event_id, asset_id) <= 1)),
    CONSTRAINT evidence_confidence_check CHECK (((confidence >= (0)::double precision) AND (confidence <= (1)::double precision))),
    CONSTRAINT evidence_extractor_kind_check CHECK ((extractor_kind = ANY (ARRAY['rule'::text, 'llm'::text, 'user'::text])))
);


--
-- Name: license_entry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.license_entry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid,
    asset_id uuid,
    title text NOT NULL,
    grantor text,
    licensee text,
    rights_summary text,
    territory text,
    valid_from date,
    valid_until date,
    status text DEFAULT 'active'::text NOT NULL,
    cost_amount numeric,
    currency text,
    obligations jsonb DEFAULT '{}'::jsonb NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: memory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memory (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    canonical_id uuid,
    scope text DEFAULT 'global'::text NOT NULL,
    scope_project_id uuid,
    kind text NOT NULL,
    subject_entity_id uuid,
    predicate text,
    object_text text,
    object_entity_id uuid,
    statement text NOT NULL,
    statement_tsv tsvector NOT NULL,
    embedding public.vector(1024),
    valid_from timestamp with time zone,
    valid_until timestamp with time zone,
    status text DEFAULT 'candidate'::text NOT NULL,
    confidence real DEFAULT 0.5 NOT NULL,
    importance real DEFAULT 0.5 NOT NULL,
    decay_rate real DEFAULT 0.0 NOT NULL,
    access_count integer DEFAULT 0 NOT NULL,
    last_accessed_at timestamp with time zone,
    dedupe_key text,
    current_revision_id uuid,
    superseded_by uuid,
    merged_into uuid,
    source_id uuid,
    observed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    content_hash text,
    embedding_model text,
    embedding_dim integer,
    approved_at timestamp with time zone,
    approved_by text,
    expires_at timestamp with time zone,
    sensitivity text DEFAULT 'normal'::text NOT NULL,
    supersedes_id uuid,
    review_reason text,
    reviewed_at timestamp with time zone,
    reviewed_by text,
    duplicate_of uuid,
    CONSTRAINT memory_confidence_check CHECK (((confidence >= (0)::double precision) AND (confidence <= (1)::double precision))),
    CONSTRAINT memory_importance_check CHECK (((importance >= (0)::double precision) AND (importance <= (1)::double precision))),
    CONSTRAINT memory_kind_check CHECK ((kind = ANY (ARRAY['preference'::text, 'fact'::text, 'decision'::text, 'rule'::text, 'profile'::text, 'summary'::text, 'config'::text, 'event'::text, 'insight'::text, 'question'::text]))),
    CONSTRAINT memory_scope_check CHECK ((scope = ANY (ARRAY['global'::text, 'user'::text, 'project'::text, 'session'::text]))),
    CONSTRAINT memory_status_check CHECK ((status = ANY (ARRAY['candidate'::text, 'active'::text, 'disputed'::text, 'superseded'::text, 'merged'::text, 'archived'::text, 'forgotten'::text])))
);


--
-- Name: memories_active; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.memories_active AS
 SELECT id,
    canonical_id,
    scope,
    scope_project_id,
    kind,
    subject_entity_id,
    predicate,
    object_text,
    object_entity_id,
    statement,
    statement_tsv,
    embedding,
    valid_from,
    valid_until,
    status,
    confidence,
    importance,
    decay_rate,
    access_count,
    last_accessed_at,
    dedupe_key,
    current_revision_id,
    superseded_by,
    merged_into,
    source_id,
    observed_at,
    created_at,
    updated_at,
    meta,
    content_hash,
    embedding_model,
    embedding_dim,
    approved_at,
    approved_by,
    expires_at,
    sensitivity,
    supersedes_id,
    review_reason,
    reviewed_at,
    reviewed_by,
    duplicate_of
   FROM public.memory
  WHERE (status = 'active'::text);


--
-- Name: memory_candidates; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.memory_candidates AS
 SELECT id,
    canonical_id,
    scope,
    scope_project_id,
    kind,
    subject_entity_id,
    predicate,
    object_text,
    object_entity_id,
    statement,
    statement_tsv,
    embedding,
    valid_from,
    valid_until,
    status,
    confidence,
    importance,
    decay_rate,
    access_count,
    last_accessed_at,
    dedupe_key,
    current_revision_id,
    superseded_by,
    merged_into,
    source_id,
    observed_at,
    created_at,
    updated_at,
    meta,
    content_hash,
    embedding_model,
    embedding_dim,
    approved_at,
    approved_by,
    expires_at,
    sensitivity,
    supersedes_id,
    review_reason,
    reviewed_at,
    reviewed_by,
    duplicate_of
   FROM public.memory
  WHERE (status = 'candidate'::text);


--
-- Name: memory_link; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memory_link (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    src_id uuid NOT NULL,
    dst_id uuid NOT NULL,
    rel text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    confidence real DEFAULT 0.5 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT memory_link_confidence_check CHECK (((confidence >= (0)::double precision) AND (confidence <= (1)::double precision)))
);


--
-- Name: memory_review; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memory_review (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    kind text NOT NULL,
    candidate_ids jsonb NOT NULL,
    evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    decision text DEFAULT 'pending'::text NOT NULL,
    decided_by text,
    decided_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT memory_review_decision_check CHECK ((decision = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]))),
    CONSTRAINT memory_review_kind_check CHECK ((kind = ANY (ARRAY['dedupe'::text, 'merge'::text, 'forget'::text, 'conflict'::text])))
);


--
-- Name: memory_revision; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memory_revision (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    memory_id uuid NOT NULL,
    version integer NOT NULL,
    statement text NOT NULL,
    object_text text,
    valid_from timestamp with time zone,
    valid_until timestamp with time zone,
    confidence real,
    importance real,
    actor_id uuid,
    change_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: merge_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merge_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    target_type text NOT NULL,
    winner_id uuid NOT NULL,
    loser_ids jsonb NOT NULL,
    actor_id uuid,
    at timestamp with time zone DEFAULT now() NOT NULL,
    rationale text,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: predicate_dict; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.predicate_dict (
    predicate text NOT NULL,
    label_zh text NOT NULL,
    inverse_predicate text,
    subject_types jsonb DEFAULT '[]'::jsonb NOT NULL,
    object_types jsonb DEFAULT '[]'::jsonb NOT NULL,
    status text DEFAULT 'active'::text NOT NULL
);


--
-- Name: project; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_id uuid,
    path public.ltree,
    name text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    started_at timestamp with time zone,
    due_at timestamp with time zone,
    archived_at timestamp with time zone,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT project_status_check CHECK ((status = ANY (ARRAY['active'::text, 'paused'::text, 'done'::text, 'archived'::text])))
);


--
-- Name: retrieval_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.retrieval_logs (
    id bigint NOT NULL,
    query text NOT NULL,
    mode text DEFAULT 'search'::text NOT NULL,
    filters jsonb DEFAULT '{}'::jsonb NOT NULL,
    top_ids jsonb DEFAULT '[]'::jsonb NOT NULL,
    result_count integer,
    latency_ms integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: retrieval_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.retrieval_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: retrieval_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.retrieval_logs_id_seq OWNED BY public.retrieval_logs.id;


--
-- Name: run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.run (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid,
    type text NOT NULL,
    status text DEFAULT 'queued'::text NOT NULL,
    model text,
    started_at timestamp with time zone,
    ended_at timestamp with time zone,
    params jsonb DEFAULT '{}'::jsonb NOT NULL,
    metrics jsonb DEFAULT '{}'::jsonb NOT NULL,
    cost_amount numeric,
    currency text,
    error text,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT run_status_check CHECK ((status = ANY (ARRAY['queued'::text, 'running'::text, 'success'::text, 'failed'::text, 'canceled'::text])))
);


--
-- Name: run_asset; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.run_asset (
    run_id uuid NOT NULL,
    asset_id uuid NOT NULL,
    role text NOT NULL,
    ordinal integer DEFAULT 0 NOT NULL,
    CONSTRAINT run_asset_role_check CHECK ((role = ANY (ARRAY['input'::text, 'output'::text, 'reference'::text, 'preview'::text])))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version text NOT NULL,
    description text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: source; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    kind text NOT NULL,
    uri text NOT NULL,
    title text,
    checksum text NOT NULL,
    published_at timestamp with time zone,
    imported_at timestamp with time zone DEFAULT now() NOT NULL,
    status text DEFAULT 'new'::text NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT source_kind_check CHECK ((kind = ANY (ARRAY['file'::text, 'markdown'::text, 'jsonl'::text, 'chat'::text, 'web'::text, 'email'::text, 'manual'::text, 'import_batch'::text]))),
    CONSTRAINT source_status_check CHECK ((status = ANY (ARRAY['new'::text, 'imported'::text, 'failed'::text, 'archived'::text])))
);


--
-- Name: task; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid,
    parent_id uuid,
    title text NOT NULL,
    status text DEFAULT 'todo'::text NOT NULL,
    priority text DEFAULT 'p2'::text NOT NULL,
    due_at timestamp with time zone,
    completed_at timestamp with time zone,
    assignee_actor_id uuid,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT task_status_check CHECK ((status = ANY (ARRAY['todo'::text, 'doing'::text, 'blocked'::text, 'done'::text, 'canceled'::text])))
);


--
-- Name: timeline_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.timeline_event (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    summary text,
    project_id uuid,
    entity_id uuid,
    memory_id uuid,
    importance real DEFAULT 0.5 NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT timeline_event_importance_check CHECK (((importance >= (0)::double precision) AND (importance <= (1)::double precision)))
);


--
-- Name: audit_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN id SET DEFAULT nextval('public.audit_log_id_seq'::regclass);


--
-- Name: retrieval_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retrieval_logs ALTER COLUMN id SET DEFAULT nextval('public.retrieval_logs_id_seq'::regclass);


--
-- Name: asset asset_checksum_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_checksum_key UNIQUE (checksum);


--
-- Name: asset asset_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: chunk chunk_document_id_ordinal_content_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chunk
    ADD CONSTRAINT chunk_document_id_ordinal_content_hash_key UNIQUE (document_id, ordinal, content_hash);


--
-- Name: chunk chunk_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chunk
    ADD CONSTRAINT chunk_pkey PRIMARY KEY (id);


--
-- Name: cost_entry cost_entry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_entry
    ADD CONSTRAINT cost_entry_pkey PRIMARY KEY (id);


--
-- Name: document document_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document
    ADD CONSTRAINT document_pkey PRIMARY KEY (id);


--
-- Name: document document_source_id_content_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document
    ADD CONSTRAINT document_source_id_content_hash_key UNIQUE (source_id, content_hash);


--
-- Name: edge edge_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edge
    ADD CONSTRAINT edge_pkey PRIMARY KEY (id);


--
-- Name: edge edge_subject_entity_id_predicate_object_entity_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edge
    ADD CONSTRAINT edge_subject_entity_id_predicate_object_entity_id_key UNIQUE (subject_entity_id, predicate, object_entity_id);


--
-- Name: entity_alias entity_alias_entity_id_norm_alias_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_alias
    ADD CONSTRAINT entity_alias_entity_id_norm_alias_key UNIQUE (entity_id, norm_alias);


--
-- Name: entity_alias entity_alias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_alias
    ADD CONSTRAINT entity_alias_pkey PRIMARY KEY (id);


--
-- Name: entity entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity
    ADD CONSTRAINT entity_pkey PRIMARY KEY (id);


--
-- Name: evidence evidence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence
    ADD CONSTRAINT evidence_pkey PRIMARY KEY (id);


--
-- Name: license_entry license_entry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.license_entry
    ADD CONSTRAINT license_entry_pkey PRIMARY KEY (id);


--
-- Name: memory_link memory_link_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_link
    ADD CONSTRAINT memory_link_pkey PRIMARY KEY (id);


--
-- Name: memory_link memory_link_src_id_dst_id_rel_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_link
    ADD CONSTRAINT memory_link_src_id_dst_id_rel_key UNIQUE (src_id, dst_id, rel);


--
-- Name: memory memory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory
    ADD CONSTRAINT memory_pkey PRIMARY KEY (id);


--
-- Name: memory_review memory_review_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_review
    ADD CONSTRAINT memory_review_pkey PRIMARY KEY (id);


--
-- Name: memory_revision memory_revision_memory_id_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_revision
    ADD CONSTRAINT memory_revision_memory_id_version_key UNIQUE (memory_id, version);


--
-- Name: memory_revision memory_revision_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_revision
    ADD CONSTRAINT memory_revision_pkey PRIMARY KEY (id);


--
-- Name: merge_log merge_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_log
    ADD CONSTRAINT merge_log_pkey PRIMARY KEY (id);


--
-- Name: predicate_dict predicate_dict_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.predicate_dict
    ADD CONSTRAINT predicate_dict_pkey PRIMARY KEY (predicate);


--
-- Name: project project_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT project_pkey PRIMARY KEY (id);


--
-- Name: retrieval_logs retrieval_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retrieval_logs
    ADD CONSTRAINT retrieval_logs_pkey PRIMARY KEY (id);


--
-- Name: run_asset run_asset_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run_asset
    ADD CONSTRAINT run_asset_pkey PRIMARY KEY (run_id, asset_id, role);


--
-- Name: run run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run
    ADD CONSTRAINT run_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: source source_kind_uri_checksum_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source
    ADD CONSTRAINT source_kind_uri_checksum_key UNIQUE (kind, uri, checksum);


--
-- Name: source source_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source
    ADD CONSTRAINT source_pkey PRIMARY KEY (id);


--
-- Name: task task_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_pkey PRIMARY KEY (id);


--
-- Name: timeline_event timeline_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timeline_event
    ADD CONSTRAINT timeline_event_pkey PRIMARY KEY (id);


--
-- Name: idx_asset_project_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_asset_project_kind ON public.asset USING btree (project_id, kind, status);


--
-- Name: idx_audit_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_at ON public.audit_log USING btree (at DESC);


--
-- Name: idx_audit_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_target ON public.audit_log USING btree (target_type, target_id);


--
-- Name: idx_chunk_document_ordinal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chunk_document_ordinal ON public.chunk USING btree (document_id, ordinal);


--
-- Name: idx_chunk_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chunk_embedding ON public.chunk USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: idx_chunk_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chunk_hash ON public.chunk USING btree (content_hash);


--
-- Name: idx_chunk_tsv; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chunk_tsv ON public.chunk USING gin (content_tsv);


--
-- Name: idx_cost_project_occurred; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cost_project_occurred ON public.cost_entry USING btree (project_id, occurred_at DESC);


--
-- Name: idx_document_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_document_source ON public.document USING btree (source_id);


--
-- Name: idx_edge_object; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_edge_object ON public.edge USING btree (object_entity_id);


--
-- Name: idx_edge_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_edge_subject ON public.edge USING btree (subject_entity_id, predicate, status);


--
-- Name: idx_entity_alias_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_entity_alias_trgm ON public.entity_alias USING gin (norm_alias public.gin_trgm_ops);


--
-- Name: idx_entity_name_tsv; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_entity_name_tsv ON public.entity USING gin (name_tsv);


--
-- Name: idx_entity_type_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_entity_type_status ON public.entity USING btree (type, status);


--
-- Name: idx_license_valid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_license_valid ON public.license_entry USING btree (valid_until, status);


--
-- Name: idx_memory_content_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_content_hash ON public.memory USING btree (content_hash);


--
-- Name: idx_memory_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_embedding ON public.memory USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: idx_memory_review_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_review_pending ON public.memory_review USING btree (decision, created_at DESC);


--
-- Name: idx_memory_scope_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_scope_kind ON public.memory USING btree (scope, kind, updated_at DESC);


--
-- Name: idx_memory_sensitivity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_sensitivity ON public.memory USING btree (sensitivity, status);


--
-- Name: idx_memory_status_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_status_active ON public.memory USING btree (status) WHERE (status = 'active'::text);


--
-- Name: idx_memory_tsv; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_tsv ON public.memory USING gin (statement_tsv);


--
-- Name: idx_memory_valid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_memory_valid ON public.memory USING btree (valid_from, valid_until);


--
-- Name: idx_project_path; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_path ON public.project USING gist (path);


--
-- Name: idx_retrieval_logs_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_retrieval_logs_created ON public.retrieval_logs USING btree (created_at DESC);


--
-- Name: idx_retrieval_logs_query; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_retrieval_logs_query ON public.retrieval_logs USING btree (query);


--
-- Name: idx_run_project_started; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_run_project_started ON public.run USING btree (project_id, started_at DESC);


--
-- Name: idx_source_kind_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_source_kind_status ON public.source USING btree (kind, status);


--
-- Name: idx_task_project_status_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_project_status_due ON public.task USING btree (project_id, status, due_at);


--
-- Name: idx_timeline_occurred; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_timeline_occurred ON public.timeline_event USING btree (occurred_at DESC);


--
-- Name: idx_timeline_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_timeline_project ON public.timeline_event USING btree (project_id, occurred_at DESC);


--
-- Name: ux_asset_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_asset_external_id ON public.asset USING btree (((meta ->> 'asset_id'::text))) WHERE (meta ? 'asset_id'::text);


--
-- Name: ux_entity_type_norm_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_entity_type_norm_active ON public.entity USING btree (type, norm_name) WHERE (status = 'active'::text);


--
-- Name: ux_memory_active_content_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_memory_active_content_hash ON public.memory USING btree (scope, content_hash) WHERE ((status = 'active'::text) AND (content_hash IS NOT NULL));


--
-- Name: ux_memory_active_dedupe; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_memory_active_dedupe ON public.memory USING btree (dedupe_key) WHERE ((status = 'active'::text) AND (dedupe_key IS NOT NULL));


--
-- Name: ux_task_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_task_external_id ON public.task USING btree (((meta ->> 'task_id'::text))) WHERE (meta ? 'task_id'::text);


--
-- Name: asset asset_parent_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_parent_asset_id_fkey FOREIGN KEY (parent_asset_id) REFERENCES public.asset(id) ON DELETE SET NULL;


--
-- Name: asset asset_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.project(id) ON DELETE SET NULL;


--
-- Name: chunk chunk_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chunk
    ADD CONSTRAINT chunk_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.document(id) ON DELETE CASCADE;


--
-- Name: cost_entry cost_entry_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_entry
    ADD CONSTRAINT cost_entry_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.project(id) ON DELETE SET NULL;


--
-- Name: cost_entry cost_entry_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_entry
    ADD CONSTRAINT cost_entry_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.run(id) ON DELETE SET NULL;


--
-- Name: document document_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document
    ADD CONSTRAINT document_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.source(id) ON DELETE CASCADE;


--
-- Name: edge edge_object_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edge
    ADD CONSTRAINT edge_object_entity_id_fkey FOREIGN KEY (object_entity_id) REFERENCES public.entity(id) ON DELETE CASCADE;


--
-- Name: edge edge_predicate_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edge
    ADD CONSTRAINT edge_predicate_fkey FOREIGN KEY (predicate) REFERENCES public.predicate_dict(predicate);


--
-- Name: edge edge_subject_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edge
    ADD CONSTRAINT edge_subject_entity_id_fkey FOREIGN KEY (subject_entity_id) REFERENCES public.entity(id) ON DELETE CASCADE;


--
-- Name: entity_alias entity_alias_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_alias
    ADD CONSTRAINT entity_alias_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES public.entity(id) ON DELETE CASCADE;


--
-- Name: entity entity_canonical_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity
    ADD CONSTRAINT entity_canonical_entity_id_fkey FOREIGN KEY (canonical_entity_id) REFERENCES public.entity(id) ON DELETE SET NULL;


--
-- Name: evidence evidence_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence
    ADD CONSTRAINT evidence_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.asset(id) ON DELETE CASCADE;


--
-- Name: evidence evidence_chunk_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence
    ADD CONSTRAINT evidence_chunk_id_fkey FOREIGN KEY (chunk_id) REFERENCES public.chunk(id) ON DELETE CASCADE;


--
-- Name: evidence evidence_edge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence
    ADD CONSTRAINT evidence_edge_id_fkey FOREIGN KEY (edge_id) REFERENCES public.edge(id) ON DELETE CASCADE;


--
-- Name: evidence evidence_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence
    ADD CONSTRAINT evidence_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES public.entity(id) ON DELETE CASCADE;


--
-- Name: evidence evidence_memory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence
    ADD CONSTRAINT evidence_memory_id_fkey FOREIGN KEY (memory_id) REFERENCES public.memory(id) ON DELETE CASCADE;


--
-- Name: evidence evidence_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence
    ADD CONSTRAINT evidence_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.source(id) ON DELETE CASCADE;


--
-- Name: evidence evidence_timeline_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence
    ADD CONSTRAINT evidence_timeline_event_id_fkey FOREIGN KEY (timeline_event_id) REFERENCES public.timeline_event(id) ON DELETE CASCADE;


--
-- Name: memory fk_memory_current_revision; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory
    ADD CONSTRAINT fk_memory_current_revision FOREIGN KEY (current_revision_id) REFERENCES public.memory_revision(id) ON DELETE SET NULL;


--
-- Name: license_entry license_entry_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.license_entry
    ADD CONSTRAINT license_entry_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.asset(id) ON DELETE SET NULL;


--
-- Name: license_entry license_entry_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.license_entry
    ADD CONSTRAINT license_entry_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.project(id) ON DELETE SET NULL;


--
-- Name: memory memory_canonical_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory
    ADD CONSTRAINT memory_canonical_id_fkey FOREIGN KEY (canonical_id) REFERENCES public.memory(id) ON DELETE SET NULL;


--
-- Name: memory memory_duplicate_of_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory
    ADD CONSTRAINT memory_duplicate_of_fkey FOREIGN KEY (duplicate_of) REFERENCES public.memory(id) ON DELETE SET NULL;


--
-- Name: memory_link memory_link_dst_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_link
    ADD CONSTRAINT memory_link_dst_id_fkey FOREIGN KEY (dst_id) REFERENCES public.memory(id) ON DELETE CASCADE;


--
-- Name: memory_link memory_link_src_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_link
    ADD CONSTRAINT memory_link_src_id_fkey FOREIGN KEY (src_id) REFERENCES public.memory(id) ON DELETE CASCADE;


--
-- Name: memory memory_merged_into_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory
    ADD CONSTRAINT memory_merged_into_fkey FOREIGN KEY (merged_into) REFERENCES public.memory(id) ON DELETE SET NULL;


--
-- Name: memory memory_object_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory
    ADD CONSTRAINT memory_object_entity_id_fkey FOREIGN KEY (object_entity_id) REFERENCES public.entity(id) ON DELETE SET NULL;


--
-- Name: memory memory_predicate_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory
    ADD CONSTRAINT memory_predicate_fkey FOREIGN KEY (predicate) REFERENCES public.predicate_dict(predicate) ON DELETE SET NULL;


--
-- Name: memory_revision memory_revision_memory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory_revision
    ADD CONSTRAINT memory_revision_memory_id_fkey FOREIGN KEY (memory_id) REFERENCES public.memory(id) ON DELETE CASCADE;


--
-- Name: memory memory_scope_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory
    ADD CONSTRAINT memory_scope_project_id_fkey FOREIGN KEY (scope_project_id) REFERENCES public.project(id) ON DELETE SET NULL;


--
-- Name: memory memory_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory
    ADD CONSTRAINT memory_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.source(id) ON DELETE SET NULL;


--
-- Name: memory memory_subject_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory
    ADD CONSTRAINT memory_subject_entity_id_fkey FOREIGN KEY (subject_entity_id) REFERENCES public.entity(id) ON DELETE SET NULL;


--
-- Name: memory memory_superseded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory
    ADD CONSTRAINT memory_superseded_by_fkey FOREIGN KEY (superseded_by) REFERENCES public.memory(id) ON DELETE SET NULL;


--
-- Name: memory memory_supersedes_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memory
    ADD CONSTRAINT memory_supersedes_id_fkey FOREIGN KEY (supersedes_id) REFERENCES public.memory(id) ON DELETE SET NULL;


--
-- Name: project project_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT project_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.project(id) ON DELETE SET NULL;


--
-- Name: run_asset run_asset_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run_asset
    ADD CONSTRAINT run_asset_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.asset(id) ON DELETE CASCADE;


--
-- Name: run_asset run_asset_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run_asset
    ADD CONSTRAINT run_asset_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.run(id) ON DELETE CASCADE;


--
-- Name: run run_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run
    ADD CONSTRAINT run_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.project(id) ON DELETE SET NULL;


--
-- Name: task task_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.task(id) ON DELETE SET NULL;


--
-- Name: task task_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.project(id) ON DELETE SET NULL;


--
-- Name: timeline_event timeline_event_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timeline_event
    ADD CONSTRAINT timeline_event_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES public.entity(id) ON DELETE SET NULL;


--
-- Name: timeline_event timeline_event_memory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timeline_event
    ADD CONSTRAINT timeline_event_memory_id_fkey FOREIGN KEY (memory_id) REFERENCES public.memory(id) ON DELETE SET NULL;


--
-- Name: timeline_event timeline_event_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timeline_event
    ADD CONSTRAINT timeline_event_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.project(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--


