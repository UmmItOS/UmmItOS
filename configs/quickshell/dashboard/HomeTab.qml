import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: root

    spacing: Theme.spacing.largeIncreased

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Big clock and date
    Rectangle {
        Layout.fillHeight: true
        implicitWidth: 150
        radius: Theme.rounding.extraLarge
        color: Theme.bgAlt

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacing.small

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH")
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: 46
                font.features: ({
                        tnum: 1
                    })
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "•  •  •"
                color: Theme.accentText
                font.pixelSize: Theme.fontSize.small
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "mm")
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: 46
                font.features: ({
                        tnum: 1
                    })
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: Theme.padding.small
                text: Qt.formatDateTime(clock.date, "ddd, d MMM")
                color: Theme.accentText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
            }
        }
    }

    // System facts
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.rounding.extraLarge
        color: Theme.bgAlt

        ColumnLayout {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                margins: Theme.padding.extraLarge
            }
            spacing: Theme.spacing.medium

            Repeater {
                model: [
                    {
                        icon: "terminal",
                        text: SysInfo.distro
                    },
                    {
                        icon: "desktop_windows",
                        text: "Hyprland"
                    },
                    {
                        icon: "schedule",
                        text: SysInfo.uptimeText
                    },
                    {
                        icon: "memory",
                        text: SysInfo.formatBytes(SysInfo.memUsed) + " of " + SysInfo.formatBytes(SysInfo.memTotal) + " used"
                    },
                    {
                        icon: "hard_drive",
                        text: SysInfo.formatBytes(SysInfo.storageUsed) + " of " + SysInfo.formatBytes(SysInfo.storageTotal) + " on /"
                    }
                ]

                RowLayout {
                    id: fact
                    required property var modelData

                    spacing: Theme.spacing.medium

                    MaterialIcon {
                        text: fact.modelData.icon
                        color: Theme.accentText
                        size: Theme.fontSize.larger
                    }

                    Text {
                        Layout.fillWidth: true
                        text: fact.modelData.text
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
