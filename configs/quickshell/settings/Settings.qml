pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The settings panel, plus options read by desktop helper scripts.
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
            name: "Privacy",
            icon: "privacy_tip"
        },
        {
            name: "Wipe",
            icon: "mop"
        },
        {
            name: "Bar",
            icon: "toolbar"
        },
        {
            name: "Screenshots",
            icon: "screenshot_region"
        },
        {
            name: "Language",
            icon: "translate"
        },
        {
            name: "About",
            icon: "info"
        }
    ]

    readonly property string home: Quickshell.env("HOME")
    // Plain key=value lines, so the script can read them without the shell.
    readonly property string recordFile: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/ummitos/recording.conf"
    readonly property string privacyFile: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/ummitos/privacy.conf"

    property string folder: home + "/Videos/Recordings"
    // wl-screenrec's -b: bytes per second, "5 MB" is 40 Mbps.
    property string bitrate: "5 MB"
    // 0 is no cap.
    property int fps: 60
    property string codec: "auto"
    property bool cursor: true

    readonly property string barFile: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/ummitos/bar.conf"

    readonly property string shotFile: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/ummitos/screenshot.conf"

    // Empty is the default: HYPRSHOT_DIR, else ~/Pictures/Screenshots.
    property string shotFolder: ""
    readonly property string shotDir: shotFolder !== "" ? shotFolder : Quickshell.env("HYPRSHOT_DIR") || home + "/Pictures/Screenshots"

    // Empty watches the shell's own folder.
    property string watchFolder: ""
    property bool watchShow: true
    property bool watchMissing: false
    property string watchPending: ""

    // Whether the gallery's search reads the text inside new screenshots.
    property bool ocrEnabled: true

    // What the wiper would remove, by name: {ocr: [{path, bytes}], ...}, and the file system they sit on.
    property var traces: ({})
    property string traceFs: ""
    property bool wiping: false
    property string wipeResult: ""

    property bool clipboardHistory: true
    property int clipboardClearMinutes: 0
    property var clipboardPolicyPending: null

    // Newest first: {name, path, size, time}.
    property var files: []

    // Waiting for the running gio; sent together once it exits.
    property var trashQueue: []

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

    // False when it is not a full path, so the field can say so; empty goes back to the default.
    function setShotFolder(path: string): bool {
        const p = path.trim().replace(/^~(?=\/|$)/, home).replace(/\/+$/, "");
        if (p !== "" && !p.startsWith("/"))
            return false;
        shotFolder = p;
        shotConf.setText("folder=" + p + "\n");
        return true;
    }

    function setBar(key: string, value: var): void {
        root[key] = value;
        barConf.setText(["watch=" + watchFolder, "show=" + (watchShow ? 1 : 0)].join("\n") + "\n");
    }

    // False when it is not a full path; a folder that is missing is reported once the check ends.
    function setWatch(path: string): bool {
        const p = path.trim().replace(/^~(?=\/|$)/, home).replace(/\/+$/, "");
        if (p === "") {
            watchMissing = false;
            setBar("watchFolder", "");
            return true;
        }
        if (!p.startsWith("/"))
            return false;
        watchPending = p;
        watchCheck.command = ["test", "-d", p];
        watchCheck.running = true;
        return true;
    }

    function writePrivacy(): void {
        privacyConf.setText(["history=" + (clipboardHistory ? 1 : 0), "clear_minutes=" + clipboardClearMinutes, "ocr=" + (ocrEnabled ? 1 : 0)].join("\n") + "\n");
    }

    function setOcr(on: bool): void {
        ocrEnabled = on;
        writePrivacy();
    }

    // The wiper script: the repo's copy when the shell runs from it, else the installed one.
    function wiperCommand(args: var): var {
        return ["sh", "-c", 'd=$(readlink -f "$1"); shift; for s in "$d/../../script/misc/wipe-traces.sh" "$HOME/script/misc/wipe-traces.sh"; do [ -x "$s" ] && exec "$s" "$@"; done; exit 127', "sh", Quickshell.shellDir].concat(args);
    }

    function scanTraces(): void {
        if (traceScan.running || wiping)
            return;
        traceScan.command = wiperCommand(["--list", "ocr", "clipboard", "changes", "launches", "place", "temp"]);
        traceScan.running = true;
    }

    // Forgets what the shell holds in memory first, so nothing writes it back after the shred.
    function wipe(names: var, passes: int): void {
        if (wiping || names.length === 0)
            return;
        wiping = true;
        wipeResult = "";
        if (names.includes("changes"))
            FileChanges.forget();
        if (names.includes("launches"))
            Launcher.forgetLaunches();
        if (names.includes("clipboard"))
            Launcher.forgetClipboard();
        if (names.includes("place"))
            Weather.setLocation("");
        if (names.includes("ocr"))
            Gallery.indexed = 0;
        wiper.counts = ({});
        wiper.command = wiperCommand(["--passes", String(passes)].concat(names));
        wiper.running = true;
    }

    function setClipboard(key: string, value: var): void {
        root[key] = value;
        Launcher.clipboardHistory = clipboardHistory;
        writePrivacy();
        if (key === "clipboardHistory" && !clipboardHistory) {
            Launcher.forgetClipboard();
            runClipboardPolicy("clear", "");
        }
        else if (key === "clipboardClearMinutes")
            runClipboardPolicy(clipboardClearMinutes > 0 ? "schedule" : "cancel", String(clipboardClearMinutes));
    }

    function clearClipboard(): void {
        Launcher.forgetClipboard();
        runClipboardPolicy("clear", "");
    }

    function runClipboardPolicy(action: string, value: string): void {
        clipboardPolicyPending = { action: action, value: value };
        startClipboardPolicy();
    }

    function startClipboardPolicy(): void {
        if (clipboardPolicy.running || clipboardPolicyPending === null)
            return;
        const next = clipboardPolicyPending;
        clipboardPolicyPending = null;
        clipboardPolicy.command = ["sh", "-c", 'd=$(readlink -f "$1"); for s in "$d/../../script/cliphist/clipboard-expiry.sh" "$HOME/script/cliphist/clipboard-expiry.sh"; do [ -x "$s" ] && exec "$s" "$2" "$3"; done; exit 127', "sh", Quickshell.shellDir, next.action, next.value];
        clipboardPolicy.running = true;
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

        path: root.recordFile
        printErrors: false
        blockWrites: false
    }

    Process {
        id: traceScan

        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                let fs = "";
                for (const line of text.split("\n")) {
                    const [kind, a, b, c] = line.split("\t");
                    if (kind === "fs")
                        fs = a;
                    else if (kind === "file") {
                        found[a] = (found[a] ?? []).concat([
                            {
                                path: b,
                                bytes: Number(c)
                            }
                        ]);
                    }
                }
                root.traces = found;
                root.traceFs = fs;
            }
        }
    }

    Process {
        id: wiper

        property var counts: ({})

        stdout: SplitParser {
            onRead: line => {
                const [kind, name, n] = line.split("\t");
                if (kind === "wiped") {
                    const next = Object.assign({}, wiper.counts);
                    next[name] = Number(n);
                    wiper.counts = next;
                }
            }
        }

        onExited: code => {
            root.wiping = false;
            const total = Object.values(counts).reduce((sum, n) => sum + n, 0);
            root.wipeResult = code === 0 ? I18n.t("%1 files overwritten and removed.").arg(total) : I18n.t("The wiper stopped with an error.");
            Notifs.say("Privacy", code === 0 ? I18n.t("Traces wiped") : I18n.t("Could not wipe the traces"), root.wipeResult, code === 0 ? "normal" : "critical");
            root.scanTraces();
        }
    }

    FileView {
        id: shotConf

        onLoaded: {
            for (const line of text().split("\n")) {
                if (line.startsWith("folder="))
                    root.shotFolder = line.slice(7);
            }
        }

        path: root.shotFile
        printErrors: false
        blockWrites: true
    }

    FileView {
        id: barConf

        onLoaded: {
            for (const line of text().split("\n")) {
                const at = line.indexOf("=");
                const key = line.slice(0, at), value = line.slice(at + 1);
                if (key === "watch")
                    root.watchFolder = value;
                else if (key === "show")
                    root.watchShow = value !== "0";
            }
        }

        path: root.barFile
        printErrors: false
        blockWrites: true
    }

    Process {
        id: watchCheck

        onExited: code => {
            root.watchMissing = code !== 0;
            if (code === 0)
                root.setBar("watchFolder", root.watchPending);
        }
    }

    FileView {
        id: privacyConf

        onLoaded: {
            for (const line of text().split("\n")) {
                const at = line.indexOf("=");
                const key = line.slice(0, at), value = line.slice(at + 1);
                if (key === "history")
                    root.clipboardHistory = value !== "0";
                else if (key === "clear_minutes")
                    root.clipboardClearMinutes = Number(value) || 0;
                else if (key === "ocr")
                    root.ocrEnabled = value !== "0";
            }
            Launcher.clipboardHistory = root.clipboardHistory;
        }

        path: root.privacyFile
        printErrors: false
        blockWrites: true
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
                Notifs.say("Settings", I18n.t("Could not move to Trash"), I18n.t("gio trash failed; the recording is still in its folder."));
            root.refresh();
            Qt.callLater(root.runTrash);
        }
    }

    Process {
        id: clipboardPolicy

        onExited: code => {
            if (code !== 0)
                Notifs.say("Settings", I18n.t("Could not apply clipboard privacy settings"), I18n.t("The clipboard helper exited with an error."));
            Qt.callLater(root.startClipboardPolicy);
        }
    }

    // Restore or immediately enforce an expiry after a shell/user-manager restart.
    Process {
        running: true
        command: ["sh", "-c", 'd=$(readlink -f "$1"); for s in "$d/../../script/cliphist/clipboard-expiry.sh" "$HOME/script/cliphist/clipboard-expiry.sh"; do [ -x "$s" ] && exec "$s" enforce; done; exit 127', "sh", Quickshell.shellDir]
    }

    // A recording that just finished belongs in the list.
    Connections {
        function onRecordingChanged(): void {
            if (!Recorder.recording && root.open)
                root.refresh();
        }

        target: Recorder
    }

    IpcHandler {
        function toggle(): void {
            root.toggle();
        }

        // 0 Record, 1 Packages, 2 Update, 3 Privacy, 4 Language, 5 About.
        function page(index: int): void {
            root.page = Math.max(0, Math.min(index, root.pages.length - 1));
            root.open = true;
        }

        function close(): void {
            root.open = false;
        }

        target: "settings"
    }
}
