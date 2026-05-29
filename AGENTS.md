# AGENTS.md

## What this is

Arch Linux dotfiles + installer for a Hyprland-based desktop environment. The "first Hong Kong Linux distribution." This repo is the installer and config bundle; the actual OS is Arch Linux underneath.

## Project structure

| Path | Purpose |
|------|---------|
| `install.sh` | Main installer entrypoint (Arch Linux only) |
| `install-menu.sh` | Interactive menu-driven TUI installer (the one users typically run) |
| `install/` | Installer sub-steps: package files, oh-my-zsh, copy-config, setup-dm |
| `install/packages_*` | Plain-text package lists (one package per line, `repo/pkgname` format) |
| `lib/` | Shared bash library (`common.sh`, `display-utils.sh`) |
| `configs/` | Dotfiles (hypr, kitty, waybar, rofi, swaync, wlogout, etc.) copied to `~/.config/` |
| `script/` | Helper scripts for Hyprland components (cliphist, hyprlock, hyprpicker, waybar, etc.) |
| `post-install.sh` | Interactive post-install config (hyprlock monitor, waybar network, etc.) — needs Hyprland session |
| `setup.sh` | Bootstrap script that clones repo then runs install |
| `.wallpaper/` | Git submodule (`UmmItOS/wallpaper`) |

## Install flow (order matters)

1. **setup.sh** → clones repo → prompts to run install
2. **install.sh** → install-packages → oh-my-zsh → copy-config → setup-dm
3. **post-install.sh --start-config** → interactive per-user config (manual step after reboot)

## Critical rules

- **Arch Linux only** — checks `/etc/arch-release`
- **Must NOT run as root** — `install-menu.sh` rejects EUID 0
- **`paru` is the package manager** — not pacman directly (paru is installed by setup.sh if missing)
- **Wallpapers are a git submodule** — clone with `--recursive` or `git submodule update --init`

## Commit conventions

- [Conventional Commits](https://www.conventionalcommits.org/) required
- Examples from CONTRIBUTING.md: `fix(battery-display): disable test mode in battery display script`
- PR template requires "Tested on my system" checkbox

## Common gotchas

- post-install.sh needs `hyprctl` → must run inside a Hyprland session
- Scripts in `script/` use a logger pattern (writes `.log` files) alongside notifications
- Package lists are plain text files sourced by the installer, not managed by any package manager natively
- No CI, no tests, no lint, no typecheck — verify changes by running the installer or checking scripts manually
- `VERSION` at repo root tracks MAJOR.MINOR.PATCH (current: v0.7.0)
