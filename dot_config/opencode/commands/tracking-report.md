---
description: Generate a read-only local orchestration tracking report
agent: orchestrator
---

Call the read-only `tracking_report({ bead?, sessions?, from?, to? })` tool using `$ARGUMENTS` as its selectors; omit selectors that were not supplied.
Accept only `--bead <id>`, `--sessions <id,...>`, `--from <ISO-8601>`, and
`--to <ISO-8601>`; with no arguments, use the current session/default report scope.
Session and time selectors intersect. Do not finalize a run, start a server, or
invent a run selector or lifecycle transition. Keep private Bead IDs and local report paths in
runtime output only.
