---
name: delivery-sync-and-cleanup
description: Safely synchronize a recorded reference checkout and optionally dispose of a completed delivery worktree and Herdr workspace.
---

# Delivery Sync and Cleanup

Run after the delivery is no longer needed and its requested endpoint is
complete. For Bead-backed work, proceed only after successful
`beads-hub-closeout`; that workflow already synchronizes the reference
checkout. Do not repeat its pull. A failed or partial Bead closeout is not
eligible for cleanup.

## Reference synchronization (non-Bead only)

Use the merged pull request as the authority for the actual base:

```sh
gh pr view <full-pr-url> --json state,mergedAt,mergeCommit,baseRefName
```

Require merged state, non-empty merge time, a 40-character merge SHA, and a
valid base branch. Use only the recorded reference checkout. Verify it is clean
and already on that exact base, fetch only the actual PR base, and verify both
the current `HEAD` and merge SHA are ancestors of `FETCH_HEAD`:

```sh
git -C <recorded-reference-checkout> status --porcelain
git -C <recorded-reference-checkout> branch --show-current
git -C <recorded-reference-checkout> fetch --no-tags origin refs/heads/<base>
git -C <recorded-reference-checkout> merge-base --is-ancestor HEAD FETCH_HEAD
git -C <recorded-reference-checkout> merge-base --is-ancestor <merge-sha> FETCH_HEAD
```

Require empty status output and an exact branch match. Recheck cleanliness,
then run exactly:

```sh
git -C <recorded-reference-checkout> pull --ff-only origin <base>
```

Do not switch branches, merge, reset, overwrite local work, retry a failed
pull, or use a guessed branch. Recheck cleanliness before the pull. Report
verification or pull failure distinctly; do not claim synchronization succeeded
or offer cleanup after a failed prerequisite.

## Optional recorded environment cleanup

Offer cleanup only when the delivery environment is no longer needed and the
recorded dedicated implementation worktree and its Herdr workspace are
eligible. State the exact recorded branch, worktree path, and workspace ID,
and explain that acceptance removes the worktree and workspace and then
attempts safe local branch deletion. Ask for an explicit Yes/No; a default,
silence, ambiguity, or No is not consent.

Before offering or acting, verify from the orchestration record and Herdr's
current worktree listing that the workspace ID, path, and branch all identify
the same target. Require the recorded worktree to exist, remain on its recorded
branch, and be clean. Missing or mismatched identities, dirty work, a missing
target, or failed prerequisites mean no cleanup; never force removal or choose
a substitute. Never remove the reference checkout.

Only after explicit Yes, use Herdr's non-forced combined removal for the exact
recorded workspace:

```sh
herdr worktree remove --workspace <recorded-workspace-id>
```

If it fails, stop and report that no branch deletion was attempted. After
successful removal, safely delete only the recorded local branch from the
recorded reference checkout:

```sh
git -C <recorded-reference-checkout> branch -d <recorded-branch>
```

Report worktree/workspace removal and branch-deletion outcomes separately.
Never delete a remote branch. If no Herdr workspace was recorded (including
standalone Bead closeout), do not guess one; retain the existing procedure's
standalone worktree behavior and report that combined Herdr cleanup was
unavailable.
