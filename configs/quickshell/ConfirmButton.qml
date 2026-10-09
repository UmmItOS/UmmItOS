pragma ComponentBehavior: Bound

import QtQuick

// A round icon button that needs two clicks: the first arms it (and shows the hint), the second confirms.
Rectangle {
    id: root

    property bool armed: false
    property string icon: "delete_sweep"
    // Said to screen readers, and shown beside the button while armed when set.
    property string label
    property string hint

    signal confirmed

    function press(): void {
        if (armed)
            confirmed();
        armed = !armed;
    }

    onArmedChanged: if (armed)
        disarm.restart()

    implicitWidth: Theme.control.button
    implicitHeight: Theme.control.button
    radius: width / 2
    color: root.armed || hover.hovered ? Theme.urgent : Theme.bgTray
    scale: tap.pressed ? Theme.pressScale : 1

    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.onPressAction: root.press()

    Behavior on color {
        FastColor {}
    }

    Behavior on scale {
        PressAnim {}
    }

    Text {
        id: hintLabel

        anchors {
            right: parent.left
            rightMargin: Theme.spacing.medium
            verticalCenter: parent.verticalCenter
        }

        text: root.hint
        color: Theme.urgent
        opacity: root.armed ? 1 : 0
        layer.enabled: opacity < 1

        font {
            family: Theme.font
            pixelSize: Theme.fontSize.smaller
            weight: Theme.weight.medium
        }

        layer.effect: MotionBlur {
            settled: hintLabel.opacity
        }

        transform: Translate {
            x: root.armed ? 0 : Theme.spacing.large

            Behavior on x {
                NumberAnimation {
                    duration: Theme.duration.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.armed ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                }
            }
        }

        Behavior on opacity {
            FastFade {}
        }
    }

    Timer {
        id: disarm

        onTriggered: root.armed = false

        interval: Theme.duration.confirmHold
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        color: Theme.fg
        size: Theme.icon.small
    }

    HoverHandler {
        id: hover

        onHoveredChanged: if (!hovered)
            root.armed = false

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        onTapped: root.press()
    }
}
