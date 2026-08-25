# Workflow

Status: implemented and container-validated; real-machine adoption remains pending.

## Initial Personal-Machine Adoption

1. Run `bash tests/run-docker.sh`.
2. Initialize from the checkout without `--apply`.
3. Select only the first module to adopt.
4. Verify the rendered target with `chezmoi diff`.
5. Apply and run the module-specific macOS smoke check.
6. Enable additional modules one at a time.
7. Run a secret scan and inspect the Git diff before any publication.

Before adopting OpenCode personally, remove plugin declarations from the unmanaged global config when the same plugin is now pinned in `portable.jsonc`. Provider/model settings may remain because the personal portable layer intentionally overrides the approved shared keys.

## Pre-Apply Backup

Chezmoi does not automatically back up existing destination files. Before the first apply, list the enabled modules and back up the existing paths for each enabled module:

```sh
chezmoi execute-template '{{ range $name, $enabled := .modules }}{{ if $enabled }}{{ $name }} {{ end }}{{ end }}'
```

| Module | Existing paths to back up |
| --- | --- |
| Ghostty | `~/.config/ghostty`, plus the old `~/Library/Application Support/com.mitchellh.ghostty/config` before retiring it manually |
| Helix | `~/.config/helix` |
| Warp | `~/.warp/settings.toml` |
| Herdr | `~/.config/herdr` |
| OpenCode | `~/.config/opencode`, `~/.local/bin/opencode-env` |
| Starship | `~/.config/starship` |
| Shell | `~/.zshrc`, `~/.config/zsh`, `~/.oh-my-zsh`, `~/.zsh/completions` |
| Git | `~/.gitconfig`, `~/.gitignore_global`, `~/.config/git` |

Only existing paths need a backup. Store backups locally because Herdr and OpenCode directories may contain private machine state that must not enter this repository.

Before the Warp modifier runs, the default pre-apply backup list captures only `~/.warp/settings.toml`; it deliberately excludes other private or generated `.warp` state and safely skips the file when absent. When selected, the configuration-only Warp module modifies that settings file and manages only `left_alt = true` and `right_alt = false` under `[terminal.input.extra_meta_keys]`. It preserves unrelated content, including private agent permissions and machine-specific preferences, and creates a minimal valid file when none exists. It does not install Warp. When disabled, chezmoi ignores `.warp` completely and does not alter or delete existing settings. Warp hot-reloads `settings.toml`; after apply, press left `Option+T` and confirm `Alt+T` reaches the shell or application instead of inserting `†`, while right Option still enters macOS characters.

Ghostty loads `~/.config/ghostty/config` first, then loads the macOS Application Support config later and lets that file override conflicts. After writing the managed XDG file, a one-time chezmoi script renames the old Application Support file to `config.pre-chezmoi-<timestamp>`. This preserves its comments beside the old path while removing the recognized override. The pre-apply backup utility also captures the original file.

When receiving this first-adoption schema change on an initialized machine, regenerate the local chezmoi config before running `chezmoi diff`. The new `[data.herdrPlugins]` table is required and deliberately has no compatibility fallback:

```sh
chezmoi init --source "$(chezmoi source-path)" --prompt
```

Select every Herdr plugin explicitly. The persisted `sourceDir` keeps the existing checkout authoritative. For Ghostty adoption, complete this reinitialization, run the backup utility so both Ghostty paths are captured, and review `chezmoi diff`. The apply archives the old Application Support config after writing the managed XDG config.

The repository includes a backup utility with every path in the table as its default list. On an initialized target machine, pull the latest source without applying it, then run the utility from the chezmoi source directory:

```sh
git -C "$(chezmoi source-path)" pull --ff-only
"$(chezmoi source-path)/scripts/backup-home-paths.sh"
```

Using Git directly updates only the source checkout; it does not apply the configuration. The utility skips missing paths and prints its timestamped destination when complete, normally `~/chezmoi-backup-YYYYMMDD-HHMMSS`.

To use a different list, create a text file containing one home-relative path per line, then pass it to the script. Blank lines and lines beginning with `#` are ignored:

```sh
"$(chezmoi source-path)/scripts/backup-home-paths.sh" \
  --paths-file "$HOME/my-backup-paths.txt" \
  --destination "$HOME/my-chezmoi-backup"
```

The script skips missing paths, preserves file metadata, and refuses absolute paths or entries containing `..`. The destination must not already exist.

Review both direct file changes and script effects before applying:

```sh
chezmoi diff
chezmoi apply --dry-run --verbose --no-tty --no-pager
chezmoi apply --verbose --no-tty --no-pager
```

`--no-tty` prevents chezmoi from acquiring a terminal unexpectedly. `--no-pager` prevents verbose output from pausing in `less` while appearing to be a long-running apply. The final command applies the already-reviewed state without interactive prompts.

The apply scripts install missing Homebrew packages additively, build and atomically install the compatible pinned Beads and Viewer forks under `~/.local/bin`, install pinned shell externals under `~/.oh-my-zsh`, install or replace selected pinned Herdr plugins under `~/.config/herdr`, and generate shell completions under `~/.zsh/completions` when their modules are enabled. The optional SDKMAN installer writes under `~/.sdkman`. These script effects may not appear as ordinary managed-file diffs.

