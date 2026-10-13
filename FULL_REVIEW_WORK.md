# Full review

When this file is mentioned (`@FULL_REVIEW_WORK.md`), run a full review of the work in scope, following the steps below. The rules being reviewed against live in [CLAUDE.md](CLAUDE.md) and [CHECKLIST.md](CHECKLIST.md); this file only says how to run the review.

## 1. Pick the scope

- If the request names files, a feature or a commit range, review that.
- Otherwise review everything not yet pushed: `git log origin/master..HEAD` plus any uncommitted changes.
- Say the scope in one line before starting: the commit range, the number of commits and the number of files.
- Leave out `.wallpaper/`, `resources/` and binary files (`.ogg`, `.qsb`, images).

## 2. Run the five lenses in parallel

Start one subagent per lens, all at once. Every agent gets the same rules:

- Read CLAUDE.md (above all "Traps found the hard way") and CHECKLIST.md first.
- **Read only.** Never edit or commit.
- Never run `qs -c ummitos` or `qs ipc`.
- Never run `wipe-traces.sh` without `--list`, or `intruder.sh`, or `doctor.sh --fix`.
- Check APIs against the installed type definitions (`/usr/lib/qt6/qml/Quickshell/`, `/usr/lib/qt6/qml/Qt*`), not online docs.
- Report only what it verified by reading the code. Each finding gives `file:line`, the issue, a concrete failure scenario, a fix, a severity and a confidence.
- Write the findings to the scratchpad, never into the repo.

| Lens | Looks for |
|---|---|
| **Ponytail (ultra)** (`/ponytail:ponytail-review` on the scope's diff; `/ponytail:ponytail-audit` instead when the scope is the whole codebase; `/ponytail:ponytail-debt` for the ledger of `ponytail:` comments, each one checked for whether its stated limit is now reached) | Code that need not exist. Helpers re-written when a shared one exists (`Surface`, `Flyout`, `FlyoutRow`, `Action`, `Segmented`, `Toggle`, `Tip`, `Reveal`, `MotionBlur`, `OverlayWindow`, `SettingRow`, `SettingsList`). The same logic in two places that can drift apart. Unused properties, Theme tokens and i18n keys (grep every one). Comments that restate the code. |
| **QML** (`/qt-development-skills:qt-qml-review`) | Broken bindings and binding loops. `Behavior` firing on first assignment. Repeater where a ListView + ScriptModel should animate. `itemAt()` in bindings. Layout misuse. Loader, Process and camera lifetimes: do they stop on unlock, reload and failure? Processes duplicated per screen. Missing `qmldir` entries. Unqualified access. The CHECKLIST property order. Polling while hidden. Animated geometry. Run `qmllint` on the touched files. |
| **Hallmark** (`/hallmark audit`) | Magic numbers instead of `Theme` tokens. Borders. Contrast. Every state designed: empty, loading, error, disabled. Motion as CHECKLIST section 2 lists it. Every control has a hover colour, `Theme.pressScale` and a pointing-hand cursor. Text through `I18n.t()`, with the key in both `zh-HK.json` and `zh-TW.json`. Copy that is honest and short. The house design system wins over generic web advice. |
| **Security audit** (`/security-audit`, guidance mode) | A trust boundary that a lower-trust principal can cross in the scope: other local users, a person at the lock screen, nearby Wi-Fi and Bluetooth devices, notification senders over D-Bus, tray apps, QR and clipboard content, web pages handed to `xdg-open`, the `greeter` user, and the git, AUR and weather sources the installer and shell trust. Each finding names the principal, the input, the control that should stop it, the boundary crossed and the concrete result; a missing best practice with no affected principal is a hardening note, not a finding. Source only: no repo code runs unless the skill's full sandbox can be enforced. |
| **Bugs and security** | Empty and null states. Races between processes and timers. Reloads, sleep and wake, more than one monitor. Anything that can block the screen or leave a state stuck (the lock screen first). Shell injection in every `Process` and `sh -c`. Parsing of tool output (`nmcli -t`, `iw`, `bluetoothctl`, `zbarimg`). Secrets kept in memory, logs or notices. File permissions. Every new stored trace has a `wipe_<name>` and an Anti-forensics card. Run `shellcheck` on changed scripts. |

For a whole-codebase security audit, or when the request asks for one, run `/security-audit` in its full audit mode instead of the lens: all six phases, with its reports written outside the repo (`~/security-audit-skill/UmmItOS/run-<N>`), never into it.

Add a lens when the scope needs one; for example, the installer (`UMMITOS_DRY_RUN=1` only), or the Hyprland config (`Hyprland --verify-config`).

## 3. Verify, merge, rank

- **Check every finding in the code yourself** before keeping it. Agents miss things that already exist: a component that translates its own label, a list that already animates.
- Merge duplicates found by more than one lens, and say which lenses found each.
- Rank them:
  - **High:** a privacy or security hole, a stuck state, data loss, or something the user sees broken.
  - **Medium:** a real bug in a less common path, a broken rule from CLAUDE.md, or drift between two copies.
  - **Low:** a fix to make when next touching the file.
- Keep a short list of claims that did not hold up and why, so they are not raised again.

## 4. Report

Reply in the conversation, not in a file:

1. The scope, in one line.
2. The **High** and **Medium** findings, each with `file:line`, what goes wrong and the fix.
3. The **Low** ones as a table.
4. What was checked and found clean, in a few bullets.
5. The dropped claims.
6. What was not covered (nothing seen on screen; files read only in part).
7. One next step, for example "say **fix High**".

Do not fix anything until asked. When asked, fix by area: one commit per finding or per file group, each checked as CHECKLIST.md section 4 says.
