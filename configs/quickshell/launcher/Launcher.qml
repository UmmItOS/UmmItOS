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

    // Decodes one image entry into the cache so the preview pane can show it.
    function decode(id: string): string {
        const path = Quickshell.cachePath("clipboard/" + id + ".png");
        decodeProc.command = ["sh", "-c", `mkdir -p "$(dirname '${path}')" && cliphist decode ${id} > '${path}'`];
        decodeProc.running = true;
        return path;
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
                    const preview = line.slice(tab + 1);
                    // cliphist renders images as "[[ binary data 2 MiB png 1920x1200 ]]"
                    const binary = preview.match(/^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/);
                    return {
                        id: line.slice(0, tab),
                        preview: preview,
                        image: binary !== null,
                        kind: binary ? binary[2] : "text",
                        detail: binary ? binary[3] + "  ·  " + binary[1] : ""
                    };
                });
            }
        }
    }

    Process {
        id: copyProc
    }

    Process {
        id: decodeProc
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
