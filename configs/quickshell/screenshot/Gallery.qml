pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    property bool open: false
    // The folder shown: the screenshot folder, or one inside it.
    property string folder: ""
    readonly property bool atRoot: folder === Screenshot.dir
    // The up card first, then folders, then pictures newest first: {kind: "up"|"dir"|"file", path, name, time}.
    property var shots: []
    property bool loading: false
    // The old cards are on their way out before the next folder's arrive.
    property bool leaving: false
    // The folder just left, so going up lands on its card.
    property string came: ""

    property string pending: ""

    function toggle(): void {
        if (open) {
            open = false;
            return;
        }
        folder = Screenshot.dir;
        came = "";
        load();
        open = true;
    }

    function load(): void {
        shots = [];
        loading = true;
        list.running = false;
        list.command = ["find", folder, "-mindepth", "1", "-maxdepth", "1", "(", "-type", "d", "-o", "(", "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", ")", ")", ")", "-printf", "%y\\t%T@\\t%p\\0"];
        list.running = true;
    }

    // Out first, then the new folder's cards fly in.
    function go(path: string, from: string): void {
        if (leaving)
            return;
        pending = path;
        came = from;
        leaving = true;
        swap.restart();
    }

    function enter(path: string): void {
        go(path, "");
    }

    function up(): void {
        if (!atRoot)
            go(folder.slice(0, folder.lastIndexOf("/")), folder);
    }

    // To the clipboard again; the watcher shows the usual copy pill and sound.
    function copy(path: string): void {
        const type = path.toLowerCase().endsWith(".png") ? "image/png" : path.toLowerCase().endsWith(".webp") ? "image/webp" : "image/jpeg";
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type "$2" < "$1"', "sh", path, type]);
        open = false;
    }

    Timer {
        id: swap

        onTriggered: {
            root.folder = root.pending;
            root.load();
        }

        interval: Theme.duration.expressiveFastSpatial
    }

    Process {
        id: list

        stdout: StdioCollector {
            onStreamFinished: {
                const all = text.split("\0").filter(l => l !== "").map(l => {
                        const [kind, stamp, ...rest] = l.split("\t");
                        const path = rest.join("\t");
                        return {
                            kind: kind === "d" ? "dir" : "file",
                            path: path,
                            name: path.slice(path.lastIndexOf("/") + 1),
                            time: Number(stamp) * 1000
                        };
                    });
                const dirs = all.filter(e => e.kind === "dir").sort((a, b) => a.name.localeCompare(b.name));
                const files = all.filter(e => e.kind === "file").sort((a, b) => b.time - a.time);
                root.shots = (root.atRoot ? [] : [
                        {
                            kind: "up",
                            path: root.folder.slice(0, root.folder.lastIndexOf("/")),
                            name: "..",
                            time: 0
                        }
                    ]).concat(dirs, files);
                root.loading = false;
                root.leaving = false;
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
