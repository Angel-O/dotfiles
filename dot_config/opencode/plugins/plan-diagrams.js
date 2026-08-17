const DIAGRAM_INSTRUCTIONS =
  "When and only when you are ready to draft an implementation plan, load the `plan-diagrams` skill before writing the plan.";

export const PlanDiagrams = async () => ({
  "chat.message": async ({ agent }, output) => {
    if (agent !== "plan") return;

    output.message.system = [output.message.system, DIAGRAM_INSTRUCTIONS]
      .filter(Boolean)
      .join("\n\n");
  },
});
