# Portable Development Environment

This repository makes a customized macOS terminal and AI-assisted development environment reproducible with chezmoi.

The source state is modular: Ghostty, Warp, Herdr, OpenCode, Starship, Zsh, Git, and Beads can be enabled independently. Personal/work role data and module choices live only in each machine's local chezmoi configuration.

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
| `warp` | Configuration-only Option/Meta policy; does not install Warp |
| `herdr` | Herdr core, shared config, and machine-selected pinned plugins |
| `opencode` | Portable config layer, launcher, local plugins, commands, and skills; does not install the OpenCode executable |
| `starship` | Starship, themes, selector, and `stheme` support |
| `shell` | Zsh fragments, Oh My Zsh, FZF, Zoxide, and cross-tool hooks |
| `git` | Non-destructive portable include, worktree aliases, and ignore rules |
| `beads` | Optional private global task store and `wbd`/`wbv` wrappers on either role |

The `opencode` module installs shared local plugins for environment protection and Plan-mode diagrams. Plan-mode instructions request compact Mermaid source, and the pinned `opencode-mermaid-renderer` published plugin renders it for terminal chat on both personal and work machines. OpenCode auto-discovers the local instruction plugin under `~/.config/opencode/plugins/`; the renderer is declared once in the managed portable configuration.

When the `warp` module is enabled, `~/.warp/settings.toml` is modified rather than tracked in full: left Option sends Alt/Meta for terminal keybindings, while right Option remains available for macOS character entry. The module does not install Warp. When disabled, chezmoi does not manage, alter, or delete existing Warp settings. Warp hot-reloads `settings.toml`; smoke-test the enabled policy by confirming `Alt+T` reaches the shell or application instead of producing `†`.

The `beads` module is optional for both personal and work roles. It installs Beads, Go, and `jq`, builds the pinned external-history `Angel-O/beads_viewer` fork as `~/.local/bin/bv`, and manages `~/.local/bin/wbd` and `~/.local/bin/wbv`. Run `wbd bootstrap` explicitly once to create the private embedded-Dolt store at `~/.local/share/beads/hub/.beads` with the default `bead` issue prefix, or run `wbd bootstrap --prefix <prefix>` for a custom prefix. Bootstrap also creates the private Viewer config at `~/.config/bv/hub.yaml` and disables Beads anonymous command metrics. The hub store supports direct dependencies across projects by stable issue ID, while `wbd` derives credential-free `ctx:` labels from each real origin-backed repository. `wbd register` records the current checkout in the private config, create and scoped-list operations register automatically, and `wbd link <bead-id> [commit]` writes a real source association to the private ledger through `bv correlate add`. Bare `wbv` prefers a `.beads` store at the current Git worktree root and otherwise launches the all-context Hub Viewer; `wbv --local` and `wbv --hub` force either mode. `wbd` is always Hub-only. Local stores are never registered with or migrated into the Hub, and agents using the global `beads-hub` skill always force `wbv --hub`; bare `wbv` remains for humans. No `.beads`, hooks, team files, or project agent guidance are added to a source repository. Disabling the module stops management and fork installation but does not uninstall packages or delete the private store, config, or ledger.

Both migration commands are repository-only and are never run by chezmoi. On a machine that already has the Hub store at `~/.local/share/beads/hub/.beads`, use the repeatable naming-only migration. It detects the persisted prefix, defaults blank input to that current prefix as a no-op, and backs up the complete Hub parent plus `~/.config/bv/hub.yaml` before a change. Run the same command again for any future prefix change:

```sh
source_dir="$(chezmoi source-path)"
bash "$source_dir/scripts/migrate-beads-hub-prefix.sh"
```

On a machine that still has the legacy `~/.local/share/beads/work` store and no Hub destination, use the one-time path migration instead. It prompts for the store-wide prefix applied to every Beads ID in the new Hub, defaults blank input to `bead`, preserves repository registrations, and creates its legacy-layout backup before mutation. After this path migration, use `migrate-beads-hub-prefix.sh` for later naming changes; do not rerun the one-time work-to-Hub script:

```sh
source_dir="$(chezmoi source-path)"
bash "$source_dir/scripts/migrate-beads-work-to-hub.sh"
```

## Integrations

| Integration | Scope |
| --- | --- |
| `opencodeBeads` | OpenCode-only `beads-hub` skill and marker-managed user `~/.config/opencode/AGENTS.md` guidance |

The `opencodeBeads` integration is offered after enabling `beads` on either role and defaults to enabled. It assumes the OpenCode executable is already available, whether installed externally or accompanied by the separate `opencode` configuration module. Enabling both is supported: the module owns the portable OpenCode configuration and launcher, while the integration owns only the `beads-hub` skill and its `portable-beads-hub` marked user guidance. Applying this transition replaces the former `work-beads` skill and marker block. With an external OpenCode installation, no general OpenCode configuration or launcher is managed. Disabling the integration stops managing the skill and removes only its own current or legacy AGENTS marker block; unrelated OpenCode files and user guidance remain untouched. Future agent adapters, such as `codexBeads`, should follow the same independent integration pattern rather than becoming Beads module or package-installation concerns.

## Safe Validation

The primary integration test runs entirely inside Docker:

```sh
bash tests/run-docker.sh
```

It renders synthetic personal, work, Ghostty-only, Warp-only, plugin-disabled Herdr, externally managed OpenCode with `opencodeBeads`, disabled-adapter, and legacy pre-integrations homes; verifies work-owned superset files survive; validates templates and syntax; applies twice; tests Beads wrappers with fake Git/`bd`/`bv` commands and temporary state; and scans public source for known private identifiers. It does not test macOS GUI behavior or execute network package/plugin/fork installers, real Beads initialization, or the Viewer.

Pull requests and pushes to `main` run the same command on GitHub's standard hosted `ubuntu-24.04` x64 runner. Docker supplies the matching `TARGETARCH` to the Alpine test image, so CI downloads chezmoi's amd64 musl build while local Apple Silicon runs continue to use arm64. Standard GitHub-hosted runners require no additional service and are free for public repositories; private repositories consume the owner's plan allowance and may be billed after its included Actions minutes are exhausted. See GitHub's [hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) and [Actions billing documentation](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions).

## Dependency Updates

The hosted [Mend Renovate GitHub App](https://github.com/apps/renovate) manages Herdr plugin refs in `.chezmoidata.toml`. If the app is not enabled, install it for this GitHub account and grant it access to this repository; no self-hosted workflow is required.

Renovate opens one grouped `Herdr plugins` PR when updates are available. Release-tag pins follow newer GitHub tags, while commit pins follow each repository's default branch. These PRs are not automerged and should pass the Docker validation before review and merge. `INVENTORY.md` intentionally records pin policy rather than duplicating exact refs.

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
