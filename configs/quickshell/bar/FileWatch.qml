import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The latest file change in the repo the shell lives in: + new, ~ changed, − deleted, → moved. Fades when quiet.
Text {
    id: root

    property string last: ""

    textFormat: Text.PlainText
    text: last
    color: Theme.dim
    elide: Text.ElideMiddle
    font.family: Theme.font
    font.pixelSize: Theme.fontSize.smaller
    opacity: quiet.running ? 1 : 0
    width: Math.min(implicitWidth, Theme.bar.fileWatch)

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.duration.expressiveFastEffects
        }
    }

    // exec: inotifywait is the Process itself, so a reload cannot orphan it.
    Process {
        running: true
        command: ["sh", "-c", 'd=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null || echo "$1"); exec inotifywait -m -r -q -e create,modify,delete,moved_to --exclude "/\\.git/" --format "%e %f" "$d"', "sh", Quickshell.shellDir]
        stdout: SplitParser {
            onRead: line => {
                const space = line.indexOf(" ");
                const event = line.slice(0, space);
                const glyph = event.includes("CREATE") ? "+" : event.includes("DELETE") ? "−" : event.includes("MOVED") ? "→" : "~";
                root.last = glyph + " " + line.slice(space + 1);
                quiet.restart();
            }
        }
    }

    Timer {
        id: quiet
        interval: Theme.duration.toast
    }
}
