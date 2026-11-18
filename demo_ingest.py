#!/usr/bin/env python3
"""End-to-end demo: put ONE record through source -> document -> chunk -> memory -> evidence,
then run a hybrid (vector + full-text) query.

Everything it writes is tagged with the prefix `demo:` so you can delete it afterwards:

    python demo_ingest.py --dsn postgresql://memory:memory@127.0.0.1:5432/memory
    python demo_ingest.py --dsn ... --clean      # delete demo rows and exit

Embeddings are optional. Without `--embed`, chunk.embedding stays NULL and the vector
branch returns nothing — the point of the demo is the data flow, not the model.
Pass `--embed` if you have Ollama running with an embedding model (default bge-m3).
"""
import argparse
import hashlib
import json
import sys
import urllib.request

DEMO = "demo:"

TEXT = """Retrieval quality usually fails for a boring reason: the index only understands one
kind of question. Embeddings match paraphrases but lose exact identifiers; inverted indexes
match identifiers but miss paraphrases. Keep both and merge the two candidate lists.

A second, quieter failure is a memory that cannot be overturned. If the store only keeps the
current conclusion, the next reader cannot tell whether it was revised, when, or why.
"""

TITLE = DEMO + " hybrid retrieval notes"


def connect(dsn):
    try:
        import psycopg  # psycopg 3
        return psycopg.connect(dsn), "psycopg3"
    except ImportError:
        pass
    try:
        import psycopg2  # psycopg 2
        return psycopg2.connect(dsn), "psycopg2"
    except ImportError:
        sys.exit('need a driver: pip install "psycopg[binary]"')


def embed(text, model, base="http://127.0.0.1:11434"):
    req = urllib.request.Request(
        base + "/api/embeddings",
        data=json.dumps({"model": model, "prompt": text}).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        vec = json.loads(r.read())["embedding"]
    return "[" + ",".join("%.6f" % x for x in vec) + "]"


def q(cur):
    return "%s" if cur.__class__.__module__.startswith("psycopg2") else "%s"


def chunks_of(text, size=600):
    """Naive paragraph-aware split; swap for your own."""
    out, buf = [], ""
    for para in text.split("\n\n"):
        if len(buf) + len(para) > size and buf:
            out.append(buf.strip())
            buf = ""
        buf += para + "\n\n"
    if buf.strip():
        out.append(buf.strip())
    return out


def clean(cur):
    p = DEMO + "%"
    cur.execute("delete from evidence where memory_id in (select id from memory where statement like %s)", (p,))
    cur.execute("delete from memory where statement like %s", (p,))
    cur.execute("delete from chunk where document_id in (select id from document where title like %s)", (p,))
    cur.execute("delete from document where title like %s", (p,))
    cur.execute("delete from source where title like %s", (p,))
    cur.execute("delete from predicate_dict where predicate = 'demo_design_rule'")
    cur.connection.commit()
    print("cleaned demo rows")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dsn", default="postgresql://memory:memory@127.0.0.1:5432/memory")
    ap.add_argument("--embed", action="store_true", help="call Ollama to fill chunk.embedding")
    ap.add_argument("--model", default="bge-m3")
    ap.add_argument("--clean", action="store_true", help="remove demo rows and exit")
    args = ap.parse_args()

    conn, drv = connect(args.dsn)
    cur = conn.cursor()
    print("connected via", drv)

    if args.clean:
        clean(cur)
        return

    clean(cur)  # idempotent: drop any previous demo run before inserting again

    # 1) source ------------------------------------------------------------
    cur.execute(
        """insert into source (kind, uri, title, checksum) values ('markdown', %s, %s, %s)
           returning id""",
        (DEMO + "notes.md", TITLE, hashlib.sha256(TEXT.encode()).hexdigest()),
    )
    src_id = cur.fetchone()[0]

    # 2) document ----------------------------------------------------------
    cur.execute(
        """insert into document (source_id, path, title, content_hash, version)
           values (%s, %s, %s, %s, 1) returning id""",
        (src_id, DEMO + "notes.txt", TITLE, hashlib.sha256(TEXT.encode()).hexdigest()),
    )
    doc_id = cur.fetchone()[0]

    # 3) chunks ------------------------------------------------------------
    chunk_ids = []
    for i, body in enumerate(chunks_of(TEXT)):
        vec = embed(body, args.model) if args.embed else None
        cur.execute(
            """insert into chunk
                 (document_id, ordinal, content, content_tsv, embedding, embedding_model,
                  embedding_dim, content_hash, char_start, char_end)
               values (%s, %s, %s, to_tsvector('simple', %s), %s, %s, %s, %s, 0, %s)
               returning id""",
            (doc_id, i, body, body,
             vec, args.model if vec else None, 1024 if vec else None,
             hashlib.sha256(body.encode()).hexdigest(), len(body)),
        )
        chunk_ids.append(cur.fetchone()[0])
    print("chunks:", len(chunk_ids))

    # 4) memory (candidate) + 5) evidence ---------------------------------
    statement = "Keep a vector index and a full-text index on the same chunk table."
    # predicate must exist in predicate_dict (memory.predicate has an FK to it)
    cur.execute(
        """insert into predicate_dict (predicate, label_zh, status)
           values ('demo_design_rule', '演示：设计规则', 'active')
           on conflict (predicate) do nothing"""
    )
    cur.execute(
        """insert into memory (kind, scope, statement, statement_tsv, predicate, status, confidence)
           values ('insight', 'global', %s, to_tsvector('simple', %s), 'demo_design_rule', 'candidate', 0.7)
           returning id""",
        (DEMO + statement, DEMO + statement),
    )
    mem_id = cur.fetchone()[0]
    cur.execute(
        """insert into evidence (memory_id, chunk_id, quote, locator)
           values (%s, %s, %s, %s::jsonb)""",
        (mem_id, chunk_ids[0], "Keep both and merge the two candidate lists.",
         json.dumps({"chunk_ordinal": 0, "section": "para 1"}, ensure_ascii=False)),
    )
    conn.commit()
    print("memory:", mem_id, "(status=candidate — a human would confirm it)")

    # 6) hybrid retrieval --------------------------------------------------
    print("\n--- full-text ---")
    cur.execute(
        """select id, left(content, 60)
             from chunk
            where content_tsv @@ plainto_tsquery('simple', %s)
            order by ts_rank(content_tsv, plainto_tsquery('simple', %s)) desc
            limit 3""",
        ("identifiers", "identifiers"),
    )
    for r in cur.fetchall():
        print(" ", r[0], "|", r[1].replace("\n", " "))

    if args.embed:
        print("\n--- vector ---")
        qv = embed("why do my searches miss obvious matches", args.model)
        cur.execute(
            """select id, round((embedding <=> %s::vector)::numeric, 4) as dist, left(content, 60)
                 from chunk
                where embedding is not null
                order by embedding <=> %s::vector
                limit 3""",
            (qv, qv),
        )
        for r in cur.fetchall():
            print(" ", r[0], "| dist", r[1], "|", r[2].replace("\n", " "))

    cur.execute("select count(*) from memory where status = 'candidate'")
    print("\ncandidate memories:", cur.fetchone()[0])
    conn.close()


if __name__ == "__main__":
    main()
