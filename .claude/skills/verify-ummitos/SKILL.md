---
name: verify-ummitos
description: Drive the UmmItOS Quickshell desktop shell (configs/quickshell) the way a user does, inside an isolated nested Hyprland, and capture screenshot/log evidence that a change works. Use after any change to the shell (bar, notifications, launcher, lock, dashboard, converter, settings) when you need proof on screen, without touching the user's live session.
---

# verify-ummitos

The shell under test is this repo's `configs/quickshell`, run as `qs -c ummitos-test` inside its own **nested Hyprland**. That stack has:

- a private D-Bus session;
- a private `XDG_RUNTIME_DIR` under `/run/user/$UID/vu/run`;
- a fake `HOME` under `/run/user/$UID/vu/home`;
- a headless output `VERIFY` (1920x1080) that it renders to.

The nested compositor's window is sent to the parent's hidden `special:verify` workspace.

The user's live `qs -c ummitos`, their home, their D-Bus, their lock and their audio are never touched. **Never** run `qs -c ummitos …` (no `-test` suffix) or `qs ipc` without these helpers. That is the live shell, and a second instance of it kills the first.

All helpers are in `scripts/` (absolute path: `<repo>/.claude/skills/verify-ummitos/scripts/`). Run them from anywhere.

## Launch

```sh
.claude/skills/verify-ummitos/scripts/up.sh
```

When it is ready, it prints `up: run <RUN_ID>, evidence in <dir>`. Ready means two things:

- the nested Hyprland answers `hyprctl` on its own socket;
- `qs -c ummitos-test` has logged `Configuration Loaded`.

It takes about 3–6 s. If a stack is already up, it refuses to start; run `down.sh` first. It also refuses when `/run/user/$UID/vu` exists without the `.verify-ummitos` marker it writes, and it stops (and tears down) if Hyprland's socket path would reach 108 bytes, the Unix socket limit.

What `up.sh` does, so you can debug it:

