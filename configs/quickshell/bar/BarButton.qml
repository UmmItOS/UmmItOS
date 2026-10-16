import QtQuick
import ".."

MaterialIcon {
    id: root

    required property string icon
    // What it does, for screen readers and the hover tip; English, looked up in I18n.
    property string label
    property color baseColor: Theme.fg
    property color hoverColor: Theme.accent2
    // Only a button that handles rightClicked takes the right button, so others do not press for nothing.
    property bool rightClickable: false
    // A small dot on the corner: something here wants a look.
    property bool badge: false
    // False while the first value is still arriving, so the dot does not animate in at login.
    property bool badgeReady: true

    signal clicked
    signal rightClicked

    Accessible.onPressAction: root.clicked()

    text: icon
    Accessible.role: Accessible.Button
    Accessible.name: I18n.t(label)
    color: mouse.containsMouse ? hoverColor : baseColor
    fill: mouse.containsMouse ? 1 : 0
    scale: mouse.pressed ? Theme.pressScale : 1

    Behavior on scale {
        PressAnim {}
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.duration.expressiveFastEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.standard
        }
    }

    // The dot springs in and out; leaving is quicker.
    Rectangle {
        anchors {
            top: parent.top
            right: parent.right
        }

        width: Theme.bar.badge
        height: width
        radius: width / 2
        color: Theme.accentText
        scale: root.badge ? 1 : 0
        opacity: root.badge ? 1 : 0

        Behavior on scale {
            enabled: root.badgeReady

            NumberAnimation {
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.badge ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
            }
        }

        Behavior on opacity {
            enabled: root.badgeReady

            NumberAnimation {
                duration: Theme.duration.expressiveFastEffects
            }
        }
    }

    // Its own icon first, so the tip reads like the button.
    Tip {
        anchorItem: root
        text: I18n.t(root.label)
        rows: [
            {
                glyph: root.icon,
                text: I18n.t(root.label)
            }
        ]
        wanted: mouse.containsMouse && !mouse.pressed
    }

    MouseArea {
        id: mouse

        onClicked: event => event.button === Qt.RightButton ? root.rightClicked() : root.clicked()

        anchors.fill: parent
        anchors.margins: -Theme.spacing.extraSmall
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: root.rightClickable ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
    }
}
