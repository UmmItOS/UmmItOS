------------------------- MODULE DisplaysModel -------------------------
(* The display chooser's undo protocol in configs/quickshell/displays/Displays.qml.
   QML runs one handler at a time on one event loop, so each action below is one
   handler, taken whole. Line numbers are Displays.qml at the sync commit in SKILL.md.
   A "layout" is the whole set of outputs and their modes: "orig" is what the user had
   before the first change, "chg" is anything the chooser switched to. *)

EXTENDS Naturals

CONSTANTS
    ChildSurvives, \* TRUE: when the shell dies, the hyprctl it had started still finishes
    Seconds,       \* Theme.duration.displayConfirm / extraLarge: ticks to keep a change (15 in the code)
    MaxApplies     \* picks per run

VARIABLES
    shellAlive, open,
    snap,        \* root.snapshot !== null (root.confirming)
    snapLayout,  \* what root.snapshot holds: the layout `seen` showed when it was taken
    remaining,   \* root.remaining
    running,     \* runner Process: "none" | "apply" | "revorig" | "revchg" (a revert to that layout)
    queued,      \* root.queued, with the same values
    layout,      \* what Hyprland really has
    seen,        \* root.outputs: what the shell last read from `hyprctl monitors`
    fileExists,  \* root.undoFile exists
    fileContent, \* the layout that file restores
    age,         \* ticks since the file was written, capped at Seconds
    wd,          \* the detached rescue(): for each one, ticks left before it looks at the file
    applies, crashes,
    kept         \* ghost: the user pressed Keep, so the change is meant to stay

vars == <<shellAlive, open, snap, snapLayout, remaining, running, queued, layout, seen,
          fileExists, fileContent, age, wd, applies, crashes, kept>>

Min(a, b) == IF a < b THEN a ELSE b
Max(a, b) == IF a > b THEN a ELSE b
Effect(c) == IF c = "revorig" THEN "orig" ELSE "chg"
Layouts == {"orig", "chg"}
Cmds == {"none", "apply", "revorig", "revchg"}

Init ==
    /\ shellAlive = TRUE /\ open = FALSE
    /\ snap = FALSE /\ snapLayout = "orig" /\ remaining = 0
    /\ running = "none" /\ queued = "none"
    /\ layout = "orig" /\ seen = "orig"
    /\ fileExists = FALSE /\ fileContent = "orig" /\ age = 0 /\ wd = {}
    /\ applies = 0 /\ crashes = 0 /\ kept = FALSE

\* run(lua), Displays.qml:49: start it, or park it in `queued` (the latest wins) while the runner is busy.
Run(c) ==
    IF running = "none" THEN running' = c /\ queued' = queued
    ELSE queued' = c /\ running' = running

\* revert(), Displays.qml:170: drop the snapshot and run() the restore. The file stays
\* until the restore has run (RunnerDone).
Revert ==
    IF snap
    THEN /\ snap' = FALSE
         /\ Run(IF snapLayout = "orig" THEN "revorig" ELSE "revchg")
         /\ UNCHANGED fileExists
    ELSE UNCHANGED <<snap, fileExists, running, queued>>

\* onOpenChanged, Displays.qml:189: opening refreshes `seen`.
Open ==
    /\ shellAlive /\ ~open
    /\ open' = TRUE /\ seen' = layout
    /\ UNCHANGED <<shellAlive, snap, snapLayout, remaining, running, queued, layout,
                   fileExists, fileContent, age, wd, applies, crashes, kept>>

\* onOpenChanged, Displays.qml:189 (Escape, IPC close, click outside): closing reverts.
Close ==
    /\ shellAlive /\ open
    /\ open' = FALSE /\ Revert
    /\ UNCHANGED <<shellAlive, snapLayout, remaining, layout, seen, fileContent, age, wd,
                   applies, crashes, kept>>

\* apply(mode), Displays.qml:150: ignored while a command is running or queued (or a
\* read is under way, which RunnerDone treats as already done); otherwise snapshot only
\* if none is held, write the file and start the watchdog, then run the change. (The
\* early return for the same mode is not modelled; picking any card is allowed.)
Apply ==
    /\ shellAlive /\ open /\ ~kept /\ applies < MaxApplies
    /\ running = "none" /\ queued = "none"
    /\ snap' = TRUE
    /\ snapLayout' = IF snap THEN snapLayout ELSE seen
    /\ fileContent' = IF snap THEN snapLayout ELSE seen
    /\ remaining' = Seconds /\ fileExists' = TRUE /\ age' = 0
    /\ wd' = wd \cup {Seconds}
    /\ applies' = applies + 1
    /\ Run("apply")
    /\ UNCHANGED <<shellAlive, open, layout, seen, crashes, kept>>

\* keep(), Displays.qml:163: drop the snapshot, remove the file, close.
Keep ==
    /\ shellAlive /\ snap
    /\ snap' = FALSE /\ fileExists' = FALSE /\ kept' = TRUE /\ open' = FALSE
    /\ UNCHANGED <<shellAlive, snapLayout, remaining, running, queued, layout, seen,
                   fileContent, age, wd, applies, crashes>>

