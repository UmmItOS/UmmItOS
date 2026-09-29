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
    property string lists: ""
    // "repo/name", in the lists' order.
    property var missing: []
    // name → the list it came from.
    property var source: ({})
    readonly property var listNames: ({
            main: "main",
            gpu: "GPU",
            laptop: "laptop"
        })

    spacing: Theme.spacing.large

    function check(): void {
        result = "checking";
        scan.running = false;
        scan.running = true;
    }

    // Each open of the page, and again once an install window closes.
    readonly property bool watching: Settings.open && visible
    onWatchingChanged: if (watching && !install.running)
        check()

    // Same rules as install/install-packages.sh: GPU on AMD only, laptop with a battery, multilib when enabled.
    Process {
        id: scan

        command: ["sh", "-c", `
            d="$(readlink -f "$1")/../../install"
            [ -f "$d/packages_main" ] || d="$(cat "\${XDG_STATE_HOME:-$HOME/.local/state}/ummitos/repo-path" 2>/dev/null)/install"
            [ -f "$d/packages_main" ] || exit 3
            l=main
            lsmod | grep -q '^nvidia\\s' || { lsmod | grep -q '^amdgpu\\s' && l="$l gpu"; }
            [ -f /sys/class/power_supply/BAT0/capacity ] && l="$l laptop"
            grep -q '^\\[multilib\\]$' /etc/pacman.conf && ml=1
            for g in $l; do
                grep -v '^[[:space:]]*$' "$d/packages_$g" | while read -r p; do
                    case "$p" in multilib/*) [ -n "$ml" ] || continue ;; esac
                    printf '%s %s\\n' "$g" "$p"
                done
            done | tee "$2"
            printf -- '--\\n'
            cut -d' ' -f2 "$2" | sed 's#.*/##' | xargs pacman -T
            rm -f "$2"
            exit 0`, "sh", Quickshell.shellDir, Quickshell.env("XDG_RUNTIME_DIR") + "/ummitos-packages"]
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
                const names = [...new Set(all.map(p => page.listNames[p[0]] ?? p[0]))];
                page.lists = names.length > 1 ? names.slice(0, -1).join(", ") + " and " + names[names.length - 1] : names[0] ?? "";
                page.result = page.missing.length > 0 ? "missing" : "ok";
            }
        }
        onExited: code => {
            if (code !== 0) {
                page.missing = [];
                page.result = "lost";
            }
        }
    }

    // A terminal, so paru can ask for the password and show its progress.
    Process {
        id: install

        onExited: page.check()
    }

    function installAll(pkgs: var): void {
        if (install.running)
            return;
        install.command = ["kitty", "-e", "sh", "-c", 'paru -S --needed "$@"; printf "\\nPress Enter to close. "; read -r _', "sh"].concat(pkgs.map(p => p.split("/").pop()));
        install.running = true;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.medium

        Item {
            implicitWidth: Theme.icon.large
            implicitHeight: Theme.icon.large

            Spinner {
                anchors.centerIn: parent
                visible: page.result === "checking"
                size: Theme.icon.large
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: page.result !== "checking"
                text: page.result === "ok" ? "check_circle" : page.result === "missing" ? "download" : "search_off"
                color: page.result === "ok" ? Theme.good : Theme.warn
                size: Theme.icon.large
                fill: 1

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.duration.expressiveFastEffects
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: {
                    switch (page.result) {
                    case "checking":
                        return "Checking packages";
                    case "ok":
                        return "Everything is installed";
                    case "missing":
                        return page.missing.length === 1 ? "1 package missing" : page.missing.length + " packages missing";
                    default:
                        return "Package lists not found";
                    }
                }
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSize.larger
                font.weight: Theme.weight.bold
            }

            Text {
                Layout.fillWidth: true
                text: page.result === "lost" ? "Run the installer once from the UmmItOS folder, so the shell knows where it is." : page.result === "checking" ? "Reading the installer's lists" : page.checked + " checked · " + page.lists
                wrapMode: Text.Wrap
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.small
            }
        }

        Action {
            icon: "refresh"
            label: "Check again"
            enabled: page.result !== "checking" && !install.running
            onClicked: page.check()
        }

        Action {
            visible: page.result === "missing"
            primary: true
            icon: install.running ? "hourglass_top" : "download"
            label: install.running ? "Installing" : "Install missing"
            enabled: !install.running
            onClicked: page.installAll(page.missing)
        }
    }

    ListView {
        id: rows

        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Theme.spacing.extraSmall
        boundsBehavior: Flickable.StopAtBounds
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
                text: "Nothing to install"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
            }
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.duration.expressiveDefaultEffects
            }
            NumberAnimation {
                property: "x"
                from: Theme.spacing.extraLarge * 2
                duration: Theme.duration.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.emphasizedDecel
            }
        }
        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Theme.duration.expressiveFastEffects
            }
            NumberAnimation {
                property: "x"
                to: Theme.spacing.extraLarge * 2
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.emphasizedAccel
            }
        }
        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.standard
            }
            // A displaced row keeps the cancelled add's opacity otherwise.
            NumberAnimation {
                property: "opacity"
                to: 1
                duration: Theme.duration.expressiveFastEffects
            }
        }

        delegate: FlyoutRow {
            id: row

            required property string modelData
            readonly property string repo: row.modelData.split("/")[0]

            width: rows.width

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Theme.padding.medium
                    rightMargin: Theme.padding.medium
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
                    text: (page.listNames[page.source[row.modelData]] ?? "") + " · " + (row.repo === "aur" ? "AUR" : row.repo)
                    textFormat: Text.PlainText
                    color: row.repo === "aur" ? Theme.accentText : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                }
            }

            TapHandler {
                onTapped: page.installAll([row.modelData])
            }
        }
    }
}
