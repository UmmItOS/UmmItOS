pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    property bool open: false
    // Newest first: {path, name, time}.
    property var shots: []
    property bool loading: false

    function toggle(): void {
        if (open) {
            open = false;
            return;
        }
        shots = [];
        loading = true;
        list.running = false;
        list.command = ["find", Screenshot.dir, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", ")", "-printf", "%T@\\t%p\\0"];
        list.running = true;
        open = true;
    }

    // To the clipboard again; the watcher shows the usual copy pill and sound.
    function copy(path: string): void {
        const type = path.toLowerCase().endsWith(".png") ? "image/png" : path.toLowerCase().endsWith(".webp") ? "image/webp" : "image/jpeg";
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type "$2" < "$1"', "sh", path, type]);
        open = false;
    }

    Process {
        id: list

        stdout: StdioCollector {
            onStreamFinished: {
                root.shots = text.split("\0").filter(l => l !== "").map(l => {
                        const tab = l.indexOf("\t");
                        const path = l.slice(tab + 1);
                        return {
                            path: path,
                            name: path.slice(path.lastIndexOf("/") + 1),
                            time: Number(l.slice(0, tab)) * 1000
                        };
                    }).sort((a, b) => b.time - a.time).slice(0, Theme.gallery.max);
                root.loading = false;
            }
        }
    }

    IpcHandler {
        function toggle(): void {
            root.toggle();
        }

        function close(): void {
            root.open = false;
        }

        target: "gallery"
    }
}
