pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// The output's volume ceiling. wpctl (the keys) has none, so the shell pulls it back.
Singleton {
    id: root

    readonly property var limits: [1, 2, 3, 4]
    property real limit: 1

    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null

    onAudioChanged: clamp()

    function setLimit(value: real): void {
        limit = value;
        limitFile.setText(String(value));
        clamp();
    }

    function clamp(): void {
        if (root.audio && root.audio.volume > root.limit)
            root.audio.volume = root.limit;
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: root.audio
        function onVolumeChanged(): void {
            root.clamp();
        }
    }

    FileView {
        id: limitFile
        path: Quickshell.statePath("volume-limit.txt")
        printErrors: false
        blockWrites: false
        onLoaded: {
            const saved = Number(text().trim());
            if (root.limits.includes(saved))
                root.limit = saved;
            root.clamp();
        }
    }
}
