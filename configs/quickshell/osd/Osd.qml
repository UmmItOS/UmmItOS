pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import ".."

// Observes only: the keys already run wpctl and brightnessctl.
Singleton {
    id: root

    property string kind: "volume"
    property string icon: ""
    property string label: ""
    property real value: 0
    property bool muted: false
    property bool shown: false

    // Nothing should flash on screen just because the shell started.
    property bool primed: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null

    // The input method in use, shown when it switches.
    property string glyph: ""
    property string inputName: ""
    // The methods in fcitx's group, in order, and the one in use.
    property var inputs: []
    property int inputIndex: 0
    property string current: ""
    // id, name and label of each method, read once per profile change, so a switch shows at once.
    property var methods: []
    property real focusedAt: 0

    // sysfs backlight emits no reliable inotify events, so the keys ask for a read.
    property real brightnessMax: 1
    property real brightnessRaw: 0
    // amdgpu_bl1 here, intel_backlight elsewhere.
    property string backlight: ""

    // A switch on a card already showing; the window pops the glyph and name.
    signal inputSwitched

    function present(newKind: string, newValue: real, newMuted: bool): void {
        if (!primed)
            return;
        if (newKind !== "app") {
            icon = "";
            label = "";
        }
        kind = newKind;
        // Volume can pass 100%, up to the chosen limit.
        value = Math.max(0, Math.min(newKind === "volume" ? Audio.limit : 1, newValue));
        muted = newMuted;
        shown = true;
        hide.restart();
    }

    function presentApp(iconPath: string, name: string, newValue: real, newMuted: bool): void {
        icon = iconPath;
        label = name;
        present("app", newValue, newMuted);
    }

    function apply(id: string, show: bool): void {
        current = id;
        const method = methods.find(m => m.id === id) ?? {
            id: id,
            name: id,
            label: ""
        };
        const newGlyph = id.startsWith("keyboard-") ? "A" : method.label || (Array.from(method.name)[0] ?? "");
        inputs = methods.length > 0 ? methods.map(m => m.id) : [id];
        const index = Math.max(0, inputs.indexOf(id));
        if (!show || !primed) {
            glyph = newGlyph;
            inputName = method.name;
            inputIndex = index;
            return;
        }
        const appearing = !shown || kind !== "input";
        glyph = newGlyph;
        inputName = method.name;
        kind = "input";
        shown = true;
        hide.restart();
        // A card that just appeared shows the old method's place first, then slides.
        if (appearing) {
            Qt.callLater(() => root.inputIndex = index);
        } else {
            inputIndex = index;
            inputSwitched();
        }
    }

    // Another app's tooltip leaves the method unchanged, so nothing shows.
    function ask(quiet: bool): void {
        exact.quiet = exact.quiet || quiet;
        if (exact.running)
            exact.again = true;
        else
            exact.running = true;
    }

    onSinkChanged: {
        primed = false;
        arm.restart();
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    Timer {
        id: hide

        onTriggered: root.shown = false

        interval: root.kind === "input" ? Theme.duration.imeHide : Theme.duration.osdHide
    }

    Timer {
        id: arm

        onTriggered: root.primed = true

        running: true
        interval: Theme.duration.osdArm
    }

    Connections {
        function onVolumeChanged() {
            root.present("volume", root.audio.volume, root.audio.muted);
        }

        function onMutedChanged() {
            root.present("volume", root.audio.volume, root.audio.muted);
        }

        target: root.audio
        enabled: root.audio !== null
    }

    Connections {
        function onRawEvent(event: var): void {
            if (event.name === "activewindowv2")
                root.focusedAt = Date.now();
        }

        target: Hyprland
    }

    // fcitx signals a switch on key press; the tray model re-reads lazily and would miss a quick switch back.
    Process {
        id: watch

        onStarted: root.ask(true)
        onExited: retry.start()

        running: true
        command: ["dbus-monitor", "--session", "type='signal',interface='org.kde.StatusNotifierItem',member='NewToolTip'"]

        stdout: SplitParser {
            onRead: line => {
                if (line.includes("member=NewToolTip"))
                    root.ask(false);
            }
        }
    }

    Process {
        id: exact

        // The state at start is not a switch.
        property bool quiet: false
        property bool again: false

        // A switch that came while this read ran.
        onExited: if (again) {
            again = false;
            running = true;
        }

        command: ["fcitx5-remote", "-n"]

        stdout: StdioCollector {
            onStreamFinished: {
                const id = text.trim();
                // fcitx keeps a method per window: a change right after a focus change is not a switch.
                if (id !== "" && id !== root.current)
                    root.apply(id, !exact.quiet && Date.now() - root.focusedAt > Theme.duration.imeFocus);
                exact.quiet = false;
            }
        }
    }

    // fcitx or the session bus restarted.
    Timer {
        id: retry

        onTriggered: watch.running = true

        interval: Theme.duration.imeRetry
    }

    // The group's methods; fcitx rewrites this file when they change.
    FileView {
        onFileChanged: reload()

        onLoaded: {
            const ids = [];
            let item = false;
            for (const line of text().split("\n")) {
                if (line.startsWith("["))
                    item = line.startsWith("[Groups/0/Items/");
                else if (item && line.startsWith("Name="))
                    ids.push(line.slice(5));
            }
            table.command = ["sh", "-c", table.script, "sh", table.layouts].concat(ids);
            table.running = true;
        }

        path: Quickshell.env("HOME") + "/.config/fcitx5/profile"
        watchChanges: true
        printErrors: false
    }

    // Each method's id, name and short label (速, 倉); a keyboard's name comes from xkb, as fcitx shows it.
    Process {
        id: table

        readonly property string layouts: '/^! /{s=$2;next} v=="" && s=="layout" && $1==l {sub(/^ *[^ ]+ +/,"");print;exit} v!="" && s=="variant" && $1==v && $2==l":" {sub(/^ *[^ ]+ +[^ ]+ +/,"");print;exit}'
        readonly property string script: 'a=$1; shift; for n; do c="/usr/share/fcitx5/inputmethod/$n.conf"; case $n in keyboard-*) k=${n#keyboard-}; name=$(awk -v l="${k%%-*}" -v v="$(case $k in *-*) echo "${k#*-}";; esac)" "$a" /usr/share/X11/xkb/rules/evdev.lst); label= ;; *) name=$(sed -n "s/^Name=//p" "$c" 2>/dev/null | head -1); label=$(sed -n "s/^Label=//p" "$c" 2>/dev/null | head -1) ;; esac; printf "%s\\t%s\\t%s\\n" "$n" "${name:-$n}" "$label"; done'

        stdout: StdioCollector {
            onStreamFinished: {
                root.methods = text.split("\n").filter(l => l !== "").map(l => {
                    const f = l.split("\t");
                    return {
                        id: f[0],
                        name: f[1] ?? f[0],
                        label: f[2] ?? ""
                    };
                });
                if (root.current !== "")
                    root.apply(root.current, false);
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/backlight/*/ 2>/dev/null | head -1"]

        stdout: StdioCollector {
            onStreamFinished: root.backlight = text.trim().replace(/\/$/, "")
        }
    }

    IpcHandler {
        function brightness(): void {
            brightnessFile.reload();
        }

        target: "osd"
    }

    FileView {
        onLoaded: root.brightnessMax = Math.max(1, Number(text().trim()))

        path: root.backlight === "" ? "" : root.backlight + "/max_brightness"
        printErrors: false
    }

    FileView {
        id: brightnessFile

        onLoaded: {
            const raw = Number(text().trim());
            if (raw === root.brightnessRaw)
                return;
            root.brightnessRaw = raw;
            root.present("brightness", raw / root.brightnessMax, false);
        }

        path: root.backlight === "" ? "" : root.backlight + "/brightness"
        printErrors: false
    }
}
