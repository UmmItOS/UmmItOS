import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// One sheet per screen drawing the wake over the desktop, with the picture
// taken before sleep as its haze. It takes no input, so a click during the
// wake reaches whatever is under it.
//
// It exists only while the wake runs, and not at all while the session is
// locked (the lock covers every layer and draws the wake itself): mapped all
// the time, an Overlay layer the size of the screen would cost a blend every
// frame and stop direct scanout for fullscreen games and video. The curtain
// is loaded with it, so the picture and the effects' buffers go too.
//
// Its namespace is deliberately outside Hyprland's `ummitos-.*` rule: that
// rule blurs (and, with blur brightness, darkens) whatever a surface covers
// until its alpha falls below 0.1, then stops at once, so the end of the
// fade jumped. The wake draws its own blur. Hyprland's layer animation does
// play as it maps, but that is on the way into black, before sleep.
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
