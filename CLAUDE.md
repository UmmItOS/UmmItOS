# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Read `AGENTS.md` first** — it is the authoritative guide to this repo (project structure, install flow, package lists, config-copy behavior, `post-install.sh` gotchas, commit conventions). This file only adds a quick orientation; do not duplicate `AGENTS.md`.

## What this is

Arch Linux dotfiles + bash installer for a Hyprland desktop environment. No build system, no application code — everything is bash scripts and config files copied into `~`.

## Common commands

```sh
./setup.sh                        # Bootstrap: deps + clone + install.sh
./install.sh                      # CLI installer (packages → oh-my-zsh → configs → display manager)
./install-menu.sh                 # Interactive TUI installer (what most users run)
./post-install.sh --start-config  # Per-user config; must run inside a Hyprland session
shellcheck install.sh install-menu.sh post-install.sh setup.sh install/*.sh lib/*.sh  # Only verification available
```

There are no tests, lint config, or CI. Verify changes by reading the scripts and running the relevant installer step in a clean Arch environment. Recent work follows the YSAP bash style guide and keeps shellcheck clean — match that.

## Hard rules (see AGENTS.md for detail)

- Arch Linux only; scripts gate on `/etc/arch-release`.
- Use `paru`, never `pacman` directly, in new install code.
- Never run/assume root — `install-menu.sh` rejects EUID 0.
- Wallpapers are a git submodule (`.wallpaper`) — clone `--recursive`.
- Installer scripts run from repo root and use relative paths (`./install/...`).
- Conventional Commits required; PRs need the "Tested on my system" checkbox.

## Shared library

`lib/common.sh` and `lib/display-utils.sh` hold reusable bash helpers — check there before writing new logging/prompt/display logic.

## Two installer paths (duplicated logic)

`install.sh` **sources** `install/*.sh` in order, so sub-steps share shell state and a failure aborts everything. `install-menu.sh` only reuses `lib/` and `install/copy-config.sh` — package installation is reimplemented inline (`read_packages_from_file`, `install_packages_with_paru`, `install_{main,gpu,laptop}_package`). Changes to how packages are read or installed must be made in **both** `install/install-packages.sh` and `install-menu.sh`, or the TUI path drifts out of sync.
