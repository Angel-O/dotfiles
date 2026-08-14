# Portable Development Environment

This repository makes a customized macOS terminal and AI-assisted development environment reproducible with chezmoi.

The source state is modular: Ghostty, Warp, Herdr, OpenCode, Starship, Zsh, and Git can be enabled independently. Personal/work role data and module choices live only in each machine's local chezmoi configuration.

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
| `opencode` | Portable config layer, launcher, local plugins, commands, and skills |
| `starship` | Starship, themes, selector, and `stheme` support |
| `shell` | Zsh fragments, Oh My Zsh, FZF, Zoxide, and cross-tool hooks |
| `git` | Non-destructive portable include, worktree aliases, and ignore rules |

When the `warp` module is enabled, `~/.warp/settings.toml` is modified rather than tracked in full: left Option sends Alt/Meta for terminal keybindings, while right Option remains available for macOS character entry. The module does not install Warp. When disabled, chezmoi does not manage, alter, or delete existing Warp settings. Warp hot-reloads `settings.toml`; smoke-test the enabled policy by confirming `Alt+T` reaches the shell or application instead of producing `†`.

## Safe Validation

The primary integration test runs entirely inside Docker:

```sh
bash tests/run-docker.sh
```

It renders synthetic personal, work, Ghostty-only, Warp-only, and plugin-disabled Herdr homes; verifies work-owned superset files survive; validates templates and syntax; applies twice; and scans public source for known private identifiers. It does not test macOS GUI behavior or execute package/plugin installers.

Pull requests and pushes to `main` run the same command on GitHub's standard hosted `ubuntu-24.04` x64 runner. Docker supplies the matching `TARGETARCH` to the Alpine test image, so CI downloads chezmoi's amd64 musl build while local Apple Silicon runs continue to use arm64. Standard GitHub-hosted runners require no additional service and are free for public repositories; private repositories consume the owner's plan allowance and may be billed after its included Actions minutes are exhausted. See GitHub's [hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) and [Actions billing documentation](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions).

## Dependency Updates

The hosted [Mend Renovate GitHub App](https://github.com/apps/renovate) manages Herdr plugin refs in `.chezmoidata.toml`. If the app is not enabled, install it for this GitHub account and grant it access to this repository; no self-hosted workflow is required.

Renovate opens one grouped `Herdr plugins` PR when updates are available. Release-tag pins follow newer GitHub tags, while commit pins follow each repository's default branch. These PRs are not automerged and should pass the Docker validation before review and merge. `INVENTORY.md` intentionally records pin policy rather than duplicating exact refs.

## Machine Workflows

Homebrew and chezmoi are prerequisites. Select one or more modules when prompted. When Herdr is enabled, select each managed plugin independently. Disabling a module or Herdr plugin selection stops future management and installation; it does not uninstall packages or live plugins.

`chezmoi init --source <path> --prompt` both regenerates the machine-local configuration and persists that checkout as the source. Run it on first setup, when changing module selections, or when chezmoi reports that the config template changed. It is not required for routine updates.

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
chezmoi apply --dry-run --verbose --no-tty
chezmoi apply --verbose --no-tty
chezmoi diff
```

For routine source-machine updates, use the persisted source and omit `init`:

```sh
source_dir="$(chezmoi source-path)"

git -C "$source_dir" pull --ff-only
bash "$source_dir/tests/run-docker.sh"
"$source_dir/scripts/backup-home-paths.sh"

chezmoi cat-config
chezmoi diff
chezmoi apply --dry-run --verbose --no-tty
chezmoi apply --verbose --no-tty
chezmoi diff
```

### Target Machine

On an already initialized target machine, pull the configured checkout before rendering or applying changes:

```sh
source_dir="$(chezmoi source-path)"

git -C "$source_dir" pull --ff-only
"$source_dir/scripts/backup-home-paths.sh"

chezmoi cat-config
chezmoi diff
chezmoi apply --dry-run --verbose --no-tty
chezmoi apply --verbose --no-tty
chezmoi diff
```

If the pull introduces a changed chezmoi config template, regenerate the target's local selections after pulling and before `cat-config` or `diff`:

```sh
chezmoi init --source "$source_dir" --prompt
```

Do not pass `--no-tty` to `init --prompt`, which intentionally requires user input. Use `--no-tty` for the dry run and final apply to prevent chezmoi from acquiring an interactive terminal unexpectedly. The final `chezmoi diff` should produce no output; run focused smoke tests afterward for affected applications, packages, and plugins. See [WORKFLOW.md](WORKFLOW.md) for backup, adoption, and reconciliation details.

## Privacy

The source is intended to be safe for a future public repository. It omits personal identities, usernames, credentials, API keys, internal endpoints, account data, and machine identifiers. OpenCode authentication, private work configuration, Herdr/OpenCode histories, caches, logs, and sessions remain unmanaged.
