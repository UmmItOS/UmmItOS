import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import ".."

// One sheet per screen, mapped only while Wake.dark is above 0. Under the
// opening black, the picture taken before sleep comes from blurred and dim
// to sharp, then gives way to the live screen it matches. It takes no
// input, so a click during the opening reaches whatever is under it.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        // 1 → 0 as the opening widens.
        readonly property real haze: 1 - Wake.open

        screen: modelData
        visible: Wake.dark > 0
        WlrLayershell.namespace: "ummitos-wake"
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

        Image {
            id: picture

            anchors.fill: parent
            source: Wake.shot > 0 ? Wake.shotOf(win.modelData.name) : ""
            asynchronous: true
            cache: false
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: picture
            visible: picture.status === Image.Ready
            blurEnabled: true
            blurMax: Theme.blur.max
            blur: win.haze
            brightness: -Theme.wakeDim * win.haze
            // Gone before the black is, so the swap to the live screen,
            // which it matches, is never seen.
            opacity: Math.min(1, (1 - Wake.open) * 4)
        }

        WakeCurtain {
            anchors.fill: parent
            dark: Wake.dark
        }
    }
}
