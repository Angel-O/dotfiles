---
name: memex-quick-search
description: Find one direct historical result with minimal Memex context, then escalate only when compact retrieval is insufficient.
allowed-tools: Bash(memex:*)
---

# Memex Quick Search

Use this skill as the default entry point for a simple historical lookup.

Run one repository-scoped query:

```bash
memex search "<one query>" --cwd . --unique-session --limit 1 --fields session_id,ts,role,snippet --format toon --non-interactive
```

Stop when the result is direct and unambiguous. Preserve its `session_id`,
record ID, machine, timestamp, role, and source provenance when a follow-up is
needed.

Only when verification or surrounding context is needed, rerun the same narrow
query with identifiers included:

```bash
memex search "<one query>" --cwd . --unique-session --limit 1 --fields session_id,ts,role,snippet,record_id,machine --format toon --non-interactive
```

Use the returned `record_id` and `machine` for bounded follow-up. For
verification, read only the matching record:

```bash
memex show --record-id <record_id> --machine <machine_id> --non-interactive
```

If surrounding evidence is necessary, use a bounded context window:

```bash
memex context --record-id <record_id> --machine <machine_id> --before 1 --after 1 --max-chars 4000 --non-interactive
```

Do not use `memex session` for ordinary lookup or read a full session. Load the
release-managed `memex-search` skill only for ambiguous discovery,
multi-session synthesis, transcript reconstruction, analogous-work
investigation, or equivalent advanced retrieval.
