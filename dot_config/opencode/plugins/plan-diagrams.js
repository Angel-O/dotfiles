const DIAGRAM_INSTRUCTIONS = `When producing an implementation plan, include a concise, human-readable ASCII diagram in a fenced text block.
Choose the diagram type that best explains the proposed change, such as a component, sequence, data-flow, or state diagram.
Use aligned boxes, arrows, and labels. The diagram must be visually formatted and understandable as rendered text; do not use Mermaid syntax as a substitute.`;

export const PlanDiagrams = async () => ({
  "chat.message": async ({ agent }, output) => {
    if (agent !== "plan") return;
    output.message.system = [output.message.system, DIAGRAM_INSTRUCTIONS]
      .filter(Boolean)
      .join("\n\n");
  },
});
