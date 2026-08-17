---
name: terminal-mermaid
description: Create compact Mermaid diagrams rendered as terminal-friendly visuals in OpenCode chat. Use when any agent needs to produce or revise a diagram.
---

# Terminal Mermaid

Create concise Mermaid diagrams that `opencode-mermaid-renderer` can visualize in the chat.

Use only supported diagram categories:

- Flowcharts: `graph TD`, `graph LR`, `graph BT`, or `graph RL`
- State diagrams: `stateDiagram-v2`
- Sequence diagrams: `sequenceDiagram`
- Class diagrams: `classDiagram`
- ER diagrams: `erDiagram`

Choose the category that best matches the information:

- Use a sequence diagram for ordered interactions or data moving between components.
- Use a flowchart for processes, transformations, and decisions.
- Use a state diagram for lifecycle states and transitions.
- Use a class diagram for static types and structural relationships.
- Use an ER diagram for entities and data relationships.

Always emit the diagram in a fenced `mermaid` code block. Do not draw the rendered ASCII diagram yourself; `opencode-mermaid-renderer` uses the Mermaid source to visualize it in the chat.

Optimize every diagram for a terminal chat viewport:

- Prefer top-to-bottom flowcharts (`graph TD`) over horizontal layouts. Use `LR` or `RL` only for very small diagrams that clearly fit on screen.
- Keep a single diagram to at most 6 nodes or participants. Split a larger model into multiple focused diagrams.
- Keep node and edge labels short, ideally 1-3 words and never more than 20 characters. Put explanations in prose outside the diagram.
- Do not put multiline text, implementation details, type signatures, paths, or sentences inside nodes.
- Show only the relationships needed for the requested explanation; omit incidental components and repeated links.
- Before responding, mentally check the rendered dimensions. Simplify or split any diagram likely to require horizontal scrolling or become unusually tall.
