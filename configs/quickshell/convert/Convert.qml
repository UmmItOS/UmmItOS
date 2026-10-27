pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The picture converter (Super+I): pictures dropped on GTA's weapon wheel, a format picked on its ring, then a mission banner.
Singleton {
    id: root

    property bool open: false
    // Local paths and web links, in the order they were dropped.
    property var files: []
    // The picture the centre shows, and the ring's picked format.
    property int index: 0
    property int choice: 0
    readonly property var formats: [
        {
            ext: "png",
            icon: "image",
            hint: "Lossless",
            about: "Lossless, and keeps transparency."
        },
        {
            ext: "jpg",
            icon: "photo_camera",
            hint: "Photos",
            about: "Small photos. Transparency turns white."
        },
        {
            ext: "webp",
            icon: "language",
            hint: "Web",
            about: "Small, and keeps transparency and animation."
        },
        {
            ext: "avif",
            icon: "compress",
            hint: "Smallest",
            about: "The smallest files. Older apps cannot open it."
        },
        {
            ext: "gif",
            icon: "gif_box",
            hint: "Animation",
            about: "Animation, in 256 colours."
        },
        {
            ext: "bmp",
            icon: "grid_on",
            hint: "Uncompressed",
            about: "Uncompressed, for old programs."
        },
        {
            ext: "tiff",
            icon: "print",
            hint: "Print",
            about: "Lossless, for print and scans."
        },
        {
            ext: "ico",
            icon: "apps",
            hint: "Icon",
            about: "An app icon, at most 256 pixels a side."
        }
    ]
    readonly property bool busy: converter.running
    // How many pictures the converter has answered for.
    property int done: 0
    // The banner after a run: "" none, "passed" or "failed", with its two lines.
    property string result: ""
    property string headline: ""
    property string detail: ""
    readonly property bool shown: open || result !== ""

    function toggle(): void {
        if (open) {
            if (!busy)
                open = false;
            return;
        }
        result = "";
        files = [];
        index = 0;
        open = true;
    }

    // Drops arrive as file:// and web links; anything else is not a picture we can fetch.
    function take(urls: var, text: string): void {
        const links = Array.from(urls, u => u.toString());
        if (links.length === 0)
            text.split(/\r?\n/).forEach(t => {
                if (/^https?:\/\/\S+$/i.test(t.trim()))
                    links.push(t.trim());
            });
        const added = [];
        links.forEach(l => {
            let item = "";
            if (l.startsWith("file://"))
                item = decodeURIComponent(l.replace(/^file:\/\/[^\/]*/, ""));
            else if (/^https?:\/\//i.test(l))
                item = l;
            if (item !== "" && !root.files.includes(item) && !added.includes(item))
                added.push(item);
        });
        if (added.length === 0)
            return;
        index = files.length;
        files = files.concat(added);
    }

    function step(by: int): void {
        if (!busy)
            choice = (choice + by + formats.length) % formats.length;
    }

    function flip(by: int): void {
        if (files.length > 0)
            index = (index + by + files.length) % files.length;
    }

    function name(item: string): string {
        const tail = item.replace(/[?#].*$/, "").replace(/\/+$/, "");
        return decodeURIComponent(tail.slice(tail.lastIndexOf("/") + 1)) || item;
    }

    function convert(): void {
        if (busy || files.length === 0)
            return;
        done = 0;
        converter.saved = [];
        converter.failed = [];
        converter.command = ["sh", "-c", 'd=$(readlink -f "$1"); shift; for s in "$d/../../script/misc/img-convert.sh" "$HOME/script/misc/img-convert.sh"; do [ -x "$s" ] && exec "$s" "$@"; done; exit 127', "sh", Quickshell.shellDir, formats[choice].ext].concat(files);
        converter.running = true;
    }

    function finish(code: int): void {
        const saved = converter.saved, failed = converter.failed, ext = formats[choice].ext.toUpperCase();
        if (code !== 0 && saved.length === 0 && failed.length === 0)
            failed.push({
                name: "",
                why: code === 127 ? "img-convert.sh is missing." : "The converter stopped."
            });
        result = saved.length > 0 ? "passed" : "failed";
        if (saved.length === 1)
            headline = I18n.t("%1 → %2").arg(name(saved[0].from)).arg(name(saved[0].to));
        else if (saved.length > 1)
            headline = I18n.t("%1 pictures → %2").arg(saved.length).arg(ext);
        else
            headline = failed.length > 1 ? I18n.t("%1 pictures could not be converted").arg(failed.length) : I18n.t("The picture could not be converted");
        const why = failed.length > 0 ? I18n.t(failed[0].why) : "";
        if (failed.length === 0)
            detail = I18n.t("Saved in %1").arg(saved[0].to.slice(0, saved[0].to.lastIndexOf("/")).replace(Quickshell.env("HOME"), "~"));
        else
            detail = saved.length > 0 ? I18n.t("%1 could not be converted: %2").arg(failed.length).arg(why) : why;
        open = false;
        Sounds.play("mission-" + result);
        hold.restart();
    }

    Process {
        id: converter

        property var saved: []
        property var failed: []

        stdout: SplitParser {
            onRead: line => {
                const [kind, a, b] = line.split("\t");
                if (kind === "ok")
                    converter.saved.push({
                        from: a,
                        to: b ?? ""
                    });
                else if (kind === "fail")
                    converter.failed.push({
                        name: a,
                        why: b ?? ""
                    });
                else
                    return;
                root.done++;
            }
        }

        onExited: code => root.finish(code)
    }

    Timer {
        id: hold

        onTriggered: root.result = ""

        interval: Theme.gta.hold
    }

    IpcHandler {
        function toggle(): void {
            root.toggle();
        }

        function close(): void {
            if (!root.busy)
                root.open = false;
        }

        target: "convert"
    }
}
