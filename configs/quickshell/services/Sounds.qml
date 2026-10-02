pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Every sound the shell makes, by event. ~/.config/ummitos/sounds.conf can point any of them at another file,
// or silence it; edits apply at once.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string file: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/ummitos/sounds.conf"

    // Event, the built-in sound (relative to the shell) and what it is for, in the order the file lists them.
    readonly property var events: [
        ["notification", "notifications/chime.ogg", "an app's notification, when the app plays no sound of its own"],
        ["notice", "toast/pop.ogg", "the shell's own short notices: colour picker, recording, update, Wi-Fi, Bluetooth"],
        ["screenshot", "screenshot/shutter.ogg", "a screenshot is saved"],
        ["text-copied", "toast/pop.ogg", "text is copied"],
        ["image-copied", "toast/snap.ogg", "an image is copied (not a screenshot, which has its shutter)"],
        ["charging", "charging/plug.ogg", "the charger is plugged in"],
        ["qr-found", "scan/found.ogg", "the QR scanner finds a code"],
        ["sao-open", "sao/open.ogg", "the SAO menu opens"],
        ["sao-tap", "sao/tap.ogg", "a button in the SAO menu is pressed"]
    ]

    // What the file sets, event to value: "" for the built-in sound, "none" for silence, or a path.
    property var chosen: ({})

    function play(event: string): void {
        const builtIn = events.find(e => e[0] === event)?.[1];
        if (!builtIn)
            return;
        const value = chosen[event] ?? "";
        if (value === "none")
            return;
        const path = value === "" ? Quickshell.shellDir + "/" + builtIn : value.replace(/^~(?=\/)/, home);
        Quickshell.execDetached(["pw-play", path]);
    }

    // The file a user edits: every event listed, each left empty for its built-in sound.
    function template(): string {
        const lines = ["# UmmItOS sounds. One line per event: event = sound file.", "# Leave it empty for the built-in sound, write none for silence, or give a path (~ works).", "# Any format pw-play reads (ogg, wav, flac, mp3). Saved changes apply at once.", ""];
        for (const e of events)
            lines.push("# " + e[2], e[0] + " = ", "");
        return lines.join("\n");
    }

    FileView {
        id: conf

        path: root.file
        watchChanges: true
        printErrors: false
        blockWrites: false
        onFileChanged: reload()
        onLoaded: {
            const next = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^\s*([a-z-]+)\s*=\s*(.*?)\s*$/);
                if (m && root.events.some(e => e[0] === m[1]))
                    next[m[1]] = m[2];
            }
            root.chosen = next;
        }
        // No file yet: write one listing every event, so there is something to edit.
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                conf.setText(root.template());
        }
    }
}
