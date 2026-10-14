// V2 plugin module. OpenCode discovers this file from the local plugins
// directory; do not add it to the package plugin array.
export default {
  id: "dotfiles.env-protection",
  setup: async (context) => context.tool.hook("execute.before", async (event) => {
      if (event.tool === "read" && JSON.stringify(event.input ?? "").includes(".env")) {
        throw new Error("Do not read .env files");
      }
    }),
};
