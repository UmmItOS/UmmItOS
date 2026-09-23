# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

UmmItOS is Arch Linux plus Hyprland, shipped as a bash installer and a dotfiles bundle. It is billed as the "first Hong Kong Linux distribution", but the OS underneath is Arch; this repo is the installer and the config bundle ([UmmItOS/UmmItOS](https://github.com/UmmItOS/UmmItOS)). It has two halves:

- **Installer** (bash): `setup.sh` → `install.sh` / `install-menu.sh` → `install/*.sh`, with shared helpers in `lib/common.sh` (`is_laptop`, `has_amdgpu`, `enable_bluetooth`, `prompt_yna`, `backup_file`, and so on).
- **Desktop shell**: `configs/quickshell/`, a QML application for Quickshell 0.3.1. It draws the bar, notifications, wallpaper and its picker, the launcher and clipboard, the dashboard, the session menu, the volume/brightness OSD, the Wi-Fi, Bluetooth, audio and accent flyouts, an Alt+Tab switcher, a keybind cheat sheet, the screenshot tool, the lock screen, a hot-corner overview, copy notices and a charging ripple. It replaced waybar, swaync, rofi, wlogout, swww, hyprshot and hyprlock. hypridle is still separate (`configs/hypr/`) and locks through the shell's IPC.

## Commands

```sh
./install-menu.sh                 # TUI installer (what most users run)
./install.sh                      # CLI installer: packages → oh-my-zsh → configs → display manager
./post-install.sh --start-config  # Per-user tuning after reboot; needs a Hyprland session + jq
shellcheck install.sh install-menu.sh post-install.sh setup.sh install/*.sh lib/*.sh script/**/*.sh

qs -c ummitos -d                  # Run the shell daemonised (exec.conf starts it at login)
qs -c ummitos ipc show            # List every IPC target and function
qs -c ummitos ipc call <target> <fn>
qs log -c ummitos                 # The running instance's log; reloads, warnings, errors
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
| `script/` | Helpers for cliphist, the idle lock, hyprpicker, updates and screen recording; copied to `~/script` |
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

- `~/.config/hypr/hyprland.conf`: **line 3** (`monitor=…`).
- `~/.config/hypr/hyprland/env.conf`: `env = HYPRSHOT_DIR, …`.

### Two installer entry points, one implementation

`install.sh` **sources** `install/*.sh` in order, so the sub-steps share shell state and one failure aborts the whole run. `install/install-packages.sh` only runs `install_all_packages` when executed directly; `install.sh` calls it after sourcing. `install-menu.sh` sources the same file and calls `install_{main,gpu,laptop}_packages` per menu entry, and runs `install/copy-config.sh` and `install/setup-dm.sh` as child scripts. Change package handling in `install-packages.sh` only; do not copy it into the menu again.

Keybinds carry their own descriptions (`bindd`, `bindeld`, …), and the shell's cheat sheet (`cheatsheet/`, Super+/) lists them from `hyprctl binds`, grouped by dispatcher. A new bind without a description is missing from the cheatsheet. Descriptions cannot contain commas.

## The shell

### Development loop

`qs -c ummitos` resolves `~/.config/quickshell/ummitos`. Symlink that path to `configs/quickshell` so edits hot-reload into the running instance, then read the log after each save.

Check QML APIs against the installed type definitions, not the online docs, which lag behind 0.3.1:

```sh
ls /usr/lib/qt6/qml/Quickshell/     # Hyprland, Io, Services/*, Wayland, Networking, Bluetooth, Widgets
grep -A5 'name: "workspaces"' /usr/lib/qt6/qml/Quickshell/Hyprland/_Ipc/*.qmltypes
```

### Structure

- **Singleton + window split.** Each surface has a singleton that holds its state and its `IpcHandler`, and a window that renders it: `Dashboard`/`DashboardWindow`, `Launcher`/`LauncherWindow`, `Session`, `Notifs`, `Osd`, `Wallpapers`, `Switcher`, `Cheatsheet`, `Screenshot`. `shell.qml` instantiates one of each window, plus `Variants` over `Quickshell.screens` for the bar.
- **Every singleton and shared component must be listed in `configs/quickshell/qmldir`.** If one is missing, it fails to resolve, and the error does not name the real cause.
- **Singletons are lazy.** A singleton that nothing references never runs. A background watcher with no UI (`services/BatteryNotifier.qml`) is therefore a `Scope` instantiated in `shell.qml`, not a singleton.
- **Notices go through the shell, never `hyprctl notify`.** Scripts and QML send `notify-send -a "<App name>" …` (always with `-a`, or the panel groups them under "notify-send"); a preview image goes in `-h string:image-path:<file>`, not `-i`. Clipboard copies are the exception: `script/cliphist/clip-store.sh` calls `qs -c ummitos ipc call copied text|image`, which stacks pills bottom-right (`toast/CopyToast.qml`). The notification panel groups history by app, which relies on `Notifs.record()` keeping each app's entries contiguous.
- **`services/`** holds shared data: `SysInfo` (proc polling), `Net` (bandwidth, one sampler however many bars), `Players` (the active MPRIS player), `Cava` (audio levels for the media ring) and `BatteryNotifier`. Anything that polls runs only while something on screen shows it: `SysInfo.active`, `Players.watched` and `Cava.running` are all switched by the dashboard.
- **Shared components** at the root are `Surface` (the material), `Flyout` (the bar dropdown used by Wi-Fi, Bluetooth and Volume), `FlyoutRow` and `FlyoutEmpty` (its list row and empty state), `Toggle`, `Slider`, `Spinner`, `MaterialIcon` and `Reveal` (the open/close animation). Reuse these rather than building one-off versions.
- **Surfaces extend `OverlayWindow`.** It takes `shown` (the singleton's open flag) and `name`, and it keeps the window mapped while `reveal` animates to 0. Content drives its opacity and scale from `reveal`. Put per-open resets in `onOpened`, not `onVisibleChanged`: a reopen during the exit never unmaps the window, so a visibility hook would not run. While closing, it drops keyboard focus and passes pointer input through. Select on hover with `pointerMoved()`, never `onEntered`. Hyprland's layer animation is off for `ummitos-*` (`no_anim` in `windows.conf`) so the two animations don't stack.

### How input reaches the shell

- Keybinds in `configs/hypr/hyprland/launcher.conf` call `qs -c ummitos ipc call <target> <fn>`. Adding a keybindable surface means adding an `IpcHandler` to its singleton. **Do not name an IPC function `show`**, because `qs ipc show` is a CLI subcommand and claims the name first.
- Alt+Tab uses `GlobalShortcut` (`bind = ALT, TAB, global, quickshell:switcherNext`). It commits on a release bind (`bindrt = ALT, Alt_L, …`) because Hyprland's bind layer consumes the release. Every commit path goes through `Switcher.release()`, which respects the pin.
- **Closing on an outside click:** bar flyouts are `PopupWindow`s and use `grabFocus: true`. `HyprlandFocusGrab` only owns layer surfaces, so it works for `PanelWindow` surfaces such as `NotificationPanel` but silently does nothing on an xdg-popup.

### Design system

`Theme.qml` is the single source of truth for colour, `rounding`, `spacing`, `padding`, `fontSize`, `icon`, `duration`, `curve` (M3 bezier control points), `tracking`, `weight` and `barHeight`. **Surface files contain no magic numbers.** If you need a new value, add a token for it.

- **No borders anywhere, deliberately.** Depth comes from elevation (`bg` → `bgAlt` → `bgTray`) and spacing. Do not add `border.width`.
- The accent is a fill colour, chosen from the bar's palette button and saved to `Quickshell.statePath("accent.txt")`; `#5003c0` is the default. `accentText` and `accent2` are derived from it, so never hardcode a purple: read the tokens and it follows the user's choice.
- The cheat sheet's turning ring is the one deliberate border, by request.
- Blur is automatic. One Hyprland `layerrule` in `configs/hypr/hyprland/windows.conf` matches `ummitos-.*`, so set `WlrLayershell.namespace: "ummitos-<name>"` on new surfaces. The block syntax uses `ignore_alpha`, not `ignorealpha`.

### Screenshots

`Screenshot` has three modes, all drawn by one overlay (`ScreenshotWindow`): `region` (Shift+Print, drag; the wheel zooms), `window` (Super+Print or Super+Shift+W, pick one) and `screen` (Print). The overlay freezes the screen with a `ScreencopyView` captured once on open, blurs it, and hangs the selection from the screen corners on tendrils that trail the pointer on springs (except in region mode, where the corners are the pointer). A region or screen shot is taken with `grim` only after the overlay has left, so the overlay is never in it. A window shot does not use `grim`: it captures the window's own surface (`HyprlandToplevel.wayland`) off screen, clips it to Hyprland's corner radius and saves it with `grabToImage`, which keeps transparency. Files go to `HYPRSHOT_DIR` (the name predates the shell) and onto the clipboard.

### Switcher and overview

`Switcher` is both Alt+Tab and the GNOME-style overview (`switcher/HotCorner.qml`, a 3px Top-layer window per screen). `Switcher.overviewing` marks the overview; only it gets the zoom-out on open, the corner rings and the stronger selection, so Alt+Tab keeps its look. Every close zooms into the chosen card. For a sharp zoom the overview first takes a full-resolution `grim -t ppm` picture and lays it over the card; previews are captured once at native size and drawn through a `ShaderEffectSource { mipmap: true }`. Never resize a live `ScreencopyView` (changing `constraintSize` mid-capture killed the shell).

### Lock screen

`Lock` (singleton) and `lock/LockScreen.qml`: a `WlSessionLock` with one `WlSessionLockSurface` per screen, drawing `LockContent`. `ipc call lock preview` shows the same content in an ordinary window, which is how the look is worked on; never save a lock file while really locked, since a reload recreates the lock. The password goes through a `PamContext` whose stack lives in the shell (`lock/pam/password`, `pam_unix`), so no `/etc/pam.d` file is needed. Before locking, each screen is captured with `grim -t ppm` into `$XDG_RUNTIME_DIR/ummitos-lock` (PNG encoding was ~0.6s and read as lag); the lock fades in from that picture and fades back to it before releasing, because a lock surface is opaque and the desktop cannot show through. `misc:allow_session_lock_restore` is on, so if `qs` dies while locked: switch to a TTY, start `qs -c ummitos -d` in the session's environment, run `qs -c ummitos ipc call lock lock`, go back and unlock.

### Debugging state

Before theorising about why a surface misbehaves, read its actual state. Add a temporary `function probe(): string` to the singleton's `IpcHandler` that returns `JSON.stringify({…})` of the internal values, call it between steps, and delete it afterwards.

For things that need input you cannot give from a terminal, mark every temporary line `// PROBE` (an `IpcHandler` that calls the function a click would, a `console.log`) and remove them with `sed -i '/\/\/ PROBE/d'`. `hyprctl dispatch movecursor x y` moves the pointer. Animations are checked by recording: `wf-recorder -f rec.mp4`, then `ffmpeg -i rec.mp4 -vf "fps=6,scale=320:-1,tile=4x3" -frames:v 1 grid.png` for a contact sheet. Never delete a user's files by guessing which one a test made; list the folder before and after and remove only the difference.

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
- **A leftover notification daemon steals the bus name.** If swaync (or dunst, mako) is still installed, D-Bus activates it whenever a notification arrives while the shell's name is released, which happens during every reload. The shell only claims the name at startup, so toasts silently stop until `qs` restarts. Mask it: `systemctl --user mask swaync.service`.
- **IPC calls during a reload are lost.** For a moment after a save the targets do not exist ("Target not found", "Not ready to accept queries yet"). In scripts, wait until the log shows a new `Configuration Loaded` before calling.
- **A failed reload can leave the log stale and the watcher idle.** After an error, the last lines of `qs log` may still show it even once the file is fixed. `touch shell.qml` and wait for a fresh `Configuration Loaded` before believing either.
- **Files in subfolders need `import ".."`** to see `Theme` and the other root types. Without it the error is `Theme is not defined` at runtime, not at load.
- **`width`, `height` and friends are FINAL.** Declaring a property with such a name on a subclass fails the whole file with "Cannot override FINAL property".
- **QML JavaScript has no object spread** (`{...a}`); build the object and assign fields.
- **`clip: true` clips to a rectangle.** Inside rounded surfaces, clip with a `ClippingRectangle` of the same radius, or corners show.
- **A blurred shape is cut off at its own bounds**, which reads as a square edge. For soft light use a radial gradient that fades to zero before the edge (a `Canvas`).
- **`ScreencopyView` captures whatever is on screen, including the shell.** Capture only when your own overlay is fully gone, or you photograph yourself.
- **State paths are per shell id.** `Quickshell.statePath()` resolves under `~/.local/state/quickshell/by-shell/<id>/`, and the id changes with how `qs` was started. Find the live one from the instance's own log, not by guessing.
- **Bluetooth needs `bluetoothd` running before `qs` starts.** Otherwise the adapter stays null until the shell restarts.

## Hard rules

- Arch Linux only. Scripts gate on `/etc/arch-release`.
- Use `paru` in new install code, never `pacman` directly. NVIDIA is unsupported, and GPU packages are AMD-only.
- Never run or assume root. `install-menu.sh` rejects EUID 0; `install.sh` does not check, but it isn't meant to run as root either.
- Wallpapers are a git submodule (`.wallpaper`). Clone with `--recursive`, or run `git submodule update --init`.
- Installer scripts run from the repo root and use relative paths (`./install/...`).
- The helpers in `script/` write `.log` files, so read those rather than relying on notifications alone.
- Conventional Commits are required, for example `fix(battery-display): disable test mode in battery display script`. PRs need the "Tested on my system" checkbox ticked.
