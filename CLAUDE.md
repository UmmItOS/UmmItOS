# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

UmmItOS is Arch Linux plus Hyprland, shipped as a bash installer and a dotfiles bundle. It is billed as the "first Hong Kong Linux distribution", but the OS underneath is Arch; this repo is the installer and the config bundle ([UmmItOS/UmmItOS](https://github.com/UmmItOS/UmmItOS)). It has two halves:

- **Installer** (bash): `setup.sh` → `install.sh` / `install-menu.sh` → `install/*.sh`, with shared helpers in `lib/common.sh` (`is_laptop`, `has_amdgpu`, `enable_bluetooth`, `prompt_yna`, `backup_file`, and so on).
- **Desktop shell**: `configs/quickshell/`, a QML application for Quickshell 0.3.1. It draws the bar (its tool cluster folds behind a » toggle at the start of the pill, kept by the `Toolbox` singleton across restarts), notifications, wallpaper and its picker, the launcher and clipboard, the dashboard, the session menu, the volume/brightness OSD (which also shows each input method switch: fcitx5's glyph, 速 or A, the moment the key is pressed), the Wi-Fi, Bluetooth, audio and accent flyouts, an Alt+Tab switcher, a keybind cheat sheet, the screenshot tool, the screen recording dialog, a lecture pen (Super+D: draw and zoom over a frozen screen), a QR scanner (Super+Shift+Q or the bar's scan button: finds every code on screen with `zbarimg`, opens web links in the default browser, joins Wi-Fi codes, copies the rest), a picture converter (Super+I: GTA V's weapon wheel with eight formats for weapons; drop pictures on it, click a slot, and a "MISSION PASSED" banner follows), the lock screen, a settings panel (the gear beside the power button: recording options, recordings, the packages the installer would add that are missing, pending updates with where UmmItOS lives and whether `git pull` there updates the shell, About; it replaces the GTK `ummit-settings` app), an SAO menu (Super+M, or drag down from a strip on the left edge: Sword Art Online's round buttons for a Profile card with HP = battery and MP = RAM, Party, Items, Message, a Skills card listing the Claude Code agent skills, Option and the ○/× Logout dialog; its palette and Rationale font live in `Theme.sao`, apart from the shell's look on purpose), a hot-corner overview, copy notices, a charging ripple, desktop widgets (a wttr.in weather card and a now-playing card on the Bottom layer, under the windows, stacked top-right in one column that dodges the notifications so neither overflows or is covered; Settings → Bar toggles each) and a joke grey "Activate Linux" reminder in the bottom-right corner (`desktop/ActivateLinux.qml`, click-through, in a namespace outside the `ummitos-*` blur rule; Settings → Misc turns it off, saved in `~/.config/ummitos/desktop.conf`, where Settings → Bar also keeps the weather card's switch) and an FPS counter, off by default, top-left on the Bottom layer with the weather card, under the windows (`desktop/FpsMeter.qml`; Settings → Misc, or `ipc call fps toggle` / `ipc call fps set 1|0`, like cl_showfps). It replaced waybar, swaync, rofi, wlogout, swww, hyprshot and hyprlock. hypridle is still separate (`configs/hypr/`) and locks through the shell's IPC.

## Before you build

Every feature, fix or change goes through the checklist: programming reviewed with `/qt-development-skills:qt-qml`, UI and UX reviewed with `/hallmark` with motion included, and nothing is done until it is checked on screen.

@DOCS/CHECKLIST.md

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

V=.claude/skills/verify-ummitos/scripts
$V/up.sh && $V/doctor.sh          # The shell from this checkout in an isolated nested Hyprland
$V/ipc.sh <target> <fn>           # Drive it; $V/shot.sh <name> for a screenshot; $V/down.sh to tear down
node $V/check-scan.mjs            # The QR panel's host against WHATWG URL parsing (the one scripted test)
```

There is no test suite, no lint config and no CI. Verification means running `shellcheck` and the shell, then reading its log and taking screenshots. `check-scan.mjs` is the only scripted test: it lifts `describe()` out of `scan/Scan.qml` and runs it in node. `/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml -I configs/quickshell <files>` finds unused imports and unqualified ids, but its hundreds of "member not found" warnings on `Theme.spacing.*` and friends are false: the token groups are plain `QtObject`s it cannot see into.

**Never start a second `qs -c ummitos` while one is running**, not even with `timeout` as a syntax check. When it exits, it takes the running instance down with it. To check a change on screen without touching the live session, use the `verify-ummitos` skill (`.claude/skills/verify-ummitos/SKILL.md`). It runs `qs -c ummitos-test` inside a nested Hyprland with its own D-Bus, runtime directory and fake HOME, on a headless output, and its `features/` folder holds a tested recipe per feature. For a single component, run a standalone file with `qs -p file.qml`.

## Where the rest lives

Each part of the repo has its own rule file in `.claude/rules/`. Claude Code loads one when you work on the files its `paths:` names; `versions.md` has no paths, so it is always loaded. Other agents: read the file for the area you touch.

| File | Covers | Loads for |
|---|---|---|
| [installer.md](.claude/rules/installer.md) | Layout and flow, the greetd login screen, package lists, config copy, `post-install.sh`, the two entry points | `setup.sh`, `install*.sh`, `post-install.sh`, `install/`, `lib/`, `configs/greeter/` |
| [hyprland.md](.claude/rules/hyprland.md) | The Lua config, binds, checking a change | `configs/hypr/` |
| [shell.md](.claude/rules/shell.md) | Development loop, structure, input, design system, debugging state | `configs/quickshell/`, `configs/greeter/`, `script/` |
| [shell-features.md](.claude/rules/shell-features.md) | Screenshots, gallery, health check, security notices, wipe, switcher, lock screen, converter | same as shell.md |
| [qml-traps.md](.claude/rules/qml-traps.md) | Traps found the hard way | `configs/quickshell/`, `configs/greeter/` |
| [versions.md](.claude/rules/versions.md) | When to cut a patch, minor or major | always |

The procedures stay in `DOCS/`: [CHECKLIST.md](DOCS/CHECKLIST.md) (imported above), [RELEASE.md](DOCS/RELEASE.md) and [FULL_REVIEW_WORK.md](DOCS/FULL_REVIEW_WORK.md).

## Hard rules

- Arch Linux only. `install.sh` and `install-menu.sh` gate on `/etc/arch-release`.
- Use `paru` in new install code, never `pacman` directly; the one exception is installing `git` and `base-devel` before paru exists (`check_paru` in `lib/common.sh` and `setup.sh`). NVIDIA is unsupported, and GPU packages are AMD-only.
- Never run or assume root. `install-menu.sh` rejects EUID 0; `install.sh` does not check, but it isn't meant to run as root either.
- Wallpapers (`.wallpaper`) and the brand images (`configs/quickshell/resources`, `UmmItOS/resources`, the About page's icon) are git submodules. Clone with `--recursive`, or run `git submodule update --init`.
- Installer scripts run from the repo root and use relative paths (`./install/...`).
- The helpers in `script/` write `.log` files, so read those rather than relying on notifications alone.
- Conventional Commits are required, for example `fix(battery-display): disable test mode in battery display script`. PRs need the "Tested on my system" checkbox ticked.
