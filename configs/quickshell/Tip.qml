import Quickshell
import QtQuick

// A short label under an icon-only control, after the pointer rests on it.
PopupWindow {
    id: root

    required property Item anchorItem
    property string text
    // The control is hovered; the tip follows after a pause.
    property bool wanted: false
    property bool showing: false

    anchor {
        item: root.anchorItem
        edges: Edges.Bottom
        gravity: Edges.Bottom
        margins.top: Theme.spacing.small
    }

    implicitWidth: label.implicitWidth + Theme.spacing.medium * 2 + Theme.windowInset
    implicitHeight: label.implicitHeight + Theme.spacing.small * 2 + Theme.windowInset
    color: "transparent"
    visible: showing || sheet.opacity > 0
    // Never takes the pointer, so it cannot cover what it describes or flicker under the cursor.
    mask: Region {}

    onWantedChanged: {
        if (wanted && text !== "") {
            delay.restart();
        } else {
            delay.stop();
            showing = false;
        }
    }

    Timer {
        id: delay
        interval: Theme.duration.tipDelay
        onTriggered: root.showing = true
    }

    Rectangle {
        id: sheet

        anchors.centerIn: parent
        width: label.implicitWidth + Theme.spacing.medium * 2
        height: label.implicitHeight + Theme.spacing.small * 2
        radius: Theme.rounding.full
        color: Theme.bgTray
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : Theme.popScale
        layer.enabled: opacity < 1
        layer.effect: MotionBlur {
            settled: sheet.opacity
        }

        Behavior on opacity {
            FastFade {}
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.showing ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
            }
        }

        Text {
            id: label

            anchors.centerIn: parent
            text: root.text
            textFormat: Text.PlainText
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
        }
    }
}
