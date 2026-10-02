pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Every sound the shell makes, by event. The shell's sounds/ folder links each event to its file; at start each
// gets a link of the same name in ~/.config/ummitos/sounds/, unless one is there. Point that link at another file
// to change the sound (ln -sf ~/x.ogg sao-open), or at /dev/null to silence it; delete it to get the built-in back.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/ummitos/sounds"

    function play(event: string): void {
        Quickshell.execDetached(["pw-play", dir + "/" + event]);
    }

    // A link already there is the user's, so it stays.
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "$2" || exit; for s in "$1"/*; do e=$2/${s##*/}; [ -e "$e" ] || [ -L "$e" ] || ln -s "$s" "$e"; done', "sh", Quickshell.shellDir + "/sounds", root.dir]
    }
}
