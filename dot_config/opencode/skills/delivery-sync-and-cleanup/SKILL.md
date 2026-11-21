---
name: delivery-sync-and-cleanup
description: Synchronize a verified merged PR's recorded reference checkout and consent-dispose of its exact Herdr delivery environments.
---

# Delivery Sync and Cleanup

This procedure is independent of tracking. Run it after the router verifies a
merged PR and provides its full URL and the runtime-recorded reference checkout
and delivery environments. Do not infer missing identities or reconstruct the
helpers' shell sequencing.

## Synchronization

Run the bundled executable once per repository and PR:

```sh
"$HOME/.config/opencode/skills/delivery-sync-and-cleanup/scripts/sync-reference" \
  <full-pr-url> <recorded-reference-checkout>
```

The helper revalidates the merged PR and actual base, then verifies the recorded
checkout is clean, already on that base, and contains both its current `HEAD`
and the merge result in the fetched base history before the single
fast-forward-only pull. Reuse a recorded successful sync for the same
repository/PR; never repeat the pull. Report a nonzero result as a synchronization
failure and do not offer cleanup.

## Consent-based Herdr cleanup

After successful synchronization and when the delivery environments are no
longer needed, consider only runtime-recorded Herdr workspace ID, worktree path,
branch, and reference checkout identities. For a shared PR, sync once, then
consider each recorded environment separately. Missing identities, a dirty or
mismatched target, or an environment without a Herdr workspace means retain and
report it; there is no Git-only worktree-removal fallback.

For each eligible target, run the helper's non-mutating check before offering
cleanup:

```sh
"$HOME/.config/opencode/skills/delivery-sync-and-cleanup/scripts/dispose-environment" \
  --check <herdr-workspace-id> <recorded-worktree-path> <recorded-branch> \
  <recorded-reference-checkout>
```

Only after that check succeeds, state the exact branch, path, and workspace ID;
explain that Yes removes the Herdr worktree and workspace, then attempts safe
local branch deletion. Ask for explicit Yes/No consent. Silence, ambiguity, or
No leaves the environment intact. On Yes, invoke the same helper with the same
four recorded identities and without `--check`; it repeats all identity and
dirty-state checks immediately before mutation.

The helper never uses force. It removes the recorded Herdr target before
attempting `git branch -d`; a Herdr removal failure prevents branch deletion,
and a later branch-deletion failure is reported as partial success with the
worktree/workspace removed and branch retained. Report sync, eligibility, and
each cleanup outcome separately. Never delete a remote branch or choose a
substitute target.