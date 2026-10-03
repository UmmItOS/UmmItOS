# Feature checklist

Go through this before a feature, fix or change to the shell is committed. The rules it points to live in [CLAUDE.md](CLAUDE.md).

## 1. Programming

- [ ] **Review the code with `/qt-development-skills:qt-qml`** while writing it, and **`/qt-development-skills:qt-qml-review`** before committing: bindings, layouts, loaders, delegates, states, performance.
- [ ] **Keep it simple (`/ponytail:ponytail`).** Reuse a shared component or helper before writing a new one (`Surface`, `Flyout`, `FlyoutRow`, `Action`, `Segmented`, `Toggle`, `Slider`, `Spinner`, `MaterialIcon`, `Reveal`, `MotionBlur`, `OverlayWindow`). No options nobody asked for; delete what nothing uses.
- [ ] **Hunt the bugs.** Trace every path the change touches:
  - empty and null states, and races between processes and timers
  - reloads (lost IPC, reset singletons), sleep and wake, more than one monitor
  - anything that could leave the screen blocked or a state stuck
  - every item in "Traps found the hard way" in CLAUDE.md
- [ ] **Every object body keeps the QML order** (children recursively): `id`; properties and aliases, then signals; functions, then signal and lifecycle handlers; the item's own geometry and styling; states, transitions and `Behavior`s; `delegate:` and inline `component` declarations after the item's own styling; child elements last. Logic never sits between children, and nothing but children sits at the bottom.
- [ ] **Text goes through `I18n.t()`,** with the key added to every language file.
- [ ] **Comments are one short line,** and only for a why the code cannot show: a trap, a workaround, a reason for a number. No history, no restating the code.
- [ ] **Scripts pass `shellcheck`.**

## 2. UI and UX

- [ ] **Review the look with `/hallmark`** (the `audit` verb). The house design system wins over generic advice:
  - every value is a `Theme` token: no magic numbers, no borders
  - text is readable: `accentOn` on accent fills, nothing that hides meaning is cut off
  - every state is designed: empty, loading, error, disabled
- [ ] **Motion is included, not added later.** Anything that appears, leaves, moves or changes state ships with its animation in the same change. A thing that snaps in, pops out or jumps is unfinished.
  - **Arrivals** slide or scale in, fade, and sharpen out of a blur, all at once. Full-screen surfaces get this from `OverlayWindow`; anything else sets `layer.enabled: opacity < 1` with a `MotionBlur` effect and a fade from 0. Leaving plays it in reverse.
  - **Timing and easing come from `Theme`** (`duration.*`, `curve.*`). Position, scale, size and rotation always ease, never linear: `emphasizedDecel` arriving, `emphasizedAccel` leaving, `expressiveDefaultSpatial` (a small overshoot) only where a surface lands. Data and plain state changes do not overshoot. Fades and colour changes may be linear.
  - **Lists animate their changes:** a `ListView` with `add`, `remove` and `displaced` transitions over a `ScriptModel`, never a plain JS array that rebuilds every row.
  - **Every control answers the pointer:** a hover colour, `Theme.pressScale` on press, both animated, and a pointing-hand cursor.
  - **Live status breathes gently:** a small halo (about 1.8× at 0.35 opacity, `duration.glow`), only while on screen and not behind the lock.
  - **Animate transforms, not geometry** (`Scale`, `Translate`, opacity). Gate a `Behavior` so the first value does not animate; stop loops nothing shows. A new duration or curve is a new `Theme` token.
  - This is the shell's own motion. Hyprland's window animations (`animations.lua`) are the owner's choice; do not retune them to match.

## 3. Bigger changes

For anything larger than a small fix, run the reviews above as parallel subagents, then check each finding in the code before acting on it. The same fan-out does the fixing:

- [ ] **Split by files.** Each fix agent owns its own files. Only one agent at a time writes `Theme.qml`, and token passes come after the fix waves.
- [ ] **Agents don't commit, and never run `qs -c ummitos` or `qs ipc`.** They read `qs log -c ummitos` and qmllint. Whoever coordinates reviews each diff, checks the surface on screen, and commits per area.
- [ ] **Nothing half-done stays in the tree.** If an agent stops mid-edit, revert its files (`git checkout -- <paths>`) and run it again, above all anything under `lock/`.

## 4. Done means checked

- [ ] `qs log -c ummitos` shows a fresh `Configuration Loaded` with no new warning.
- [ ] qmllint is clean on the touched files: no unqualified access, no unused imports. The `Theme` "member not found" warnings are known false ones.
- [ ] The changed surface was seen in a screenshot or recording.
- [ ] Anything that could not be clicked from a terminal is said plainly.
- [ ] Committed straight to `master` with a Conventional Commits message.
