# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

UmmItOS is Arch Linux plus Hyprland, shipped as a bash installer and a dotfiles bundle. It is billed as the "first Hong Kong Linux distribution", but the OS underneath is Arch; this repo is the installer and the config bundle ([UmmItOS/UmmItOS](https://github.com/UmmItOS/UmmItOS)). It has two halves:

- **Installer** (bash): `setup.sh` → `install.sh` / `install-menu.sh` → `install/*.sh`, with shared helpers in `lib/common.sh` (`is_laptop`, `has_amdgpu`, `enable_bluetooth`, `prompt_yna`, `backup_file`, and so on).
- **Desktop shell**: `configs/quickshell/`, a QML application for Quickshell 0.3.1. It draws the bar, notifications, wallpaper and its picker, the launcher and clipboard, the dashboard, the session menu, the volume/brightness OSD, the Wi-Fi, Bluetooth, audio and accent flyouts, an Alt+Tab switcher, a keybind cheat sheet, the screenshot tool, the screen recording dialog, the lock screen, a hot-corner overview, copy notices and a charging ripple. It replaced waybar, swaync, rofi, wlogout, swww, hyprshot and hyprlock. hypridle is still separate (`configs/hypr/`) and locks through the shell's IPC.

## Commands

```sh
./install-menu.sh                 # TUI installer (what most users run)
./install.sh                      # CLI installer: packages → oh-my-zsh → configs → display manager
./post-install.sh --start-config  # Per-user tuning after reboot; needs a Hyprland session + jq
shellcheck install.sh install-menu.sh post-install.sh setup.sh install/*.sh lib/*.sh script/**/*.sh

qs -c ummitos -d                  # Run the shell daemonised (autostart.lua starts it at login)
qs -c ummitos ipc show            # List every IPC target and function
qs -c ummitos ipc call <target> <fn>
qs log -c ummitos                 # The running instance's log; reloads, warnings, errors
```

There are no tests, no lint config and no CI. Verification means running `shellcheck` and running the shell, then reading its log and taking screenshots (`grim`). `/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml -I configs/quickshell <files>` finds unused imports and unqualified ids, but its hundreds of "member not found" warnings on `Theme.spacing.*` and friends are false: the token groups are plain `QtObject`s it cannot see into.

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

- `~/.config/hypr/hyprland.lua`: the first `hl.monitor(…)` line. Keep it on one line.
- `~/.config/hypr/hyprland/env.lua`: the `hl.env("HYPRSHOT_DIR", …)` line. Keep it on one line.

### Two installer entry points, one implementation

`install.sh` **sources** `install/*.sh` in order, so the sub-steps share shell state and one failure aborts the whole run. `install/install-packages.sh` only runs `install_all_packages` when executed directly; `install.sh` calls it after sourcing. `install-menu.sh` sources the same file and calls `install_{main,gpu,laptop}_packages` per menu entry, and runs `install/copy-config.sh` and `install/setup-dm.sh` as child scripts. Change package handling in `install-packages.sh` only; do not copy it into the menu again.

### Hyprland config is Lua

`configs/hypr/hyprland.lua` `require`s one module per concern from `configs/hypr/hyprland/`: `env`, `autostart`, `keybinds` (Hyprland's own), `shortcuts` (apps, shell, utilities), `media-keys`, `appearance`, `animations`, `input`, `misc`, `plugins`, `debug`, `permissions`. Hyprland 0.56 prefers `hyprland.lua` over `hyprland.conf` when both exist, and picks one only at startup, so a switch needs a new session. Check the API against `/usr/share/hypr/stubs/hl.meta.lua` (the installed version), not the wiki's `main`, which runs ahead of the release.

- **Check a change without restarting:** `Hyprland --verify-config -c configs/hypr/hyprland.lua` reports unknown keys and Lua errors. `hyprctl keyword` does not work under Lua; use `hyprctl eval '<lua>'` or `hyprctl dispatch '<hl.dsp… expression>'`.
- **Every bind has a `description` that starts with its cheat sheet group** (`Shell: Session menu`). Under Lua `hyprctl binds` reports every dispatcher as `__lua`, so the cheat sheet (`cheatsheet/`, Super+/) reads the group from that prefix. A bind without a description is missing from it.
- **Keys:** use key names (`Return`, not `code:36`, which loads as an empty key). 0.56.2 ignores `mouse = true` on `hl.bind`; `hl.dsp.window.drag()` and `resize()` handle the button themselves.
- **`~/.config/hypr` is a copy, not a symlink, and holds the user's own values** (monitor layout, `qt5ct`, portal autostarts, touchpad, opacity, no permission rules). Mirror a repo change into the matching live file by hand, back it up first, and never overwrite the live file with the repo's. Change the Hyprland config only when asked: a shell look is fixed in QML, not by changing global settings such as `decoration:blur`, which also affect every window.
- **End-to-end test:** run a nested `Hyprland -c <copy>.lua` from a copy that leaves out `require("hyprland.autostart")` (it would start a second `qs`), drive it with `hyprctl -i <instance> dispatch '…'`, then `hl.dsp.exit()`.

## The shell

### Development loop

`qs -c ummitos` resolves `~/.config/quickshell/ummitos`. Symlink that path to `configs/quickshell` so edits hot-reload into the running instance, then read the log after each save.

Check QML APIs against the installed type definitions, not the online docs, which lag behind 0.3.1:

```sh
ls /usr/lib/qt6/qml/Quickshell/     # Hyprland, Io, Services/*, Wayland, Networking, Bluetooth, Widgets
grep -A5 'name: "workspaces"' /usr/lib/qt6/qml/Quickshell/Hyprland/_Ipc/*.qmltypes
```

### Structure

- **Singleton + window split.** Each surface has a singleton that holds its state and its `IpcHandler`, and a window that renders it: `Dashboard`/`DashboardWindow`, `Launcher`/`LauncherWindow`, `Session`, `Notifs`, `Osd`, `Wallpapers`, `Switcher`, `Cheatsheet`, `Screenshot`, `Recorder`/`RecordWindow`. `shell.qml` instantiates one of each window, plus `Variants` over `Quickshell.screens` for the bar.
- **Every singleton and shared component must be listed in `configs/quickshell/qmldir`.** If one is missing, it fails to resolve, and the error does not name the real cause.
- **Singletons are lazy.** A singleton that nothing references never runs. A background watcher with no UI (`services/BatteryNotifier.qml`) is therefore a `Scope` instantiated in `shell.qml`, not a singleton.
- **Notices go through the shell, never `hyprctl notify`.** Scripts and QML send `notify-send -a "<App name>" …` (always with `-a`, or the panel groups them under "notify-send"); a preview image goes in `-h string:image-path:<file>`, not `-i`. Clipboard copies are the exception: `script/cliphist/clip-store.sh` calls `qs -c ummitos ipc call copied text|image`, which stacks pills bottom-right (`toast/CopyToast.qml`). The notification panel groups history by app, which relies on `Notifs.record()` keeping each app's entries contiguous.
- **`services/`** holds shared data: `SysInfo` (proc polling), `Net` (bandwidth, one sampler however many bars), `Players` (the active MPRIS player), `Cava` (audio levels for the media ring) and `BatteryNotifier`. Anything that polls runs only while something on screen shows it: the dashboard binds `SysInfo.active` to its System tab and `Players.watched` (which gates `Cava.running`) to its Dashboard tab, not just to being open.
- **Shared components** at the root are `Surface` (the material), `Flyout` (the bar dropdown used by Wi-Fi, Bluetooth and Volume), `FlyoutRow` and `FlyoutEmpty` (its list row and empty state), `Toggle`, `Slider`, `Spinner`, `MaterialIcon` and `Reveal` (the open/close animation). Reuse these rather than building one-off versions.
- **Surfaces extend `OverlayWindow`.** It takes `shown` (the singleton's open flag) and `name`, and it keeps the window mapped while `reveal` animates to 0. Content drives its opacity and scale from `reveal`. Put per-open resets in `onOpened`, not `onVisibleChanged`: a reopen during the exit never unmaps the window, so a visibility hook would not run. While closing, it drops keyboard focus and passes pointer input through. Select on hover with `pointerMoved()`, never `onEntered`. Hyprland's layer animation is off for `ummitos-*` (`no_anim` in `appearance.lua`) so the two animations don't stack.

### How input reaches the shell

- Keybinds in `configs/hypr/hyprland/shortcuts.lua` call `qs -c ummitos ipc call <target> <fn>`. Adding a keybindable surface means adding an `IpcHandler` to its singleton. **Do not name an IPC function `show`**, because `qs ipc show` is a CLI subcommand and claims the name first.
- Alt+Tab uses `GlobalShortcut` (`hl.dsp.global("quickshell:switcherNext")` in `shortcuts.lua`). It commits on a release bind (`"ALT + Alt_L"` with `release = true, transparent = true`) because Hyprland's bind layer consumes the release. Every commit path goes through `Switcher.release()`, which respects the pin.
- **Tray menus are drawn by the shell** (`bar/TrayMenu.qml`, a `Flyout` over `QsMenuOpener`), not by `QsMenuAnchor`: Qt's native menus follow the platform theme, which for this Qt 6 shell is plain light. `bar/Tray.qml` also swaps in a glyph or the app's desktop icon when a tray icon is missing, and on start re-registers `org.kde.StatusNotifierItem-*` names the new watcher does not list (apps such as Proton VPN register once and vanish after a shell restart).
- **Closing on an outside click:** bar flyouts are `PopupWindow`s and use `grabFocus: true`. `HyprlandFocusGrab` only owns layer surfaces, so it works for `PanelWindow` surfaces such as `NotificationPanel` but silently does nothing on an xdg-popup.

### Comments

One short line, only for a why the code cannot show (a trap, a workaround, a reason for a number). No multi-line blocks, no restating what the code does, no history of what was tried. If it needs a paragraph, it belongs in this file.

### Design system

`Theme.qml` is the single source of truth for colour, `rounding`, `spacing`, `padding`, `fontSize`, `icon`, `duration`, `curve` (M3 bezier control points), `tracking`, `weight`, `barHeight`, `glass` (a card's sheen on a blurred panel) and `panelTint`. **Surface files contain no magic numbers.** If you need a new value, add a token for it.

- **No borders anywhere, deliberately.** Depth comes from elevation (`bg` → `bgAlt` → `bgTray`) and spacing. Do not add `border.width`.
- The accent is a fill colour, chosen from the bar's palette button and saved to `Quickshell.statePath("accent.txt")`; `#5003c0` is the default. `accentText` and `accent2` are derived from it, so never hardcode a purple: read the tokens and it follows the user's choice.
- The cheat sheet's turning ring is the one deliberate border, by request.
- Blur is Hyprland's, shared with every window, so every surface shows what is really under it and all blur looks alike. Do not draw a surface's own blur of the wallpaper: it shows the bottom layer, not the windows under the surface.
- One Hyprland `hl.layer_rule` in `configs/hypr/hyprland/appearance.lua` matches `ummitos-.*`, so set `WlrLayershell.namespace: "ummitos-<name>"` on new surfaces. The exception is a surface that fades its own transparency over the screen (the wake, `wake-curtain`): the rule blurs and darkens what it covers until its alpha drops below 0.1 (`ignore_alpha`), then stops at once, which reads as a jump at the end of the fade. Such a surface uses a namespace outside the rule and stays mapped, so Hyprland never animates it in or out either.

### Screenshots

`Screenshot` has three modes, all drawn by one overlay (`ScreenshotWindow`): `region` (Shift+Print, drag; the wheel zooms), `window` (Super+Print or Super+Shift+W, pick one) and `screen` (Print). The overlay freezes the screen with a `ScreencopyView` captured once on open, blurs it, and hangs the selection from the screen corners on tendrils that trail the pointer on springs (except in region mode, where the corners are the pointer). A region or screen shot is taken with `grim` only after the overlay has left, so the overlay is never in it. A window shot does not use `grim`: it captures the window's own surface (`HyprlandToplevel.wayland`) off screen, clips it to Hyprland's corner radius and saves it with `grabToImage`, which keeps transparency. Files go to `HYPRSHOT_DIR` (the name predates the shell) and onto the clipboard.

### Switcher and overview

`Switcher` is both Alt+Tab and the GNOME-style overview (`switcher/HotCorner.qml`, a 3px Top-layer window per screen). `Switcher.overviewing` marks the overview; only it gets the zoom-out on open, the corner rings and the stronger selection, so Alt+Tab keeps its look. Every close zooms into the chosen card. For a sharp zoom the overview first takes a full-resolution `grim -t ppm` picture and lays it over the card; previews are captured once at native size and drawn through a `ShaderEffectSource { mipmap: true }`. Never resize a live `ScreencopyView` (changing `constraintSize` mid-capture killed the shell).

### Lock screen

`Lock` (singleton) and `lock/LockScreen.qml`: a `WlSessionLock` with one `WlSessionLockSurface` per screen, drawing `LockContent`. `ipc call lock preview` shows the same content in an ordinary window, which is how the look is worked on; never save a lock file while really locked, since a reload recreates the lock. The password goes through a `PamContext` whose stack lives in the shell (`lock/pam/password`, `pam_unix`), so no `/etc/pam.d` file is needed. Before locking, each screen is captured with `grim -t ppm` into `$XDG_RUNTIME_DIR/ummitos-lock` (PNG encoding was ~0.6s and read as lag); the lock fades in from that picture and fades back to it before releasing, because a lock surface is opaque and the desktop cannot show through. `misc:allow_session_lock_restore` is on, so if `qs` dies while locked: switch to a TTY, start `qs -c ummitos -d` in the session's environment, run `qs -c ummitos ipc call lock lock`, go back and unlock.

### Debugging state

Before theorising about why a surface misbehaves, read its actual state. Add a temporary `function probe(): string` to the singleton's `IpcHandler` that returns `JSON.stringify({…})` of the internal values, call it between steps, and delete it afterwards.

For things that need input you cannot give from a terminal, mark every temporary line `// PROBE` (an `IpcHandler` that calls the function a click would, a `console.log`) and remove them with `sed -i '/\/\/ PROBE/d'`. `hyprctl dispatch movecursor x y` moves the pointer. Animations are checked by recording: `wl-screenrec -f rec.mp4`, then `ffmpeg -i rec.mp4 -vf "fps=6,scale=320:-1,tile=4x3" -frames:v 1 grid.png` for a contact sheet. Never delete a user's files by guessing which one a test made; list the folder before and after and remove only the difference.

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
- **`sed -i` does not trigger a hot reload.** It writes a new file and renames it over the old one, and the watcher misses the swap. After a `sed -i`, `touch shell.qml`. A popup (`PopupWindow` with `grabFocus`) cannot be opened from a probe either: the compositor dismisses a grab that no click started.
- **IPC calls during a reload are lost.** For a moment after a save the targets do not exist ("Target not found", "Not ready to accept queries yet"). In scripts, wait until the log shows a new `Configuration Loaded` before calling.
- **A failed reload can leave the log stale and the watcher idle.** After an error, the last lines of `qs log` may still show it even once the file is fixed. `touch shell.qml` and wait for a fresh `Configuration Loaded` before believing either.
- **Files in subfolders need `import ".."`** to see `Theme` and the other root types. Without it the error is `Theme is not defined` at runtime, not at load.
- **`width`, `height` and friends are FINAL.** Declaring a property with such a name on a subclass fails the whole file with "Cannot override FINAL property".
- **QML JavaScript has no object spread** (`{...a}`); build the object and assign fields.
- **`clip: true` clips to a rectangle.** Inside rounded surfaces, clip with a `ClippingRectangle` of the same radius, or corners show.
- **A blurred shape is cut off at its own bounds**, which reads as a square edge. For soft light use a radial gradient that fades to zero before the edge (a `Canvas`). To glow an outline, capture it with a `ShaderEffectSource` whose `sourceRect` is padded past the item, then blur that; feeding one `MultiEffect` straight into another (with `layer.enabled` on the first) hid the first one.
- **`ScreencopyView` captures whatever is on screen, including the shell.** Capture only when your own overlay is fully gone, or you photograph yourself.
- **State paths are per shell id.** `Quickshell.statePath()` resolves under `~/.local/state/quickshell/by-shell/<id>/`, and the id changes with how `qs` was started. Find the live one from the instance's own log, not by guessing.
- **Bluetooth needs `bluetoothd` running before `qs` starts.** Otherwise the adapter stays null until the shell restarts.
- **A missing theme icon is not an error.** `image://icon/<name>` for a name the theme lacks loads as Qt's magenta checkerboard with `status === Image.Ready`. Check `Quickshell.iconPath(name, true) !== ""` first. A tray pixmap that never arrived has a `image://qspixmap/…/0` source.
- **`itemAt()` in a binding runs once.** It is a call, not a property, so a binding on `repeater.itemAt(i)` evaluated before the Repeater built its items stays null. Read through `repeater.count` so it re-runs.
- **Several `Binding`s writing one property need `restoreMode: Binding.RestoreNone`.** With the default, the one switching off restores the value it saw when it switched on, in an order nothing guarantees, and leaves a stale value.
- **A flag in a singleton read by a `Variants` delegate is read once per screen.** Clearing it in the first screen's handler starves the others; clear it with `Qt.callLater` in the singleton.
- **A `Canvas` under a hidden item never paints.** For a mask or effect source drawn with a `Canvas`, keep it visible and capture it with a `ShaderEffectSource { hideSource: true }`, rather than `visible: false` plus `layer.enabled`.
- **`MultiEffect`'s inverted mask draws nothing when its mask is empty or zero-sized**, not everything. For shapes that grow from nothing (the wake's circles), write a `ShaderEffect`: the source is `wake/curtain.frag`, compiled next to it with `/usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o curtain.frag.qsb curtain.frag`. Commit both; the shell loads the `.qsb`, so installs need no shader tools. **A hot reload keeps the old compiled shader** (Qt caches it by URL): after changing a shader's uniforms, rename the file or restart `qs`, or it reads the new properties as zero.
- **Animate transforms, not geometry.** Growing an item by `width`/`height` every frame re-lays it out, and resizing a blurred source rebuilds its blur texture every frame; both stutter. Draw it once at full size and animate a `Scale` or `Translate`.
- **Notifications are replaced in place.** `notify-send -r`, players and progress notices update the same `Notification` object, so anything copied from it must be refreshed on `summaryChanged`/`bodyChanged`/`imageChanged`.

## Hard rules

- Arch Linux only. Scripts gate on `/etc/arch-release`.
- Use `paru` in new install code, never `pacman` directly. NVIDIA is unsupported, and GPU packages are AMD-only.
- Never run or assume root. `install-menu.sh` rejects EUID 0; `install.sh` does not check, but it isn't meant to run as root either.
- Wallpapers are a git submodule (`.wallpaper`). Clone with `--recursive`, or run `git submodule update --init`.
- Installer scripts run from the repo root and use relative paths (`./install/...`).
- The helpers in `script/` write `.log` files, so read those rather than relying on notifications alone.
- Conventional Commits are required, for example `fix(battery-display): disable test mode in battery display script`. PRs need the "Tested on my system" checkbox ticked.
