---
paths:
  - "setup.sh"
  - "install.sh"
  - "install-menu.sh"
  - "post-install.sh"
  - "install/**"
  - "lib/**"
  - "configs/greeter/**"
  - "script/misc/_tui.sh"
---

# The installer

## Layout and flow

| Path | Purpose |
|------|---------|
| `setup.sh` | Bootstrap: installs `git`/`paru` if missing, clones the repo, runs `install.sh` |
| `install/` | Installer sub-steps and plain-text package lists |
| `lib/` | Shared bash library (`common.sh`, `display-utils.sh`) |
| `configs/` | Dotfiles copied to `~/.config/` (and `configs/.zshrc` to `~/.zshrc`) |
| `script/` | Helpers for cliphist, the idle lock, hyprpicker, updates and screen recording; copied to `~/script` |
| `.wallpaper/` | Git submodule (`UmmItOS/wallpaper`), copied to `~/.wallpaper` |

The order matters: `setup.sh` → `install.sh` → `install/install-packages.sh` → `install/oh-my-zsh.sh` → `install/copy-config.sh` → `install/setup-dm.sh` → reboot → `post-install.sh --start-config`.

## Login screen (greetd)

`install/setup-dm.sh` replaces GDM with greetd. greetd runs `cage -s -- qs -p /usr/share/ummitos/greeter` as the `greeter` user: `configs/greeter/` (copied there with `cp -rL`; its `Theme.qml`, `MaterialIcon.qml` and `avatar.webp` are symlinks into the shell, so the look has one source). The greeter cannot read `~`, so the shell's `services/GreeterSync.qml` copies the wallpaper and accent into `/var/lib/ummitos-greeter` (owned by the user) whenever they change. Its home is `/`, so the greetd command points `XDG_*_HOME` at `/var/cache/ummitos-greeter` (owned by `greeter`, mode 700; never `/tmp`, where another account could plant compiled QML first), and sets `QT_WAYLAND_DISABLE_WINDOWDECORATION=1` because cage draws no title bars. `UMMITOS_GREETER_SESSION` swaps the session it launches, for testing a login without starting a second Hyprland. `qs -p configs/greeter` previews it in a session (no greetd, so it cannot log in).

## Package lists

Each list is plain text, one `repo/pkgname` per line, and the installer reads it into an array.

- `install/packages_main`: core desktop packages (Arch repos and AUR).
- `install/packages_gpu`: AMD only. NVIDIA is unsupported, and GPU packages are skipped when NVIDIA is detected.
- `install/packages_laptop`: `brightnessctl`, installed only when a battery is detected.

## Config copy

`install/copy-config.sh` copies with `cp -rv`, **prompts before overwriting**, and runs `chsh -s /usr/bin/zsh`.

## post-install.sh

It must run inside a Hyprland session (it calls `hyprctl`) and needs `jq`. Before editing a file, it writes a `.bak.YYYYMMDD-HHMMSS` backup. It edits these by position or pattern, so moving these lines breaks it:

- `~/.config/hypr/hyprland.lua`: the first `hl.monitor(…)` line. Keep it on one line.
- `~/.config/hypr/hyprland/env.lua`: the `hl.env("HYPRSHOT_DIR", …)` line. Keep it on one line.

## Two installer entry points, one implementation

Both call `run_installer` in `lib/install-flow.sh`: a colourful terminal checklist of steps (`step_main`, `step_gpu`, `step_laptop`, `step_omz`, `step_dots`, `step_dm`), each run in turn on the normal screen (they ask questions), then a results screen. `install-menu.sh` shows the checklist; `install.sh` passes `--all`, which skips it after one question. The screens are `script/misc/_tui.sh`, the same library `script/misc/update.sh` and `post-install.sh` use, so a change to the look is made once. A failed step skips the rest (`stop_on_fail`), since a login screen without its packages would lock you out. `install/install-packages.sh` still only runs `install_all_packages` when executed directly; the flow calls its functions. Change package handling there only.

**Test an installer with `UMMITOS_DRY_RUN=1`**: `tui_run` prints each step's name and runs nothing. `post-install.sh` has no dry run: test it with a fake `HOME` and a stub `hyprctl` first in `PATH`. Never run a real step on the machine you are working on to see what it does.
