---
name: herdr-agent-name
description: Rename the current OpenCode agent in Herdr. Use when the user asks to name or rename this agent, including through the /herdr-name command.
---

# Herdr Agent Name

Use the bundled `scripts/herdr-agent-name` executable relative to this skill's base directory. Pass the requested name as its only argument and do not call `herdr agent rename` directly.

The script validates the name, verifies that the session is managed by Herdr, and targets the current pane through `HERDR_PANE_ID`. Report the assigned name or the script's error concisely.
