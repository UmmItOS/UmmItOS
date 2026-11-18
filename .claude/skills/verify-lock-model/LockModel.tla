---------------------------- MODULE LockModel ----------------------------
(* The lock screen's state machine in configs/quickshell/lock/Lock.qml.
   QML runs one handler at a time on one event loop, so each action below is
   one handler, taken whole. Line numbers are Lock.qml at the sync commit in
   SKILL.md. *)

CONSTANT AllowPreview  \* FALSE: assume nobody calls `lock preview` or `lock alarm` (both IPC only)

VARIABLES
    locked,       \* root.locked
    previewing,   \* root.previewing
    preparing,    \* root.preparing: a capture() is in flight
    then,         \* grab.then: what release2() runs, "none" | "lock" | "preview"
    grab,         \* the grab Process and the picture wait: "idle" | "running" | "loaded"
    unlocking,    \* root.unlocking
    releaseTimer, \* the release Timer is running
    checking,     \* root.checking: a PAM conversation is in flight
    \* Ghost state, not in the code:
    subLocked,    \* root.checkLocked: the PAM check in flight began while locked
    authed,       \* a check submitted during this lock passed PAM
    wantLock      \* lock() was asked for while unlocked or mid-unlock, and the code has not ended locked yet

vars == <<locked, previewing, preparing, then, grab, unlocking, releaseTimer,
          checking, subLocked, authed, wantLock>>

Init ==
    /\ locked = FALSE /\ previewing = FALSE /\ preparing = FALSE
    /\ then = "none" /\ grab = "idle"
    /\ unlocking = FALSE /\ releaseTimer = FALSE /\ checking = FALSE
    /\ subLocked = FALSE /\ authed = FALSE /\ wantLock = FALSE

\* capture(then), Lock.qml:58: preparing = true, start grab with `then`.
StartCapture(t) ==
    /\ preparing' = TRUE /\ grab' = "running" /\ then' = t

\* lock(), Lock.qml:68 (IPC `lock lock`, Super+L, lock.sh, Session menu).
Lock ==
    /\ IF locked /\ unlocking
         THEN \* mid-unlock: stop release, stay locked
              /\ releaseTimer' = FALSE /\ unlocking' = FALSE /\ authed' = FALSE /\ wantLock' = FALSE
              /\ UNCHANGED <<locked, previewing, preparing, then, grab, checking, subLocked>>
         ELSE IF locked
           THEN UNCHANGED vars
         ELSE IF preparing
           THEN \* a preview's capture in flight ends as this lock: grab.then = take
                /\ then' = "lock" /\ wantLock' = TRUE
                /\ UNCHANGED <<locked, previewing, preparing, grab, unlocking, releaseTimer, checking, subLocked, authed>>
           ELSE /\ StartCapture("lock")
                /\ wantLock' = TRUE
                /\ UNCHANGED <<locked, previewing, unlocking, releaseTimer, checking, subLocked, authed>>

\* preview(), Lock.qml:93 (IPC `lock preview`, and `lock alarm`).
Preview ==
    AllowPreview /\
    IF previewing
      THEN /\ previewing' = FALSE
           /\ UNCHANGED <<locked, preparing, then, grab, unlocking, releaseTimer, checking, subLocked, authed, wantLock>>
      ELSE IF ~preparing
        THEN /\ StartCapture("preview")
             /\ UNCHANGED <<locked, previewing, unlocking, releaseTimer, checking, subLocked, authed, wantLock>>
        ELSE UNCHANGED vars

\* release2(), Lock.qml:115: preparing = false, run then. For a lock, take() also stops release and clears unlocking.
Release2Body ==
    /\ preparing' = FALSE /\ grab' = "idle" /\ then' = "none"
    /\ locked' = (locked \/ then = "lock")
    /\ previewing' = (previewing \/ then = "preview")
    /\ authed' = IF then = "lock" THEN FALSE ELSE authed
    /\ wantLock' = IF then = "lock" THEN FALSE ELSE wantLock
    /\ releaseTimer' = IF then = "lock" THEN FALSE ELSE releaseTimer
    /\ unlocking' = IF then = "lock" THEN FALSE ELSE unlocking

