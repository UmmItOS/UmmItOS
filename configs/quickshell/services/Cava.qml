pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Audio levels from cava, for the ring around the album art. cava reads
// PipeWire and writes one line per frame of bar heights (0-100); it only runs
// while something on screen shows it and music is actually playing.
Singleton {
    id: root

    readonly property int bars: 24
    property list<real> levels: []

    readonly property bool running: Players.watched && (Players.active?.isPlaying ?? false)

    // Its own config, written beside the cache, so a user's cava config for
    // the terminal is left alone. noise_reduction is cava's smoothing (default
    // 77); at 20 the bars follow the beat instead of drifting after it.
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
