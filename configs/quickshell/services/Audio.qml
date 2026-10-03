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
    // Until the saved limit is read, clamping to the default 100% would cut a volume the user set above it.
    property bool loaded: false

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

    onAudioChanged: clamp()

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        function onVolumeChanged(): void {
            root.clamp();
        }

        target: root.audio
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
