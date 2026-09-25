pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The recording dialog: which sound to record, then a countdown before it starts.
Singleton {
    id: root

    property bool open: false
    property bool system: true
    property bool mic: false
    // 5 to 1 while counting down, 0 otherwise.
    property int count: 0
    readonly property bool counting: count > 0

    function start(): void {
        if (!open || counting)
            return;
        choiceFile.setText(JSON.stringify({
            system: root.system,
            mic: root.mic
        }));
        count = 5;
        tick.restart();
    }

    function cancel(): void {
        tick.stop();
        count = 0;
        open = false;
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.count > 1) {
                root.count--;
                return;
            }
            stop();
            root.count = 0;
            root.open = false;
            begin.restart();
        }
    }

    // After the dialog's exit, so it is not in the video.
    Timer {
        id: begin
        interval: Theme.duration.expressiveDefaultSpatial + Theme.duration.small
        onTriggered: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/script/misc/screen-record.sh", "start", root.system ? "1" : "0", root.mic ? "1" : "0"])
    }

    FileView {
        id: choiceFile
        path: Quickshell.statePath("record.json")
        printErrors: false
        blockWrites: false
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                root.system = saved.system ?? true;
                root.mic = saved.mic ?? false;
            } catch (e) {}
        }
    }

    IpcHandler {
        target: "record"

        function open(): void {
            if (!root.counting)
                root.open = true;
        }

        function close(): void {
            root.cancel();
        }
    }
}
