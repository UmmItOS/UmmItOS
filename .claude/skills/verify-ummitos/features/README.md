# UmmItOS shell verification map

This is the maintained source for verifying the user-facing behaviour of the UmmItOS Quickshell shell. Read this index first, then use the matching feature file as the recipe.

## Baseline preconditions

- Start the isolated stack with `.claude/skills/verify-ummitos/scripts/up.sh`.
- `.claude/skills/verify-ummitos/scripts/doctor.sh` prints only `ok` lines.
- The stack begins empty: a fake HOME with no wallpapers, no `~/script` and no saved state. Features that need either say how to seed them. There is no PipeWire, no BlueZ and no real network identity.
- Never drive the live `qs -c ummitos`. Every command goes through `ipc.sh`, `run.sh` or `shot.sh`.

## Driving conventions

- Open surfaces the way a keybind does, through IPC (see `configs/hypr/hyprland/shortcuts.lua`). Type with `run.sh wtype`.
- Close each surface after a journey (Escape or its IPC close), so the next journey starts from the baseline.
- Wrap any call that can wait in `timeout`.
- Wait about 8 s after `up.sh` for the start-up health check. Its "1 things need attention" toast is critical, so it stays top right until dismissed; do not wait for it to expire. Park the pointer at 960,540 before driving surfaces that light up on hover.
- Drive the lock last: nothing in the stack can unlock it, so `down.sh` ends that journey.

## Proof and skip reporting

- Take a screenshot with `shot.sh <feature>-<step>` before and after each action, and record the feature ID with it.
- Check `$STACK/qs.out` for new `ERROR`/`WARN` lines after the journey.
- Report features that need audio, Bluetooth or real network as not verifiable in this stack. Do not prove them through a different path.

## Features

| File | Feature | Proven in this stack |
|---|---|---|
| [notifications.md](notifications.md) | Toasts, panel, clear, DND | yes (2026-11-06) |
| [launcher.md](launcher.md) | App launcher and clipboard manager | yes (2026-11-06) |
| [dashboard.md](dashboard.md) | Dashboard, System and Workspaces tabs | yes (2026-11-06) |
| [converter.md](converter.md) | Picture converter wheel (open, pick, close; drop not drivable) | partly (2026-11-04) |
| [scan.md](scan.md) | QR scanner: find and detail (Open not driven) | yes (2026-11-06) |
| [fps.md](fps.md) | FPS counter: on, off, saved | yes (2026-11-06) |
| [displays.md](displays.md) | Display chooser: modes, auto-revert, watchdog, desktop right-click | yes (2026-11-06) |
| [desktop-menu.md](desktop-menu.md) | Desktop right-click menu: actions, show-on-desktop switches, keyboard | yes (2026-11-06) |
| [wallpaper.md](wallpaper.md) | Wallpaper pickers: Alt+W carousel and the right-click drawer (chips, preview, set, shuffle) | yes (2026-11-06) |
| [heavy-process.md](heavy-process.md) | Heavy process warning on the bar (CPU proven; GPU not drivable here) | partly (2026-11-06) |
| [lock.md](lock.md) | Lock screen: preview, engage, one wrong password (unlock and the music spectrum not drivable). Drive last. | yes (2026-11-06) |
