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
    // Set by screen-record.sh; nothing else on screen shows a recording is running.
    property bool recording: false
    // When it started, in ms since the epoch, for the bar's elapsed time.
    property real since: 0
    // Between the countdown and the recorder starting, the keys must not reopen the dialog.
    readonly property bool busy: counting || begin.running || starting || recording
    // From launching the script until it reports in; it checks the mic and screen first.
    property bool starting: false

    function start(): void {
        if (!open || busy)
            return;
        choiceFile.setText(JSON.stringify({
            system: root.system,
            mic: root.mic
        }));
        count = 5;
        tick.restart();
    }

    // How long the recording has run, as m:ss or h:mm:ss.
    function elapsed(now: date): string {
        const s = Math.max(0, Math.floor((now.getTime() - root.since) / 1000));
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60;
        const two = n => String(n).padStart(2, "0");
        return (h > 0 ? h + ":" + two(m) : m) + ":" + two(sec);
    }

    // The script with no arguments stops a running recording and saves it.
    function stop(): void {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/script/misc/screen-record.sh"]);
    }

    function cancel(): void {
        tick.stop();
        begin.stop();
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
        onTriggered: {
            root.starting = true;
            startLimit.restart();
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/script/misc/screen-record.sh", "start", root.system ? "1" : "0", root.mic ? "1" : "0"]);
        }
    }

    // A script that never reports in must not leave the dialog locked out.
    Timer {
        id: startLimit
        interval: Theme.duration.recordStart
        onTriggered: root.starting = false
    }

    // A recording already running when the shell (re)starts, dated by its state file.
    Process {
        running: true
        command: ["sh", "-c", 'pgrep -x wl-screenrec > /dev/null && stat -c %Y "$XDG_RUNTIME_DIR/screen-record/path"']
        stdout: StdioCollector {
            onStreamFinished: {
                const seconds = Number(text.trim());
                if (seconds > 0) {
                    root.since = seconds * 1000;
                    root.recording = true;
                }
            }
        }
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
            if (!root.busy)
                root.open = true;
        }

        function started(): void {
            root.since = Date.now();
            root.starting = false;
            root.recording = true;
        }

        function stopped(): void {
            root.starting = false;
            root.recording = false;
        }

        function close(): void {
            root.cancel();
        }
    }
}
