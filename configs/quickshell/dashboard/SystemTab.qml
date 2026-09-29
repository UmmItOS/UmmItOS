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
                value: isNaN(SysInfo.gpuTemp) ? 0 : SysInfo.gpuTemp / 100
                primary: isNaN(SysInfo.gpuTemp) ? "n/a" : Math.round(SysInfo.gpuTemp) + "°C"
                label: isNaN(SysInfo.gpuTemp) ? I18n.t("No GPU sensor") : I18n.t("GPU temp")
            }

            Gauge {
                Layout.alignment: Qt.AlignCenter
                value: SysInfo.cpuUsage
                primary: Math.round(SysInfo.cpuUsage * 100) + "%"
                label: isNaN(SysInfo.cpuTemp) ? "CPU" : "CPU · " + Math.round(SysInfo.cpuTemp) + "°C"
            }

            Gauge {
                Layout.alignment: Qt.AlignCenter
                value: SysInfo.memRatio
                primary: SysInfo.formatBytes(SysInfo.memUsed)
                label: I18n.t("of %1").arg(SysInfo.formatBytes(SysInfo.memTotal))
            }

            Gauge {
                Layout.alignment: Qt.AlignCenter
                value: SysInfo.storageRatio
                primary: SysInfo.formatBytes(SysInfo.storageUsed)
                label: I18n.t("of %1").arg(SysInfo.formatBytes(SysInfo.storageTotal))
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.dashboard.systemCard
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
                // Static, so a new uptime updates one Text instead of rebuilding every row.
                model: [
                    {
                        icon: "rocket_launch",
                        label: I18n.t("Distro")
                    },
                    {
                        icon: "desktop_windows",
                        label: I18n.t("Compositor")
                    },
                    {
                        icon: "schedule",
                        label: I18n.t("Uptime")
                    }
                ]

                RowLayout {
                    id: fact

                    required property var modelData
                    readonly property string value: modelData.label === "Distro" ? SysInfo.distro : modelData.label === "Uptime" ? SysInfo.uptimeText : "Hyprland"

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
                            Layout.maximumWidth: root.width / Theme.dashboard.factShare
                            text: fact.value
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

