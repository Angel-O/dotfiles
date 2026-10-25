---
name: add-linear-id
description: Set the current Herdr tab base and OpenCode session title to a supplied issue ID, including through /add-linear-id.
---

# Add Linear ID

Run the bundled `scripts/add-linear-id` executable with the complete supplied ID as its single argument. Do not alter the ID or set either label/title separately. The helper verifies this pane's Herdr-managed OpenCode session, renames its inherited current tab to the bare ID, and prefixes the existing session title with `<ID>: ` on every invocation. Report its result concisely.
