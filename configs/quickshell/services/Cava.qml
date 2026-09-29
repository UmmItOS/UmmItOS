pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Runs only while shown and playing.
Singleton {
    id: root

    readonly property int bars: 24
    property list<real> levels: []

    readonly property bool running: Players.watched && (Players.active?.isPlaying ?? false)

    // Own config, not the user's; noise_reduction 20 follows the beat.
    readonly property string config: `[general]
bars = ${bars}
framerate = 60
[input]
method = pipewire
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
[smoothing]
noise_reduction = 20
`

    onRunningChanged: {
        if (!running)
            levels = [];
    }

    Process {
        running: root.running
        command: ["sh", "-c", 'f="$1/cava.conf"; mkdir -p "$1" && printf "%s" "$2" > "$f" && exec cava -p "$f"', "sh", Quickshell.cachePath(""), root.config]

        stdout: SplitParser {
            onRead: line => root.levels = line.split(";").filter(v => v !== "").map(v => Number(v) / 100)
        }
    }
}
