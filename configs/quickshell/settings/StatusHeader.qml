import QtQuick
import QtQuick.Layouts
import ".."

// A settings page's status line: a spinner or icon, a title and a hint, then the page's actions.
RowLayout {
    id: header

    property bool busy: false
    property string icon
    property color tone: Theme.good
    property string title
    property string hint
    default property alias actions: slot.data

    Layout.fillWidth: true
    spacing: Theme.spacing.medium

    Item {
        implicitWidth: Theme.icon.large
        implicitHeight: Theme.icon.large

        Spinner {
            anchors.centerIn: parent
            visible: header.busy
            size: Theme.icon.large
        }

        MaterialIcon {
            id: glyph

            anchors.centerIn: parent
            visible: !header.busy
            text: header.icon
            color: header.tone
            size: Theme.icon.large
            fill: 1

            Behavior on color {
                FastColor {}
            }
        }

        // A new result lands with a small overshoot rather than swapping in place.
        NumberAnimation {
            id: pop

            target: glyph
            property: "scale"
            from: Theme.popScale
            to: 1
            duration: Theme.duration.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
        }
    }

    onBusyChanged: if (!busy)
        pop.restart()

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: header.title
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.larger
            font.weight: Theme.weight.bold
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            textFormat: Text.PlainText
            text: header.hint
            wrapMode: Text.Wrap
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }
    }

    RowLayout {
        id: slot
        spacing: Theme.spacing.medium
    }
}
