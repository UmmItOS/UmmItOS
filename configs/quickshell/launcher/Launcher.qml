pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // "apps" or "clipboard"
    property string mode: "apps"
    property bool open: false
    property list<var> clipboard: []

    // Set only once decoded, so the Image never reads a half-written file.
    property string decodedPath
    property string decodingId
    property string decodedText
    property string decodedTextId
    readonly property string cacheDir: Quickshell.cachePath("clipboard")

    function show(newMode: string): void {
        mode = newMode;
        // Empty until the fresh list lands, so Enter cannot copy a stale entry.
        if (newMode === "clipboard") {
            clipboard = [];
            clipList.running = true;
        }
        open = true;
    }

    function toggle(newMode: string): void {
        if (open && mode === newMode)
            open = false;
        else
            show(newMode);
    }

    // Launch counts by desktop id.
    property var launches: ({})

    function launch(entry: var): void {
        // Once, even if a second click lands while the grid fades out.
        if (!open)
            return;
        open = false;
        const next = Object.assign({}, launches);
        next[entry.id] = (next[entry.id] ?? 0) + 1;
        launches = next;
        launchesFile.setText(JSON.stringify(launches));
        entry.execute();
    }

    FileView {
        id: launchesFile
        path: Quickshell.statePath("launches.json")
        printErrors: false
        blockWrites: false
        onLoaded: {
            try {
                root.launches = JSON.parse(text());
            } catch (e) {
                root.launches = {};
            }
        }
    }

    // Decodes one image entry into the cache so the preview pane can show it.
    function decode(id: string): void {
        if (decodingId === id)
            return;
        decodingId = id;
        decodedPath = "";
        decodeProc.running = false;
        decodeProc.forId = id;
        // Written aside and moved in, so a file there is always whole.
        decodeProc.command = ["sh", "-c", 'mkdir -p "$1" && f="$1/$2.png" && { [ -s "$f" ] || { cliphist decode "$2" > "$f.part" && mv "$f.part" "$f"; }; }', "sh", cacheDir, id];
        decodeProc.running = true;
    }

    function decodeText(id: string): void {
        clearDecode();
        textProc.running = false;
        // The id rides in the output, so a killed run's late text cannot land on the wrong entry.
        textProc.command = ["sh", "-c", 'printf "%s\\n" "$1"; cliphist decode "$1"', "sh", id];
        textProc.running = true;
    }

    function clearDecode(): void {
        decodeProc.running = false;
        decodingId = "";
        decodedPath = "";
    }

    function copy(id: string): void {
        if (!open)
            return;
        open = false;
        copyProc.command = ["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", id];
        copyProc.running = true;
    }

    // "8595\t[[ binary data ... ]]" -> { id, preview }
    Process {
        id: clipList
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.clipboard = text.split("\n").filter(l => l !== "").map(line => {
                    const tab = line.indexOf("\t");
                    const preview = line.slice(tab + 1);
                    // cliphist renders images as "[[ binary data 2 MiB png 1920x1200 ]]"
                    const binary = preview.match(/^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/);
                    return {
                        id: line.slice(0, tab),
                        preview: preview,
                        image: binary !== null,
                        kind: binary ? binary[2] : "text",
                        detail: binary ? binary[3] + "  ·  " + binary[1] : ""
                    };
                });
                // Previews of entries cliphist has since dropped are dead weight.
                prune.command = ["sh", "-c", 'cd "$1" 2>/dev/null || exit 0; shift; for f in *.png; do case " $* " in *" ${f%.png} "*) ;; *) rm -f -- "$f" ;; esac; done', "sh", root.cacheDir, ...root.clipboard.map(c => c.id)];
                prune.running = true;
            }
        }
    }

    Process {
        id: prune
    }

    Process {
        id: copyProc
    }

    Process {
        id: decodeProc

        // Focus may have moved on by the time it exits.
        property string forId

        onExited: code => {
            if (code === 0 && forId === root.decodingId)
                root.decodedPath = root.cacheDir + "/" + forId + ".png";
        }
    }

    Process {
        id: textProc

        stdout: StdioCollector {
            onStreamFinished: {
                const nl = text.indexOf("\n");
                root.decodedText = text.slice(nl + 1);
                root.decodedTextId = text.slice(0, nl);
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function apps(): void {
            root.toggle("apps");
        }

        function clipboard(): void {
            root.toggle("clipboard");
        }

        function close(): void {
            root.open = false;
        }
    }
}
