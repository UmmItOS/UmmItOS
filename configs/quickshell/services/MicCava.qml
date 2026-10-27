pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import ".."

// The microphone's level, drawn beside the clock. With Settings > Bar > "Show the microphone level" off it listens only while another app is already recording; on, it keeps the mic open for the bars.
Singleton {
    id: root

    readonly property int bars: 24
    property list<real> levels: []
    // Discs showing the bars, one per screen.
    property int viewers: 0

    // Names of input sources whose active port is really available (a jack with a mic in it, or a USB mic). Read from pactl, since Quickshell cannot see a port's availability.
    property var availNames: []
    // The source to draw: the default if its jack is available, else the first available one.
    readonly property var source: (Pipewire.defaultAudioSource && availNames.includes(Pipewire.defaultAudioSource.name) ? Pipewire.defaultAudioSource : inputs[0]) ?? null
    readonly property bool present: inputs.length > 0
    readonly property bool muted: source?.audio?.muted ?? false
    // Another app records from a microphone (our own cava stream does not count).
    readonly property bool inUse: Pipewire.nodes.values.some(n => n.isStream && !n.isSink && n.name !== "cava")
    readonly property bool running: viewers > 0 && (Settings.micListen || inUse) && !muted && present

    readonly property string config: `[general]
bars = ${bars}
framerate = 30
[input]
method = pipewire
source = ${source?.name ?? "auto"}
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
[smoothing]
noise_reduction = 30
`

    // What was last said about the microphone, shown beside the disc for a while: a sensor's report.
    property string note: ""
    readonly property bool noting: noteTimer.running
    // The first reading is the state at start, not news.
    property bool settled: false

    // kind: "info" a device arrived, "muted" you muted it, "on" you unmuted it, "gone" it is not there. Red is off or missing, green is on.
    property string noteKind: "info"

    function say(text: string, kind: string): void {
        note = text;
        noteKind = kind;
        noteTimer.restart();
    }

    // You muted or unmuted it (the disc, or a key): the device is still there.
    onMutedChanged: {
        if (settled && present)
            say(muted ? I18n.t("Microphone muted") : I18n.t("Microphone on"), muted ? "muted" : "on");
    }

    function toggleMute(): void {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    // The input nodes with a mic actually plugged in, not every input device a card exposes.
    readonly property var inputs: Pipewire.nodes.values.filter(n => root.availNames.includes(n.name))
    property var known: []

    function label(node: var): string {
        return node.description || node.nickname || node.name;
    }

    // Plugged in or pulled out: say which, and say so when none is left.
    onInputsChanged: {
        const now = inputs.map(n => n.name);
        if (settled) {
            for (const n of inputs.filter(n => !known.includes(n.name)))
                say(I18n.t("%1 connected").arg(label(n)), "info");
            const gone = known.filter(k => !now.includes(k));
            if (gone.length > 0)
                say(now.length === 0 ? I18n.t("No microphone") : I18n.t("Microphone disconnected"), "gone");
        }
        known = now;
    }

    Timer {
        running: true
        interval: Theme.duration.micSettle
        onTriggered: root.settled = true
    }

    Timer {
        id: noteTimer

        interval: Theme.duration.toast
    }

    onRunningChanged: {
        if (!running)
            levels = [];
    }

    // A jack plug or unplug does not change the node set, so watch pactl's events too.
    Connections {
        function onValuesChanged(): void {
            availDebounce.restart();
        }

        target: Pipewire.nodes
    }

    Timer {
        id: availDebounce

        interval: Theme.duration.small
        onTriggered: avail.running = true
    }

    // Reads which input sources have an available active port.
    Process {
        id: avail

        running: true
        command: ["sh", "-c", 'pactl list sources 2>/dev/null | awk \'/^[[:space:]]*Name: / { name=$2; delete av } /\\(type:.*availab|: .*\\(type:/ { l=$0; sub(/^[[:space:]]+/,"",l); split(l,a,":"); av[a[1]]=(l ~ /not available/)?"no":"yes" } /^[[:space:]]*Active Port: / { if (name !~ /monitor/ && av[$3] != "no") print name }\'']
        stdout: StdioCollector {
            onStreamFinished: root.availNames = text.split("\n").filter(v => v !== "")
        }
    }

    // pactl's own events: a mic plugged into or out of the jack fires a source change.
    Process {
        running: true
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("source") || line.includes("server") || line.includes("card"))
                    availDebounce.restart();
            }
        }
    }

    PwObjectTracker {
        objects: [root.source]
    }

    Process {
        running: root.running
        command: ["sh", "-c", 'f="$1/cava-mic.conf"; mkdir -p "$1" && printf "%s" "$2" > "$f" && exec cava -p "$f"', "sh", Quickshell.cachePath(""), root.config]

        stdout: SplitParser {
            onRead: line => root.levels = line.split(";").filter(v => v !== "").map(v => Number(v) / 100)
        }
    }
}
