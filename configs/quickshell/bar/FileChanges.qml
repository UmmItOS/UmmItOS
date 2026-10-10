pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    readonly property int keep: 100
    readonly property string dir: 'd=$1; [ "$2" = repo ] && d=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null || echo "$1");'
    readonly property var target: ["sh", Settings.watchFolder !== "" ? Settings.watchFolder : Quickshell.shellDir, Settings.watchFolder !== "" ? "dir" : "repo"]

    property var entries: []
    property bool restarting: false

    readonly property var last: entries.length > 0 ? entries[0] : null
    readonly property bool recent: quiet.running

    // Drops the list from memory and the pending write, ahead of a wipe of its file.
    function forget(): void {
        save.stop();
        entries = [];
    }

    function record(glyph: string, path: string, time: real, live: bool): void {
        const list = entries.slice();
        const top = list[0];
        if (top && top.path === path && time - top.time < 2000)
            list[0] = {
                glyph: glyph,
                path: path,
                time: time
            };
        else
            list.unshift({
                glyph: glyph,
                path: path,
                time: time
            });
        list.length = Math.min(list.length, keep);
        entries = list;
        if (live)
            quiet.restart();
        save.restart();
    }

    Connections {
        function onWatchFolderChanged(): void {
            root.restarting = true;
            Qt.callLater(() => root.restarting = false);
        }

        target: Settings
    }

    FileView {
        id: saved

        onLoaded: {
            try {
                root.entries = JSON.parse(text()).filter(e => e.time <= Date.now());
            } catch (e) {
                root.entries = [];
            }
            catchUp.running = Settings.watchShow;
        }
        onLoadFailed: catchUp.running = Settings.watchShow

        path: Quickshell.statePath("file-changes.json")
        printErrors: false
        blockWrites: false
    }

    Timer {
        id: save

        onTriggered: saved.setText(JSON.stringify(root.entries))

        interval: Theme.duration.toast / 4
    }

    Timer {
        id: quiet

        interval: Theme.duration.toast
    }

    // exec: inotifywait is the Process itself, so a reload cannot orphan it.
    Process {
        running: Settings.watchShow && !root.restarting
        command: ["sh", "-c", root.dir + ' exec inotifywait -m -r -q -e create,modify,delete,moved_to --exclude "/\\.git/" --format "%e %w%f" "$d"'].concat(root.target)
        stdout: SplitParser {
            onRead: line => {
                const space = line.indexOf(" ");
                const event = line.slice(0, space);
                const glyph = event.includes("CREATE") ? "+" : event.includes("DELETE") ? "−" : event.includes("MOVED") ? "→" : "~";
                root.record(glyph, line.slice(space + 1), Date.now(), true);
            }
        }
    }

    // Saving a file of the shell reloads it and loses what was caught meanwhile.
    Process {
        id: catchUp

        command: ["sh", "-c", root.dir + ' find "$d" -path "$d/.git" -prune -o -type f -newermt "6 seconds ago" ! -newermt now -printf "%T@\\t%p\\n" | sort -n | tail -n 1'].concat(root.target)
        stdout: StdioCollector {
            onStreamFinished: {
                const [stamp, path] = text.trim().split("\t");
                const time = Number(stamp) * 1000;
                if (path && !root.entries.some(e => e.path === path && Math.abs(e.time - time) < 3000))
                    root.record("~", path, time, true);
            }
        }
    }
}
