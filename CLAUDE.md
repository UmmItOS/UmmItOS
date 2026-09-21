# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Read `AGENTS.md` first** — it is the authoritative guide to the installer side of this repo (project structure, install flow, package lists, config-copy behavior, commit conventions). This file adds the desktop-shell architecture, which `AGENTS.md` does not cover.

## What this is

Arch Linux dotfiles + bash installer for a Hyprland desktop. Two halves:

- **Installer** — bash. `setup.sh` → `install.sh` / `install-menu.sh` → `install/*.sh`.
- **Desktop shell** — `configs/quickshell/`, a ~30-file QML application (Quickshell 0.3.1). It is the bar, notifications, wallpaper, app launcher, clipboard, dashboard, session menu, OSD and Wi-Fi menu. It replaced waybar, swaync, rofi, wlogout and swww, which are gone from the repo.

## Common commands

```sh
./install-menu.sh                 # Interactive TUI installer (what most users run)
./install.sh                      # CLI installer (packages → oh-my-zsh → configs → display manager)
./post-install.sh --start-config  # Optional per-user tuning; needs a Hyprland session
shellcheck install.sh install-menu.sh post-install.sh setup.sh install/*.sh lib/*.sh script/**/*.sh

qs -c ummitos                     # Run the shell in the foreground; QML errors print here
qs -c ummitos ipc show            # List every IPC target and function
timeout 6 qs -c ummitos 2>&1 | grep -i error   # Non-interactive syntax/binding check
```

There are no tests, lint config, or CI. `shellcheck` and running the shell are the only verification.

## Working on the shell

The config is installed as a **named config directory** at `~/.config/quickshell/ummitos`, which is what `qs -c ummitos` resolves. For development, symlink it to the repo so edits hot-reload:

```sh
ln -s ~/path/to/repo/configs/quickshell ~/.config/quickshell/ummitos
```

**Verify QML APIs against the installed type definitions, not the online docs** — the docs lag the installed version, and guessing property names wastes a reload cycle:

```sh
ls /usr/lib/qt6/qml/Quickshell/            # modules: Hyprland, Io, Services/*, Wayland, Networking, Widgets
grep -A5 'name: "workspaces"' /usr/lib/qt6/qml/Quickshell/Hyprland/_Ipc/*.qmltypes
```

### Structure

Each surface is a **singleton holding state + IPC**, and a **window** that renders it. `Dashboard.qml` owns `open`/`tab`; `DashboardWindow.qml` draws it. Same split for `Launcher`, `Session`, `Notifs`, `Osd`, `Wallpapers`.

**Every singleton and shared component must be registered in `configs/quickshell/qmldir`** or it will not resolve, with no error that names the real cause.

`shell.qml` instantiates one of each window, plus `Variants` over `Quickshell.screens` for the bar.

### The design system

`Theme.qml` is the single source of truth: colour, `rounding`, `spacing`, `padding`, `fontSize`, `icon`, `duration`, `curve` (M3 bezier control points), `tracking`, `weight`, `barHeight`. **No magic numbers in surface files** — if a value is needed, add a token.

- `Surface.qml` is the material: a subtle top-edge gradient. Raised things use it.
- **There are no borders anywhere, deliberately.** Depth is elevation (`bg` → `bgAlt` → `bgTray`) and space. Do not add `border.width`.
- Accent `#5003c0` is for fills; `accentText` is the same hue lifted for text on dark.

### Keybinds reach the shell over IPC

`configs/hypr/hyprland/launcher.conf` calls `qs -c ummitos ipc call <target> <function>`. Adding a surface means adding an `IpcHandler` to its singleton.

**Do not name an IPC function `show`** — `qs ipc show` is a subcommand and the CLI claims the name before the handler sees it.

### Blur

A single Hyprland `layerrule` in `configs/hypr/hyprland/windows.conf` matches `ummitos-.*`, so any new surface gets blur for free by setting `WlrLayershell.namespace: "ummitos-<name>"`. The block syntax wants `ignore_alpha`, not the old one-line form's `ignorealpha`.

## Traps found the hard way

- **`Layout.fillWidth` is contagious.** A child that fills makes its row growable, which propagates up and ate the bar's centring spacers. `Layout.preferredWidth` on the row root cannot cap it — give the child a fixed width instead.
- **`Behavior` fires on the first assignment too.** Properties fed by async data animate up from zero on first paint. Gate the `Behavior` with a flag flipped after the first real value.
- **`RotationAnimation` leaves `rotation` where it stopped.** A spinner and a static icon must not be the same element, or the static one renders tilted.
- **Assign the committed value before clearing a preview value.** A derived `readonly property` that falls back between the two will flash the stale value for a frame.
- **List-typed QML properties are JS arrays.** `DesktopEntry.keywords` is a list; calling `.toLowerCase()` on it throws and silently empties the whole binding.
- **Anchoring an Item inside a Layout is undefined behaviour.** Use `TapHandler`/`WheelHandler`/`HoverHandler` instead of an anchored `MouseArea`.

## Hard rules (see AGENTS.md for detail)

- Arch Linux only; scripts gate on `/etc/arch-release`.
- Use `paru`, never `pacman` directly, in new install code.
- Never run/assume root — `install-menu.sh` rejects EUID 0.
- Wallpapers are a git submodule (`.wallpaper`) — clone `--recursive`.
- Installer scripts run from repo root and use relative paths (`./install/...`).
- Conventional Commits required; PRs need the "Tested on my system" checkbox.

## Two installer paths (duplicated logic)

`install.sh` **sources** `install/*.sh` in order, so sub-steps share shell state and a failure aborts everything. `install-menu.sh` only reuses `lib/` and `install/copy-config.sh` — package installation is reimplemented inline (`read_packages_from_file`, `install_packages_with_paru`, `install_{main,gpu,laptop}_package`). Changes to how packages are read or installed must be made in **both** `install/install-packages.sh` and `install-menu.sh`, or the TUI path drifts out of sync.

`copy-config.sh` steps are numbered `"n" "total"` by hand — adding a step means renumbering all of them.
