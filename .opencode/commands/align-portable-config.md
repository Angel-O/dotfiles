---
description: Review and selectively align managed OpenCode config from live content
agent: orchestrator
---

Review the managed OpenCode configuration in the current repository and selectively align it from the live machine. This is a read-only assessment until a user confirms a non-empty selection.

## Assess

1. Compare the managed source/rendering pairs exactly, including formatting, comments, key ordering, and other content differences that can cause configuration-application drift:
   - source: `dot_config/opencode/portable.jsonc.tmpl` and `dot_config/opencode/cli.json.tmpl` (render them for the current machine when needed);
   - live: `~/.config/opencode/portable.jsonc` and `~/.config/opencode/cli.json`.
2. Exclude only secrets, authentication, and provider-local content as genuinely ineligible for portable source. Do not open, compare, or reconcile unmanaged `~/.config/opencode/opencode.jsonc`.
3. Assign stable numeric row IDs for this run, then render every eligible content discrepancy as a numbered Markdown table with the ID, managed surface/path, managed content, live content, and a concise difference. Keep those IDs unchanged while selecting and confirming; do not invent IDs or silently omit a discrepancy.

## Select

Make one `question` tool call containing exactly these two questions, in this order:

1. `mode`: choose exactly one of `all`, `none`, `inclusions`, or `exclusions`.
2. `row IDs`: enter the numeric IDs immediately in this same questionnaire; accept a comma- or space-separated list, and leave it blank for `all` or `none`.

Validate the mode and every ID against the rows from this run. Reject blank or malformed IDs where IDs are required, duplicates, out-of-range IDs, and IDs for ineligible rows; do not guess, coerce, or silently drop input. If validation fails, re-prompt with the same two-question questionnaire until the input is valid or cancelled.

Resolve deterministically: `all` selects every eligible row; `none` selects none; `inclusions` selects only the listed rows; `exclusions` selects every eligible row except the listed rows. A resulting empty selection is not work. Display the selected row IDs and their discrepancy table before proceeding. If the questionnaire is cancelled, or the selection is `none` or empty, report that no alignment was selected and launch no worker.

## Confirm and delegate

For a non-empty selection, ask a separate explicit confirmation question after displaying it. Do not combine confirmation with the selection questionnaire. On cancellation or any answer other than an explicit affirmative, report that no alignment was selected and launch no worker.

Only after explicit confirmation, load the `herdr` skill and launch the managed worker using the existing convention:

```text
~/.local/bin/herdr-agent-launch worker tab worker <absolute-delivery-worktree-path>
herdr agent prompt worker "<bounded alignment contract>" --wait
```

Pass the selected table rows as the worker's only evidence. The worker contract must say: import only the selected eligible live content into the matching portable source (`portable.jsonc.tmpl` or `cli.json.tmpl`); preserve the managed/unmanaged boundary; never edit live configuration; never read or use `opencode.jsonc`; never install this project-local command; never change separate agent, plugin, launcher, dependency, or other setup files, secrets, authentication, provider-local data, or unselected rows; modify no file outside the two matching managed config templates, and do not reject a selected discrepancy in those templates merely because its setting concerns an agent or plugin; and stop and report ambiguity instead of guessing. The worker must make no change before this confirmation and must report its changed files and validation results.
