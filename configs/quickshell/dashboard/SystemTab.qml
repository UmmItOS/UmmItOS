pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// Everything the machine can say about itself: the live gauges, what it is
// running, and how full it is. The home tab answers "now"; this one answers
// "what am I on".
ColumnLayout {
    id: root

    spacing: Theme.spacing.medium

    // On a card, like the facts below it: gauges floating on the panel while
    // everything else sat on a surface was two languages on one tab. The card
    // takes the slack, so the tab fills instead of trailing off into a third
    // of a screen of nothing.
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 170 + Theme.padding.extraLarge * 2
        radius: Theme.rounding.extraLarge
        color: Theme.bgAlt

        RowLayout {
            anchors {
                fill: parent
                margins: Theme.padding.extraLarge
            }
            spacing: Theme.spacing.extraLargeIncreased

            Gauge {
                Layout.alignment: Qt.AlignCenter
                value: SysInfo.gpuTemp / 100
                primary: Math.round(SysInfo.gpuTemp) + "°C"
                label: "GPU temp"
            }

            Gauge {
                Layout.alignment: Qt.AlignCenter
                value: SysInfo.cpuUsage
                primary: Math.round(SysInfo.cpuTemp) + "°C"
                label: Math.round(SysInfo.cpuUsage * 100) + "% CPU"
            }

            Gauge {
                Layout.alignment: Qt.AlignCenter
                value: SysInfo.memRatio
                primary: SysInfo.formatBytes(SysInfo.memUsed)
                label: "of " + SysInfo.formatBytes(SysInfo.memTotal)
            }

            Gauge {
                Layout.alignment: Qt.AlignCenter
                value: SysInfo.storageRatio
                primary: SysInfo.formatBytes(SysInfo.storageUsed)
                label: "of " + SysInfo.formatBytes(SysInfo.storageTotal)
            }
        }
    }

    // Three facts across rather than down: the gauges already own the height,
    // and stacked rows overflowed the card into the meters below.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 92
        radius: Theme.rounding.extraLarge
        color: Theme.bgAlt

        RowLayout {
            anchors {
                fill: parent
                margins: Theme.padding.large
            }
            spacing: Theme.spacing.large

            Repeater {
                model: [
                    {
                        icon: "rocket_launch",
                        label: "Distro",
                        value: SysInfo.distro
                    },
                    {
                        icon: "desktop_windows",
                        label: "Compositor",
                        value: "Hyprland"
                    },
                    {
                        icon: "schedule",
                        label: "Uptime",
                        value: SysInfo.uptimeText.replace("up ", "")
                    }
                ]

                RowLayout {
                    id: fact

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Theme.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        text: fact.modelData.icon
                        color: Theme.accentText
                        size: Theme.icon.normal
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: fact.modelData.label
                            color: Theme.dim
                            font {
                                family: Theme.font
                                pixelSize: Theme.fontSize.small
                                weight: Theme.weight.medium
                                letterSpacing: Theme.tracking.wide
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: fact.modelData.value
                            color: Theme.fg
                            elide: Text.ElideRight
                            font {
                                family: Theme.fontDisplay
                                pixelSize: Theme.fontSize.larger
                                bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}

// The memory and storage meters that used to sit on the home tab are gone: the
// two gauges above already carry the same two numbers, and stacking a third row
// of cards under them crashed the scene graph outright.

