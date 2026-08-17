# Decision Log

This log records discussion outcomes. Proposed items remain explicitly marked and should not be treated as accepted implementation requirements.

## Accepted Decisions

| Decision | Rationale |
| --- | --- |
| Use chezmoi as the configuration manager | It supports templates, per-machine data, scripts, external resources, diffing, and merge workflows |
| Use a Git repository to transfer and review source state | Git provides history, review, rollback, and machine-to-machine synchronization |
| Design the repository to be public-safe | A public repository avoids cross-account access friction between personal and work GitHub accounts |
| Keep all secrets and personal information out of the repository | Public ciphertext or accidental credentials are unnecessary risks for this setup |
| Model personal and work context explicitly | Context is more stable and meaningful than relying only on hostname |
| Include feature flags as well as machine role | A work machine may still enable selected personal-like capabilities and vice versa |
| Preview and merge during adoption | The work machine already contains useful configuration that must not be overwritten blindly |
| Require approval before synchronization changes are committed, pushed, or applied | Automation should detect drift, not silently publish or overwrite it |
| Inventory only relevant package dependencies | A complete package dump would include unrelated software and reduce clarity |
| Keep the initial repository documentation-only | Configuration import begins only after inventory review |
| Keep workstation provisioning narrow | Provision only the core tools and dependencies explicitly selected during inventory review |
| Keep IDE metadata local and ignored | `.idea/` may remain locally but must not be tracked in the repository |

## Inventory Review Decisions

### Ghostty

| Artifact | Decision |
| --- | --- |
| XDG configuration, themes, font setting, and window behavior | Track as shared at `~/.config/ghostty/config` |
| Ghostty application | Install Homebrew stable if missing |
| Hack font | Install shared through Homebrew |
| Old macOS Application Support config | Archive once after applying XDG so it cannot override XDG settings |
| Historical config backups | Exclude from chezmoi |

### Herdr

| Artifact | Decision |
| --- | --- |
| Main config | Shared template with portable paths and conditional plugin bindings |
| Reviewr tab helper and settings | Track when Reviewr is selected; use the shared Glow renderer |
| Space Usage, Herdr Bar, Zoxide, and Reviewr settings | Track only when each plugin is selected |
| Plugin registry, downloaded trees, sessions, histories, logs, backups, and release notes | Regenerate where needed and exclude from Git |
| Herdr application | Use official stable installer when missing |
| All managed Herdr plugins | Select independently per machine and install from pinned sources when selected |
| Reviewr | Link local development checkout personally; install pinned GitHub release at work when selected |
| Elio executable | Install whenever Herdr is enabled |
| Elio GitHub plugin | Optional machine-local selection independent of the executable |

### Warp

| Artifact | Decision |
| --- | --- |
| `~/.warp/settings.toml` | Use an opt-in `warp` module and additive modifier for only `[terminal.input.extra_meta_keys]`: left Option sends Alt/Meta and right Option remains available for macOS character entry; preserve every unrelated setting |
| Warp application | Do not install or uninstall Warp; disabling the module stops configuration management without altering or deleting existing settings |

### OpenCode

| Artifact | Decision |
| --- | --- |
| Main config | Keep the existing global file unmanaged and layer role-aware `portable.jsonc` through `OPENCODE_CONFIG` |
| TUI config | Shared template following plugin scopes |
| Launcher | Shared template with optional ignored local environment file |
| npm manifest, lock file, `node_modules`, backups, cache, and runtime state | Exclude and regenerate where needed |
| OpenCode application | Assume preinstalled |
| Warp plugin | Personal-only |
| Codex Auth, Quota, Handoff, and History Search plugins | Install shared and pin versions |
| LM Studio application, plugin, and environment | Personal-only; install application if missing personally |
| Environment Protection and Plan Diagrams local plugins | Track as shared |
| Herdr state integration | Regenerate on both machines |
| Herdr Name command and Agent-Name skill | Track as shared |
| Grilling skill | Install shared from pinned source |
| Demo GIF skill | Exclude |

### Starship and Zsh

