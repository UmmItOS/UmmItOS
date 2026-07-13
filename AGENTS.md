# AGENTS.md

## What this is

Arch Linux dotfiles + installer for a Hyprland-based desktop environment. Marketed as the "first Hong Kong Linux distribution," but the OS underneath is Arch Linux; this repo is the installer and config bundle.

- Repository: https://github.com/UmmItOS/UmmItOS
- Organization: https://github.com/UmmItOS

## Project structure

| Path | Purpose |
|------|---------|
| `setup.sh` | Bootstrap: installs `git`/`paru` if missing, clones the repo, then runs `install.sh` |
| `install.sh` | Main CLI installer entrypoint (sources sub-scripts in order) |
| `install-menu.sh` | Interactive TUI menu installer — the one most users actually run |
| `install/` | Installer sub-steps and plain-text package lists |
| `install/packages_*` | Package lists in `repo/pkgname` format, one per line |
| `lib/` | Shared bash library (`common.sh`, `display-utils.sh`) |
| `configs/` | Dotfiles copied to `~/.config/` (and `.zshrc` to `$HOME`) |
| `script/` | Helper scripts for Hyprland components; copied to `~/script` |
| `post-install.sh` | Interactive per-user config after reboot — requires a Hyprland session |
| `.wallpaper/` | Git submodule (`UmmItOS/wallpaper`) copied to `~/.wallpaper` |

## Install flow (order matters)

1. `setup.sh` → installs dependencies → clones repo → runs `install.sh`
2. `install.sh` → `install/install-packages.sh` → `install/oh-my-zsh.sh` → `install/copy-config.sh` → `install/setup-dm.sh`
3. Reboot
4. `post-install.sh --start-config` → interactive monitor/network/screenshot/user-path setup

All installer scripts assume they are run from the repo root and use relative paths such as `./install/...`.

## Critical rules

- **Arch Linux only** — scripts check `/etc/arch-release` and exit otherwise.
- **Do not run as root** — `install-menu.sh` rejects EUID 0; `install.sh` does not, but it is not meant to be run as root either.
- **`paru` is the package manager** — never call `pacman` directly in new install code. `setup.sh` installs `paru` from the AUR if it is missing.
- **Wallpapers are a git submodule** — clone with `--recursive` or run `git submodule update --init` after cloning.

## Package lists

- `install/packages_main` — core desktop packages (Arch repos + AUR).
- `install/packages_gpu` — AMD GPU packages only. NVIDIA is explicitly unsupported; the installer skips GPU packages if NVIDIA is detected.
- `install/packages_laptop` — `brightnessctl` and `playerctl`, installed only when a battery is detected.
- `install/packages_daily` — **currently unused** by either installer; exists as a manual reference list.

Lists are plain text, one `repo/pkgname` per line, and are read into arrays by the installer.

## Config copy behavior

- `install/copy-config.sh` copies `configs/*` → `~/.config/`, `script/` → `~/script`, `.wallpaper/` → `~/.wallpaper`, and `configs/.zshrc` → `~/.zshrc`.
- It uses `cp -rv` and **prompts before overwriting** existing files.
- It also sets zsh as the default shell via `chsh -s /usr/bin/zsh`.

## post-install.sh gotchas

- Must run inside a Hyprland session because it calls `hyprctl`.
- Requires `jq` to modify `waybar/config.jsonc` and parse monitor JSON.
- Modifies specific files/lines:
  - `~/.config/hypr/hyprlock.conf` — `monitor = ...`
  - `~/.config/waybar/config.jsonc` — `.network.interface`
  - `~/.config/hypr/hyprland.conf` — line 3 (`monitor=...`)
  - `~/.config/hypr/hyprland/exec.conf` — lines 3 and 7 (home-directory paths)
  - `~/.config/hypr/hyprland/env.conf` — `HYPRSHOT_DIR`
- Backups are created with `.bak.YYYYMMDD-HHMMSS` before edits.

## Scripts in `script/`

- Helper scripts for cliphist, hyprlock, swaync, swww, waybar, hyprpicker, etc.
- Use a logger pattern that writes `.log` files; check logs rather than relying only on notifications.

## Commit conventions

- [Conventional Commits](https://www.conventionalcommits.org/) are required.
- Example from `CONTRIBUTING.md`: `fix(battery-display): disable test mode in battery display script`
- PR template requires a "Tested on my system" checkbox.

## Verification

- No CI workflows, tests, lint, or typecheck — verify by reading bash scripts and, when possible, running the relevant installer step in a clean Arch environment.
