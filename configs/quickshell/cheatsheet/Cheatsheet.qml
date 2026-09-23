pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Every keybind that carries a description, read from the running Hyprland
// when the sheet opens, so it cannot drift from the config.
Singleton {
    id: root

    property bool open: false
    property var groups: []

    readonly property var order: ["Shell", "Apps", "Window", "Workspace", "Utilities", "Media"]

    // The Lua config starts every description with its group ("Shell:
    // Session menu"), since under Lua hyprctl reports every dispatcher as
    // "__lua". A description without one (the old hyprlang config) is
    // grouped by what the bind runs instead.
    function split(bind: var): var {
        const m = bind.description.match(/^(\w+):\s*(.*)$/);
        if (m && order.includes(m[1]))
            return {
                group: m[1],
                text: m[2]
            };
        return {
            group: groupOf(bind),
            text: bind.description
        };
    }

    function groupOf(bind: var): string {
        const d = bind.dispatcher;
        const a = bind.arg ?? "";
        // Media first: the brightness keys also call the shell's IPC.
        if (/^(brightnessctl|wpctl|playerctl)/.test(a))
            return "Media";
        if (/wf-recorder|hyprpicker|woomer|smile|ipc call screenshot/.test(a))
            return "Utilities";
        if (d === "global" || a.includes("qs -c ummitos ipc"))
            return "Shell";
        if (d === "workspace" || d === "movetoworkspace" || d === "togglespecialworkspace")
            return "Workspace";
        if (d === "exec")
            return "Apps";
        return "Window";
    }

    function keysOf(bind: var): list<string> {
        const mods = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]].filter(m => bind.modmask & m[0]).map(m => m[1]);
        const named = {
            "mouse:272": "LMB",
            "mouse:273": "RMB",
            "mouse_down": "Scroll ↓",
            "mouse_up": "Scroll ↑",
            "left": "←",
            "right": "→",
            "up": "↑",
            "down": "↓",
            "Alt_L": "Alt",
            "Return": "Enter",
            "PRINT": "Print",
            "Print": "Print",
            "TAB": "Tab",
            "slash": "/"
        };
        let key = bind.keycode === 36 ? "Enter" : bind.keycode === 61 ? "/" : (named[bind.key] ?? bind.key);
        // Media keys by what they are for, short enough to leave the
        // description room.
        const media = {
            "XF86MonBrightnessUp": "Bright +",
            "XF86MonBrightnessDown": "Bright −",
            "XF86AudioRaiseVolume": "Vol +",
            "XF86AudioLowerVolume": "Vol −",
            "XF86AudioMute": "Mute",
            "XF86AudioPlay": "Play",
            "XF86AudioPrev": "Prev",
            "XF86AudioNext": "Next"
        };
        if (media[key])
            key = media[key];
        else if (key.startsWith("XF86"))
            key = key.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2");
        else if (key.length === 1)
            key = key.toUpperCase();
        // A bind on a modifier's own release (Alt for the switcher) would read
        // "Alt Alt".
        return mods.includes(key) ? mods : [...mods, key];
    }

    function build(binds: var): void {
        const byGroup = {};
        for (const b of binds.filter(b => b.has_description)) {
            const parts = split(b);
            const g = parts.group;
            const description = parts.text;
            const keys = keysOf(b);
            // "Switch to workspace 1" … "10" collapse into one row.
            const n = description.match(/^(.*?)\s*(\d+)$/);
            const rows = byGroup[g] ?? (byGroup[g] = []);
            if (n) {
                const stem = n[1];
                const prefix = keys.slice(0, -1).join("+");
                const same = rows.find(r => r.stem === stem && r.prefix === prefix);
                if (same) {
                    same.last = keys[keys.length - 1];
                    same.description = `${stem} 1–${n[2]}`;
                    same.keys = [...keys.slice(0, -1), `${same.first}…${same.last}`];
                    continue;
                }
                rows.push({
                    stem: stem,
                    prefix: prefix,
                    first: keys[keys.length - 1],
                    keys: keys,
                    description: description
                });
                continue;
            }
            rows.push({
                keys: keys,
                description: description
            });
        }
        groups = order.filter(g => byGroup[g]).map(g => ({
                    title: g,
                    rows: byGroup[g]
                }));
    }

    onOpenChanged: {
        if (open)
            read.running = true;
    }

    Process {
        id: read
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.build(JSON.parse(text));
                } catch (e) {
                    root.groups = [];
                }
            }
        }
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(): void {
            root.open = !root.open;
        }

        function close(): void {
            root.open = false;
        }
    }
}
