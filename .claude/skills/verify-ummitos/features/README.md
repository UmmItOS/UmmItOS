# UmmItOS shell verification map

This is the maintained source for verifying the user-facing behaviour of the UmmItOS Quickshell shell. Read this index first, then use the matching feature file as the recipe.

## Baseline preconditions

- Start the isolated stack with `.claude/skills/verify-ummitos/scripts/up.sh`.
- `.claude/skills/verify-ummitos/scripts/doctor.sh` prints only `ok` lines.
- The stack begins empty: a fake HOME with no wallpapers, no `~/script` and no saved state. There is no PipeWire, no BlueZ and no real network identity.
- Never drive the live `qs -c ummitos`. Every command goes through `ipc.sh`, `run.sh` or `shot.sh`.

## Driving conventions

- Open surfaces the way a keybind does, through IPC (see `configs/hypr/hyprland/shortcuts.lua`). Type with `run.sh wtype`.
- Close each surface after a journey (Escape or its IPC close), so the next journey starts from the baseline.
- Wrap any call that can wait in `timeout`.

## Proof and skip reporting

- Take a screenshot with `shot.sh <feature>-<step>` before and after each action, and record the feature ID with it.
- Check `$STACK/qs.out` for new `ERROR`/`WARN` lines after the journey.
- Report features that need audio, Bluetooth or real network as not verifiable in this stack. Do not prove them through a different path.

## Features

| File | Feature | Proven in this stack |
|---|---|---|
| [notifications.md](notifications.md) | Toasts and the notification panel | yes (first run, 2026-10-29) |
| [launcher.md](launcher.md) | App launcher and clipboard manager | not yet |
| [lock.md](lock.md) | Lock screen | not yet |
| [dashboard.md](dashboard.md) | Dashboard tabs | not yet |
| [converter.md](converter.md) | Picture converter wheel | not yet |
