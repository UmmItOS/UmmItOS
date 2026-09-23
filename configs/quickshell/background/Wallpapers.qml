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

    // Set for one change: the random button reveals its pick through a
    // growing circle, the way awww's transition used to. Everything else fades.
    property bool reveal: false

    // The folder is read again whenever it is about to be used, so wallpapers
    // added to ~/.wallpaper show up without restarting the shell.
    property bool pendingRandom: false

    onPickerOpenChanged: {
        if (pickerOpen)
            scan.running = true;
    }

    function setRandom(): void {
        pendingRandom = true;
        scan.running = true;
    }

    function pickRandom(): void {
        if (list.length === 0)
            return;
        reveal = true;
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

    // Recursive, so the Anime/ and Landscape/ subfolders are included.
    Process {
        id: scan
        running: true
        command: ["find", root.dir, "-type", "f", "-regex", ".*\\.\\(jpg\\|png\\|jpeg\\)"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Only a real change replaces the list: a new array resets
                // every view on it, even when it holds the same files.
                const found = text.trim().split("\n").filter(l => l !== "");
                if (found.join("\n") !== root.list.join("\n"))
                    root.list = found;
                if (root.pendingRandom || !root.actual || !root.list.includes(root.actual)) {
                    root.pendingRandom = false;
                    root.pickRandom();
                }
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