1. Copies `configs/hypr` to the stack and removes `require("hyprland.autostart")` (which would start a second shell) and `require("hyprland.permissions")` (whose screencopy prompt blocks the shell's own captures).
2. Forces one monitor rule.
3. Adds a runtime window rule in the **parent** Hyprland that moves class `aquamarine` to `special:verify silent`.
4. Starts `start-hyprland` under `dbus-run-session`.
5. Creates the headless `VERIFY` output and disables `WAYLAND-1` (the window output, which gets no frames while hidden).
6. Starts `qs -c ummitos-test` with the stack environment, under `bwrap` with every `/dev/video*` and `/dev/media*` node replaced by `/dev/null` inside that process only. The lock's intruder alarm opens a Qt Camera there; the mask keeps the real webcam off. A camera cannot be proven blocked on a host with no such node, and `ipc.sh` also refuses `lock alarm`.

It is a hot-reloading checkout: `~/.config/quickshell/ummitos-test` inside the fake HOME links to `<repo>/configs/quickshell`. A save in the repo reloads the test shell, and the live shell too. Wait for a new `Configuration Loaded` in `$STACK/qs.out` before driving after an edit.

## Doctor

```sh
.claude/skills/verify-ummitos/scripts/doctor.sh
```

This is read-only. Every line must say `ok`. It checks that:

- the session and the test qs processes are alive;
- the nested Hyprland answers;
- the test config link points at **this** repo;
- `VERIFY` exists, so grim can capture;
- the IPC targets answer, and `qs.out` exists and holds none of Quickshell's Hyprland-IPC failure messages;
- the last load line in `qs.out` is `Configuration Loaded`, not an `ERROR`.

Run it first whenever something looks off. On any `FAIL`, run `down.sh`, then `up.sh`.

## Drive

| Need | Command |
|---|---|
| Call the test shell's IPC | `scripts/ipc.sh <target> <function> [args]`, e.g. `scripts/ipc.sh launcher apps` |
| List IPC targets | `scripts/run.sh qs -c ummitos-test ipc show` |
| Run anything inside the stack | `scripts/run.sh <cmd…>`, e.g. `scripts/run.sh notify-send -a Verify "Title" "Body"` |
| Type keys into the focused test surface | `scripts/run.sh wtype "text"`, `scripts/run.sh wtype -k Return`, `scripts/run.sh wtype -k Escape` |
| Move the pointer | `scripts/run.sh hyprctl dispatch 'hl.dsp.cursor.move({ x = 960, y = 540 })'` |
| Inspect windows and layers | `scripts/run.sh hyprctl -j layers`, `scripts/run.sh hyprctl -j clients` |

How to drive it:

- Prefer IPC targets and keyboard input over coordinates. The surfaces and their IPC functions are listed in `features/`.
- Every IPC function and argument comes from the `IpcHandler` blocks in `configs/quickshell/**`. Check with `ipc show`.
- Wrap anything that might wait in `timeout`. A blocked helper otherwise blocks the whole run.

## Evidence

```sh
.claude/skills/verify-ummitos/scripts/shot.sh <name>   # prints the PNG path
```

- Evidence goes to `~/.local/state/verify-ummitos/runs/<RUN_ID>/`, outside the repo and outside the stack, so it survives `down.sh`.
- `down.sh` also copies the test shell's log there as `qs.log`.
- Crop for reading: `magick <shot> -crop 700x300+1220+40 crop.png`.

Proof standards:

- Drive the real user path: IPC binds and keys the way Hyprland binds call them. Never call internal setters or add probe IPC for the proof itself.
- Capture before and after, not just the end screen.
- Check side effects alongside the pixels. Read `qs.out` for errors. For features that write state, check the files under `$STACK/home` (the fake HOME), and never under the real `~`.
- `qs.out` always has `ERROR quickshell.service.pipewire.loop: Failed to connect pipewire context` and a BlueZ `objectmanager` warning: expected, the stack has neither. Any other new ERROR/WARN after your journey is a finding.
- The stack has **no PipeWire, no BlueZ and no real network identity**. Sound, the volume/mic discs, the media card with a real player and the Bluetooth/Wi-Fi flyouts cannot be proven here. Say so in the report instead of passing them.
- When a journey fails because the stack lacks a precondition, report the failure and add the reason to that feature's Gotchas. Never weaken the journey to pass.

## Cleanup

```sh
.claude/skills/verify-ummitos/scripts/down.sh
```

It kills only what `up.sh` started:

- the session and qs process groups, by the PIDs it recorded;
- helpers that D-Bus activation started on the private bus (gvfsd, xdg-document-portal). These are found by their `XDG_RUNTIME_DIR=$STACK/run` environment.

Then it:

- unmounts the FUSE mounts under the stack;
- disables the parent window rule;
- deletes `/run/user/$UID/vu`, but only if it holds the `.verify-ummitos` marker `up.sh` wrote; otherwise it says so and leaves it.

It never kills by process name. The evidence under `~/.local/state/verify-ummitos/runs/` is kept; delete old runs yourself when they are no longer needed.

After a failed iteration, run `down.sh` anyway. To check nothing is left behind:

```sh
grep -c "/run/user/$UID/vu/" /proc/self/mountinfo   # 0
ls /run/user/$UID/vu                          # absent
pgrep -a qs                                   # only the live "qs -c ummitos"
```

## Helpers

| Script | What it does |
|---|---|
| `scripts/up.sh` | Start the stack; records PIDs and the environment in `$STACK/stack.env`. |
| `scripts/doctor.sh` | Read-only health check; exit 0 = drivable. |
| `scripts/ipc.sh` | `qs -c ummitos-test ipc call …` inside the stack. |
| `scripts/run.sh` | Run any command with the stack environment. |
| `scripts/shot.sh` | `grim -o VERIFY` into the run's evidence folder, with a 10 s timeout. |
| `scripts/down.sh` | Tear down only what this stack started; keeps the evidence. |
| `scripts/env.sh` | Sourced by the others: paths, IDs, and `in_stack`. |

## Features

See `features/README.md`. Keep it current with `/maintain-verification-skill`.
