import QtQuick
import Quickshell

Rectangle {
    id: root

    property bool active: false
    readonly property bool hovered: root.enabled && hover.hovered
    readonly property var flyout: root.QsWindow.window?.registerKeyboardStop ? root.QsWindow.window : null
    property var registeredFlyout: null
    property var activationHandlers: []
    // Existing callers own the row's primary pointer handler.
    readonly property var activationHandler: root.activationHandlers.find(item => item.enabled && (!(item instanceof MouseArea) || item.visible) && (item.acceptedButtons & Qt.LeftButton)) ?? null
    readonly property bool keyboardActivatable: root.visible && root.enabled && root.activationHandler !== null
    readonly property bool keyboardFocused: root.activeFocus && (root.flyout?.keyboardNavigation ?? false)
    property eventPoint keyboardPoint
    // Content colours: readable on the accent fill once active.
    readonly property color ink: root.active ? Theme.accentOn : Theme.fg
    readonly property color inkDim: root.active ? Theme.accentOn : Theme.dim

    function registerStop(): void {
        if (root.registeredFlyout === root.flyout)
            return;
        root.registeredFlyout?.unregisterKeyboardStop(root);
        root.registeredFlyout = root.flyout;
        root.registeredFlyout?.registerKeyboardStop(root);
    }

    function activate(): void {
        if (!root.keyboardActivatable)
            return;
        if (root.activationHandler instanceof TapHandler)
            root.activationHandler.tapped(root.keyboardPoint, Qt.LeftButton);
        else
            root.activationHandler.clicked(null);
    }

    onFlyoutChanged: root.registerStop()
    Component.onCompleted: {
        root.activationHandlers = [...root.data].filter(item => item instanceof TapHandler || item instanceof MouseArea);
        root.registerStop();
    }
    Component.onDestruction: root.registeredFlyout?.unregisterKeyboardStop(root)
    Keys.onPressed: event => root.flyout?.handleKey(event)
    Accessible.onPressAction: root.activate()
    Accessible.onToggleAction: if (root.Accessible.checkable)
        root.activate()

    implicitHeight: Theme.control.row
    radius: Theme.rounding.large
    // The one in use is filled with the accent, so it cannot be missed.
    color: root.active ? Theme.accent : root.hovered ? Theme.bgTray : "transparent"

    Behavior on color {
        FastColor {}
    }

    HoverHandler {
        id: hover

        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    // A separate fill survives callers that paint their own selection background.
    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: Theme.spacing.extraSmall
        }

        width: Theme.spacing.extraSmall
        radius: Theme.rounding.full
        color: root.active ? Theme.accentOn : Theme.accentText
        opacity: root.keyboardFocused ? 1 : 0

        Behavior on opacity {
            FastFade {}
        }

        Behavior on color {
            FastColor {}
        }
    }
}
