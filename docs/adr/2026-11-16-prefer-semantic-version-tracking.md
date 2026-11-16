# Prefer semantic-version tracking

## Version 1 — 2026-11-16

### Decision

Track dependencies by semantic version when viable. When semantic-version
tracking is not viable, track a branch and pin the dependency to an exact
commit hash.

### Rationale

Semantic versions signal potentially breaking changes and allow Renovate to
include available release notes in update pull requests. Commit pins provide
an update path and a reproducible revision when suitable versions are unavailable.

### Alternatives discarded

| Alternative | Why it was discarded |
| --- | --- |
| Track commit hashes for all dependencies | Commit updates lack semantic-version signals and may not provide release notes in Renovate pull requests. |
