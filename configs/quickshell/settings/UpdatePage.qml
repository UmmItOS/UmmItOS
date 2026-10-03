pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."

// What an upgrade would bring, and one click to run script/misc/update.sh.
ColumnLayout {
    id: page

    // "idle" until Check is pressed, then "checking", "ok", "pending", "offline" or "noTool" (pacman-contrib missing).
    property string result: "idle"
    // "repo name old new" or "aur name old new".
    property var pending: []
    property var lastUpgrade: null

    // Where the running shell lives: {linked, dir, root, branch, upstream, behind, dirty, known}.
    property var source: null
    property bool pulling: false

    readonly property int aurCount: pending.filter(p => p.startsWith("aur ")).length
    readonly property int daysSince: lastUpgrade ? Math.floor((Date.now() - lastUpgrade.getTime()) / 86400000) : -1
    // UpdateReminder starts nagging at a week.
    readonly property bool stale: daysSince >= 7

    spacing: Theme.spacing.large

    // Only on request: checkupdates and git fetch go to the network.
    function check(): void {
        result = "checking";
        scan.running = false;
        scan.running = true;
        look(true);
    }

    function look(fetch: bool): void {
        where.fetch = fetch;
        where.running = false;
        where.running = true;
    }

    function ago(days: int): string {
        return days === 0 ? I18n.t("today") : days === 1 ? I18n.t("yesterday") : I18n.t("%1 days ago").arg(days);
    }

    // Opening the page reads only local state: the pacman log and the clone, without fetching.
    readonly property bool watching: Settings.open && visible
    onWatchingChanged: if (watching && !where.running)
        look(false)

    // checkupdates syncs a copy of the databases, so it needs no root and leaves pacman's alone.
    Process {
        id: scan

        command: ["sh", "-c", `
            command -v checkupdates >/dev/null || exit 4
            out=$(checkupdates 2>/dev/null)
            [ $? -eq 1 ] && exit 5
            printf '%s\\n' "$out" | sed '/^$/d; s/^/repo /'
            command -v paru >/dev/null && paru -Qua 2>/dev/null | sed 's/^/aur /'
            exit 0`]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const m = line.match(/^(repo|aur) (\S+) (\S+) -> (\S+)/);
                    if (m)
                        found.push(m.slice(1, 5).join(" "));
                }
                page.pending = found;
            }
        }
        onExited: code => page.result = code === 4 ? "noTool" : code === 5 ? "offline" : page.pending.length > 0 ? "pending" : "ok"
    }

    // Linked means the running shell resolves into a git clone, so `git pull` updates it.
    Process {
        id: where

        property bool fetch: false

        command: ["sh", "-c", `
            tac /var/log/pacman.log | grep -a -m1 'starting full system upgrade' | sed 's/^/last /'
            d=$(readlink -f "$1")
            echo "dir $d"
            cat "\${XDG_STATE_HOME:-$HOME/.local/state}/ummitos/repo-path" 2>/dev/null | sed 's/^/known /'
            r=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || exit 0
            [ -f "$r/configs/quickshell/shell.qml" ] || exit 0
            echo "root $r"
            echo "branch $(git -C "$r" branch --show-current)"
            echo "dirty $(git -C "$r" status --porcelain --untracked-files=no | wc -l)"
            u=$(git -C "$r" rev-parse --abbrev-ref '@{u}' 2>/dev/null) || exit 0
            echo "upstream $u"
            [ "$2" = 1 ] && timeout 15 git -C "$r" fetch --quiet 2>/dev/null
            echo "behind $(git -C "$r" rev-list --count 'HEAD..@{u}')"`, "sh", Quickshell.shellDir, where.fetch ? "1" : "0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const info = {
                    linked: false,
                    behind: 0,
                    dirty: 0
                };
                for (const line of text.split("\n")) {
                    const at = line.indexOf(" ");
                    const key = line.slice(0, at), value = line.slice(at + 1);
                    const last = line.match(/^last \[([^\]]+)([+-]\d\d)(\d\d)\]/);
                    if (last)
                        page.lastUpgrade = new Date(last[1] + last[2] + ":" + last[3]);
                    else if (key === "behind" || key === "dirty")
                        info[key] = Number(value) || 0;
                    else if (key !== "")
                        info[key] = value;
                }
                info.linked = info.root !== undefined;
                page.source = info;
            }
        }
    }

    // Fast-forward only: a clone with its own commits is left for the user to merge.
    Process {
        id: pull

        command: ["timeout", "60", "git", "-C", page.source?.root ?? "", "pull", "--ff-only", "--quiet"]
        stderr: StdioCollector {
            id: pullError
        }
        onExited: code => {
            page.pulling = false;
            if (code !== 0)
                Notifs.say("Settings", I18n.t("Could not update UmmItOS"), pullError.text.trim() || I18n.t("git pull stopped; see the UmmItOS folder."));
            else
                Notifs.say("Settings", I18n.t("UmmItOS updated"), I18n.t("If the shell does not reload, restart it: qs kill -c ummitos && qs -c ummitos -d. Hyprland config and ~/script are copies: copy their changes by hand."));
            page.look(false);
        }
    }

    // A terminal: update.sh asks what to upgrade, and paru asks for the password.
    Process {
        id: upgrade

        // Back to unchecked: what is left to update is only looked up when asked.
        onExited: {
            page.pending = [];
            page.result = "idle";
            page.look(false);
        }
    }

    function runUpdate(): void {
        if (upgrade.running)
            return;
        // The UmmItOS folder this shell runs from first, then ~/script, then plain paru.
        upgrade.command = ["kitty", "-e", "sh", "-c", 'for s in "$(readlink -f "$1")/../../script/misc/update.sh" "$HOME/script/misc/update.sh"; do [ -x "$s" ] && exec "$s"; done; paru; printf "\\nPress Enter to close. "; read -r _', "sh", Quickshell.shellDir];
        upgrade.running = true;
    }

    StatusHeader {
        busy: page.result === "checking"
        icon: page.result === "idle" ? "update" : page.result === "ok" ? "check_circle" : page.result === "pending" ? "update" : page.result === "offline" ? "cloud_off" : "help"
        tone: page.result === "idle" ? (page.stale ? Theme.warn : Theme.dim) : page.result === "ok" && !page.stale ? Theme.good : page.result === "pending" ? Theme.accentText : Theme.warn
        title: {
            switch (page.result) {
            case "idle":
                return I18n.t("Updates not checked yet");
            case "checking":
                return I18n.t("Checking for updates");
            case "ok":
                return I18n.t("Up to date");
            case "pending":
                return page.pending.length === 1 ? I18n.t("1 update available") : I18n.t("%1 updates available").arg(page.pending.length);
            case "offline":
                return I18n.t("Could not reach the mirrors");
            default:
                return I18n.t("Cannot check for updates");
            }
        }
        hint: {
            if (page.result === "noTool")
                return I18n.t("checkupdates comes with pacman-contrib; the Packages page can install it.");
            if (page.result === "offline")
                return I18n.t("Check the network, then try again. Updating still works once it is back.");
            const parts = [];
            if (page.daysSince >= 0)
                parts.push(I18n.t("Last full upgrade %1").arg(page.ago(page.daysSince)));
            if (page.result === "pending" && page.aurCount > 0)
                parts.push(I18n.t("%1 from the AUR").arg(page.aurCount));
            return parts.join(" · ");
        }

        Action {
            primary: page.result === "idle"
            icon: "refresh"
            label: I18n.t("Check")
            enabled: page.result !== "checking" && !upgrade.running
            onClicked: page.check()
        }

        Action {
            primary: page.result === "pending" || (page.stale && page.result !== "idle")
            icon: upgrade.running ? "hourglass_top" : "system_update_alt"
            label: upgrade.running ? I18n.t("Updating") : I18n.t("Update now")
            enabled: !upgrade.running && !page.pulling
            onClicked: page.runUpdate()
        }
    }

    // Where UmmItOS lives, and whether `git pull` there updates this shell.
    Rectangle {
        id: card

        readonly property bool linked: page.source?.linked ?? false
        readonly property bool behind: (page.source?.behind ?? 0) > 0
        // A real directory would take the link inside it, so it is moved aside first.
        readonly property string linkCommand: {
            const q = s => "'" + s.replace(/'/g, "'\\''") + "'";
            const dir = Quickshell.shellDir.replace(/\/+$/, "");
            return "mv -T " + q(dir) + " " + q(dir + ".bak") + " && ln -s " + q((page.source?.known ?? "<UmmItOS folder>") + "/configs/quickshell") + " " + q(dir);
        }

        Layout.fillWidth: true
        implicitHeight: cardRow.implicitHeight + Theme.spacing.large * 2
        radius: Theme.rounding.large
        color: Theme.glass
        visible: page.source !== null
        opacity: visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.duration.expressiveDefaultEffects
            }
        }

        RowLayout {
            id: cardRow

            anchors {
                fill: parent
                margins: Theme.spacing.large
            }
            spacing: Theme.spacing.medium

            MaterialIcon {
                text: card.linked ? "link" : "warning"
                color: card.linked ? (card.behind ? Theme.accentText : Theme.good) : Theme.warn
                size: Theme.icon.normal
                fill: 1
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: card.linked ? "UmmItOS · " + Settings.tilde(page.source?.root ?? "") : I18n.t("This shell is a copy")
                    textFormat: Text.PlainText
                    elide: Text.ElideMiddle
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.normal
                    font.weight: Theme.weight.medium
                }

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: card.linked ? Theme.dim : Theme.warn
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    text: {
                        const s = page.source;
                        if (!s)
                            return "";
                        if (!s.linked)
                            return I18n.t("%1 is not linked to a UmmItOS clone, so git pull will not update it. Link it with ln -sfn, and pulling keeps it current.").arg(Settings.tilde(s.dir ?? ""));
                        const head = I18n.t("Linked, branch %1").arg(s.branch || I18n.t("detached"));
                        if (!s.upstream)
                            return head + " · " + I18n.t("no upstream, so pull it by hand");
                        const tail = s.behind > 0 ? (s.behind === 1 ? I18n.t("1 commit behind %1").arg(s.upstream) : I18n.t("%1 commits behind %2").arg(s.behind).arg(s.upstream)) : I18n.t("up to date with %1").arg(s.upstream);
                        return head + " · " + tail + (s.dirty > 0 ? " · " + I18n.t("%1 changed file(s)").arg(s.dirty) : "");
                    }
                }
            }

            Action {
                visible: card.linked && card.behind && (page.source?.upstream ?? "") !== ""
                primary: true
                icon: page.pulling ? "hourglass_top" : "download"
                label: page.pulling ? I18n.t("Pulling") : I18n.t("Pull")
                // A pull reloads the shell, which would kill the tracked upgrade terminal.
                enabled: !page.pulling && !upgrade.running
                onClicked: {
                    page.pulling = true;
                    pull.running = true;
                }
            }

            Action {
                visible: card.linked
                icon: "folder_open"
                label: I18n.t("Open")
                onClicked: Quickshell.execDetached(["xdg-open", page.source.root])
            }

            Action {
                visible: !card.linked
                icon: "content_copy"
                label: I18n.t("Copy command")
                onClicked: Quickshell.execDetached(["wl-copy", "--", card.linkCommand])
            }
        }
    }

    SettingsList {
        id: rows

        // ScriptModel diffs, so a package still pending after a re-check keeps its row.
        model: ScriptModel {
            values: page.pending
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: page.result === "idle" || page.result === "ok"
            spacing: Theme.spacing.small

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: page.result === "idle" ? "manage_search" : "task_alt"
                color: Theme.dim
                size: Theme.icon.extraLarge
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: page.result === "idle" ? I18n.t("Press Check to see what an update would bring") : page.stale ? I18n.t("Nothing new, but a full upgrade is still worth running") : I18n.t("Nothing to update")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
            }
        }

        delegate: FlyoutRow {
            id: row

            required property string modelData
            readonly property var parts: row.modelData.split(" ")
            readonly property bool aur: row.parts[0] === "aur"

            width: rows.width
            scale: press.pressed ? Theme.pressScale : 1

            Behavior on scale {
                PressAnim {}
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Theme.spacing.medium
                    rightMargin: Theme.spacing.medium
                }
                spacing: Theme.spacing.medium

                MaterialIcon {
                    text: row.hovered ? "open_in_new" : "deployed_code"
                    color: row.hovered ? row.ink : row.inkDim
                    size: Theme.icon.small
                }

                Text {
                    Layout.fillWidth: true
                    text: row.parts[1] ?? ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: row.ink
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    font.weight: Theme.weight.medium
                }

                Text {
                    text: (row.parts[2] ?? "") + "  →  " + (row.parts[3] ?? "")
                    textFormat: Text.PlainText
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    font.features: ({
                            tnum: 1
                        })
                }

                Text {
                    visible: row.aur
                    text: "AUR"
                    color: Theme.accentText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    font.weight: Theme.weight.medium
                }
            }

            // The package's page, for its changelog and news.
            TapHandler {
                id: press
                onTapped: Quickshell.execDetached(["xdg-open", row.aur ? "https://aur.archlinux.org/packages/" + encodeURIComponent(row.parts[1]) : "https://archlinux.org/packages/?q=" + encodeURIComponent(row.parts[1])])
            }
        }
    }
}
