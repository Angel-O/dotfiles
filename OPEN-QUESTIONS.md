# Open Questions

The source implementation is complete. These rollout and live-environment questions remain.

## macOS Smoke Tests

| Question | Current direction |
| --- | --- |
| Does Ghostty load the managed XDG path and render both themes/fonts correctly after the old Application Support config is retired? | Validate when adopting the Ghostty module |
| Do the Homebrew cask identifiers remain valid on the target Mac? | Validate with the package installer dry run before the first apply |
| Does the current OpenCode release accept the retained TUI plugin declaration? | Validate with `opencode debug config` before personal OpenCode adoption |
| Do all selected Herdr plugins build cleanly from their pinned refs on a fresh Mac? | Validate first in the personal Herdr rollout; Cargo is installed only if absent |
| Does the official Herdr installer remain compatible with the selected stable channel? | Validate only when Herdr is absent |

## Work Adoption

| Question | Current direction |
| --- | --- |
| Which existing work Herdr/OpenCode plugin declarations should be removed? | Inspect and remove manually; never record names publicly |
| Which work launcher variables must move into `env.local` before the launcher is managed? | Migrate locally before applying the OpenCode module |
| Does Starship loading after the existing Agnoster setup produce the intended prompt? | Preview and smoke-test the Shell and Starship modules together |

## Synchronization and Publication

| Question | Current direction |
| --- | --- |
| What command should provide the approval-oriented sync workflow? | Design a helper after real module adoption proves the daily workflow |
| Should drift notification use launchd or Watchman? | Start manually and automate notification only after observing real usage |
| Which merge tool should chezmoi use? | Choose an already-familiar visual or terminal merge tool |
| What additional secret scanner should gate publication? | Keep the Docker source scan and add a standard scanner before creating a remote |
| When should the repository be published? | Only after personal module adoption and an explicit publication request |
