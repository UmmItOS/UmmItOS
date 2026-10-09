pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The latest file change in a folder: + new, ~ changed, − deleted, → moved. Fades when quiet.
Text {
    id: root

    property string last: ""
    property bool restarting: false

    readonly property string folder: Settings.watchFolder
    // The shell's own folder is looked up to its repo; a chosen one is watched as it is.
    readonly property string dir: 'd=$1; [ "$2" = repo ] && d=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null || echo "$1");'
    readonly property var target: ["sh", Settings.watchFolder !== "" ? Settings.watchFolder : Quickshell.shellDir, Settings.watchFolder !== "" ? "dir" : "repo"]

    function note(glyph: string, name: string): void {
        last = glyph + " " + name;
        quiet.restart();
    }

    onFolderChanged: {
        last = "";
        restarting = true;
        Qt.callLater(() => restarting = false);
    }

    textFormat: Text.PlainText
    text: last
    color: Theme.dim
    elide: Text.ElideMiddle
    font.family: Theme.font
    font.pixelSize: Theme.fontSize.smaller
    opacity: quiet.running ? 1 : 0
    visible: opacity > 0
    width: Math.min(implicitWidth, Theme.bar.fileWatch)

    Behavior on opacity {
        FastFade {}
    }

    // exec: inotifywait is the Process itself, so a reload cannot orphan it.
    Process {
        running: Settings.watchShow && !root.restarting
        command: ["sh", "-c", root.dir + ' exec inotifywait -m -r -q -e create,modify,delete,moved_to --exclude "/\\.git/" --format "%e %f" "$d"'].concat(root.target)
        stdout: SplitParser {
            onRead: line => {
                const space = line.indexOf(" ");
                const event = line.slice(0, space);
                const glyph = event.includes("CREATE") ? "+" : event.includes("DELETE") ? "−" : event.includes("MOVED") ? "→" : "~";
                root.note(glyph, line.slice(space + 1));
            }
        }
    }

    // Saving a file of the shell reloads it, which wipes this label: show the save that did it.
    Process {
        running: Settings.watchShow
        command: ["sh", "-c", root.dir + ' find "$d" -path "$d/.git" -prune -o -type f -mmin -0.1 -printf "%T@\\t%f\\n" | sort -n | tail -n 1'].concat(root.target)
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim().split("\t")[1];
                if (name && root.last === "")
                    root.note("~", name);
            }
        }
    }

    Timer {
        id: quiet

        interval: Theme.duration.toast
    }
}
