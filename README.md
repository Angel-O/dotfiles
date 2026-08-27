# Portable Development Environment

This repository makes a customized macOS terminal and AI-assisted development environment reproducible with chezmoi.

The source state is modular: Ghostty, Helix, Warp, Herdr, OpenCode, Starship, Zsh, Git, and Beads can be enabled independently. Personal/work role data and module choices live only in each machine's local chezmoi configuration.

## Documents

| Document | Purpose |
| --- | --- |
| [INVENTORY.md](INVENTORY.md) | Verified inventory and approved treatment of each artifact |
| [REQUIREMENTS.md](REQUIREMENTS.md) | Consolidated requirements and constraints |
| [DECISIONS.md](DECISIONS.md) | Decisions made so far and their rationale |
| [DESIGN.md](DESIGN.md) | Implemented repository and machine-profile design |
| [WORKFLOW.md](WORKFLOW.md) | Adoption, restoration, and synchronization workflow |
| [OPEN-QUESTIONS.md](OPEN-QUESTIONS.md) | Remaining rollout and validation questions |

## Current Phase

The modular chezmoi source and Docker integration harness are implemented, published, and validated on real source and target machines.

The inventory uses these classifications:

| Classification | Meaning |
| --- | --- |
| Track | Store the portable file directly in chezmoi |
| Template | Render machine-specific content from chezmoi data |
| Regenerate | Recreate with a package manager or native installer |
| Local | Preserve independently on each machine |
| Ignore | Do not synchronize generated or runtime state |
| Remove | Obsolete or unsafe configuration to remove separately |
| Decide | Requires an explicit decision; no reviewed inventory item should remain here |

## Modules

| Module | Scope |
| --- | --- |
| `ghostty` | XDG config, Ghostty cask, Hack, and JetBrains Mono |
| `helix` | Authored XDG configuration with the shared `dracula_at_night` theme |
| `warp` | Configuration-only Option/Meta policy; does not install Warp |
| `herdr` | Herdr core, shared config, and machine-selected pinned plugins |
| `opencode` | Portable config layer, launcher, local plugins, commands, and skills; does not install the OpenCode executable |
| `starship` | Starship, themes, selector, and `stheme` support |
| `shell` | Zsh fragments, Oh My Zsh, FZF, Zoxide, and cross-tool hooks |
| `git` | Non-destructive portable include, worktree aliases, and ignore rules |
| `beads` | Optional private global task store and Viewer-owned `wbd`/`wbv` commands on either role |

The `opencode` module installs shared local plugins for environment protection and Plan-mode diagrams. The Plan plugin adds only a late trigger: immediately before drafting a plan, the built-in Plan agent lazily loads the globally hidden `plan-diagrams` skill, which then loads the unrestricted `terminal-mermaid` skill for reusable diagram selection, syntax, rendering, and viewport guidance. The pinned `opencode-mermaid-renderer` published plugin renders the resulting compact Mermaid source in terminal chat on both personal and work machines. OpenCode auto-discovers the local trigger plugin under `~/.config/opencode/plugins/`; the renderer is declared once in the managed portable configuration.

When the `warp` module is enabled, `~/.warp/settings.toml` is modified rather than tracked in full: left Option sends Alt/Meta for terminal keybindings, while right Option remains available for macOS character entry. The module does not install Warp. When disabled, chezmoi does not manage, alter, or delete existing Warp settings. Warp hot-reloads `settings.toml`; smoke-test the enabled policy by confirming `Alt+T` reaches the shell or application instead of producing `†`.

