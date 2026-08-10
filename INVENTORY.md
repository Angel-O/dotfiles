# Configuration Inventory

Inventory date: 2026-08-09.

This is a snapshot of the currently verified personal-machine setup. The treatment and scope columns incorporate the completed inventory questionnaire.

## Ghostty

| Artifact | Current location or source | Verified state | Approved treatment | Scope | Notes |
| --- | --- | --- | --- | --- | --- |
| Live macOS configuration | `~/Library/Application Support/com.mitchellh.ghostty/config` | Active | Track (approved) | Shared | Authoritative Ghostty configuration on this Mac |
| Theme selection | Live configuration | `TokyoNight` for dark mode and `TokyoNight Day` for light mode | Track with live config | Shared | Themes are bundled with Ghostty |
| Font selection | Live configuration | Hack Regular, size 14 | Track setting; install font cask | Shared | Font files must not be committed |
| Window behavior | Live configuration | Start maximized outside fullscreen; padded-notch manual fullscreen | Track with live config | Shared/macOS | Uses `fullscreen`, `macos-non-native-fullscreen`, and `maximize` |
| Stale configuration | `~/.config/ghostty/config` | Not authoritative on this Mac | Remove later (approved) | Obsolete | Remove in a separate cleanup after confirming Ghostty remains unaffected |
| Stale Cyberdream theme | `~/.config/ghostty/themes/cyberdream` | Not active | Remove later (approved) | Obsolete | Remove with the stale Ghostty configuration in a separate cleanup |
| Configuration backups | Beside the live macOS configuration | Historical snapshots | Exclude (approved) | Runtime | Local retention or cleanup is outside chezmoi |
| Ghostty application | Homebrew cask | Version 1.3.1 observed | Install Homebrew stable if missing | Shared/macOS | Do not commit or pin the application binary |

## Herdr Core

| Artifact | Current location or source | Verified state | Approved treatment | Scope | Notes |
| --- | --- | --- | --- | --- | --- |
| Main configuration | `~/.config/herdr/config.toml` | Active | Shared template | Shared with machine values | Share UI, theme, keybindings, and plugin actions; template paths and optional plugin bindings |
| Reviewr tab helper | `~/.config/herdr/reviewr-toggle-tab.sh` | Active executable | Track | Shared | Absolute home path in Herdr config must become portable |
| Reviewr configuration | Plugin config directory | Active | Shared template | Shared plus one personal key | Share all current settings except `file_markdown_renderer`, which is personal-only |
| Space usage configuration | Plugin config directory | Active | Track | Shared | Share sidebar mode, interval, and window-title totals |
| Herdr Bar configuration | Plugin config directory | Active | Track | Shared | Share `preview = false` |
| File viewer configuration | Plugin config directory | Mostly upstream example comments plus four active settings | Track concise active settings | Personal optional feature | Omit plugin, config, and dependencies at work initially |
| Plugin registry | `~/.config/herdr/plugins.json` | Generated | Regenerate and exclude | Runtime | Contains machine paths and installation timestamps |
| Downloaded GitHub plugins | `~/.config/herdr/plugins/github/` | Generated checkouts/builds | Regenerate and exclude | Runtime | Reinstall from pinned declarations |
| Plugin lock file | `~/.config/herdr/.plugins.lock` | Empty | Ignore | Runtime | Not currently useful as a portable declaration |
| Sessions and histories | `~/.config/herdr/sessions/`, `session*.json` | Runtime state | Exclude | Runtime/private | May reveal projects and activity |
| Logs | `~/.config/herdr/*.log` and session logs | Runtime state | Exclude | Runtime/private | Do not synchronize |
| Backups and release notes | Herdr config directory | Generated/historical | Exclude | Runtime | Do not synchronize |
| Herdr executable | `~/.local/bin/herdr` | Version 0.8.0 observed, local ARM64 binary | Official stable installer if missing | Shared/macOS | Installation must be idempotent; do not copy the binary |

## Herdr GitHub Plugins

| Plugin ID | Observed version | Installed reference | Enabled | Approved treatment |
| --- | --- | --- | --- |
| `angel-o.agent-resume` | 0.1.0 | Resolved commit `0485314f` | Yes | Install pinned, shared |
| `angel-o.labels` | 0.2.4 | Tag `v0.2.4` | Yes | Install pinned, shared, including Zsh hook |
| `beyondlex.herdr-recent-navigator` | 0.6.2 | Resolved commit `79cd2fea` | Yes | Install pinned, shared |
| `ez-corp.space-usage` | 1.9.0 | Commit `edfa3644` | Yes | Install pinned, shared |
| `herdr-bar` | 0.2.1 | Commit `01cc0620` | Yes | Install pinned, shared |
| `herdr-file-viewer` | 1.15.0 | Tag `v1.15.0` | Yes | Install pinned, personal optional feature |
| `herdr-logbook` | 0.0.8 | Tag `v0.0.8` | Yes | Install pinned, personal-only; keep data local |
| `robert-flo.elio` | 0.1.0 | Commit `851a05c6` | Yes | Install pinned, personal-only |

