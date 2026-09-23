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

        // Clock, and the month its date sits in.
        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 210 + calendar.implicitWidth + Theme.padding.large
            radius: Theme.rounding.extraLarge
            color: Theme.bgAlt

            Column {
                // Centred in the card's first 210 px, as it was before the
                // calendar joined it.
                x: (210 - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: -8

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH")
                    color: Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.hero
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
                    font.pixelSize: Theme.fontSize.hero
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

            MonthCalendar {
                id: calendar

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: Theme.padding.large
                }
                now: clock.date
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
