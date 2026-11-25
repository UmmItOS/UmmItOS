---
name: verify-displays-model
description: Model-check the display chooser's undo protocol (configs/quickshell/displays/Displays.qml) with TLA+/TLC, so every order of pick, close, keep, timer, queued command, shell reload and detached watchdog is checked. Use after any change to Displays.qml's apply(), keep(), revert(), run(), rescue(), forget(), the Timer, the runner Process or Component.onCompleted, or to anything in DisplaysWindow.qml that calls Displays.apply/keep/revert.
---

# verify-displays-model

The display chooser (Super+P) changes the monitors at runtime and promises to put them back unless the user presses Keep. A wrong layout can leave the screen black, so the promise has to hold even when the shell is reloaded or dies in the middle. It rests on four things that run at different times: a one-second Timer in the shell, a revert file in `$XDG_RUNTIME_DIR`, a detached `sleep` process that applies that file after 15 s, and one command runner that queues. The model checks every order of those.

## The properties

| Name | In plain words | Harm if broken |
|---|---|---|
| `NeverStranded` | while a change is in place or on its way and was not kept, something that restores the original layout is armed: the shell's snapshot, the revert file with a watchdog or a restart to read it, or a restore already running or queued | the monitors stay in the changed layout (for example only an unplugged screen on) with nothing left to undo it |
| `SnapshotIsHome` | whatever a revert would restore is the layout from before the first change | "reverting" lands in a changed layout, and the user's real layout is gone until they rebuild it by hand |

Two scopes, for one unknown: when the shell dies, does the `hyprctl` it already started still finish? **`childlives`**: yes (tested 2026-11-25: a `Process` child of `qs -p` survived `kill -9` of qs). **`childdies`**: no. A hot reload of the shell may behave like either; that is untested.

## Run it

```sh
.claude/skills/verify-displays-model/check.sh
```

It needs `java` (any recent JRE). The first run downloads TLC (`tla2tools.jar`, tag `v1.8.0`) to `~/.cache/ummitos-tla/` and checks its pinned sha256. The tag is a rolling prerelease, so a new upload changes the hash: before changing `sum` in `check.sh`, compare it with GitHub's own digest, `gh api repos/tlaplus/tlaplus/releases/tags/v1.8.0 --jq '.assets[] | select(.name=="tla2tools.jar") | .digest'`. The 4 runs (2 scopes × 2 properties) take about 3 s. Each line says `holds`, `known finding F<n>`, or `NEW VIOLATION: <actions>` with a trace file under `/tmp/verify-displays-model/`. Exit 0 means no new violation. `check.sh <file.tla>` checks another copy of the model, for trying a change before you write it.

Bounds: 2 picks, 1 shell death per run, `Seconds` = 2 ticks (the code uses 15; only the order matters). A pass covers these bounds and the assumptions below, not the whole system.

## Coverage

Covered, with the line numbers the model's comments cite:

- `configs/quickshell/displays/Displays.qml`: `refresh()` (42), `run()` (49), `rescue()` (137), `sweep()` (142), `forget()` (146), `apply()` (150), `keep()` (163), `revert()` (170), `Component.onCompleted` (182), `onOpenChanged` (189), the Timer (200), `runner.onExited` (222), and the hardware-changed revert in `reader` (275).
- `configs/quickshell/displays/DisplaysWindow.qml`: Escape and the outside click set `Displays.open = false` (97, 105), which reverts; Revert and Keep buttons (474, 484); card clicks and keys call `Displays.apply` (116, 189, 286).
- `configs/quickshell/background/Background.qml:46` opens the panel.

**Sync commit: `0711303`.** At that commit the model describes the files above. Move it forward only after you have read every change to them since this commit and confirmed the model still describes them.

How the model maps the code:

- Each action is one QML handler taken whole (QML runs one at a time). `Tick` is one second: the Timer's count-down, the file's age, and each watchdog's `sleep`.
- `layout` is what Hyprland really has; `seen` is `root.outputs`, the shell's cached read. `snapLayout` is what `root.snapshot` holds. `fileContent` is what the revert file restores. `"orig"` is the layout before the first change, `"chg"` any changed one.
- `running` and `queued` are the runner Process and `root.queued` (the latest queued command wins, as in `run()`). `revorig` and `revchg` are restores to those two layouts.
- `wd` holds one entry per detached `rescue()`; a fired one restores only if the file exists and is at least `Seconds` old.
- `Crash` is the shell dying or reloading: state and queue are lost, the file and the watchdogs stay.
- Ghost variable, not in the code: `kept` (the user pressed Keep, so the change is meant to stay).

