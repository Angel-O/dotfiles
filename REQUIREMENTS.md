# Requirements

Status: draft for iterative review.

## Goal

Reproduce the useful parts of a highly customized Ghostty, Herdr, OpenCode, Starship, Git, and Zsh environment on another Mac quickly and predictably, without transferring private runtime state or destroying useful configuration already present on the target machine.

## Functional Requirements

| ID | Requirement | Status |
| --- | --- | --- |
| R1 | Maintain portable configuration in a chezmoi-backed Git repository | Accepted |
| R2 | Support personal and work machine contexts from one repository | Accepted |
| R3 | Support narrowly defined optional capabilities in addition to a broad machine role | Accepted |
| R4 | Restore only the explicitly selected applications, fonts, command-line dependencies, plugins, skills, commands, themes, and helper scripts | Accepted |
| R5 | Preserve target-machine configuration during initial adoption through preview and explicit reconciliation | Accepted |
| R6 | Detect local changes to managed files and present them for approval | Accepted |
| R7 | Require manual approval before importing, committing, pushing, or applying configuration changes | Accepted |
| R8 | Document every inventoried artifact with its source, scope, sensitivity, restoration method, and approved treatment | Accepted |
| R13 | Allow Ghostty, Herdr, OpenCode, Starship, Zsh, and Git modules to be initialized and applied independently | Accepted |
| R9 | Leave personal and work Git identities manually managed outside chezmoi | Accepted |
| R10 | Make a new-machine bootstrap concise while retaining safety prompts | Accepted |
| R11 | Make repeated setup runs idempotent: already-satisfied steps remain unchanged and newly enabled features are added safely | Accepted |
| R12 | Allow optional features to be enabled after initial installation without rebuilding or destabilizing the rest of the environment | Accepted |

## Safety Requirements

| ID | Requirement | Status |
| --- | --- | --- |
| S1 | Do not commit personal information, API keys, authentication files, company details, internal endpoints, machine identifiers, or secrets | Accepted |
| S2 | Do not synchronize OpenCode conversations, databases, tool output, snapshots, logs, caches, or quota history | Accepted |
| S3 | Do not synchronize Herdr sessions, histories, logs, generated plugin checkouts, or installation timestamps | Accepted |
| S4 | Do not commit font binaries when a package-manager installation is available | Accepted |
| S5 | Do not run destructive package cleanup on the work machine | Accepted |
| S6 | Do not use exact/purge directory semantics during initial adoption | Accepted |
| S7 | Run a secret scan and inspect the Git diff before publication | Accepted |
| S8 | Never disable Git TLS verification as part of the portable setup | Accepted |

## Portability Requirements

| ID | Requirement | Status |
| --- | --- | --- |
| P1 | Avoid literal usernames and absolute home paths in portable configuration | Accepted |
| P2 | Distinguish shared, work, personal, machine, secret, generated, runtime, obsolete, and undecided state | Accepted |
| P3 | Prefer declarative installation over copying downloaded source trees or compiled binaries | Accepted |
| P4 | Pin plugin and external skill versions where reproducibility matters | Accepted |
| P5 | Keep machine-local authentication in native application storage, a keychain, password manager, or ignored local file | Accepted |
| P6 | Keep configuration compatible with an already-configured work machine | Accepted |
| P7 | Treat disabling an optional feature as "stop managing or installing it," not automatic uninstallation, unless removal is explicitly requested | Accepted |

## Current Non-Goals

| Item | Reason |
| --- | --- |
| General workstation provisioning | Homebrew, Git, GitHub CLI, VS Code, and OpenCode are assumed preinstalled |
| Publishing a GitHub repository | Public safety and contents have not been reviewed |
| Committing the current documentation | A commit was not requested |
| Automatically synchronizing secrets | Credentials must remain machine-local |
| Synchronizing runtime histories | Chezmoi is not appropriate for rapidly changing private state |
| Cleaning stale Ghostty files | Approved for a later, separate cleanup rather than this setup |
| Correcting local Git TLS verification | The unsafe setting is excluded from portable config, but local cleanup was not selected |
| Mirroring every installed Homebrew package | Only relevant dependencies are in scope |