The final plugin manifest will need exact `owner/repository` values. Public upstream identifiers are not considered credentials, but they should be confirmed before implementation.

## Herdr Machine-Specific Plugin Installation

| Plugin ID | Observed version | Current personal source | Approved treatment |
| --- | --- | --- | --- |
| `persiyanov.reviewr` | 0.29.0 | Permanent local source checkout | Keep local link personally; install pinned GitHub release at work |

Elio changed during the review from a temporary local link to a GitHub-installed plugin. The Herdr plugin remains distinct from the Homebrew-installed `elio` executable and both are personal-only.

## OpenCode Core

| Artifact | Current location or source | Verified state | Approved treatment | Scope | Notes |
| --- | --- | --- | --- | --- | --- |
| Existing global configuration | `~/.config/opencode/opencode.jsonc` | Active | Leave unmanaged | Local superset | Private work provider/model settings remain authoritative and outside public source |
| Portable configuration layer | `~/.config/opencode/portable.jsonc` | Implemented in source state | Role-aware template loaded through `OPENCODE_CONFIG` | Shared plus personal additions | Work rendering omits provider/model and ordinary array-valued keys |
| TUI configuration | `~/.config/opencode/tui.jsonc` | Active | Manage personally; preserve work file | Personal/local work | Work TUI is ignored so its superset remains untouched |
| Launcher | `~/.local/bin/opencode-env` | Active executable via shell alias | Shared template plus local env | Shared with local extension | Share non-sensitive behavior; source ignored local values when needed |
| Shell alias | `~/.zshrc` | Routes `opencode` through the launcher | Track in Zsh fragment | Shared | Required for launcher behavior to take effect |
| Local environment file | Not currently established | Proposed only | Local and excluded | Secret/machine | Add only for a concrete need; mode 0600 and never commit |
| npm manifest | `~/.config/opencode/package.json` | Contains OpenCode plugin API dependency | Exclude and regenerate | Generated | Do not import initially |
| npm lock file | `~/.config/opencode/package-lock.json` | Present | Exclude and regenerate | Generated | Do not import initially |
| Installed npm tree | `~/.config/opencode/node_modules/` | Generated | Exclude | Runtime | Recreate through OpenCode/plugin installation |
| Backups | OpenCode config directory | Historical | Exclude | Runtime | May contain old provider settings |
| OpenCode application | Homebrew formula | Version 1.18.15 observed | Assume preinstalled | External prerequisite | Do not provision as part of this setup |

## OpenCode Published Plugins

| Declaration | Version state | Approved scope | Approved treatment |
| --- | --- | --- | --- |
| `@warp-dot-dev/opencode-warp@0.1.5` | Pinned | Personal-only | Install personally only |
| `opencode-openai-codex-auth` | Unpinned | Shared | Select and pin a version; authenticate locally |
| `@slkiser/opencode-quota@latest` | Floating | Shared | Replace `latest` with a pinned version |
| `opencode-handoff` | Unpinned | Shared | Select and pin a version |
| `opencode-lmstudio@1.0.0-rc.2` | Pinned | Personal-only local AI | Install LM Studio if missing personally; omit all integration at work |
| `opencode-history-search` | Unpinned | Shared | Select and pin a version; keep history databases local |

## OpenCode Local Plugins, Commands, and Skills

| Artifact | Current location | Purpose | Approved treatment | Scope |
| --- | --- | --- | --- | --- |
| `env-protection.js` | `~/.config/opencode/plugins/` | Prevent OpenCode from reading `.env` paths | Track | Shared |
| `plan-diagrams.js` | `~/.config/opencode/plugins/` | Adds ASCII diagram instructions to planning sessions | Track | Shared |
| `herdr-agent-state.js` | `~/.config/opencode/plugins/` | Reports OpenCode session state to Herdr | Regenerate through Herdr integration | Shared/generated |
| `herdr-name.md` | `~/.config/opencode/command/` | Global command for naming the active Herdr agent | Track | Shared |
| `grilling` | `~/.config/opencode/skills/` | Structured requirements/design interview workflow | Install from pinned source | Shared |
| `herdr-agent-name` | `~/.config/opencode/skills/` | Renames the current OpenCode agent in Herdr | Track | Shared |
| `demo-gif` | `~/.config/opencode/skills/` | Demo GIF and recording workflow | Exclude | Out of scope |

