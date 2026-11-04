import QtQuick

Rectangle {
    id: root

    property bool checked: false
    property bool keyboardFocusVisible: root.activeFocus

    readonly property int knob: Theme.control.toggleKnob
    readonly property int inset: Theme.control.toggleInset

    signal toggled

    function activate(): void {
        if (root.enabled && root.visible)
            root.toggled();
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            event.accepted = true;
            if (!event.isAutoRepeat)
                root.activate();
        }
    }
    Accessible.onPressAction: root.activate()
    Accessible.onToggleAction: root.activate()

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: root.checked
    activeFocusOnTab: root.enabled && !root.Accessible.ignored
    implicitWidth: root.knob * 2 + root.inset * 2
    implicitHeight: root.knob + root.inset * 2
    radius: height / 2
    color: root.keyboardFocusVisible ? Theme.accentText : root.checked ? Theme.accent : Theme.bgTray

    scale: press.pressed ? Theme.pressScale : 1

    Behavior on color {
        FastColor {}
    }

    Behavior on scale {
        PressAnim {}
    }

    Rectangle {
        x: root.checked ? parent.width - width - root.inset : root.inset
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.knob
        implicitHeight: root.knob
        radius: width / 2
        color: root.keyboardFocusVisible ? Theme.bg : root.checked ? Theme.accentOn : Theme.fg

        Behavior on color {
            FastColor {}
        }

        Behavior on x {
            NumberAnimation {
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
            }
        }
    }

    MouseArea {
        id: press

        onClicked: root.activate()

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
    }
}
