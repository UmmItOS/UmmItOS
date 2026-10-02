pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Every sound the shell makes, by event. Each is a link in ~/.config/ummitos/sounds/ named after its event;
// point one at another file to change it (ln -sf ~/x.ogg sao-open), or at /dev/null to silence it.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/ummitos/sounds"

    // Event and its built-in sound, relative to the shell.
    readonly property var events: [
        ["notification", "notifications/chime.ogg"],
        ["notice", "toast/pop.ogg"],
        ["screenshot", "screenshot/shutter.ogg"],
        ["text-copied", "toast/pop.ogg"],
        ["image-copied", "toast/snap.ogg"],
        ["charging", "charging/plug.ogg"],
        ["qr-found", "scan/found.ogg"],
        ["sao-open", "sao/open.ogg"],
        ["sao-tap", "sao/tap.ogg"]
    ]

    function play(event: string): void {
        if (events.some(e => e[0] === event))
            Quickshell.execDetached(["pw-play", dir + "/" + event]);
    }

    // A link for each event that has none yet, to its built-in sound; a link already there is the user's and stays.
    Process {
        running: true
        command: ["sh", "-c", 'd=$1; shift; mkdir -p "$d" || exit; while [ $# -gt 1 ]; do [ -e "$d/$1" ] || [ -L "$d/$1" ] || ln -s "$2" "$d/$1"; shift 2; done', "sh", root.dir].concat(root.events.map(e => [e[0], Quickshell.shellDir + "/" + e[1]]).reduce((all, pair) => all.concat(pair), []))
    }
}
