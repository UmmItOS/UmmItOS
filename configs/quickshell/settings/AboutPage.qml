pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

// What this system is, and where UmmItOS lives.
ColumnLayout {
    id: page

    // Label, value, label, value…, filled from the system once.
    property var facts: []

    spacing: Theme.spacing.large

    // Once, the first time Settings opens, not at every shell load.
    Process {
        running: Settings.open && page.facts.length === 0
        command: ["sh", "-c", ". /etc/os-release; echo \"$PRETTY_NAME\"; uname -r; hyprctl version | head -n 1 | cut -d ' ' -f 2; qs --version | cut -d ' ' -f 2; cat /etc/hostname"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.split("\n");
                page.facts = ["User", Quickshell.env("USER"), "Computer", v[4] ?? "", "Base", v[0] ?? "", "Kernel", v[1] ?? "", "Hyprland", v[2] ?? "", "Quickshell", v[3] ?? ""];
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.large

        ClippingRectangle {
            implicitWidth: Theme.icon.huge * 2
            implicitHeight: implicitWidth
            radius: width / 2
            color: Theme.bgTray

            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("../lock/avatar.webp")
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width * 2
                sourceSize.height: height * 2
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.extraSmall

            Text {
                text: "UmmItOS"
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSize.extraLarge
                font.weight: Theme.weight.bold
            }

            Text {
                Layout.fillWidth: true
                text: I18n.t("The first Hong Kong Linux distribution: Arch Linux and Hyprland, with a shell of its own.")
                wrapMode: Text.WordWrap
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.normal
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: grid.implicitHeight + Theme.padding.large * 2
        radius: Theme.rounding.large
        color: Theme.glass

        GridLayout {
            id: grid

            anchors {
                fill: parent
                margins: Theme.padding.large
            }
            columns: 2
            columnSpacing: Theme.spacing.extraLarge
            rowSpacing: Theme.spacing.medium

            Repeater {
                model: page.facts

                Text {
                    required property string modelData
                    required property int index

                    Layout.fillWidth: index % 2 === 1
                    text: index % 2 === 0 ? I18n.t(modelData) : modelData
                    elide: Text.ElideRight
                    color: index % 2 === 0 ? Theme.dim : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.normal
                    font.weight: index % 2 === 0 ? Theme.weight.regular : Theme.weight.medium
                }
            }
        }
    }

    RowLayout {
        spacing: Theme.spacing.medium

        Action {
            primary: true
            icon: "code"
            label: I18n.t("UmmItOS on GitHub")
            onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/UmmItOS/UmmItOS"])
        }

        Action {
            icon: "bug_report"
            label: I18n.t("Report a problem")
            onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/UmmItOS/UmmItOS/issues"])
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