| Artifact | Decision |
| --- | --- |
| Herdr Dracula theme and active selector | Track and select as shared |
| Tokyo Night and Catppuccin Powerline themes | Track as shared optional themes |
| `stheme` and its documentation | Track as shared |
| Starship | Install Homebrew stable if missing |
| `.zshrc` | Refactor into managed fragments and reconcile existing work config |
| Oh My Zsh and transient-prompt plugin | Install shared from pinned sources |
| Zoxide and FZF | Install and configure as shared |
| Direnv and Antigravity PATH | Exclude |
| Herdr/OpenCode aliases | Track as shared |
| Warp alias | Personal-only |
| Git worktree shell functions | Shared template with portable root |
| Codex auth-link wrapper | Exclude pending separate review |
| Zsh edit/reload helpers | Shared template |
| Docker platform override | Exclude |
| NVM and SDKMAN | Optional Node and JVM features respectively |
| Herdr completions | Regenerate when Herdr and shell modules are enabled |

### Git, Packages, and Fonts

| Artifact | Decision |
| --- | --- |
| Git identities | Manage manually outside chezmoi |
| Non-worktree Git aliases | Exclude |
| Git worktree aliases | Track as shared template |
| Global ignore | Track as shared |
| Repeated Claude-local ignore | Normalize to one shared rule |
| Missing commit-template reference | Remove later and exclude |
| VS Code editor/diff/merge configuration | Track as shared; assume VS Code preinstalled |
| Sourcetree configuration | Exclude |
| Disabled TLS verification | Exclude only; do not port |
| GitHub credential helper | Assume already configured and exclude |
| Homebrew, Git, GitHub CLI, VS Code, and OpenCode | Assume preinstalled |
| JetBrains Mono | Install shared |
| Geist Mono and Monaspace | Exclude |
| Glow | Install when Reviewr is selected |
| jq | Install explicitly as shared dependency |
| Rust/Cargo | Install only when a selected plugin requires a local build |

## Verified Corrections

| Correction | Consequence |
| --- | --- |
| Ghostty reads XDG first and macOS Application Support later | Manage XDG and use a one-time post-apply migration to archive the old file outside recognized config filenames |
| Ghostty uses Tokyo Night themes and Hack, not the stale Cyberdream/JetBrains configuration | Font and theme restoration must follow the live file |
| The Herdr Elio adapter was initially linked from a temporary checkout | It is now a pinned, optional machine-local plugin independent of the shared `elio` executable |
| The Herdr Reviewr plugin is locally linked from a permanent source checkout | Restoration needs either clone-and-link or GitHub installation |

## Accepted Implementation Directions

| Decision | Reason |
| --- | --- |
| Use `personal` and `work` as machine roles | Provides a clear initial distinction |
| Add narrowly defined feature flags and plugin selections | Avoids vague tagging while supporting Node, JVM, and machine-local Herdr choices |
| Split Zsh into managed fragments | Shared fragments can coexist with existing work configuration |
| Split Git configuration into shared and context-specific includes | Identities and company settings remain local |
| Pin third-party plugin versions | Enables deterministic restoration |
| Use an ignored `~/.config/opencode/env.local` for machine-local environment values | Keeps the tracked launcher public-safe |
| Use Homebrew for applications, formulas, and redistributable fonts where possible | Avoids committing binaries |
| Use notification-only automatic drift detection | Provides awareness without unattended mutation |
| Make setup and later feature enablement idempotent and additive | Rerunning setup must install newly selected capabilities without breaking existing configuration or removing unselected software |
| Allow modules to be selected independently | Ghostty, Warp, Herdr, OpenCode, Starship, Zsh, and Git can be adopted one at a time |
| Keep work plugin cleanup manual | Desired plugins are added idempotently, while private unwanted plugin names never enter public source |

## Explicitly Rejected Directions

| Direction | Reason |
| --- | --- |
| Copy all of `~/.config` | It would include unrelated, generated, private, and machine-specific state |
| Commit entire Herdr or OpenCode data directories | They contain runtime state, local paths, and potentially private content |
| Automatically apply remote changes on the work machine | It could overwrite useful local configuration |
| Automatically commit every detected local change | It could publish mistakes or sensitive values |
| Use `brew bundle cleanup` on the work machine | It could remove employer-provided or independently installed software |
| Treat the stale Cyberdream Ghostty files as live configuration | Verified live state is elsewhere |