\* runner.onExited, Displays.qml:222: refresh `seen`, then start what was queued; with
\* nothing queued and no change being confirmed, the file is no longer needed.
RunnerDone ==
    /\ shellAlive /\ running # "none"
    /\ layout' = IF running = "apply" THEN "chg" ELSE Effect(running)
    /\ seen' = IF running = "apply" THEN "chg" ELSE Effect(running)
    /\ running' = queued /\ queued' = "none"
    /\ fileExists' = IF queued = "none" /\ ~snap THEN FALSE ELSE fileExists
    /\ UNCHANGED <<shellAlive, open, snap, snapLayout, remaining, fileContent,
                   age, wd, applies, crashes, kept>>

\* One second passes (only while no hyprctl is mid-call): the Timer at Displays.qml:200
\* counts down and reverts at 0; the file ages; each watchdog's sleep runs down.
Tick ==
    /\ running = "none"
    /\ age' = Min(age + 1, Seconds)
    /\ wd' = {Max(e - 1, 0) : e \in wd}
    /\ IF shellAlive /\ snap
       THEN /\ remaining' = remaining - 1
            /\ IF remaining - 1 <= 0
               THEN Revert
               ELSE UNCHANGED <<snap, fileExists, running, queued>>
       ELSE UNCHANGED <<remaining, snap, fileExists, running, queued>>
    /\ UNCHANGED <<shellAlive, open, snapLayout, layout, seen, fileContent, applies, crashes, kept>>

\* rescue(), Displays.qml:137: after its sleep, restore from the file if it is at least
\* `Seconds` old, then remove it. Detached: it runs whether or not the shell is alive.
WatchdogFire ==
    /\ 0 \in wd /\ wd' = wd \ {0}
    /\ IF fileExists /\ age >= Seconds
       THEN layout' = fileContent /\ fileExists' = FALSE
       ELSE UNCHANGED <<layout, fileExists>>
    /\ UNCHANGED <<shellAlive, open, snap, snapLayout, remaining, running, queued, seen,
                   fileContent, age, applies, crashes, kept>>

\* The shell dies or is reloaded (every edit of the shell hot-reloads it): its state and
\* queue are gone, the file and the detached watchdogs stay. A command already started
\* finishes only if ChildSurvives.
Crash ==
    /\ shellAlive /\ crashes < 1
    /\ shellAlive' = FALSE /\ open' = FALSE /\ snap' = FALSE /\ remaining' = 0
    /\ queued' = "none" /\ running' = "none"
    /\ layout' = IF ChildSurvives /\ running # "none"
                 THEN (IF running = "apply" THEN "chg" ELSE Effect(running))
                 ELSE layout
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<snapLayout, seen, fileExists, fileContent, age, wd, applies, kept>>

\* Component.onCompleted, Displays.qml:182: refresh, then rescue(0, 0): a file left by the
\* shell that ran before is restored at once, whatever its age.
Restart ==
    /\ ~shellAlive /\ shellAlive' = TRUE
    /\ IF fileExists
       THEN layout' = fileContent /\ fileExists' = FALSE /\ seen' = fileContent
       ELSE UNCHANGED <<layout, fileExists>> /\ seen' = layout
    /\ UNCHANGED <<open, snap, snapLayout, remaining, running, queued, fileContent, age, wd,
                   applies, crashes, kept>>

Next == Open \/ Close \/ Apply \/ Keep \/ RunnerDone \/ Tick \/ WatchdogFire \/ Crash \/ Restart

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ shellAlive \in BOOLEAN /\ open \in BOOLEAN /\ snap \in BOOLEAN
    /\ snapLayout \in Layouts /\ remaining \in 0..Seconds
    /\ running \in Cmds /\ queued \in Cmds
    /\ layout \in Layouts /\ seen \in Layouts
    /\ fileExists \in BOOLEAN /\ fileContent \in Layouts /\ age \in 0..Seconds
    /\ wd \subseteq 0..Seconds /\ applies \in 0..MaxApplies /\ crashes \in 0..1 /\ kept \in BOOLEAN

\* A change is on the way or in place, and the user has not kept it.
Pending == ~kept /\ (layout = "chg" \/ running = "apply" \/ queued = "apply")

\* Something that will put the original layout back is armed.
Covered ==
    \/ snap /\ snapLayout = "orig"
    \/ fileExists /\ fileContent = "orig" /\ (wd # {} \/ ~shellAlive) \* a watchdog still pends, or a restart will rescue it
    \/ running = "revorig" \/ queued = "revorig"

\* A change that was not kept is always on its way back, even if the shell dies.
NeverStranded == Pending => Covered

\* What a revert would restore is the layout from before the first change.
SnapshotIsHome == (snap => snapLayout = "orig") /\ (fileExists => fileContent = "orig")

=============================================================================