## OpenCode Private and Runtime State

| Artifact | Current location | Classification | Reason |
| --- | --- | --- | --- |
| Authentication | `~/.local/share/opencode/auth.json` | Local/secret | Contains credentials |
| Session database | `~/.local/share/opencode/opencode.db*` | Ignore/private | Contains conversation and session metadata |
| Logs | `~/.local/share/opencode/log/` | Ignore/private | Operational data |
| Repository metadata | `~/.local/share/opencode/repos/` | Ignore/private | May reveal local projects |
| Snapshots | `~/.local/share/opencode/snapshot/` | Ignore/private | May include source content |
| Storage | `~/.local/share/opencode/storage/` | Ignore/private | Application runtime state |
| Tool output | `~/.local/share/opencode/tool-output/` | Ignore/private | May include commands, source, and sensitive output |
| Quota state/history | OpenCode data and cache directories | Ignore/private | Account-related runtime information |
| Cache | `~/.cache/opencode/` | Ignore | Downloaded packages and transient state |

## Starship

| Artifact | Current location or source | Verified state | Approved treatment | Scope |
| --- | --- | --- | --- | --- |
| Herdr Dracula theme | `~/.config/starship/themes/herdr-dracula.toml` | Custom and currently active | Track and select | Shared |
| Tokyo Night theme | `~/.config/starship/themes/tokyo-night.toml` | Installed theme snapshot | Track as optional | Shared |
| Catppuccin Powerline theme | `~/.config/starship/themes/catppuccin-powerline.toml` | Installed theme snapshot | Track as optional | Shared |
| Active selector | `~/.config/starship/current.toml` | Symlink to Herdr Dracula | Manage symlink to Herdr Dracula | Shared |
| Theme-switching documentation | `~/.config/starship/README.md` | Current local documentation | Track | Shared |
| `stheme` function | `~/.zshrc` | Lists, generates, refreshes, and selects themes | Track in Starship shell fragment | Shared |
| Starship executable | Homebrew formula | Version 1.26.0 observed | Install Homebrew stable if missing | Shared |

## Zsh and Shell Integration

| Artifact | Current state | Approved treatment | Scope | Notes |
| --- | --- | --- | --- | --- |
| Main `.zshrc` | Approximately 380 lines and mixes shared, personal, generated, and machine-specific settings | Refactor into managed fragments | Mixed | Preserve and reconcile existing work shell config |
| Oh My Zsh | Loaded from `~/.oh-my-zsh` | Install pinned source if missing | Shared | Built-in plugins include Git and macOS |
| Homebrew path setup | Apple Silicon path | Template | macOS/architecture | Should not assume one architecture |
| Herdr Labels hook | Loads the plugin's generated shell hook | Track integration logic | Shared | Depends on Herdr plugin installation |
| Custom completion path | `~/.zsh/completions` | Track loader; regenerate completions | Shared | Herdr and Codex completions currently present |
| Zoxide initialization | Active | Install and track | Shared | Requires `zoxide` |
| FZF integration | Active with path fallback | Install and track | Shared | Required by worktree selector |
| Herdr/OpenCode aliases | Active | Track | Shared | Includes launcher-backed `opencode` alias |
| Warp alias | Active | Track conditionally | Personal-only | Follows personal-only Warp integration |
| Git worktree functions | Navigation, creation, selection, and path helpers | Shared template | Shared | Template the worktree root |
| Codex wrapper | Links project-local config with global authentication | Exclude pending separate review | Out of scope | Must not synchronize authentication files |
| Zsh editing/reload helpers | `zconfig`, `reload` | Shared template | Shared | Editor command may be templated |
| Docker platform override | Forces `linux/arm64` | Exclude | Out of scope | Leave machine behavior unmanaged |
| LM Studio variables and path | Personal localhost integration | Template and install app if missing | Personal-only local AI | No real secret may be committed |
| NVM initialization | Active | Optional Node feature | Machine-selected | Install only when selected |
| SDKMAN initialization | Active | Optional JVM feature | Machine-selected | Install only when selected |
| Antigravity path | Contains an absolute home path | Exclude | Out of scope | Do not port |
| Local bin path | Active | Track | Shared | Required by Herdr and OpenCode launchers |
| Direnv hook | Active | Exclude | Out of scope | Do not port Direnv integration |
| Starship initialization | Active | Track | Shared | Uses the managed selector symlink |
| Transient prompt | Custom lilac marker | Track | Shared | Depends on third-party Zsh plugin |
| Zsh transient prompt plugin | Git checkout under Oh My Zsh custom plugins | Commit `bdd5917f` observed | Install pinned external | Shared |

