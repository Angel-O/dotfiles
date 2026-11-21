---
name: delivery-sync-and-cleanup
description: Safely synchronize a verified merged PR's recorded reference checkout and optionally remove its recorded delivery worktrees and Herdr workspaces.
---

# Delivery Sync and Cleanup

This procedure is independent of issue tracking. Run it only after the router
has verified a merged PR and supplies its full URL, merge SHA, actual base
branch, recorded reference checkout, and any recorded delivery environments.
Do not query or mutate an issue tracker here, infer a base, or accept unverified
merge details.

## Reference synchronization

Require the supplied merge SHA to be 40 hex characters and the base to be the
verified PR base. Use only the recorded reference checkout; require it to be
clean and already on that exact branch. Fetch only the base and verify both the
current `HEAD` and merge SHA are ancestors of `FETCH_HEAD`:

```sh
git -C <recorded-reference-checkout> status --porcelain
git -C <recorded-reference-checkout> branch --show-current
git -C <recorded-reference-checkout> fetch --no-tags origin refs/heads/<base>
git -C <recorded-reference-checkout> merge-base --is-ancestor HEAD FETCH_HEAD
git -C <recorded-reference-checkout> merge-base --is-ancestor <merge-sha> FETCH_HEAD
```

Require empty status output and an exact branch match. Recheck cleanliness,
then synchronize exactly once per repository and PR:

```sh
git -C <recorded-reference-checkout> pull --ff-only origin <base>
```

Reuse a recorded successful synchronization for the same repository/PR; never
repeat its pull. Do not switch branches, merge, reset, overwrite local work, or
retry a failed pull. If verification or the pull fails, report the sync phase
failure distinctly and do not proceed to cleanup.

## Optional recorded environment cleanup

Only after successful synchronization and when the delivery environment is no
longer needed, consider the runtime-recorded delivery environments associated
with this PR. For a shared PR, sync once, then consider each recorded worktree
and workspace separately. Never discover or substitute a target.

Before asking, verify that the recorded Herdr workspace ID, path, and branch
identify the same existing worktree, and require that worktree to remain on its
recorded branch and be clean. Missing, dirty, or mismatched targets, or any
failed prerequisite, mean skip and report; never force removal or remove the
reference checkout.

For each eligible target, state its exact branch, path, and workspace ID, and
explain that Yes removes that worktree and Herdr workspace and then attempts
safe local branch deletion. Ask for explicit Yes/No consent. Silence,
ambiguity, or No is not consent and leaves that target intact.

Only after an explicit Yes, remove the exact workspace without force:

```sh
herdr worktree remove --workspace <recorded-workspace-id>
```

If removal fails, report it and do not attempt branch deletion. After successful
removal, safely delete only the recorded local branch from the recorded
reference checkout:

```sh
git -C <recorded-reference-checkout> branch -d <recorded-branch>
```

Report worktree/workspace removal and branch deletion separately. Never delete
a remote branch. If no eligible Herdr workspace identity was recorded, skip
combined cleanup and report that no eligible target was available.