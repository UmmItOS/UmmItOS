pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.wallpaper"
    readonly property string statePath: Quickshell.statePath("wallpaper.txt")

    property list<string> list: []
    property bool pickerOpen

    // `actual` is the confirmed wallpaper; `previewPath` is what the picker is
    // hovering over. The background always draws `current`, so arrowing through
    // the picker changes the wallpaper without committing to it.
    property string actual
    property string previewPath
    readonly property string current: previewPath !== "" ? previewPath : actual

    // "…/Anime/foo.jpg" -> "foo"
    function name(path: string): string {
        const base = path.slice(path.lastIndexOf("/") + 1);
        const dot = base.lastIndexOf(".");
        return dot > 0 ? base.slice(0, dot) : base;
    }

    function setRandom(): void {
        if (list.length === 0)
            return;
        let next = list[Math.floor(Math.random() * list.length)];
        if (list.length > 1)
            while (next === actual)
                next = list[Math.floor(Math.random() * list.length)];
        set(next);
    }

    function preview(path: string): void {
        previewPath = path;
    }

    function clearPreview(): void {
        previewPath = "";
    }

    function set(path: string): void {
        // Order matters: clearing previewPath first would drop `current` back to
        // the old `actual` for one frame, flashing the previous wallpaper.
        actual = path;
        previewPath = "";
        stateFile.setText(path);
    }

    // hyprlock reads its own config and cannot see ours, so its background is
    // rewritten whenever the wallpaper is committed. Scoped to the background
    // block, and written back $HOME-relative so the config stays portable —
    // the same edit script/awww/detect.sh used to make.
    onActualChanged: {
        if (actual === "")
            return;
        const home = Quickshell.env("HOME");
        const portable = actual.startsWith(home) ? "$HOME" + actual.slice(home.length) : actual;
        lockSync.running = false;
        lockSync.command = ["sed", "-i", `/^# Background wallpaper/,/^}/ s|^    path = .*|    path = ${portable}|`, home + "/.config/hypr/hyprlock.conf"];
        lockSync.running = true;
    }

    Process {
        id: lockSync
    }

    // Same extension filter as script/swww/random-wallpaper.sh, and recursive
    // so the Anime/ and Landscape/ subfolders are included.
    Process {
        running: true
        command: ["find", root.dir, "-type", "f", "-regex", ".*\\.\\(jpg\\|png\\|jpeg\\)"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.list = text.trim().split("\n").filter(l => l !== "");
                if (!root.actual || !root.list.includes(root.actual))
                    root.setRandom();
            }
        }
    }

    // Remembers the wallpaper across restarts.
    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        // Never stall the UI thread on Enter to save one line of text.
        blockWrites: false
        onLoaded: {
            const saved = text().trim();
            if (saved)
                root.actual = saved;
        }
    }

    // qs -c ummitos ipc call wallpaper next
    IpcHandler {
        target: "wallpaper"

        function next(): void {
            root.setRandom();
        }

        function set(path: string): void {
            root.set(path);
        }

        function get(): string {
            return root.actual;
        }

        function toggle(): void {
            root.pickerOpen = !root.pickerOpen;
        }
    }
}
