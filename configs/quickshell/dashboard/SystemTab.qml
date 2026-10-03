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
            spacing: Theme.spacing.extraLarge

            Gauge {
                Layout.alignment: Qt.AlignCenter
                value: isNaN(SysInfo.gpuTemp) ? 0 : SysInfo.gpuTemp / 100
                primary: isNaN(SysInfo.gpuTemp) ? I18n.t("n/a") : Math.round(SysInfo.gpuTemp) + "°C"
                label: isNaN(SysInfo.gpuTemp) ? I18n.t("No GPU sensor") : I18n.t("GPU temp")
            }

            Gauge {
                Layout.alignment: Qt.AlignCenter
                value: SysInfo.cpuUsage
                primary: Math.round(SysInfo.cpuUsage * 100) + "%"
                label: isNaN(SysInfo.cpuTemp) ? "CPU" : I18n.t("CPU · %1°C").arg(Math.round(SysInfo.cpuTemp))
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
            spacing: Theme.spacing.extraLarge

            Item {
                Layout.fillWidth: true
            }

            Repeater {
                // Static, so a new uptime updates one Text instead of rebuilding every row.
                model: [
                    {
                        icon: "rocket_launch",
                        key: "Distro"
                    },
                    {
                        icon: "desktop_windows",
                        key: "Compositor"
                    },
                    {
                        icon: "schedule",
                        key: "Uptime"
                    }
                ]

                RowLayout {
                    id: fact

                    required property var modelData
                    // Picked by key, never by the shown label, which changes with the language.
                    readonly property string value: modelData.key === "Distro" ? SysInfo.distro : modelData.key === "Uptime" ? SysInfo.uptimeText : "Hyprland"

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
                            textFormat: Text.PlainText
                            text: I18n.t(fact.modelData.key)
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
                            textFormat: Text.PlainText
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

