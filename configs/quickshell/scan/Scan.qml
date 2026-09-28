pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// QR codes on the screen: photograph it, find every code, let the user act on each.
Singleton {
    id: root

    property bool open: false
    property bool scanning: false
    // Set by the window, so a press during the fade-out closes instead of photographing it.
    property bool showing: false
    // Picked once, so the washes stay on the screen that was scanned.
    property var screen: null
    // {kind, data, title, detail, x, y, w, h}: see describe().
    property var codes: []

    readonly property string shot: Quickshell.env("XDG_RUNTIME_DIR") + "/ummitos-scan.ppm"

    function start(on: var): void {
        if (open || showing) {
            open = false;
            return;
        }
        if (scanning)
            return;
        screen = on ?? Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        scanning = true;
        find.running = true;
    }

    // Open only printable-ASCII links, so nothing invisible reaches xdg-open.
    function describe(data: string): var {
        const web = data.match(/^(https?):\/\/([\x21-\x7e]+)$/i);
        if (web) {
            const host = web[2].split(/[\/?#]/)[0];
            return {
                kind: "link",
                title: host,
                detail: web[2].slice(host.length)
            };
        }
        if (/^(mailto|tel|geo):[\x21-\x7e]+$/i.test(data))
            return {
                kind: data.split(":")[0].toLowerCase(),
                title: data.slice(data.indexOf(":") + 1),
                detail: ""
            };
        if (/^WIFI:/i.test(data)) {
            const field = key => (data.match(new RegExp("[:;]" + key + ":((?:\\\\.|[^;])*)")) ?? [])[1]?.replace(/\\(.)/g, "$1") ?? "";
            return {
                kind: "wifi",
                title: field("S"),
                detail: field("T") || "Open network",
                password: field("P")
            };
        }
        return {
            kind: "text",
            title: data,
            detail: ""
        };
    }

    function act(code: var): void {
        if (code.kind === "wifi")
            join.exec(["sh", "-c", 'nmcli dev wifi connect "$1" ${2:+password "$2"} >/dev/null || notify-send -a "Wi-Fi" "Could not join $1"', "sh", code.title, code.password]);
        else if (code.kind === "text")
            return copy(code.data);
        else
            Quickshell.execDetached(["xdg-open", code.data]);
        open = false;
    }

    function copy(text: string): void {
        Quickshell.execDetached(["wl-copy", "--", text]);
        open = false;
    }

    // Size line, then zbar's XML; XML mangles non-ASCII into broken base64, so those are read again.
    function parse(text: string): void {
        if (!text.includes("<barcodes")) {
            scanning = false;
            Quickshell.execDetached(["notify-send", "-a", "QR scanner", "Scan failed", "Could not photograph or read the screen."]);
            return;
        }
        const width = Number(text.split("\n")[0].split(" ")[0]);
        const factor = width > 0 && screen ? width / screen.width : 1;
        const found = [];
        const symbol = /<polygon points='([^']*)'\/><data( format='base64')?[^>]*><!\[CDATA\[([\s\S]*?)\]\]><\/data>/g;
        let m;
        while ((m = symbol.exec(text)) !== null) {
            const points = m[1].trim().split(/\s+/).map(p => p.split(",").map(Number));
            const xs = points.map(p => p[0] / factor), ys = points.map(p => p[1] / factor);
            const x = Math.min(...xs), y = Math.min(...ys);
            found.push({
                data: m[2] ? null : m[3],
                x: x,
                y: y,
                w: Math.max(...xs) - x,
                h: Math.max(...ys) - y
            });
        }
        const unread = found.filter(c => c.data === null);
        if (unread.length === 0)
            return finish(found);
        reread.pending = found;
        reread.command = ["sh", "-c", 'f="$1"; shift; for r; do grim -g "$r" -t ppm "$f" && zbarimg -q --raw -Sbinary "$f"; printf "\\036"; done; rm -f "$f"', "sh", shot, ...unread.map(c => `${Math.floor(screen.x + c.x) - 1},${Math.floor(screen.y + c.y) - 1} ${Math.ceil(c.w) + 2}x${Math.ceil(c.h) + 2}`)];
        reread.running = true;
    }

    function finish(found: var): void {
        scanning = false;
        codes = found.filter(c => c.data).map(c => {
            const code = describe(c.data);
            code.data = c.data;
            code.x = c.x;
            code.y = c.y;
            code.w = c.w;
            code.h = c.h;
            return code;
        });
        if (codes.length > 0)
            open = true;
        else
            Quickshell.execDetached(["notify-send", "-a", "QR scanner", "No QR code on screen"]);
    }

    Process {
        id: find

        command: ["sh", "-c", 'grim -t ppm -o "$1" "$2" || exit; head -c 32 "$2" | sed -n 2p; zbarimg -q --xml "$2"; rm -f "$2"', "sh", root.screen?.name ?? "", root.shot]
        // Also ends a scan whose grim or zbar failed, so a second press works.
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    // Each unread code on its own, in zbar's raw mode, which keeps UTF-8 intact.
    Process {
        id: reread

        property var pending: []

        stdout: StdioCollector {
            onStreamFinished: {
                const texts = text.split("\x1e");
                const found = reread.pending;
                let i = 0;
                for (const code of found)
                    if (code.data === null)
                        code.data = (texts[i++] ?? "").replace(/\n$/, "");
                root.finish(found);
            }
        }
    }

    Process {
        id: join
    }

    IpcHandler {
        target: "scan"

        function toggle(): void {
            root.start(null);
        }

        function close(): void {
            root.open = false;
        }
    }
}
