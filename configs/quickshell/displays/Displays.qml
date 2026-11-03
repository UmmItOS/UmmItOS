pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import ".."

// The display chooser's state: the outputs as Hyprland reports them, and runtime-only changes to them that undo themselves unless kept.
Singleton {
    id: root

    property bool open: false
    property var outputs: []
    // The first enabled output when first read; it stays while connected, so "This screen only" never swaps sides once the other one is alone.
    property string primary: ""
    // The outputs as they were before an apply, while the change waits to be kept; null otherwise.
    property var snapshot: null
    // Seconds left to keep a change.
    property int remaining: 0
    // A Lua call that arrived while another was running; the latest wins.
    property string queued: ""
    // A read asked for while another was running.
    property bool stale: false

    // The revert waits here too, so a watchdog that outlives the shell can run it; the signature keeps a restarted compositor from running another session's file.
    readonly property string undoFile: Quickshell.env("XDG_RUNTIME_DIR") + "/ummitos-displays-revert-" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + ".lua"
    readonly property int seconds: Math.round(Theme.duration.displayConfirm / Theme.duration.extraLarge)
    readonly property bool confirming: root.snapshot !== null
    // An output already on comes first: a connected but switched-off one may show nothing.
    readonly property string secondary: (root.outputs.find(o => o.name !== root.primary && !o.disabled) ?? root.outputs.find(o => o.name !== root.primary))?.name ?? ""
    // Derived, never stored: Hyprland is the only source of truth.
    readonly property string mode: {
        if (root.outputs.some(o => o.mirrorOf !== "none"))
            return "mirror";
        const on = root.outputs.filter(o => !o.disabled);
        if (on.length === 1)
            return on[0].name === root.primary ? "single" : "second";
        return "extend";
    }

    function refresh(): void {
        if (reader.running)
            root.stale = true;
        else
            reader.running = true;
    }

    function run(lua: string): void {
        if (runner.running) {
            root.queued = lua;
            return;
        }
        runner.command = ["hyprctl", "eval", lua];
        runner.running = true;
    }

    // Both disabled and mirror are always stated: Hyprland merges a rule into the old one, so a left-out field keeps its old value.
    function rule(e: var): string {
        const head = `output = "${e.name}", disabled = ${e.off}, mirror = "${e.mirror}"`;
        return "hl.monitor({ " + head + (e.off ? "" : `, mode = "${e.mode}", position = "${e.position}", scale = ${e.scale}`) + " })";
    }

    // Outputs staying on come first, then mirrors, then those switching off, so none is ever left with nothing to show it.
    function script(entries: var): string {
        return entries.filter(e => !e.off && e.mirror === "").concat(entries.filter(e => !e.off && e.mirror !== ""), entries.filter(e => e.off)).map(root.rule).join("\n");
    }

    // What an output runs at now; a disabled one reports unusable sizes, so it gets its preferred mode.
    function keepOf(o: var): var {
        return o.disabled ? {
            mode: "preferred",
            scale: o.scale > 0 ? o.scale : 1
        } : {
            mode: o.width + "x" + o.height + "@" + o.refreshRate.toFixed(2),
            scale: o.scale
        };
    }

    function planFor(mode: string): var {
        const plan = root.outputs.map(o => {
            const first = o.name === root.primary;
            const keep = root.keepOf(o);
            return {
                name: o.name,
                off: mode === "single" ? !first : mode === "second" ? o.name !== root.secondary : false,
                mirror: mode === "mirror" && !first ? root.primary : "",
                mode: keep.mode,
                position: mode === "extend" && !first ? "auto-right" : "auto",
                scale: keep.scale
            };
        });
        // Never every output off at once.
        if (plan.length > 0 && plan.every(e => e.off))
            (plan.find(e => e.name === root.primary) ?? plan[0]).off = false;
        return plan;
    }

    // Only for outputs still connected, and never with every one of them off.
    function restorePlan(was: var): var {
        const here = root.outputs.map(o => o.name);
        const plan = was.filter(o => here.includes(o.name)).map(o => {
            const keep = root.keepOf(o);
            return {
                name: o.name,
                off: o.disabled,
                mirror: here.includes(o.mirrorOf) ? o.mirrorOf : "",
                mode: keep.mode,
                position: o.x + "x" + o.y,
                scale: keep.scale
            };
        });
        if (plan.length === 0 && root.outputs.length > 0) {
            const keep = root.keepOf(root.outputs[0]);
            plan.push({
                name: root.outputs[0].name,
                off: false,
                mirror: "",
                mode: keep.mode,
                position: "auto",
                scale: keep.scale
            });
        }
        if (plan.length > 0 && plan.every(e => e.off)) {
            plan[0].off = false;
            plan[0].position = "auto";
        }
        // A mirror of an output that is off or absent from the plan would mirror nothing.
        for (const e of plan) {
            if (!plan.some(t => t.name === e.mirror && t.off === false))
                e.mirror = "";
        }
        return plan;
    }

    // Runs the saved revert after a delay if the file is still there and no newer change refreshed it.
    function rescue(delay: int): void {
        Quickshell.execDetached(["sh", "-c", 'sleep "$1"; f="$2"; [ -f "$f" ] && [ $(( $(date +%s) - $(stat -c %Y "$f") )) -ge "$3" ] && hyprctl eval "$(cat "$f")" && rm -f "$f"', "sh", String(delay), root.undoFile, String(root.seconds)]);
    }

    // Files of other compositor sessions can never apply.
    function sweep(): void {
        Quickshell.execDetached(["sh", "-c", 'for f in "$XDG_RUNTIME_DIR"/ummitos-displays-revert*.lua; do [ "$f" = "$1" ] || rm -f "$f"; done', "sh", root.undoFile]);
    }

    function forget(): void {
        Quickshell.execDetached(["rm", "-f", root.undoFile]);
    }

    function apply(mode: string): void {
        if (root.outputs.length < 2 || mode === root.mode)
            return;
        // Picking again while waiting still reverts to the very first state.
        if (!root.confirming)
            root.snapshot = root.outputs;
        root.remaining = root.seconds;
        // FileView skips a write whose text it already holds; the stamp goes last, since hyprctl reads a leading -- as a flag.
        undo.setText(root.script(root.restorePlan(root.snapshot)) + "\n-- " + Date.now());
        root.rescue(root.seconds);
        root.run(root.script(root.planFor(mode)));
    }

    function keep(): void {
        root.snapshot = null;
        root.forget();
        root.open = false;
    }

    // Safe to call from anywhere and any number of times.
    function revert(): void {
        const was = root.snapshot;
        if (!was)
            return;
        root.snapshot = null;
        root.forget();
        const plan = root.restorePlan(was);
        if (plan.length > 0)
            root.run(root.script(plan));
    }

    // Read once at start, so the first open already knows; a revert left by a crash runs now.
    Component.onCompleted: {
        root.refresh();
        root.sweep();
        root.rescue(0);
    }

    // However it closes, a change not kept is undone.
    onOpenChanged: {
        if (root.open)
            root.refresh();
        else
            root.revert();
    }

    Timer {
        onTriggered: {
            if (--root.remaining <= 0)
                root.revert();
        }

        running: root.confirming
        interval: Theme.duration.extraLarge
        repeat: true
    }

    Connections {
        function onRawEvent(event: var): void {
            if (event.name === "monitoradded" || event.name === "monitorremoved")
                root.refresh();
        }

        target: Hyprland
    }

    Process {
        id: runner

        onExited: {
            root.refresh();
            if (root.queued !== "") {
                const next = root.queued;
                root.queued = "";
                root.run(next);
            }
        }
    }

    Process {
        id: reader

        onExited: {
            if (root.stale) {
                root.stale = false;
                root.refresh();
            }
        }

        command: ["hyprctl", "-j", "monitors", "all"]

        stdout: StdioCollector {
            onStreamFinished: {
                let all;
                try {
                    all = JSON.parse(text);
                } catch (e) {
                    return;
                }
                // The names go into Lua source, so anything odd is left out.
                const list = all.filter(m => /^[A-Za-z0-9_-]+$/.test(m.name));
                // hyprctl names the mirrored source by id.
                const names = {};
                for (const m of list)
                    names[m.id] = m.name;
                root.outputs = list.map(m => ({
                            name: m.name,
                            description: m.description ?? "",
                            width: m.width,
                            height: m.height,
                            refreshRate: m.refreshRate,
                            x: m.x,
                            y: m.y,
                            scale: m.scale,
                            disabled: m.disabled,
                            mirrorOf: m.mirrorOf === "none" ? "none" : (names[m.mirrorOf] ?? String(m.mirrorOf)),
                            focused: m.focused
                        }));
                if (!list.some(m => m.name === root.primary))
                    root.primary = (list.find(m => !m.disabled) ?? list[0])?.name ?? "";
                // A snapshot of other hardware no longer describes it.
                if (root.confirming && root.snapshot.map(o => o.name).sort().join() !== list.map(m => m.name).sort().join())
                    root.revert();
            }
        }
    }

    FileView {
        id: undo

        path: root.undoFile
        printErrors: false
        // Written before the change runs and read by a process that outlives the shell, so never later.
        blockWrites: true
    }

    IpcHandler {
        function toggle(): void {
            root.open = !root.open;
        }

        function close(): void {
            root.open = false;
        }

        target: "displays"
    }
}
