import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// A thin strip down the left edge, under the bar: drag down from it to pull the SAO menu, as in the anime.
// Top layer, under fullscreen windows, so a game never trips it.
PanelWindow {
    id: root

    required property var modelData

    screen: modelData
    WlrLayershell.namespace: "sao-edge"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        left: true
    }
    margins.top: Theme.barHeight
    implicitWidth: Theme.sao.edge
    implicitHeight: Math.round((modelData?.height ?? 0) * Theme.sao.edgeReach)
    color: "transparent"

    // SAO's orange shows where to grab, over light windows and dark alike.
    Rectangle {
        anchors.fill: parent
        color: Theme.sao.orange
        opacity: pull.pressed || pull.containsMouse ? 1 : 0

        Behavior on opacity {
            FastFade {}
        }
    }

    MouseArea {
        id: pull

        property real from: 0
        property bool pulled: false

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: mouse => {
            from = mouse.y;
            pulled = false;
        }
        // Opens mid-pull, the moment the drag is far enough, as a pull should feel.
        onPositionChanged: mouse => {
            if (pressed && !pulled && mouse.y - from > Theme.sao.pull) {
                pulled = true;
                Sao.show(root.modelData);
            }
        }
    }
}
