pragma Singleton

import Quickshell
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

    PwObjectTracker {
        objects: [root.sink]
    }

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

    Timer {
        id: hide
        interval: 1400
        onTriggered: root.shown = false
    }

    // Settle before arming, or a new sink flashes a volume nobody touched.
    Timer {
        id: arm
        running: true
        interval: 1200
        onTriggered: root.primed = true
    }

    onSinkChanged: {
        primed = false;
        arm.restart();
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

    // sysfs backlight emits no reliable inotify events, so it is read.
    property real brightnessMax: 1
    property real brightnessRaw: 0
    // amdgpu_bl1 here, intel_backlight elsewhere.
    property string backlight: ""

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/backlight/*/ 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.backlight = text.trim().replace(/\/$/, "")
        }
    }

    // The keys report over IPC, so this can be slow.
    Timer {
        running: root.backlight !== ""
        interval: 2000
        repeat: true
        onTriggered: brightnessFile.reload()
    }

    IpcHandler {
        target: "osd"

        function brightness(): void {
            brightnessFile.reload();
        }
    }

    FileView {
        path: root.backlight === "" ? "" : root.backlight + "/max_brightness"
        printErrors: false
        onLoaded: root.brightnessMax = Math.max(1, Number(text().trim()))
    }

    FileView {
        id: brightnessFile
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
