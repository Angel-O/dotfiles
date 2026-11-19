---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in rounds. The **frontier** is the next decision whose prerequisites are settled. Ask exactly one frontier question per turn using OpenCode's `question` tool. Each tool call must contain exactly one question and a recommendation. Wait for the user's answer before choosing or asking the next question.

Keep all remaining questions internal. Reconsider the next question in light of each answer, recompute the frontier, and do not present a batch of remaining questions as prose.

If the `question` tool is unavailable, say so and ask exactly one plain-text question at a time, with your recommendation. Wait for the answer before asking another.

Finding _facts_ is your job, never the user's. When a question needs a fact from the environment (filesystem, tools, etc.), use the available tools or dispatch a sub-agent to find it — don't ask the user for anything you could look up yourself. Wait for required facts before asking questions that depend on them.

The session is done when the frontier is empty: every branch of the design tree has been visited, nothing remains silently assumed. Do not act on the plan until the user confirms you have reached a shared understanding.
