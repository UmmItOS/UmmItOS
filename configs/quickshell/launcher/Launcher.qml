pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // "apps" or "clipboard"
    property string mode: "apps"
    property bool open: false
    property list<var> clipboard: []

    function show(newMode: string): void {
        mode = newMode;
        if (newMode === "clipboard")
            clipList.running = true;
        open = true;
    }

    function toggle(newMode: string): void {
        if (open && mode === newMode)
            open = false;
        else
            show(newMode);
    }

    function launch(entry: var): void {
        open = false;
        entry.execute();
    }

    function copy(id: string): void {
        open = false;
        copyProc.command = ["sh", "-c", `cliphist decode ${id} | wl-copy`];
        copyProc.running = true;
    }

    // "8595\t[[ binary data ... ]]" -> { id, preview }
    Process {
        id: clipList
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.clipboard = text.split("\n").filter(l => l !== "").map(line => {
                    const tab = line.indexOf("\t");
                    return {
                        id: line.slice(0, tab),
                        preview: line.slice(tab + 1)
                    };
                });
            }
        }
    }

    Process {
        id: copyProc
    }

    IpcHandler {
        target: "launcher"

        function apps(): void {
            root.toggle("apps");
        }

        function clipboard(): void {
            root.toggle("clipboard");
        }

        function close(): void {
            root.open = false;
        }
    }
}
