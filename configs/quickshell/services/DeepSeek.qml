pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The DeepSeek account balance for the desktop card, read again every few minutes while the card shows.
Singleton {
    id: root

    // The balance entry of the last good answer; a later failure keeps it.
    property var info: null
    // Whether the balance covers API calls, as the service says.
    property bool usable: true
    property bool failed: false
    // No key file, or an empty one.
    property bool noKey: false

    readonly property bool ready: info !== null
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
                root.info = null;
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
                    const entry = answer.balance_infos.find(b => b.currency === "CNY") ?? answer.balance_infos[0];
                    if (!entry)
                        throw new Error("no balance");
                    root.info = entry;
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
