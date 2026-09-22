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

        // What is playing, where the clock is. Both answer "now"; the
        // machine's own numbers answer something else and live under System.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.rounding.extraLarge
            color: Theme.bgAlt

            MediaPanel {
                anchors {
                    fill: parent
                    margins: Theme.padding.large
                }
            }
        }
    }
}
