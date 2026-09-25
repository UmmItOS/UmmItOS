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

    // `actual` is confirmed; `previewPath` is what the picker hovers.
    property string actual
    property string previewPath
    readonly property string current: previewPath !== "" ? previewPath : actual

    // "…/Anime/foo.jpg" -> "foo"
    function name(path: string): string {
        const base = path.slice(path.lastIndexOf("/") + 1);
        const dot = base.lastIndexOf(".");
        return dot > 0 ? base.slice(0, dot) : base;
    }

    // Only the random pick reveals through a circle; the rest fade.
    property bool reveal: false

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
        // Cleared once every screen has read it, not by the first to swap.
        Qt.callLater(() => reveal = false);
    }

    function preview(path: string): void {
        previewPath = path;
    }

    function clearPreview(): void {
        previewPath = "";
    }

    function set(path: string): void {
        // Assign first, or `current` flashes the old wallpaper for a frame.
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
                // Only a real change: a new array resets every view on it.
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
