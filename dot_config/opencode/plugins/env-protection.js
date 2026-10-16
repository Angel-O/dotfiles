export default {
  id: "dotfiles.env-protection",
  // OpenCode invokes setup's return value as the unload disposer.
  setup: async (context) => {
    const registration = await context.tool.hook("execute.before", async (event) => {
      if (event.tool === "read" && JSON.stringify(event.input ?? "").includes(".env")) {
        throw new Error("Do not read .env files")
      }
    })
    return () => registration.dispose()
  },
}
