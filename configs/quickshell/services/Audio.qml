pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import ".."

// The output's volume ceiling. wpctl (the keys) has none, so the shell pulls it back.
Singleton {
    id: root

    readonly property var limits: [1, 2, 3, 4]
    property real limit: 1
    // Until the saved limit is read, clamping to the default 100% would cut a volume the user set above it.
    property bool loaded: false
    // Off until the sink settles, so the shell's start and a new sink stay quiet.
    property bool primed: false

    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null

    function setLimit(value: real): void {
        limit = value;
        limitFile.setText(String(value));
        clamp();
    }

    function clamp(): void {
        if (root.loaded && root.audio && root.audio.volume > root.limit)
            root.audio.volume = root.limit;
    }

    // GNOME's pop on every volume step, from the keys, the bar or an app's slider.
    function pop(): void {
        if (!primed || popGap.running)
            return;
        Sounds.play("volume-change");
        popGap.start();
    }

    onAudioChanged: clamp()

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        function onVolumeChanged(): void {
            root.clamp();
            root.pop();
        }

        target: root.audio
    }

    Timer {
        onTriggered: root.primed = true

        running: true
        interval: Theme.duration.osdArm
    }

    Timer {
        id: popGap

        interval: Theme.duration.volumePop
    }

    FileView {
        id: limitFile

        onLoaded: {
            const saved = Number(text().trim());
            if (root.limits.includes(saved))
                root.limit = saved;
            root.loaded = true;
            root.clamp();
        }

        onLoadFailed: {
            root.loaded = true;
            root.clamp();
        }

        path: Quickshell.statePath("volume-limit.txt")
        printErrors: false
        blockWrites: false
    }
}
