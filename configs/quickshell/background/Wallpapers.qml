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

    // The folder the random pick draws from, relative to dir; "" is every wallpaper.
    property string folder: ""
    readonly property var inFolder: folder === "" ? [] : list.filter(p => p.startsWith(dir + "/" + folder + "/"))
    // Falls back to everything when the chosen folder is gone or empty, so a pick never does nothing.
    readonly property var pool: inFolder.length > 0 ? inFolder : list
    // Every folder holding pictures, a parent before its subfolders: {path, name, depth, count}.
    readonly property var folders: {
        const counts = {};
        for (const p of list) {
            const parts = p.slice(dir.length + 1).split("/").slice(0, -1);
            for (let i = 1; i <= parts.length; i++) {
                const key = parts.slice(0, i).join("/");
                counts[key] = (counts[key] ?? 0) + 1;
            }
        }
        // Segment by segment, so "Anime Foo" cannot fall between "Anime" and "Anime/Alya".
        return Object.keys(counts).map(k => k.split("/")).sort((a, b) => {
            for (let i = 0; i < Math.min(a.length, b.length); i++)
                if (a[i] !== b[i])
                    return a[i].localeCompare(b[i]);
            return a.length - b.length;
        }).map(parts => {
            const path = parts.join("/");
            return {
                path: path,
                name: parts[parts.length - 1],
                depth: parts.length - 1,
                count: counts[path]
            };
        });
    }

    // True only while the chosen folder still has pictures, so the bar never marks a fallback.
    readonly property bool filtered: inFolder.length > 0
    readonly property bool scanning: scan.running
    // Set after the first scan, so views can skip animating the values it brings.
    property bool ready: false
    // The first scan waits for both state files, or it picks over the saved wallpaper or folder.
    property int loading: 2

    function loadedOne(): void {
        if (--loading === 0)
            scan.running = true;
    }

    function setFolder(path: string): void {
        folder = path;
        folderFile.setText(path);
        setRandom();
    }

    onPickerOpenChanged: {
        if (pickerOpen)
            scan.running = true;
    }

    function setRandom(): void {
        pendingRandom = true;
        scan.running = true;
    }

    function pickRandom(): void {
        const from = pool;
        if (from.length === 0)
            return;
        reveal = true;
        let next = from[Math.floor(Math.random() * from.length)];
        if (from.length > 1)
            while (next === actual)
                next = from[Math.floor(Math.random() * from.length)];
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
                root.ready = true;
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
            root.loadedOne();
        }
        onLoadFailed: root.loadedOne()
    }

    FileView {
        id: folderFile
        path: Quickshell.statePath("wallpaper-folder.txt")
        printErrors: false
        blockWrites: false
        onLoaded: {
            root.folder = text().trim();
            root.loadedOne();
        }
        onLoadFailed: root.loadedOne()
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
