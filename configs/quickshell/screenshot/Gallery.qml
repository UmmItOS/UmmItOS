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

    // Text typed in the search field; a picture matches when its read text contains it.
    property string query: ""
    // Whether the shown cards should fly in: a folder does, search results do not.
    property bool flyIn: true
    // How many pictures have their text read, out of how many there are.
    property int indexed: 0
    property int total: 0

    readonly property string db: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/ummitos/ocr.db"

    function toggle(): void {
        if (open) {
            open = false;
            return;
        }
        folder = Screenshot.dir;
        came = "";
        query = "";
        flyIn = true;
        load();
        open = true;
        // Reads the text of any picture not yet read; it is a no-op while one run is going.
        Quickshell.execDetached(["sh", "-c", 'd=$(readlink -f "$1"); for s in "$d/../../script/misc/ocr-index.sh" "$HOME/script/misc/ocr-index.sh"; do [ -x "$s" ] && exec nice -n 19 "$s"; done', "sh", Quickshell.shellDir]);
        progress.restart();
        count.running = true;
    }

    function setQuery(text: string): void {
        query = text.trim();
        if (query === "") {
            flyIn = true;
            load();
            return;
        }
        flyIn = false;
        shots = [];
        loading = true;
        const like = query.replace(/\\/g, "\\\\").replace(/%/g, "\\%").replace(/_/g, "\\_").replace(/'/g, "''");
        find.running = false;
        find.command = ["sqlite3", "-cmd", ".timeout 5000", "-separator", "\t", db, "SELECT path, mtime FROM shots WHERE text LIKE '%" + like + "%' ESCAPE '\\' ORDER BY mtime DESC LIMIT 2000"];
        find.running = true;
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
        flyIn = true;
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

    // Pictures whose read text holds the query, from anywhere in the folder.
    Process {
        id: find

        stdout: StdioCollector {
            onStreamFinished: {
                root.shots = text.split("\n").filter(l => l !== "").map(l => {
                        const [path, stamp] = l.split("\t");
                        return {
                            kind: "file",
                            path: path,
                            name: path.slice(path.lastIndexOf("/") + 1),
                            time: Number(stamp) * 1000
                        };
                    });
                root.loading = false;
                root.leaving = false;
            }
        }
    }

    // Progress of reading the pictures' text, while the gallery is open and it is unfinished.
    Process {
        id: count

        command: ["sh", "-c", 'sqlite3 -cmd ".timeout 5000" "$2" "SELECT count(*) FROM shots" 2>/dev/null || echo 0; find "$1" -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) | wc -l', "sh", Screenshot.dir, root.db]
        stdout: StdioCollector {
            onStreamFinished: {
                const [done, all] = text.trim().split("\n").map(Number);
                root.indexed = done || 0;
                root.total = all || 0;
            }
        }
    }

    Timer {
        id: progress

        onTriggered: count.running = true

        interval: Theme.duration.toast / 2
        running: root.open && root.indexed < root.total
        repeat: true
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
