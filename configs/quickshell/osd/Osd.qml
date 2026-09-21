pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// Watches volume and brightness and asks the OSD to appear. It never changes
// either one: the keys already run wpctl and brightnessctl, so this only
// observes, and an adjustment made any other way shows up just the same.
Singleton {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property bool shown: false

    // Nothing should flash on screen just because the shell started.
    property bool primed: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null

    PwObjectTracker {
        objects: [root.sink]
    }

    function present(newKind: string, newValue: real, newMuted: bool): void {
        if (!primed)
            return;
        kind = newKind;
        value = Math.max(0, Math.min(1, newValue));
        muted = newMuted;
        shown = true;
        hide.restart();
    }

    Timer {
        id: hide
        interval: 1400
        onTriggered: root.shown = false
    }

    // One pass to settle the starting values, then arm.
    Timer {
        running: true
        interval: 1200
        onTriggered: root.primed = true
    }

    Connections {
        target: root.audio
        enabled: root.audio !== null

        function onVolumeChanged() {
            root.present("volume", root.audio.volume, root.audio.muted);
        }

        function onMutedChanged() {
            root.present("volume", root.audio.volume, root.audio.muted);
        }
    }

    // Brightness has no property to bind to. sysfs does not reliably emit
    // inotify events for backlight attributes, so this reads the file rather
    // than trusting a watch; it is a handful of bytes.
    property real brightnessMax: 1
    property real brightnessRaw: 0
    // Resolved at startup: the device is amdgpu_bl1 here, intel_backlight
    // elsewhere. Hardcoding one name would make this laptop-specific.
    property string backlight: ""

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/backlight/*/ 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.backlight = text.trim().replace(/\/$/, "")
        }
    }

    Timer {
        running: root.backlight !== ""
        interval: 300
        repeat: true
        onTriggered: brightness.reload()
    }

    FileView {
        id: brightnessMaxFile
        path: root.backlight === "" ? "" : root.backlight + "/max_brightness"
        printErrors: false
        onLoaded: root.brightnessMax = Math.max(1, Number(text().trim()))
    }

    FileView {
        id: brightness
        path: root.backlight === "" ? "" : root.backlight + "/brightness"
        printErrors: false
        onLoaded: {
            const raw = Number(text().trim());
            if (raw === root.brightnessRaw)
                return;
            root.brightnessRaw = raw;
            root.present("brightness", raw / root.brightnessMax, false);
        }
    }
}
