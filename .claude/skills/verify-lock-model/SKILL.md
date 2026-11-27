---
name: verify-lock-model
description: Model-check the UmmItOS lock screen's state machine (configs/quickshell/lock/Lock.qml) with TLA+/TLC, so every order of lock, capture, password, PAM and release is checked. Use after any change to Lock.qml's lock(), preview(), capture/release2, submit/fail, the PAM handlers or the release Timer, or to anything that calls Lock.lock().
---

# verify-lock-model

The lock screen promises that the desktop opens only after the right password is typed into the lock that is showing, and that every lock request ends locked. Both depend on the order in which a handful of events arrive, which tests and screenshots rarely reach. `LockModel.tla` describes the lock's state machine, and TLC tries every order of its steps.

## The properties

| Name | In plain words | Harm if broken |
|---|---|---|
| `NoUnauthenticatedUnlock` | `locked` goes from true to false only after a password submitted during this lock passed PAM | the desktop opens without anyone authenticating at the screen that is showing |
| `NoUnlockWhileLockPending` | nothing unlocks while a lock request is still being carried out | closing the lid right after typing the password lets the machine sleep unlocked |
| `LockRequestHonoured` | every lock request is carried out | Super+L, the idle timer or sleep leaves the desktop open |

Two scopes: **regression** (`AllowPreview = FALSE`, nobody calls `lock preview` or `lock alarm`, both IPC only) and **full** (`AllowPreview = TRUE`).

## Run it

```sh
.claude/skills/verify-lock-model/check.sh
```

It needs `java` (any recent JRE). The first run downloads TLC (`tla2tools.jar` v1.8.0) to `~/.cache/ummitos-tla/` and checks its pinned sha256. Each of the 6 runs (2 scopes × 3 properties) takes about a second. Each line says `holds`, `known finding Fn`, or `NEW VIOLATION` with the action sequence; the full trace of a violation is in `/tmp/verify-lock-model/<scope>-<property>.trace`. Exit 0 means no new violation, 1 a new one, 2 a missing tool.

`check.sh <file.tla>` checks another copy of the model, for trying a change before you write it.

## Coverage

Covered, with the line numbers the model's comments cite:

- `configs/quickshell/lock/Lock.qml`: `lock()` (67) and its `take` callback, `capture()` (57), `preview()` (90), `readyCheck()` (100), `release2()` (112), `submit()` (119), `fail()` (130), grab `onExited` (167), `waitLimit` (199), the `release` Timer (213), PAM `onCompleted`/`onError` (236, 251), `checkLocked`, the `lock` IpcHandler.
- `configs/quickshell/lock/LockContent.qml`: the password field's Return calls `Lock.submit()` whenever the lock or the preview shows; nothing disables it while `unlocking`.

**Sync commit: `83a89ed`.** At that commit the model describes the files above. Move it forward only after you have read every change to them since this commit and confirmed the model still describes them.

How the model maps the code:

- Each action is one QML handler taken whole. QML runs handlers one at a time on one event loop, so nothing else can run inside one.
- `grab` stands for the capture Process and the picture wait: `running` from `capture()` to `onExited`, `loaded` from a successful exit until `readyCheck()` or `waitLimit` calls `release2()`.
- `checking` is a PAM conversation in flight. `PamSuccess` is `onCompleted` with `PamResult.Success`; `PamFail` covers any other result and `onError`.
- `subLocked` is `root.checkLocked`. Ghost variables, not in the code: `authed` (a check submitted during this lock passed), `wantLock` (a lock request is not carried out yet).

Not covered: Quickshell's `WlSessionLock` and the compositor (the model trusts that `locked = true` puts the lock surface up), a hot reload or a crash (Lock.qml fails closed there, see `.claude/rules/shell-features.md`), `lock.sh` and hypridle (outside the shell), the intruder alarm and camera, the wake curtain's picture reuse, timing (the model has no clock: the 500 ms release and the 300 ms picture wait are only "later").

## Fixed findings

`known-findings.txt` is empty: every property holds in both scopes. These three were found by this check at `57e5a43` and fixed in `d19ac08`; each was replayed step by step against the code first. All needed someone who had just typed the correct password or a preview opened by IPC.

- **F1** (`NoUnauthenticatedUnlock`). A second correct password inside the 500 ms unlock re-armed `release` after the unlock, and a Super+L inside the next 500 ms was opened by it. Fixed: `take` stops `release` and clears `unlocking` when the lock takes hold.
- **F2** (`NoUnauthenticatedUnlock`). A password checked in the preview, with a real `lock()` arriving before PAM answered, opened the real lock. Fixed: `onCompleted` unlocks only when `checkLocked` equals `locked`.
- **F3** (`LockRequestHonoured`). `lock()` during a preview's capture returned at `if (locked || preparing)` and the request was lost. Fixed: it sets `grab.then = take`, so the capture ends as the lock. Shown by the model only: in the test stack two IPC calls are slower than the capture, so the old code locked too.

Removing any one of the three fixes from a copy of the model brings back a violation (checked 2026-11-18).

## When you change Lock.qml

1. Does the change touch a covered handler, add a path that writes `locked`, `previewing`, `unlocking`, `checking` or `preparing`, or add a caller of `Lock.lock()`/`Lock.submit()`? If not, record nothing; move the sync commit only when you next confirm the whole model.
2. Update `LockModel.tla` from the code first: one action per handler, same guards, same assignments, line comments updated. Do not shape it by the result.
3. Run `check.sh`.
4. Change a property only when the code's promise changed on purpose, with evidence (commit message, comment, the owner's request). Write the old and new wording in the commit message.
5. Update the line numbers and the sync commit here.

## Reading a result

Read every result with the `/statechart` skill: it turns a violation into its shortest path in plain words, and draws the state chart of a passing model.

For a `NEW VIOLATION`, replay each step against the code. If a step cannot happen in Lock.qml (a guard the model lacks, two handlers the model merged, an assignment it misses), the model is wrong: fix the model, not the property. If every step can happen, it is a bug: tell it as steps in the code's words, name the commit that introduced it, and do not weaken the property to make it pass. Product fixes go in their own commit.

A check you have never seen fail proves nothing: after a model change, break the matching code path in a scratch copy of the model (`check.sh /tmp/x.tla`) and confirm a property catches it. Proven on 2026-11-18: removing the mid-unlock branch of `lock()` (Lock.qml:66-72) gives `NoUnlockWhileLockPending` violated by `Lock GrabFail Submit PamSuccess Lock ReleaseFire`. Re-proven 2026-11-27. Keep the ghost in the broken branch (`wantLock' = TRUE`, everything else unchanged): dropping the ghost too makes every property blind to the lost request, and the broken copy then passes.