The `beads` module is optional for both personal and work roles. It installs Go and `jq`, then builds exact, compatible commits from the `Angel-O/beads` and `Angel-O/beads_viewer` forks and atomically installs `bd`, `bv`, `wbd`, and `wbv` under `~/.local/bin`. All four builds complete before any live binary is replaced; each file is then replaced by a same-filesystem rename, and the joint revision stamp is written last so an interrupted update is retried. The Beads build uses the fork's required CGO and pure-Go regex settings and is ad-hoc signed on macOS. The Viewer checkout also supplies migration scripts installed under `~/.local/libexec/beads-viewer`, so they remain available after the temporary clones are removed. Run `wbd bootstrap` explicitly once, optionally with `--prefix <prefix>`, to create the private Hub store and Viewer configuration. `wbd` is always Hub-only; bare `wbv` is for humans, while agents use the fork-owned `beads-hub` policy and `beads-hub-closeout` workflow from the same pinned Viewer commit and explicitly select Hub mode. No `.beads`, hooks, team files, or project agent guidance are added to source repositories. Disabling the module stops future installation and management without deleting installed commands, the private store, configuration, ledger, or migration backups. Removing the Homebrew Beads declaration does not uninstall an existing formula; managed shells resolve the pinned `~/.local/bin/bd` first.

Migrations are explicit operator actions and are never run by chezmoi. For an existing Hub store, run:

```sh
~/.local/libexec/beads-viewer/migrate-beads-hub-prefix.sh
```

For the one-time migration from the legacy `~/.local/share/beads/work` layout, run:

```sh
~/.local/libexec/beads-viewer/migrate-beads-work-to-hub.sh
```

## Integrations

| Integration | Scope |
| --- | --- |
| `opencodeBeads` | OpenCode installation of the pinned fork-owned `beads-hub` and `beads-hub-closeout` skills, marker-managed user `~/.config/opencode/AGENTS.md` guidance, and the Herdr-backed `orchestrate-bead` command when Herdr is enabled |

The `opencodeBeads` integration is offered after enabling `beads` on either role and defaults to enabled. It assumes the OpenCode executable is already available, whether installed externally or accompanied by the separate `opencode` configuration module. Enabling both is supported: the module owns the portable OpenCode configuration and launcher, while the integration installs the Viewer-owned `beads-hub` and `beads-hub-closeout` skills, including the closeout validation helper, at the same commit as the binaries and owns its `portable-beads-hub` marked user guidance. When Herdr is also enabled, the integration migrates `orchestrate-bead` from the singular global `command/` directory and manages it under `commands/`. Applying this transition replaces the former `work-beads` skill and marker block. With an external OpenCode installation, no general OpenCode configuration or launcher is managed. Disabling the integration removes the installed skills, the managed command, and only its own current or legacy AGENTS marker block; unrelated OpenCode files and user guidance remain untouched. Future agent adapters, such as `codexBeads`, should follow the same independent integration pattern rather than becoming Beads module or package-installation concerns.

## Safe Validation

The primary integration test runs entirely inside Docker:

```sh
bash tests/run-docker.sh
```

It renders synthetic personal, work, Ghostty-only, Helix-only, Warp-only, plugin-disabled Herdr, externally managed OpenCode with `opencodeBeads`, disabled-adapter, and legacy pre-integrations homes; verifies work-owned superset files survive; validates templates and syntax; applies twice; checks the paired Beads/Viewer installer and pinned skill deployment; and scans public source for known private identifiers. It does not test macOS GUI behavior, execute network package/plugin/fork installers, initialize a real Beads store, or duplicate fork-owned product tests.

Pull requests and pushes to `main` run the same command on GitHub's standard hosted `ubuntu-24.04` x64 runner. Docker supplies the matching `TARGETARCH` to the Alpine test image, so CI downloads chezmoi's amd64 musl build while local Apple Silicon runs continue to use arm64. Standard GitHub-hosted runners require no additional service and are free for public repositories; private repositories consume the owner's plan allowance and may be billed after its included Actions minutes are exhausted. See GitHub's [hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) and [Actions billing documentation](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions).

## Dependency Updates

