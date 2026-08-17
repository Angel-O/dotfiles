# Design

Status: implemented in source state; not yet applied to a real home directory.

## Context Model

Each machine should have local chezmoi data describing intent rather than embedding a hostname throughout templates.

```toml
[data.machine]
role = "work"

[data.modules]
warp = false

[data.features]
nodeDevelopment = false
jvmDevelopment = false

[data.herdrPlugins]
agentResume = true
labels = true
recentNavigator = true
spaceUsage = true
bar = true
zoxide = true
elio = false
reviewr = true
```

The data file generated on each machine remains local. Public source templates may use these values, but must not contain private machine values.

## Configuration Layers

| Layer | Responsibility | Examples |
| --- | --- | --- |
| Shared | Portable behavior used by selected modules | Themes, aliases, keybindings, Git worktree helpers |
| Module | Independently selected tool configuration | Ghostty, Warp, Herdr, OpenCode, Starship, Zsh, Git |
| Role | Broad personal/work differences | Personal-only local AI; Reviewr source policy |
| Feature | Independently enabled optional capabilities | Node development and JVM development |
| Plugin | Machine-local Herdr selections | Agent Resume, Labels, Recent Navigator, Space Usage, Bar, Zoxide, Elio, Reviewr |
| Machine | Device-specific paths or architecture | Workspace root, ARM64 package behavior |
| Local secret | Values never stored in Git | Credentials, company endpoints, API keys |
| Runtime | Application-owned mutable state | Sessions, logs, caches, databases |

## Chezmoi Source Layout

```text
dotfiles/
├── .chezmoi.toml.tmpl
├── .chezmoiignore
├── .chezmoidata.toml
├── .chezmoiexternal.toml.tmpl
├── .chezmoitemplates/Brewfile.tmpl
├── dot_config/{ghostty,git,herdr,opencode,starship,zsh}/
├── dot_warp/modify_settings.toml
├── dot_local/bin/
├── modify_dot_{gitconfig,zshrc}
├── run_{before,after}_*.sh.tmpl
└── tests/
```

Repository documentation and tests are source-only entries excluded by `.chezmoiignore`.

## Zsh Composition

The current monolithic `.zshrc` mixes several scopes. A possible target structure is:

```text
~/.config/zsh/
├── early.zsh
├── core.zsh
├── git-worktrees.zsh
├── herdr-labels.zsh
├── herdr.zsh
├── opencode.zsh
├── starship.zsh
├── personal.zsh
├── work.zsh
└── local.zsh
```

Chezmoi preserves the work machine's existing `.zshrc` and manages two marker blocks around it. The first sources `early.zsh` before machine-owned initialization; this loads the dependency-free, latency-sensitive Herdr Labels hook only when that plugin is selected. The normal block at the end sources the remaining fragments through `portable.zsh`. `local.zsh` remains unmanaged, and role-specific fragments can be conditionally rendered or ignored.

## Git Composition

Chezmoi should manage only the approved shared Git subset: worktree aliases, global ignore rules, the normalized Claude-local ignore, and VS Code editor/diff/merge settings. Non-worktree aliases, identities, signing configuration, internal URLs, credentials, GitHub credential-helper setup, Sourcetree settings, and the local TLS override remain outside chezmoi.

## OpenCode Superset Layer

The existing global `~/.config/opencode/opencode.jsonc` remains unmanaged. The launcher sets `OPENCODE_CONFIG=~/.config/opencode/portable.jsonc`, which OpenCode merges after the global layer. Work rendering omits provider/model and ordinary array-valued settings; plugin declarations are safe because OpenCode explicitly accumulates and de-duplicates plugins across config sources.

Plan diagram guidance is loaded lazily rather than injected into every Plan message. The local Plan plugin adds a minimal instruction to load `plan-diagrams` only when drafting begins; portable permissions hide that skill globally and allow it for the built-in Plan agent on both roles. `plan-diagrams` delegates common renderer syntax, diagram selection, and terminal viewport constraints to the unrestricted `terminal-mermaid` skill so any agent can reuse that guidance when a diagram is requested.

Private work launcher values live in ignored `~/.config/opencode/env.local` and are sourced before OpenCode starts.

## Plugin Restoration

| Plugin type | Proposed mechanism |
| --- | --- |
| OpenCode published plugin | Pin in rendered OpenCode configuration where appropriate |
| OpenCode local authored plugin | Track source file directly |
| OpenCode Herdr integration | Regenerate using Herdr's integration installer |
| Herdr GitHub plugin | Idempotently install from pinned source data when selected locally |
| Reviewr on personal machine | Keep the existing local development link |
| Reviewr on work machine | Install a pinned GitHub release |
| Oh My Zsh third-party plugin | Use a pinned chezmoi external or installation script |

Generated plugin checkouts and compiled outputs should not be committed.

## Secret Boundary

The repository may contain environment variable names and examples, but never real secret values. Machine-local options include:

| Mechanism | Suitable use |
| --- | --- |
| Native application authentication | OpenCode OAuth and provider login |
| macOS Keychain or approved password manager | Long-lived secret retrieval |
| Ignored mode-0600 local environment file | Small number of machine-local variables |
| Unmanaged local project mechanism | Project-specific environment when needed |

Encrypted files in a public repository are not currently required and should not be introduced without a concrete need.

## Automation Boundary

Automation may install missing declared dependencies, detect configuration drift, render templates, and present diffs. It should not automatically import target changes, commit, push, apply remote changes, remove extra packages, or publish secrets.

## Idempotence Model

| Mechanism | Required behavior on repeated application |
| --- | --- |
| Managed files | Converge to the rendered target; make no write when content is already correct |
| Homebrew bundle | Recheck missing declarations on every apply without cleanup or implicit removal |
| Installer scripts | Run idempotent state checks on every apply so manually removed dependencies can be repaired |
| Third-party installers | Query current installation and version before installing or updating |
| Feature enablement | Add the newly enabled capability while leaving unrelated tools and configuration unchanged |
| Feature disablement | Stop rendering or installing the capability; do not uninstall it automatically |

Chezmoi supplies idempotent file convergence and state-aware script types. Package, plugin, and custom-script idempotence remains an implementation responsibility and must be validated per installer.
