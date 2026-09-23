pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

// The bar's date line, and the month it belongs to hanging under it. The
// time above still opens the dashboard; the date opens the calendar.
Text {
    id: root

    required property date now

    property bool popupOpen: false
    // The month on show, as months since year 0, so stepping is one add.
    property int shown: now.getFullYear() * 12 + now.getMonth()
    readonly property int year: Math.floor(shown / 12)
    readonly property int month: shown % 12

    function today(): void {
        root.shown = root.now.getFullYear() * 12 + root.now.getMonth();
    }

    text: Qt.formatDateTime(now, "ddd d MMM")
    color: hover.hovered || root.popupOpen ? Theme.accent2 : Theme.dim
    font {
        family: Theme.font
        pixelSize: Theme.fontSize.small
        weight: Theme.weight.medium
        letterSpacing: Theme.tracking.wide
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.duration.expressiveFastEffects
        }
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.popupOpen = !root.popupOpen
    }

    Flyout {
        anchorItem: root
        visible: root.popupOpen
        title: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
        hug: true
        toggleVisible: false
        // Every open starts on this month, wherever the last one was left.
        onCloseRequested: {
            root.popupOpen = false;
            root.today();
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.large

            BarButton {
                icon: "chevron_left"
                onClicked: root.shown--
            }

            BarButton {
                icon: "chevron_right"
                onClicked: root.shown++
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 1
            }

            // Only there when it would go somewhere.
            BarButton {
                icon: "today"
                visible: root.shown !== root.now.getFullYear() * 12 + root.now.getMonth()
                onClicked: root.today()
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: grid.locale

            delegate: Text {
                required property string shortName

                horizontalAlignment: Text.AlignHCenter
                text: shortName
                color: Theme.dim
                font {
                    family: Theme.font
                    pixelSize: Theme.fontSize.small
                    weight: Theme.weight.medium
                    letterSpacing: Theme.tracking.wide
                }
            }
        }

        MonthGrid {
            id: grid

            Layout.fillWidth: true
            month: root.month
            year: root.year
            spacing: Theme.spacing.extraSmall

            delegate: Item {
                id: cell

                required property var model

                implicitWidth: Theme.control.button
                implicitHeight: Theme.control.button

                // Today is a filled accent disc; everything else is just type.
                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.control.button
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    visible: cell.model.today
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.model.day
                    color: cell.model.today ? Theme.fg : cell.model.month === grid.month ? Theme.fg : Theme.dim
                    opacity: cell.model.month === grid.month ? 1 : 0.5
                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.normal
                        weight: cell.model.today ? Theme.weight.bold : Theme.weight.regular
                        features: ({
                                tnum: 1
                            })
                    }
                }
            }
        }

        // The wheel turns months anywhere on the page, like flicking pages.
        WheelHandler {
            onWheel: event => root.shown += event.angleDelta.y > 0 ? -1 : 1
        }
    }
}
