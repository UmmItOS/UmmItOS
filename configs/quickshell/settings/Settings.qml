pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The settings panel, and the recording options script/misc/screen-record.sh reads.
Singleton {
    id: root

    property bool open: false
    property int page: 0
    readonly property var pages: [
        {
            name: "Record",
            icon: "videocam"
        },
        {
            name: "Packages",
            icon: "deployed_code"
        },
        {
            name: "Update",
            icon: "system_update_alt"
        },
        {
            name: "About",
            icon: "info"
        }
    ]

    readonly property string home: Quickshell.env("HOME")
    // Plain key=value lines, so the script can read them without the shell.
    readonly property string recordFile: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/ummitos/recording.conf"

    property string folder: home + "/Videos/Recordings"
    // wl-screenrec's -b: bytes per second, "5 MB" is 40 Mbps.
    property string bitrate: "5 MB"
    // 0 is no cap.
    property int fps: 60
    property string codec: "auto"
    property bool cursor: true

    // Newest first: {name, path, size, time}.
    property var files: []

    function toggle(): void {
        open = !open;
    }

    function set(key: string, value: var): void {
        root[key] = value;
        conf.setText(["folder=" + folder, "bitrate=" + bitrate, "fps=" + fps, "codec=" + codec, "cursor=" + (cursor ? 1 : 0)].join("\n") + "\n");
        if (key === "folder")
            refresh();
    }

    // False when it is not a full path, so the field can say so.
    function setFolder(path: string): bool {
        const p = path.trim().replace(/^~(?=\/|$)/, home).replace(/\/+$/, "");
        if (!p.startsWith("/"))
            return false;
        set("folder", p);
        return true;
    }

    // Home as ~, only as a whole path segment.
    function tilde(path: string): string {
        if (path === home)
            return "~";
        return path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
    }

    function size(bytes: real): string {
        const units = ["B", "KB", "MB", "GB"];
        let i = 0;
        while (bytes >= 1024 && i < units.length - 1) {
            bytes /= 1024;
            i++;
        }
        return (i > 1 ? bytes.toFixed(1) : Math.round(bytes)) + " " + units[i];
    }

    function refresh(): void {
        list.running = false;
        list.running = true;
    }

    function openFile(path: string): void {
        Quickshell.execDetached(["xdg-open", path]);
    }

    function openFolder(): void {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "sh", folder]);
    }

    // Waiting for the running gio; sent together once it exits.
    property var trashQueue: []

    // To the Trash, not deleted, so a wrong click can be undone.
    function trash(path: string): void {
        trashQueue = trashQueue.concat([path]);
        runTrash();
    }

    function runTrash(): void {
        if (trasher.running || trashQueue.length === 0)
            return;
        trasher.command = ["gio", "trash", "--"].concat(trashQueue);
        trashQueue = [];
        trasher.running = true;
    }

    // Its folder may not exist yet; the file is written on the first change.
    Process {
        running: true
        command: ["mkdir", "-p", root.recordFile.replace(/\/[^/]*$/, "")]
    }

    FileView {
        id: conf
        path: root.recordFile
        printErrors: false
        blockWrites: false
        onLoaded: {
            for (const line of text().split("\n")) {
                const at = line.indexOf("=");
                const key = line.slice(0, at), value = line.slice(at + 1);
                if (key === "folder" && value !== "")
                    root.folder = value;
                else if (key === "bitrate" && value !== "")
                    root.bitrate = value;
                else if (key === "fps")
                    root.fps = Number(value) || 0;
                else if (key === "codec" && value !== "")
                    root.codec = value;
                else if (key === "cursor")
                    root.cursor = value !== "0";
            }
        }
    }

    Process {
        id: list
        command: ["find", root.folder, "-maxdepth", "1", "-type", "f", "(", "-name", "*.mp4", "-o", "-name", "*.mkv", "-o", "-name", "*.webm", ")", "-printf", "%T@\\t%s\\t%f\\0"]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\0").filter(l => l !== "").map(l => {
                    const [time, size] = l.split("\t");
                    const name = l.split("\t").slice(2).join("\t");
                    return {
                        name: name,
                        path: root.folder + "/" + name,
                        size: Number(size),
                        time: Number(time) * 1000
                    };
                }).sort((a, b) => b.time - a.time)
        }
    }

    Process {
        id: trasher
        onExited: code => {
            if (code !== 0)
                Quickshell.execDetached(["notify-send", "-a", "Settings", "Could not move to Trash", "gio trash failed; the recording is still in its folder."]);
            root.refresh();
            Qt.callLater(root.runTrash);
        }
    }

    // A recording that just finished belongs in the list.
    Connections {
        target: Recorder
        function onRecordingChanged(): void {
            if (!Recorder.recording && root.open)
                root.refresh();
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            root.toggle();
        }

        // 0 Record, 1 Packages, 2 Update, 3 About.
        function page(index: int): void {
            root.page = Math.max(0, Math.min(index, root.pages.length - 1));
            root.open = true;
        }

        function close(): void {
            root.open = false;
        }
    }
}
