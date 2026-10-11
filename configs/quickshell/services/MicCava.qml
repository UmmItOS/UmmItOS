pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// The microphone's level, drawn beside the clock. It only listens while another app is already recording from the mic and a disc is on screen: the shell never opens the mic by itself.
Singleton {
    id: root

    readonly property int bars: 24
    property list<real> levels: []
    // Discs showing the bars, one per screen.
    property int viewers: 0

    // WirePlumber may name no default source; then the first input device is it.
    readonly property var source: Pipewire.defaultAudioSource ?? Pipewire.nodes.values.find(n => !n.isStream && !n.isSink && n.name.includes("input")) ?? null
    readonly property bool muted: source?.audio?.muted ?? false
    // Another app records from a microphone (our own cava stream does not count).
    readonly property bool inUse: Pipewire.nodes.values.some(n => n.isStream && !n.isSink && n.name !== "cava")
    readonly property bool running: viewers > 0 && inUse && !muted && (source?.name ?? "") !== ""

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

    function toggleMute(): void {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    onRunningChanged: {
        if (!running)
            levels = [];
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