## Existing Work-Machine Adoption

Do not initialize and apply in one step. First initialize the source and select one module without modifying target files:

```sh
chezmoi init <repository> --prompt
chezmoi diff
```

Module-specific adoption rules:

| Module | Adoption rule |
| --- | --- |
| Zsh | Review the marker block added to the existing `.zshrc`; all existing Agnoster and Direnv content remains |
| Git | Review the portable include added to the existing `.gitconfig`; identity and credential settings remain unmanaged |
| Warp | Review only the Option/Meta changes in `.warp/settings.toml`; unrelated settings remain byte-preserved where practical and no application is installed |
| Herdr | Review the complete shared config diff, then remove unwanted old work plugins manually before or after applying |
| OpenCode | Keep the global config untouched, remove old/duplicate portable plugin declarations locally, migrate private launcher variables to `env.local`, and use the portable config layer |

After reconciliation:

```sh
chezmoi diff
chezmoi apply --verbose --no-tty --no-pager
```

For Zsh and Git, marker-based `modify_` scripts preserve the work-owned files and add one portable include block. OpenCode keeps its private global config and consumes the managed portable layer through `OPENCODE_CONFIG`. Plugin cleanup is manual because private plugin names must not enter public source state.

## Package Adoption

Package installation should be additive and idempotent:

| Rule | Purpose |
| --- | --- |
| Install only missing declared dependencies | Preserve existing target setup |
| Never run `brew bundle cleanup` automatically | Avoid removing work-managed software |
| Treat optional tools as features | Do not install personal tools at work by default |
| Keep native authentication local | Avoid moving account state between machines |
| Check current plugin and tool versions before installation | Make repeated setup runs safe and predictable |

## Enabling a Feature Later

Optional features must not require rebuilding the machine. The intended flow is:

1. Change the machine-local feature or Herdr plugin selection, such as enabling Node development or Reviewr.
2. Preview the newly rendered files, packages, and scripts with `chezmoi diff`.
3. Apply the target state.
4. Install only the newly missing packages and plugins.
5. Leave already-correct files and installations unchanged.
6. Run focused validation for the newly enabled feature.

Feature or plugin disablement is additive-safe by default: it stops future management or installation but does not automatically uninstall packages, uninstall live plugins, or delete local data. Removal requires a separate explicit action.

## Daily Source-First Editing

For managed files, prefer editing chezmoi source and applying immediately:

```sh
chezmoi edit --apply <target-file>
```

This keeps source and destination aligned, including for templated files.

## Daily Target-First Editing

Some applications encourage editing their live configuration. In that case:

1. Run `chezmoi diff` to inspect drift.
2. Use `chezmoi merge <target-file>` for templates or conflicting source changes.
3. Use `chezmoi re-add <target-file>` only for non-templated managed files.
4. Inspect the source repository diff.
5. Run a secret scan.
6. Commit and push manually after approval.

Chezmoi documents that `re-add` does not work with templates.

## Receiving Changes

1. Refuse automatic application when unrecorded local target changes exist.
2. Pull the source repository with fast-forward-only behavior.
3. For this first-adoption schema change, run `chezmoi init --source "$(chezmoi source-path)" --prompt` and select every Herdr plugin before rendering any templates.
4. Run `chezmoi diff`.
5. Reconcile unexpected target differences.
6. Apply only after approval.
7. Run focused smoke checks for affected tools.

Without step 3, an existing config has no `[data.herdrPlugins]` table and template rendering fails. Do not add fallback values: the selections are machine-local opt-ins/outs that require an explicit one-time decision.

## Drift Notification

A future scheduled job may detect that managed destination files differ from target state and notify the user. It must not automatically re-add, commit, push, merge, or apply changes.

## Restore Validation

| Area | Example validation |
| --- | --- |
| Ghostty | Confirm the XDG config, theme, font availability, startup behavior, and absence of a recognized overriding Application Support config |
| Helix | Open Helix and confirm the `dracula_at_night` theme loads; verify logs, caches, histories, language-server state, and generated files remain unmanaged |
| Warp | When enabled, confirm left `Option+T` reaches the shell/application instead of inserting `†`, right Option still enters macOS characters, and unrelated settings remain intact |
| Herdr | Confirm version, keybindings, plugin list, plugin configs, and OpenCode integration |
| OpenCode | Confirm version, launcher variables, global plugins, commands, and skills without copying auth |
| Starship | Confirm active symlink, theme rendering, glyphs, and `stheme` behavior |
| Git | Confirm worktree aliases, shared ignore rules, and VS Code tooling without changing manually managed identity or credentials |
| Zsh | Start a clean login shell and confirm hooks, aliases, completions, prompt, and optional features |

## New-Machine Goal

The eventual bootstrap should be concise, but it must still prompt for machine role and approved optional features. Git identity remains manually managed. A one-command install is a goal after the repository has been tested, not a reason to skip review safeguards.
