import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// Outside the ummitos-.* rule, whose blur cut off at alpha 0.1.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        readonly property bool active: Wake.dark > 0 && !Lock.locked

        screen: modelData
        visible: win.active
        WlrLayershell.namespace: "wake-curtain"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        mask: Region {}
        color: "transparent"

        Loader {
            anchors.fill: parent
            active: win.active

            sourceComponent: WakeCurtain {
                dark: Wake.dark
                picture: Wake.shot > 0 ? Wake.shotOf(win.modelData.name) : ""
            }
        }
    }
}
