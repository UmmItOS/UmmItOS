pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root

    spacing: Theme.spacing.medium

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Theme.spacing.medium

        // Clock
        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 210
            radius: Theme.rounding.extraLarge
            color: Theme.bgAlt

            Column {
                anchors.centerIn: parent
                spacing: -8

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH")
                    color: Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: 78
                    font.bold: true
                    font.features: ({
                            tnum: 1
                        })
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "mm")
                    color: Theme.accentText
                    font.family: Theme.fontDisplay
                    font.pixelSize: 78
                    font.bold: true
                    font.features: ({
                            tnum: 1
                        })
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: Theme.padding.large
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.normal
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
                spacing: Theme.spacing.largeIncreased

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
                        spacing: Theme.spacing.largeIncreased

                        Rectangle {
                            implicitWidth: 44
                            implicitHeight: 44
                            radius: Theme.rounding.medium
                            color: Theme.bg

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: fact.modelData.icon
                                color: Theme.accentText
                                size: 24
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: fact.modelData.label
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.small
                            }

                            Text {
                                Layout.fillWidth: true
                                text: fact.modelData.value
                                color: Theme.fg
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSize.larger
                                font.bold: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    // Memory and storage as filled meters rather than a line of text
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.medium

        Repeater {
            model: [
                {
                    icon: "memory",
                    label: "Memory",
                    ratio: SysInfo.memRatio,
                    used: SysInfo.memUsed,
                    total: SysInfo.memTotal
                },
                {
                    icon: "hard_drive",
                    label: "Storage",
                    ratio: SysInfo.storageRatio,
                    used: SysInfo.storageUsed,
                    total: SysInfo.storageTotal
                }
            ]

            Rectangle {
                id: meter
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 92
                radius: Theme.rounding.extraLarge
                color: Theme.bgAlt

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: Theme.padding.large
                    }
                    spacing: Theme.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.small

                        MaterialIcon {
                            text: meter.modelData.icon
                            color: Theme.accentText
                            size: 22
                        }

                        Text {
                            text: meter.modelData.label
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.smaller
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: SysInfo.formatBytes(meter.modelData.used) + " / " + SysInfo.formatBytes(meter.modelData.total)
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.smaller
                            font.features: ({
                                    tnum: 1
                                })
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 10
                        radius: height / 2
                        color: Theme.bg

                        Rectangle {
                            id: fill

                            readonly property real ratio: Math.max(0, Math.min(1, meter.modelData.ratio))
                            // The first reading arrives after the panel opens. Without
                            // this the bar animates up from zero every time, which
                            // reads as a value changing rather than being shown.
                            property bool animated: false

                            onRatioChanged: {
                                if (ratio > 0 && !animated)
                                    Qt.callLater(() => animated = true);
                            }

                            width: parent.width * ratio
                            height: parent.height
                            radius: height / 2
                            color: fill.ratio > 0.9 ? Theme.urgent : Theme.accentText

                            Behavior on width {
                                enabled: fill.animated
                                NumberAnimation {
                                    duration: Theme.duration.expressiveDefaultSpatial
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
