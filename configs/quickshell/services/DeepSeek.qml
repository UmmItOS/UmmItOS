pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The DeepSeek account balance for the desktop card, read again every few minutes while the card shows.
Singleton {
    id: root

    // Every currency of the last good answer; a later failure keeps them.
    property var entries: []
    // A key file is there and not empty; the key itself is never held here.
    property bool keySaved: false
    // Whether the balance covers API calls, as the service says.
    property bool usable: true
    property bool failed: false
    // No key file, or an empty one.
    property bool noKey: false

    // The chosen currency's entry, else whichever the account has.
    readonly property var info: entries.find(e => e.currency === Settings.deepseekCurrency) ?? entries[0] ?? null
    readonly property bool ready: info !== null
    // The account has no balance in the chosen currency, so the card shows another.
    readonly property bool otherCurrency: ready && info.currency !== Settings.deepseekCurrency
    readonly property string total: info?.total_balance ?? ""
    readonly property string granted: info?.granted_balance ?? ""
    readonly property string toppedUp: info?.topped_up_balance ?? ""
    readonly property string currency: info?.currency ?? ""
    readonly property string symbol: currency === "CNY" ? "¥" : currency === "USD" ? "$" : currency + " "
    readonly property string keyFile: (Quickshell.env("XDG_CONFIG_HOME") || Settings.home + "/.config") + "/ummitos/deepseek.key"

    function refresh(): void {
        if (!Settings.deepseekShow || fetch.running)
            return;
        fetch.running = true;
    }

    // The one place a key enters: only the characters a key has, so nothing else reaches curl's config line.
    function setKey(key: string): bool {
        const k = key.trim();
        if (!/^[A-Za-z0-9._-]{8,200}$/.test(k))
            return false;
        writer.key = k;
        writer.running = true;
        return true;
    }

    function clearKey(): void {
        Quickshell.execDetached(["rm", "-f", root.keyFile]);
        root.entries = [];
        root.noKey = true;
        root.failed = false;
        root.keySaved = false;
    }

    Component.onCompleted: probe.running = true

    Process {
        id: probe

        onExited: code => root.keySaved = code === 0

        command: ["test", "-s", root.keyFile]
    }

    // Written through stdin so no process list shows the key, and readable by this user only.
    Process {
        id: writer

        property string key

        onStarted: {
            write(key + "\n");
            key = "";
            stdinEnabled = false;
        }

        onExited: {
            probe.running = true;
            root.refresh();
        }

        command: ["sh", "-c", 'umask 077; mkdir -p "${1%/*}"; cat > "$1" && chmod 600 "$1"', "sh", root.keyFile]
        stdinEnabled: true
    }

    Process {
        id: fetch

        // 3: no key file; 22: the service said no (a wrong key); anything else: no network yet, tried again soon.
        onExited: code => {
            if (code === 0)
                return;
            root.noKey = code === 3;
            root.failed = code !== 3;
            // Without a key an old balance would only mislead.
            if (code === 3)
                root.entries = [];
            if (code !== 3 && code !== 22)
                retry.restart();
        }

        // The key goes to curl through a pipe, so no process list shows it.
        command: ["sh", "-c", 'f="$1"; [ -s "$f" ] || exit 3; printf "header = \\042Authorization: Bearer %s\\042\\n" "$(tr -d "[:space:]" < "$f")" | curl -sf --max-time 15 -K - "$2"', "sh", root.keyFile, "https://api.deepseek.com/user/balance"]

        stdout: StdioCollector {
            // A failed read keeps the last balance rather than blanking the card.
            onStreamFinished: {
                if (text.trim() === "")
                    return;
                try {
                    const answer = JSON.parse(text);
                    if (!Array.isArray(answer.balance_infos) || answer.balance_infos.length === 0)
                        throw new Error("no balance");
                    root.entries = answer.balance_infos;
                    root.usable = answer.is_available !== false;
                    root.failed = false;
                    root.noKey = false;
                } catch (e) {
                    root.failed = true;
                }
            }
        }
    }

    // Timers stop while the laptop sleeps, so waking would show an old balance.
    Connections {
        function onWoke(): void {
            root.refresh();
        }

        target: Wake
    }

    Timer {
        id: retry

        onTriggered: root.refresh()

        interval: Theme.duration.weatherRetry
    }

    // Switching the card on reads at once.
    Timer {
        onTriggered: root.refresh()

        running: Settings.deepseekShow
        repeat: true
        triggeredOnStart: true
        interval: Theme.duration.balanceRefresh
    }

    IpcHandler {
        function refresh(): void {
            root.refresh();
        }

        target: "deepseek"
    }
}
