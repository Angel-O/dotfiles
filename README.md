# Portable Development Environment

This repository makes a customized macOS terminal and AI-assisted development environment reproducible with chezmoi.

The source state is modular: Ghostty, Herdr, OpenCode, Starship, Zsh, and Git can be enabled independently. Personal/work role data and module choices live only in each machine's local chezmoi configuration.

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

The modular chezmoi source and Docker integration harness are implemented. No chezmoi configuration has been applied to the real home directory, and no remote, commit, or publication has been created.

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
| `ghostty` | Live macOS config, Ghostty cask, Hack, and JetBrains Mono |
| `herdr` | Herdr core, shared config, helper, and role-aware pinned plugins |
| `opencode` | Portable config layer, launcher, local plugins, commands, and skills |
| `starship` | Starship, themes, selector, and `stheme` support |
| `shell` | Zsh fragments, Oh My Zsh, FZF, Zoxide, and cross-tool hooks |
| `git` | Non-destructive portable include, worktree aliases, and ignore rules |

## Safe Validation

The primary integration test runs entirely inside Docker:

```sh
bash tests/run-docker.sh
```

It renders synthetic personal, work, and Ghostty-only homes; verifies work-owned superset files survive; validates templates and syntax; applies twice; and scans public source for known private identifiers. It does not test macOS GUI behavior or execute package/plugin installers.

## Dependency Updates

The hosted [Mend Renovate GitHub App](https://github.com/apps/renovate) manages Herdr plugin refs in `.chezmoidata.toml`. If the app is not enabled, install it for this GitHub account and grant it access to this repository; no self-hosted workflow is required.

Renovate opens one grouped `Herdr plugins` PR when updates are available. Release-tag pins follow newer GitHub tags, while commit pins follow each repository's default branch. These PRs are not automerged and should pass the Docker validation before review and merge. `INVENTORY.md` intentionally records pin policy rather than duplicating exact refs.

## Local Initialization

Homebrew and chezmoi are prerequisites. Initialize from this checkout without applying:

```sh
chezmoi init --source "$HOME/workspace/source/dotfiles" --prompt
chezmoi diff
```

Select one or more modules when prompted. Before the first apply, follow the [pre-apply backup](WORKFLOW.md#pre-apply-backup) checklist, then review the diff:

```sh
chezmoi apply --dry-run --verbose
chezmoi apply --interactive --verbose --no-tty
```

`--no-tty` uses a line-based `yes/no/all/quit` prompt. Type the complete choice and press Enter; this avoids terminal input issues with chezmoi's interactive text widget.

To change the selected modules later:

```sh
chezmoi init --source "$HOME/workspace/source/dotfiles" --prompt
chezmoi diff
chezmoi apply
```

Disabling a module does not uninstall packages or delete previously created configuration.

## Privacy

The source is intended to be safe for a future public repository. It omits personal identities, usernames, credentials, API keys, internal endpoints, account data, and machine identifiers. OpenCode authentication, private work configuration, Herdr/OpenCode histories, caches, logs, and sessions remain unmanaged.