Assumptions (each is a way the real system could differ):

- A `hyprctl` call finishes within one second (`Tick` waits for the runner to be idle).
- The detached `rm` from `forget()` finishes before anything else happens; a new pick within milliseconds of Keep could in theory have its new file removed by the old `rm`.
- `seen` is refreshed the moment a runner command ends and when the panel opens; the real refresh is a second process, so there is a short extra gap.
- Only a pick changes the layout; the model has one changed layout, so which of the four modes was picked does not matter.

Not covered: whether `planFor()` and `restorePlan()` ever produce a plan with every output off, or a mirror of an output that is off (a second target: they are pure functions that a script could lift out and run over every small set of outputs); Hyprland's own behaviour for the Lua `hl.monitor` calls; the panel's cards, animation and text.

## Findings

All four were replayed step by step against `Displays.qml` and can happen. None needs more than normal use plus a shell reload, except F2. They are listed in `known-findings.txt`; delete a line once its bug is fixed. A model of the fixed design (below) holds, so the properties are reachable.

- **F1** (`NeverStranded`). Pick a layout, then close the panel at once (Escape) while the apply `hyprctl` is still running, then the shell reloads or dies before that call ends. `revert()` has already deleted the revert file (`forget()`, line 175) and its restore is only queued behind the apply (`run()` stores it in `root.queued`, line 51). The reload loses the queued restore; the apply finishes; no file is left for the watchdog. The monitors stay changed. Window: the length of one `hyprctl` call plus a reload in it.
- **F2** (`NeverStranded`, `childdies` only). The same, with the restore already started when the shell dies. It happens only if a reload kills a running `hyprctl`. `kill -9` does not (tested), a hot reload is untested.
- **F3** (`SnapshotIsHome`). `apply()` takes `root.outputs` as the layout to return to (line 155), and `root.outputs` is a cache that a revert in flight has not updated. Pick, let the Timer revert (or Escape), and pick again before that restore ends and the reader refreshes: the new snapshot and revert file hold the changed layout, so after 15 s without Keep the "revert" lands in it. The same cache goes stale in two longer-lived ways, both seen as counterexamples of a fixed variant of the model: (a) after a shell reload during the 15 s, the changed layout is still on screen, and a pick before the watchdog fires snapshots it and overwrites the revert file with it; (b) the watchdog (or anything outside the runner) restores the layout under an open panel, and nothing refreshes the cache, so the next pick snapshots the old changed layout.
- Root cause of F1 and F3: the recovery is dropped or overwritten before it has finished its job. A design that passes both properties in both scopes (checked 2026-11-25 on a scratch copy): remove the revert file only when the restore has run (in `runner.onExited`), refuse a pick while a command runs or is queued, and take the snapshot from the revert file if one exists, otherwise from a fresh read.

## When you change Displays.qml

1. Does the change touch a covered handler, add a path that writes `snapshot`, `queued`, the revert file or the `rescue()` process, or add a caller of `Displays.apply/keep/revert`? If not, record nothing; move the sync commit only when you next confirm the whole of the covered code at it.
2. Update `DisplaysModel.tla` from the code first: one action per handler, same guards, same assignments, line comments updated. Do not shape it by the result.
3. Run `check.sh`.
4. Change a property only when the code's promise changed on purpose, with evidence (commit message, comment, the owner's request). Write the old and new wording in the commit message.
5. Update the line numbers and the sync commit here.

## Reading a result

Read every result with the `/statechart` skill: it turns a violation into its shortest path in plain words, and draws the state chart of a passing model.

For a `NEW VIOLATION`, replay each step against `Displays.qml`. If a step cannot happen (a guard the model lacks, two handlers the model merged, an assignment it misses), the model is wrong: fix the model, not the property. If every step can happen, it is a bug: name the commit that introduced it, tell the counterexample in the code's words, state the harm in one sentence, add a line to `known-findings.txt` and a bullet under Findings. Do not edit product code unless the owner asks.

A fixed bug leaves a known line that no longer matches: `check.sh` will then print `holds`; delete the line.

A check you have never seen fail proves nothing. Proven on 2026-11-25, on a scratch copy of a model with the fixes above applied: dropping the watchdog's entry in `Apply` fails `NeverStranded` with `Open Apply Crash Restart`; not writing the file in `Apply` fails it with `Open Apply Crash`; deleting the file in `Revert` again fails it with `Open Apply Close Crash`. After a model change, repeat one of these on a scratch copy (`check.sh /tmp/x.tla`) and confirm the property still catches it.
