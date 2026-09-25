pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root

    spacing: Theme.spacing.medium

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: gauges.implicitHeight + Theme.padding.extraLarge * 2
        radius: Theme.rounding.extraLarge
        color: Theme.glass

        RowLayout {
            id: gauges

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

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 92
        radius: Theme.rounding.extraLarge
        color: Theme.glass

        RowLayout {
            anchors {
                fill: parent
                margins: Theme.padding.large
            }
            spacing: Theme.spacing.extraLargeIncreased

            Item {
                Layout.fillWidth: true
            }

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

                    spacing: Theme.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        text: fact.modelData.icon
                        color: Theme.accentText
                        size: Theme.icon.normal
                    }

                    ColumnLayout {
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
                            // A Layout never elides without a width cap.
                            Layout.maximumWidth: root.width / 4
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

            Item {
                Layout.fillWidth: true
            }
        }
    }
}

