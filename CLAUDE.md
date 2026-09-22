# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

UmmItOS is Arch Linux plus Hyprland, shipped as a bash installer and a dotfiles bundle. It is billed as the "first Hong Kong Linux distribution", but the OS underneath is Arch; this repo is the installer and the config bundle ([UmmItOS/UmmItOS](https://github.com/UmmItOS/UmmItOS)). It has two halves:

- **Installer** (bash): `setup.sh` → `install.sh` / `install-menu.sh` → `install/*.sh`, with shared helpers in `lib/common.sh` (`is_laptop`, `has_amdgpu`, `enable_bluetooth`, `prompt_yna`, `backup_file`, and so on).
- **Desktop shell**: `configs/quickshell/`, a QML application for Quickshell 0.3.1. It provides the bar, notification toasts and centre, wallpaper and picker, launcher and clipboard, dashboard, session menu, volume/brightness OSD, and the Wi-Fi, Bluetooth and audio flyouts. It also includes an Alt+Tab switcher. It replaces waybar, swaync, rofi, wlogout and swww. hyprlock and hypridle remain (`configs/hypr/`).

## Commands

```sh
./install-menu.sh                 # TUI installer (what most users run)
./install.sh                      # CLI installer: packages → oh-my-zsh → configs → display manager
./post-install.sh --start-config  # Per-user tuning after reboot; needs a Hyprland session + jq
shellcheck install.sh install-menu.sh post-install.sh setup.sh install/*.sh lib/*.sh script/**/*.sh

qs -c ummitos -d                  # Run the shell daemonised (exec.conf starts it at login)
qs -c ummitos ipc show            # List every IPC target and function
qs -c ummitos ipc call <target> <fn>
qs log read /run/user/$UID/quickshell/by-id/*/log.qslog   # Errors from the running instance
```

There are no tests, no lint config and no CI. Verification means running `shellcheck` and running the shell, then reading its log and taking screenshots (`grim`).

**Never start a second `qs -c ummitos` while one is running**, not even with `timeout` as a syntax check. When it exits, it takes the running instance down with it. To check something in isolation, symlink the config under a different name (`~/.config/quickshell/ummitos-test`) or run a standalone file with `qs -p file.qml`, and remove it afterwards.

## The installer

### Layout and flow

| Path | Purpose |
|------|---------|
| `setup.sh` | Bootstrap: installs `git`/`paru` if missing, clones the repo, runs `install.sh` |
| `install/` | Installer sub-steps and plain-text package lists |
| `lib/` | Shared bash library (`common.sh`, `display-utils.sh`) |
| `configs/` | Dotfiles copied to `~/.config/` (and `configs/.zshrc` to `~/.zshrc`) |
| `script/` | Helpers for cliphist, hyprlock, hyprpicker, updates and screen recording; copied to `~/script` |
| `.wallpaper/` | Git submodule (`UmmItOS/wallpaper`), copied to `~/.wallpaper` |

The order matters: `setup.sh` → `install.sh` → `install/install-packages.sh` → `install/oh-my-zsh.sh` → `install/copy-config.sh` → `install/setup-dm.sh` → reboot → `post-install.sh --start-config`.

### Package lists

Each list is plain text, one `repo/pkgname` per line, and the installer reads it into an array.

- `install/packages_main`: core desktop packages (Arch repos and AUR).
- `install/packages_gpu`: AMD only. NVIDIA is unsupported, and GPU packages are skipped when NVIDIA is detected.
- `install/packages_laptop`: `brightnessctl` and `playerctl`, installed only when a battery is detected.

### Config copy

`install/copy-config.sh` copies with `cp -rv`, **prompts before overwriting**, and runs `chsh -s /usr/bin/zsh`.

### post-install.sh

It must run inside a Hyprland session (it calls `hyprctl`) and needs `jq`. Before editing a file, it writes a `.bak.YYYYMMDD-HHMMSS` backup. It edits these by position or pattern, so moving these lines breaks it:

- `~/.config/hypr/hyprlock.conf`: the `monitor = …` line.
- `~/.config/hypr/hyprland.conf`: **line 3** (`monitor=…`).
- `~/.config/hypr/hyprland/env.conf`: `env = HYPRSHOT_DIR, …`.

### Two installer entry points, one implementation

`install.sh` **sources** `install/*.sh` in order, so the sub-steps share shell state and one failure aborts the whole run. `install/install-packages.sh` only runs `install_all_packages` when executed directly; `install.sh` calls it after sourcing. `install-menu.sh` sources the same file and calls `install_{main,gpu,laptop}_packages` per menu entry, and runs `install/copy-config.sh` and `install/setup-dm.sh` as child scripts. Change package handling in `install-packages.sh` only; do not copy it into the menu again.

Keybinds carry their own descriptions (`bindd`, `bindeld`, …), and `script/hotkey-tui.sh` lists them from `hyprctl binds`. A new bind without a description is missing from the cheatsheet. Descriptions cannot contain commas.

## The shell

### Development loop

`qs -c ummitos` resolves `~/.config/quickshell/ummitos`. Symlink that path to `configs/quickshell` so edits hot-reload into the running instance, then read the log after each save.

Check QML APIs against the installed type definitions, not the online docs, which lag behind 0.3.1:

```sh
ls /usr/lib/qt6/qml/Quickshell/     # Hyprland, Io, Services/*, Wayland, Networking, Bluetooth, Widgets
grep -A5 'name: "workspaces"' /usr/lib/qt6/qml/Quickshell/Hyprland/_Ipc/*.qmltypes
```

### Structure

- **Singleton + window split.** Each surface has a singleton that holds its state and its `IpcHandler`, and a window that renders it: `Dashboard`/`DashboardWindow`, `Launcher`/`LauncherWindow`, `Session`, `Notifs`, `Osd`, `Wallpapers`, `Switcher`. `shell.qml` instantiates one of each window, plus `Variants` over `Quickshell.screens` for the bar.
- **Every singleton and shared component must be listed in `configs/quickshell/qmldir`.** If one is missing, it fails to resolve, and the error does not name the real cause.
- **Singletons are lazy.** A singleton that nothing references never runs. A background watcher with no UI (`services/BatteryNotifier.qml`) is therefore a `Scope` instantiated in `shell.qml`, not a singleton.
- **`services/`** holds shared data sources: `SysInfo` (proc polling), `Players` (the active MPRIS player plus the position tick) and `BatteryNotifier`.
- **Shared components** at the root are `Surface` (the material), `Flyout` (the bar dropdown used by Wi-Fi, Bluetooth and Volume), `Toggle`, `Slider`, `Spinner`, `MaterialIcon` and `Reveal` (the open/close animation). Reuse these rather than building one-off versions.
- **Surfaces extend `OverlayWindow`.** It takes `shown` (the singleton's open flag) and `name`, and it keeps the window mapped while `reveal` animates to 0. Content drives its opacity and scale from `reveal`. Put per-open resets in `onOpened`, not `onVisibleChanged`: a reopen during the exit never unmaps the window, so a visibility hook would not run. While closing, it drops keyboard focus and passes pointer input through. Select on hover with `pointerMoved()`, never `onEntered`. Hyprland's layer animation is off for `ummitos-*` (`no_anim` in `windows.conf`) so the two animations don't stack.

### How input reaches the shell

- Keybinds in `configs/hypr/hyprland/launcher.conf` call `qs -c ummitos ipc call <target> <fn>`. Adding a keybindable surface means adding an `IpcHandler` to its singleton. **Do not name an IPC function `show`**, because `qs ipc show` is a CLI subcommand and claims the name first.
- Alt+Tab uses `GlobalShortcut` (`bind = ALT, TAB, global, quickshell:switcherNext`). It commits on a release bind (`bindrt = ALT, Alt_L, …`) because Hyprland's bind layer consumes the release. Every commit path goes through `Switcher.release()`, which respects the pin.
- **Closing on an outside click:** bar flyouts are `PopupWindow`s and use `grabFocus: true`. `HyprlandFocusGrab` only owns layer surfaces, so it works for `PanelWindow` surfaces such as `NotificationPanel` but silently does nothing on an xdg-popup.

### Design system

`Theme.qml` is the single source of truth for colour, `rounding`, `spacing`, `padding`, `fontSize`, `icon`, `duration`, `curve` (M3 bezier control points), `tracking`, `weight` and `barHeight`. **Surface files contain no magic numbers.** If you need a new value, add a token for it.

- **No borders anywhere, deliberately.** Depth comes from elevation (`bg` → `bgAlt` → `bgTray`) and spacing. Do not add `border.width`.
- The accent `#5003c0` is for fills. `accentText` is the same hue, lifted so it stays readable as text on the dark background.
- Blur is automatic. One Hyprland `layerrule` in `configs/hypr/hyprland/windows.conf` matches `ummitos-.*`, so set `WlrLayershell.namespace: "ummitos-<name>"` on new surfaces. The block syntax uses `ignore_alpha`, not `ignorealpha`.

### Debugging state

Before theorising about why a surface misbehaves, read its actual state. Add a temporary `function probe(): string` to the singleton's `IpcHandler` that returns `JSON.stringify({…})` of the internal values, call it between steps, and delete it afterwards.

## Traps found the hard way

- **`Layout.fillWidth` is contagious.** A filling child makes its row growable all the way up the tree, which ate the bar's centring. Give the child a fixed width instead. Centre things with anchors, not with spacers either side of content whose width varies.
- **`Behavior` fires on the first assignment.** Async-fed values animate up from zero on first paint, so gate the `Behavior` on a flag.
- **`RotationAnimation` leaves `rotation` where it stopped.** Use separate elements for the spinner and the static icon.
- **Assign the committed value before clearing a preview value**, or a derived fallback binding flashes the stale value.
- **List-typed QML properties are JS arrays.** Calling `.toLowerCase()` on one throws, and the whole binding silently empties.
- **Anchoring an Item inside a Layout is undefined behaviour.** Use `TapHandler`, `WheelHandler` or `HoverHandler` instead of an anchored `MouseArea`.
- **`layer.enabled` plus `scale` magnifies a raster.** To grow an item that carries a glow, change its size, not its `scale`.
- **Enter events are not movement.** They fire when a surface opens under a still cursor or when geometry shifts. Compare the pointer position in window coordinates instead.
- **Anchors own `x` and `y`.** A binding on `x` for an item with `anchors.fill` is silently ignored. Slide with a `Translate` transform instead.
- **`Hyprland.workspaces` yields nulls** during create and destroy, so filter entries before reading them.
- **Repeater-in-Layout cannot animate removal.** Lists that should animate items leaving (the notifications) are `ListView`s with `add`, `remove` and `displaced` transitions. Delegates outlive their model entry during `remove`, so read `modelData?.x ?? ""`.
- **Name collisions shadow modules.** `bar/Bluetooth.qml` shadows `Quickshell.Bluetooth`, so the module is imported `as Bluez`.
- **MPRIS length is unreliable.** When `lengthSupported` is false, Quickshell reports the position as the length, and some players (Floorp) publish the length late. Gate progress bars on `lengthSupported && length > 0`.
- **Degenerate geometry can crash Qt.** Clamp computed radii to at least 1 (see `dashboard/Gauge.qml`).
- **PipeWire nodes:** a device is `isSink && !isStream`, and an app stream is `isSink && isStream`. Nodes need a `PwObjectTracker` before their `audio` properties are readable.
- **Bluetooth needs `bluetoothd` running before `qs` starts.** Otherwise the adapter stays null until the shell restarts.

## Hard rules

- Arch Linux only. Scripts gate on `/etc/arch-release`.
- Use `paru` in new install code, never `pacman` directly. NVIDIA is unsupported, and GPU packages are AMD-only.
- Never run or assume root. `install-menu.sh` rejects EUID 0; `install.sh` does not check, but it isn't meant to run as root either.
- Wallpapers are a git submodule (`.wallpaper`). Clone with `--recursive`, or run `git submodule update --init`.
- Installer scripts run from the repo root and use relative paths (`./install/...`).
- The helpers in `script/` write `.log` files, so read those rather than relying on notifications alone.
- Conventional Commits are required, for example `fix(battery-display): disable test mode in battery display script`. PRs need the "Tested on my system" checkbox ticked.
