pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import ".."

// QR codes on the screen: photograph it, find every code, let the user read and act on each.
Singleton {
    id: root

    property bool open: false
    property bool scanning: false
    // Set by the window, so a press during the fade-out closes instead of photographing it.
    property bool showing: false
    // Picked once, so the washes stay on the screen that was scanned.
    property var screen: null
    // See finish(): what each code holds, where it is on screen and in the picture.
    property var codes: []
    // Bumped per scan: the picture keeps one path, and Qt caches images by URL.
    property int taken: 0

    readonly property string shot: Quickshell.env("XDG_RUNTIME_DIR") + "/ummitos-scan.ppm"
    readonly property string crop: shot + ".crop"
    readonly property url picture: "file://" + shot + "?" + taken

    // The scan picture stays for the detail panel's crop until the overlay has gone.
    onShowingChanged: if (!showing && !open)
        forget()

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

    // Percent-decoded, and left as it is when the encoding is broken.
    function decode(text: string): string {
        try {
            return decodeURIComponent(text.replace(/\+/g, " "));
        } catch (e) {
            return text;
        }
    }

    function pairs(query: string): var {
        return query.split("&").filter(p => p !== "").map(p => {
            const eq = p.indexOf("=");
            return eq < 0 ? [decode(p), ""] : [decode(p.slice(0, eq)), decode(p.slice(eq + 1))];
        });
    }

    // Kind, the panel's type line, a short title for the label, and the labelled fields.
    function describe(data: string): var {
        // Open only printable-ASCII links, so nothing invisible reaches xdg-open.
        const web = data.match(/^(https?):\/\/([\x21-\x7e]+)$/i);
        if (web) {
            const rest = web[2];
            const authority = rest.split(/[\/?#]/)[0];
            // A user:password@ before the host is a classic disguise; the host is after the last @.
            const host = authority.split("@").pop();
            const path = rest.slice(authority.length).split(/[?#]/)[0];
            const fragment = rest.split("#")[1] ?? "";
            const fields = [["Scheme", web[1].toLowerCase()], ["Host", host]];
            if (authority.includes("@"))
                fields.push(["User info", authority.slice(0, authority.lastIndexOf("@"))]);
            if (path !== "" && path !== "/")
                fields.push(["Path", path]);
            for (const pair of pairs(rest.split("#")[0].split("?")[1] ?? ""))
                fields.push([pair[0], pair[1], true]);
            if (fragment !== "")
                fields.push(["Fragment", decode(fragment)]);
            return {
                kind: "link",
                type: "Web link",
                title: host,
                fields: fields
            };
        }
        const uri = data.match(/^(mailto|tel|geo):([\x21-\x7e]+)$/i);
        // A tel: or geo: of any other shape is shown as text, not handed to whatever handler is installed.
        const shaped = {
            tel: /^[+\d().\-]+$/,
            geo: /^-?[\d.]+,-?[\d.]+(,-?[\d.]+)?([;?][\w.=,;&+\-%]*)?$/
        }[uri?.[1].toLowerCase()];
        if (uri && (!shaped || shaped.test(uri[2]))) {
            const kind = uri[1].toLowerCase();
            const head = uri[2].split("?")[0];
            const label = {
                mailto: "Address",
                tel: "Number",
                geo: "Coordinates"
            }[kind];
            return {
                kind: kind,
                type: {
                    mailto: "Email",
                    tel: "Phone number",
                    geo: "Place"
                }[kind],
                title: head,
                fields: [[label, head]].concat(pairs(uri[2].split("?")[1] ?? ""))
            };
        }
        if (/^WIFI:/i.test(data)) {
            // Split on unescaped ";" first, so an escaped ":" or ";" in a value cannot start a field.
            const values = {};
            for (const part of data.slice(5).match(/(?:\\.|[^;])+/g) ?? []) {
                const colon = part.indexOf(":");
                if (colon > 0)
                    values[part.slice(0, colon).toUpperCase()] = part.slice(colon + 1).replace(/\\(.)/g, "$1");
            }
            const fields = [["Network", values.S ?? ""], ["Security", values.T && values.T.toLowerCase() !== "nopass" ? values.T : I18n.t("No password")]];
            if ((values.H ?? "").toLowerCase() === "true")
                fields.push(["Hidden", I18n.t("Yes")]);
            return {
                kind: "wifi",
                type: "Wi-Fi network",
                title: values.S ?? "",
                fields: fields,
                password: values.P ?? "",
                // The raw text with only the P field hidden, by a fixed count that does not tell its length.
                masked: data.replace(/(^WIFI:|;)(P:)((?:\\.|[^;])*)/i, (m, before, key, value) => value === "" ? m : before + key + "••••••••")
            };
        }
        return {
            kind: "text",
            type: "Text",
            title: data.split("\n")[0],
            fields: []
        };
    }

    function act(code: var): void {
        if (code.kind === "wifi")
            join.exec(["sh", "-c", 'nmcli dev wifi connect "$1" ${2:+password "$2"} >/dev/null || notify-send -a "Wi-Fi" -- "$3"', "sh", code.title, code.password, I18n.t("Could not join %1").arg(code.title)]);
        else if (code.kind === "text")
            return copy(code.data);
        else
            Quickshell.execDetached(["xdg-open", code.kind === "mailto" ? mailto(code.data) : code.data]);
        open = false;
    }

    // Some mail clients attach a local file named in attach=; only the plain fields go through.
    function mailto(link: string): string {
        const [head, query] = link.split("?");
        const kept = (query ?? "").split("&").filter(p => /^(to|cc|bcc|subject|body)=/i.test(p));
        return kept.length > 0 ? head + "?" + kept.join("&") : head;
    }

    function copy(text: string): void {
        Quickshell.execDetached(["wl-copy", "--", text]);
        open = false;
    }

    // Size line, then zbar's XML; XML mangles non-ASCII into broken base64, so those are read again.
    function parse(text: string): void {
        if (!text.includes("<barcodes")) {
            scanning = false;
            forget();
            Quickshell.execDetached(["notify-send", "-a", "QR scanner", I18n.t("Scan failed"), I18n.t("Could not photograph or read the screen.")]);
            return;
        }
        const width = Number(text.split("\n")[0].split(" ")[0]);
        const factor = width > 0 && screen ? width / screen.width : 1;
        const found = [];
        const symbol = /<symbol type='([^']*)'[^>]*?orientation='(\w+)'[^>]*><polygon points='([^']*)'\/><data( format='base64')?[^>]*><!\[CDATA\[([\s\S]*?)\]\]><\/data>/g;
        let m;
        while ((m = symbol.exec(text)) !== null) {
            const points = m[3].trim().split(/\s+/).map(p => p.split(",").map(Number));
            const px = points.map(p => p[0]), py = points.map(p => p[1]);
            const x = Math.min(...px), y = Math.min(...py);
            const w = Math.max(...px) - x, h = Math.max(...py) - y;
            found.push({
                data: m[4] ? null : m[5],
                format: m[1],
                orientation: m[2],
                pixels: Qt.rect(x, y, w, h),
                x: x / factor,
                y: y / factor,
                w: w / factor,
                h: h / factor
            });
        }
        const unread = found.filter(c => c.data === null);
        if (unread.length === 0)
            return finish(found);
        reread.pending = found;
        reread.command = ["sh", "-c", 'f="$1"; shift; for r; do grim -g "$r" -t ppm "$f" && zbarimg -q --raw -Sbinary "$f"; printf "\\036"; done; rm -f "$f"', "sh", crop, ...unread.map(c => `${Math.floor(screen.x + c.x) - 1},${Math.floor(screen.y + c.y) - 1} ${Math.ceil(c.w) + 2}x${Math.ceil(c.h) + 2}`)];
        reread.running = true;
    }

    function finish(found: var): void {
        scanning = false;
        taken++;
        codes = found.filter(c => c.data).map(c => {
            const code = describe(c.data);
            for (const key of ["data", "format", "orientation", "pixels", "x", "y", "w", "h"])
                code[key] = c[key];
            return code;
        });
        if (codes.length > 0) {
            // A rising two-note bip, only when something was found.
            Quickshell.execDetached(["pw-play", Quickshell.shellDir + "/scan/found.ogg"]);
            open = true;
        } else {
            forget();
            Quickshell.execDetached(["notify-send", "-a", "QR scanner", I18n.t("No QR code on screen")]);
        }
    }

    function forget(): void {
        Quickshell.execDetached(["rm", "-f", shot]);
    }

    Process {
        id: find

        command: ["sh", "-c", 'grim -t ppm -o "$1" "$2" || exit; head -c 32 "$2" | sed -n 2p; zbarimg -q --xml "$2"', "sh", root.screen?.name ?? "", root.shot]
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