## Git

| Artifact | Current state | Approved treatment | Scope | Notes |
| --- | --- | --- | --- | --- |
| User identity | Personal identity configured globally | Manage manually; exclude | Local | Value intentionally omitted |
| Future work identity | Not inventoried on this machine | Manage manually; exclude | Work/local | Keep company details out of the repository |
| Non-worktree aliases | Checkout, logging, branches, and fetch helpers | Exclude | Out of scope | Do not port |
| Worktree aliases | Custom listing, creation, removal, and path conventions | Shared template | Shared | Workspace root must be portable |
| Global ignore | `.gitignore_global` | Track | Shared | Contains macOS, BSP, and Scala build entries |
| XDG Git ignore | `~/.config/git/ignore` | Repeats one Claude-local rule many times | Normalize to one tracked rule | Shared | Keep `**/.claude/settings.local.json` once |
| Commit template setting | Points to a missing file | Remove later and exclude | Obsolete | Broken reference must not be ported |
| VS Code editor/diff/merge tools | Configured; VS Code already present on both machines | Track | Shared | Assume VS Code preinstalled |
| Sourcetree diff/merge tools | Configured | Exclude | Out of scope | Do not port |
| TLS verification | Disabled globally | Exclude only | Local/unsafe | Must not be ported; current-machine cleanup was not selected |
| GitHub credential helper | Uses `gh` from Homebrew | Assume configured; exclude | Local | Authentication and helper setup remain machine-local |
| Coderabbit machine identifier | Present | Ignore | Machine/private | Value intentionally omitted |

## Relevant Packages and Fonts

This list intentionally includes only observed dependencies related to the environment under discussion, not every package installed on the machine.

| Package or capability | Observed installation | Purpose | Approved treatment |
| --- | --- | --- | --- |
| Homebrew | Installed | Package manager | Assume preinstalled; never run cleanup automatically |
| Ghostty | Homebrew cask | Terminal | Install stable if missing, shared |
| OpenCode | Homebrew formula | AI coding agent | Assume preinstalled |
| Herdr | Local executable | Terminal multiplexer/agent workspace | Official stable installer if missing, shared |
| Starship | Homebrew formula | Prompt | Install stable if missing, shared |
| Git and GitHub CLI | Homebrew formulas | Source control and GitHub access | Assume preinstalled and configured |
| VS Code | Homebrew cask or existing app | Shared Git editor/diff/merge tool | Assume preinstalled |
| Hack font | Homebrew cask | Active Ghostty font | Install shared |
| Geist Mono font | Homebrew cask | Available unused font | Exclude |
| JetBrains Mono font | Homebrew cask | Desired available font | Install shared |
| Monaspace font | Homebrew cask | Available unused font | Exclude |
| FZF | Homebrew formula | Shell and worktree selector | Install shared |
| Zoxide | Homebrew formula | Shell navigation | Install shared |
| Direnv | Homebrew formula | Project-local environments | Exclude |
| Bat, Git Delta, and Glow | Homebrew formulas | Personal Herdr renderers | Install only with corresponding personal plugin settings |
| jq | Homebrew formula or transitive install | Herdr helper scripts | Install explicitly, shared |
| Elio | Homebrew formula | Personal terminal file explorer | Install personal-only with pinned Herdr plugin |
| Cargo/Rust | Rust toolchain, Cargo 1.97.1 observed | Builds selected Herdr plugins | Install only when a selected plugin requires a local build |
| Node.js/npm and NVM | Mixed toolchain installation | Optional Node development | Manage only when optional Node feature is selected |
| SDKMAN | User-managed installation | Optional JVM development | Manage only when optional JVM feature is selected |
| Oh My Zsh | User-managed Git checkout | Zsh framework | Install shared from pinned source if missing |
| LM Studio | Homebrew cask | Personal local AI | Install if missing personally; exclude at work |

## Known Inventory Risks

| Risk | Consequence | Required action |
| --- | --- | --- |
| Some files are generated but stored beside authored configuration | Accidental publication of paths or runtime data | Classify before importing directories |
| Several plugins use floating or implicit versions | Restoration may produce different behavior | Resolve and pin versions during implementation |
| Work machine already has configuration | Applying complete files could erase useful work settings | Merge once and prefer includes/fragments afterward |
| Absolute paths appear in several configurations | Restored setup would depend on one username or directory layout | Template or replace with `$HOME`/`~` where supported |
| A public repository is planned | Credentials or internal identifiers could leak | Secret scan and manual review before every publication |
| Existing Git configuration disables TLS verification | Security exposure | Do not port; current-machine cleanup remains outside scope |