\* grab onExited with a non-zero code, Lock.qml:170: release2() at once.
GrabFail ==
    /\ grab = "running"
    /\ Release2Body
    /\ UNCHANGED <<checking, subLocked>>

\* grab onExited with 0, Lock.qml:170: captured, waitLimit started.
GrabOk ==
    /\ grab = "running"
    /\ grab' = "loaded"
    /\ UNCHANGED <<locked, previewing, preparing, then, unlocking, releaseTimer, checking, subLocked, authed, wantLock>>

\* readyCheck() (Lock.qml:103) once the pictures load, or waitLimit (Lock.qml:202): release2().
Ready ==
    /\ grab = "loaded"
    /\ Release2Body
    /\ UNCHANGED <<checking, subLocked>>

\* submit(), Lock.qml:122: checkLocked = locked. From the password field of LockContent, drawn while locked or previewing.
Submit ==
    /\ (locked \/ previewing) /\ ~checking
    /\ checking' = TRUE /\ subLocked' = locked
    /\ UNCHANGED <<locked, previewing, preparing, then, grab, unlocking, releaseTimer, authed, wantLock>>

\* pam onCompleted with a failure, or onError: fail(), Lock.qml:133.
PamFail ==
    /\ checking
    /\ checking' = FALSE
    /\ UNCHANGED <<locked, previewing, preparing, then, grab, unlocking, releaseTimer, subLocked, authed, wantLock>>

\* pam onCompleted with PamResult.Success, Lock.qml:239: unlocking and release restarted, only when checkLocked matches locked.
PamSuccess ==
    /\ checking
    /\ checking' = FALSE
    /\ IF subLocked = locked
         THEN /\ unlocking' = TRUE /\ releaseTimer' = TRUE
              /\ authed' = (authed \/ (subLocked /\ locked))
         ELSE UNCHANGED <<unlocking, releaseTimer, authed>>
    /\ UNCHANGED <<locked, previewing, preparing, then, grab, subLocked, wantLock>>

\* release Timer onTriggered, Lock.qml:216: unlock.
ReleaseFire ==
    /\ releaseTimer
    /\ locked' = FALSE /\ previewing' = FALSE /\ unlocking' = FALSE /\ releaseTimer' = FALSE
    /\ UNCHANGED <<preparing, then, grab, checking, subLocked, authed, wantLock>>

User   == Lock \/ Preview \/ Submit
System == GrabFail \/ GrabOk \/ Ready \/ PamFail \/ PamSuccess \/ ReleaseFire

Next == User \/ System

\* The shell's own steps always happen; the person may stop acting at any time.
Spec == Init /\ [][Next]_vars
             /\ WF_vars(GrabOk \/ GrabFail) /\ WF_vars(Ready)
             /\ WF_vars(PamFail \/ PamSuccess) /\ WF_vars(ReleaseFire)

TypeOK ==
    /\ then \in {"none", "lock", "preview"}
    /\ grab \in {"idle", "running", "loaded"}
    /\ preparing = (grab # "idle")

(* Property 1. The lock only opens after the right password was typed into
   this lock. Harm if broken: the desktop opens without anyone authenticating
   at the locked screen. *)
NoUnauthenticatedUnlock == [][locked /\ ~locked' => authed]_vars

(* Property 2. Nothing unlocks while a lock request is still being carried
   out. Harm if broken: closing the lid right after typing the password lets
   the machine sleep unlocked. *)
NoUnlockWhileLockPending == [][~(wantLock /\ locked /\ ~locked')]_vars

(* Property 3. Every lock request is carried out. Harm if broken: Super+L, the
   idle timer or sleep leaves the desktop open. *)
LockRequestHonoured == wantLock ~> ~wantLock

=============================================================================
