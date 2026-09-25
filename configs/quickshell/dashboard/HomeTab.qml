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
            color: Theme.glass

            Column {
                anchors.centerIn: parent
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

        }

        // The month the date sits in, a card of its own.
        Rectangle {
            Layout.fillHeight: true
            implicitWidth: calendar.implicitWidth + Theme.padding.large * 2
            radius: Theme.rounding.extraLarge
            color: Theme.glass

            MonthCalendar {
                id: calendar

                anchors.centerIn: parent
                width: implicitWidth
                now: clock.date
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.rounding.extraLarge
            color: Theme.glass

            MediaPanel {
                anchors {
                    fill: parent
                    margins: Theme.padding.large
                }
            }
        }
    }
}
