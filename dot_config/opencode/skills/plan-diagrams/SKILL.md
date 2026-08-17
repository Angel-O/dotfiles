---
name: plan-diagrams
description: Add an appropriate Mermaid diagram to the final implementation plan. Use only in Plan mode, immediately before drafting the plan.
---

# Plan Diagrams

Before drafting the implementation plan, load the `terminal-mermaid` skill for the core diagram syntax, selection, rendering, and viewport rules.

Include a concise Mermaid diagram that explains the proposed change. Default to a `sequenceDiagram` because implementation plans usually describe data flow and ordered interactions between components.

Use another supported category instead, or in addition, only when the user explicitly requests it. Always honor a user-requested diagram category.
