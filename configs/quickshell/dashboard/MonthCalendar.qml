pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../bar"

ColumnLayout {
    id: root

    required property date now

    // The month on show, as months since year 0, so stepping is one add.
    property int shown: thisMonth
    readonly property int thisMonth: now.getFullYear() * 12 + now.getMonth()
    readonly property int year: Math.floor(shown / 12)
    readonly property int month: shown % 12

    spacing: Theme.spacing.small

    Connections {
        target: Dashboard
        function onOpenChanged(): void {
            root.shown = root.thisMonth;
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.medium

        Text {
            Layout.fillWidth: true
            text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
            color: Theme.fg
            font {
                family: Theme.fontDisplay
                pixelSize: Theme.fontSize.larger
                weight: Theme.weight.bold
            }
        }

        // Only there when it would go somewhere.
        BarButton {
            icon: "today"
            visible: root.shown !== root.thisMonth
            onClicked: root.shown = root.thisMonth
        }

        BarButton {
            icon: "chevron_left"
            onClicked: root.shown--
        }

        BarButton {
            icon: "chevron_right"
            onClicked: root.shown++
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
        spacing: 0

        delegate: Item {
            id: cell

            required property var model

            implicitWidth: Theme.control.field
            implicitHeight: Theme.control.field

            // Today is a filled accent disc; everything else is just type.
            Rectangle {
                anchors.centerIn: parent
                width: Theme.control.field
                height: width
                radius: width / 2
                color: Theme.accent
                visible: cell.model.today
            }

            Text {
                anchors.centerIn: parent
                text: cell.model.day
                color: cell.model.month === grid.month ? Theme.fg : Theme.dim
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

    WheelHandler {
        onWheel: event => root.shown += event.angleDelta.y > 0 ? -1 : 1
    }
}
