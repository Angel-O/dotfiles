const DIAGRAM_INSTRUCTIONS = `When producing an implementation plan, include a concise Mermaid diagram that explains the proposed change.
Use only diagram categories supported by opencode-mermaid-renderer:
- Flowcharts: graph TD, graph LR, graph BT, or graph RL
- State diagrams: stateDiagram-v2
- Sequence diagrams: sequenceDiagram
- Class diagrams: classDiagram
- ER diagrams: erDiagram
Always emit the diagram in a fenced \`mermaid\` code block. Do not draw the rendered ASCII diagram yourself; opencode-mermaid-renderer uses the Mermaid source to visualize it in the chat.

Default to a sequenceDiagram because implementation plans usually describe data flow and ordered interactions between components. Use another supported diagram type instead, or in addition, only when the user explicitly requests it. If the user requests a diagram type, honor that request.

Optimize every diagram for a terminal chat viewport:
- Prefer top-to-bottom flowcharts (graph TD) over horizontal layouts. Use LR or RL only for very small diagrams that clearly fit on screen.
- Keep a single diagram to at most 6 nodes or participants. Split a larger model into multiple focused diagrams.
- Keep node and edge labels short, ideally 1-3 words and never more than 20 characters. Put explanations in prose outside the diagram.
- Do not put multiline text, implementation details, type signatures, paths, or sentences inside nodes.
- Show only the relationships needed to understand the plan; omit incidental components and repeated links.
- Before responding, mentally check the rendered dimensions. Simplify or split any diagram likely to require horizontal scrolling or become unusually tall.`;

export const PlanDiagrams = async () => ({
  "chat.message": async ({ agent }, output) => {
    if (agent !== "plan") return;

    output.message.system = [output.message.system, DIAGRAM_INSTRUCTIONS]
      .filter(Boolean)
      .join("\n\n");
  },
});
