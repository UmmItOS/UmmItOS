pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."

// Which of the installer's packages this system lacks, and one click to install them.
ColumnLayout {
    id: page

    // "checking", "ok", "missing" or "lost" (the package lists were not found).
    property string result: "checking"
    property int checked: 0
    // The lists checked, as keys of listNames.
    property var groups: []

    readonly property string listText: {
        const names = groups.map(g => I18n.t(listNames[g] ?? g));
        return names.length > 1 ? I18n.t("%1 and %2").arg(names.slice(0, -1).join(I18n.t(", "))).arg(names[names.length - 1]) : names[0] ?? "";
    }

    // "repo/name", in the lists' order.
    property var missing: []
    // name → the list it came from.
    property var source: ({})

    readonly property var listNames: ({
            main: "main",
            gpu: "GPU",
            laptop: "laptop"
        })

    // Each open of the page, and again once an install window closes.
    readonly property bool watching: Settings.open && visible

    function check(): void {
        result = "checking";
        scan.running = false;
        scan.running = true;
    }

    function installAll(pkgs: var): void {
        if (install.running)
            return;
        // The UmmItOS folder this shell runs from first, then ~/script, then plain paru.
        install.command = ["kitty", "-e", "sh", "-c", 'd=$(readlink -f "$1"); shift; for s in "$d/../../script/misc/install-packages.sh" "$HOME/script/misc/install-packages.sh"; do [ -x "$s" ] && exec "$s" "$@"; done; paru -S --needed "$@"; printf "\\nPress Enter to close. "; read -r _', "sh", Quickshell.shellDir].concat(pkgs.map(p => p.split("/").pop()));
        install.running = true;
    }

    onWatchingChanged: if (watching && !install.running)
        check()

    spacing: Theme.spacing.large

    // Same rules as install/install-packages.sh: GPU on AMD only, laptop with a battery, multilib when enabled.
    Process {
        id: scan

        onExited: code => {
            if (code !== 0) {
                page.missing = [];
                page.result = "lost";
            }
        }

        command: ["sh", "-c", `
            d="$(readlink -f "$1")/../../install"
            [ -f "$d/packages_main" ] || d="$(cat "\${XDG_STATE_HOME:-$HOME/.local/state}/ummitos/repo-path" 2>/dev/null)/install"
            [ -f "$d/packages_main" ] || exit 3
            l=main
            lsmod | grep -q '^nvidia\\s' || { lsmod | grep -q '^amdgpu\\s' && l="$l gpu"; }
            [ -f /sys/class/power_supply/BAT0/capacity ] && l="$l laptop"
            grep -q '^\\[multilib\\]$' /etc/pacman.conf && ml=1
            all=$(for g in $l; do
                grep -v '^[[:space:]]*$' "$d/packages_$g" | while read -r p; do
                    case "$p" in multilib/*) [ -n "$ml" ] || continue ;; esac
                    printf '%s %s\\n' "$g" "$p"
                done
            done)
            printf '%s\\n--\\n' "$all"
            printf '%s\\n' "$all" | cut -d' ' -f2 | sed 's#.*/##' | xargs pacman -T
            exit 0`, "sh", Quickshell.shellDir]

        stdout: StdioCollector {
            onStreamFinished: {
                const [head, tail] = text.split("--\n");
                if (tail === undefined)
                    return;
                const all = head.split("\n").filter(l => l !== "").map(l => l.split(" "));
                const lacking = tail.split("\n").filter(l => l !== "");
                const from = {};
                for (const [group, pkg] of all)
                    from[pkg] = group;
                page.source = from;
                page.missing = all.map(p => p[1]).filter(p => lacking.includes(p.split("/").pop()));
                page.checked = all.length;
                page.groups = [...new Set(all.map(p => p[0]))];
                page.result = page.missing.length > 0 ? "missing" : "ok";
            }
        }
    }

    // A terminal, so paru can ask for the password and show its progress.
    Process {
        id: install

        onExited: page.check()
    }

    StatusHeader {
        busy: page.result === "checking"
        icon: page.result === "ok" ? "check_circle" : page.result === "missing" ? "download" : "search_off"
        tone: page.result === "ok" ? Theme.good : Theme.warn

        title: {
            switch (page.result) {
            case "checking":
                return I18n.t("Checking packages");
            case "ok":
                return I18n.t("Everything is installed");
            case "missing":
                return page.missing.length === 1 ? I18n.t("1 package missing") : I18n.t("%1 packages missing").arg(page.missing.length);
            default:
                return I18n.t("Package lists not found");
            }
        }

        hint: page.result === "lost" ? I18n.t("Run the installer once from the UmmItOS folder, so the shell knows where it is.") : page.result === "checking" ? I18n.t("Reading the installer's lists") : I18n.t("%1 checked · %2").arg(page.checked).arg(page.listText)

        Action {
            onClicked: page.check()

            icon: "refresh"
            label: I18n.t("Check again")
            enabled: page.result !== "checking" && !install.running
        }

        Action {
            onClicked: page.installAll(page.missing)

            visible: page.result === "missing"
            primary: true
            icon: install.running ? "hourglass_top" : "download"
            label: install.running ? I18n.t("Installing") : I18n.t("Install missing")
            enabled: !install.running
        }
    }

    SettingsList {
        id: rows

        // ScriptModel diffs, so a package still missing after a re-check keeps its row.
        model: ScriptModel {
            values: page.missing
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: page.result === "ok"
            spacing: Theme.spacing.small

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "verified"
                color: Theme.dim
                size: Theme.icon.extraLarge
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: I18n.t("Nothing to install")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
            }
        }

        delegate: FlyoutRow {
            id: row

            required property string modelData
            readonly property string repo: row.modelData.split("/")[0]

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
                    text: row.hovered && !install.running ? "download" : "deployed_code"
                    color: row.hovered ? row.ink : row.inkDim
                    size: Theme.icon.small
                }

                Text {
                    Layout.fillWidth: true
                    text: row.modelData.split("/").pop()
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: row.ink
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    font.weight: Theme.weight.medium
                }

                Text {
                    text: I18n.t(page.listNames[page.source[row.modelData]] ?? "") + " · " + (row.repo === "aur" ? "AUR" : row.repo)
                    textFormat: Text.PlainText
                    color: row.repo === "aur" ? Theme.accentText : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                }
            }

            TapHandler {
                id: press

                onTapped: page.installAll([row.modelData])
            }
        }
    }
}
