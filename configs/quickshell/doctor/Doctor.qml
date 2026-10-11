pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// Checks that this machine runs what the repo holds (script/misc/doctor.sh), line by line like a package install.
Singleton {
    id: root

    property bool open: false
    property bool running: false
    // {status: ok|warn|fail, group, title, detail}, in the order the script reports them.
    property var lines: []
    property int good: 0
    property int warned: 0
    property int failed: 0
    property bool finished: false
    // The script found its own copies in ~/script stale or missing, which Fix scripts repairs.
    readonly property bool fixable: lines.some(l => l.group === "Scripts" && l.status !== "ok")

    function scriptCommand(args: var): var {
        return ["sh", "-c", 'd=$(readlink -f "$1"); shift; for s in "$d/../../script/misc/doctor.sh" "$HOME/script/misc/doctor.sh"; do [ -x "$s" ] && exec "$s" "$@"; done; echo "fail\tScripts\tdoctor.sh\tNot found: run the installer or copy script/ to ~/script"; echo "done\t0\t0\t1"', "sh", Quickshell.shellDir].concat(args);
    }

    function run(): void {
        if (running)
            return;
        lines = [];
        good = warned = failed = 0;
        finished = false;
        running = true;
        check.command = scriptCommand([]);
        check.running = true;
    }

    function toggle(): void {
        open = !open;
        if (open)
            run();
    }

    // Copies the repo's scripts over ~/script, then checks again.
    function fixScripts(): void {
        if (running)
            return;
        fixer.command = scriptCommand(["--fix", "scripts"]);
        fixer.running = true;
    }

    Process {
        id: check

        stdout: SplitParser {
            onRead: line => {
                const [status, a, b, c] = line.split("\t");
                if (status === "done") {
                    root.good = Number(a);
                    root.warned = Number(b);
                    root.failed = Number(c);
                    return;
                }
                root.lines = root.lines.concat([
                    {
                        status: status,
                        group: a,
                        title: b,
                        detail: c ?? ""
                    }
                ]);
            }
        }

        onExited: {
            root.running = false;
            root.finished = true;
        }
    }

    Process {
        id: fixer

        onExited: root.run()
    }

    // Once after start, quietly: a problem is a notice, a clean bill of health is not.
    Process {
        id: startup

        running: false
        command: root.scriptCommand([])
        stdout: StdioCollector {
            onStreamFinished: {
                const bad = text.split("\n").filter(l => l.startsWith("fail\t")).length;
                if (bad > 0)
                    Notifs.say("UmmItOS", I18n.t("%1 things need attention").arg(bad), I18n.t("Open the health check with Super+H."), "critical");
            }
        }
    }

    Timer {
        running: true
        interval: Theme.duration.doctorStart

        onTriggered: startup.running = true
    }

    IpcHandler {
        function toggle(): void {
            root.toggle();
        }

        function close(): void {
            root.open = false;
        }

        target: "doctor"
    }
}