The hosted [Mend Renovate GitHub App](https://github.com/apps/renovate) manages Herdr plugin refs and both Beads runtime fork pins in `.chezmoidata.toml`. If the app is not enabled, install it for this GitHub account and grant it access to this repository; no self-hosted workflow is required.

Renovate opens one grouped `Herdr plugins` PR when plugin updates are available. Release-tag pins follow newer GitHub tags, while plugin commit pins follow their configured branches. The exact Beads and Viewer commits follow their configured feature branches and share one `Beads runtime` update group because they form a compatibility pair. Review the resulting pair, including an unchanged companion pin when only one branch advances, and merge only after Docker validation passes. Renovate PRs are not automerged. `INVENTORY.md` intentionally records pin policy rather than duplicating exact refs.

## Machine Workflows

Homebrew and chezmoi are prerequisites. Select one or more modules and offered integrations when prompted. When Herdr is enabled, select each managed plugin independently. Disabling a module, integration, or Herdr plugin selection stops future management and installation; it does not uninstall packages or live plugins.

`chezmoi init --source <path> --prompt` both regenerates the machine-local configuration and persists that checkout as the source. Run it on first setup, when changing module selections, or when chezmoi reports that the config template changed. It is not required for routine updates.

Existing personal installations must run this command once after receiving cross-role Beads support and answer the Beads prompt. During prompted initialization, both roles are always asked about Beads and, when it is enabled, the OpenCode integration; current canonical values are the prompt defaults rather than suppressing either prompt.

### Source Machine

The source machine uses the canonical checkout at `~/workspace/source/dotfiles`. For first setup or a configuration-schema change:

```sh
source_dir="$HOME/workspace/source/dotfiles"

git -C "$source_dir" pull --ff-only
bash "$source_dir/tests/run-docker.sh"

chezmoi init --source "$source_dir" --prompt
chezmoi source-path
chezmoi cat-config

"$source_dir/scripts/backup-home-paths.sh"

chezmoi diff
chezmoi apply --dry-run --verbose --no-tty --no-pager
chezmoi apply --verbose --no-tty --no-pager
chezmoi diff --exclude scripts
```

For routine source-machine updates, use the persisted source and omit `init`:

```sh
source_dir="$(chezmoi source-path)"

git -C "$source_dir" pull --ff-only
bash "$source_dir/tests/run-docker.sh"
"$source_dir/scripts/backup-home-paths.sh"

chezmoi cat-config
chezmoi diff
chezmoi apply --dry-run --verbose --no-tty --no-pager
chezmoi apply --verbose --no-tty --no-pager
chezmoi diff --exclude scripts
```

### Target Machine

On an already initialized target machine, pull the configured checkout before rendering or applying changes:

```sh
source_dir="$(chezmoi source-path)"

git -C "$source_dir" pull --ff-only
"$source_dir/scripts/backup-home-paths.sh"

chezmoi cat-config
chezmoi diff
chezmoi apply --dry-run --verbose --no-tty --no-pager
chezmoi apply --verbose --no-tty --no-pager
chezmoi diff --exclude scripts
```

If the pull introduces a changed chezmoi config template, regenerate the target's local selections after pulling and before `cat-config` or `diff`:

```sh
chezmoi init --source "$source_dir" --prompt
```

Do not pass `--no-tty` to `init --prompt`, which intentionally requires user input. Use `--no-tty` for the dry run and final apply to prevent chezmoi from acquiring an interactive terminal unexpectedly, and `--no-pager` so verbose output cannot pause invisibly in `less` waiting for input. Plain `chezmoi diff` includes recurring `run_before_*` and `run_after_*` scripts as virtual additions because they run on every apply. The final `chezmoi diff --exclude scripts` checks managed-file drift and should produce no output; run focused smoke tests afterward for affected applications, packages, and plugins. See [WORKFLOW.md](WORKFLOW.md) for backup, adoption, and reconciliation details.

## Privacy

The source is intended to be safe for a future public repository. It omits personal identities, usernames, credentials, API keys, internal endpoints, account data, and machine identifiers. OpenCode authentication, private work configuration, Herdr/OpenCode histories, caches, logs, and sessions remain unmanaged.
