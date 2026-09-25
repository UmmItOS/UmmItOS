import Quickshell
import Quickshell.Wayland
import QtQuick

// Per-open resets go in onOpened: a reopen mid-exit never unmaps.
PanelWindow {
    id: root

    required property bool shown
    required property string name
    // Scrim strength at full reveal. 0 for surfaces that draw their own ground.
    property real scrim: 0
    property int focusMode: WlrKeyboardFocus.Exclusive

    // 0 closed, 1 open. Drive content opacity and scale from this.
    property real reveal: root.shown ? 1 : 0
    // Last pointer position in window coordinates, for pointerMoved().
    property point lastPointer: Qt.point(-1, -1)

    signal opened

    // Enter events fire under a still cursor; compare positions instead.
    function pointerMoved(item: Item, x: real, y: real): bool {
        const p = item.mapToItem(null, x, y);
        const first = root.lastPointer.x < 0;
        const moved = Math.abs(p.x - root.lastPointer.x) > 2 || Math.abs(p.y - root.lastPointer.y) > 2;
        root.lastPointer = p;
        return !first && moved;
    }

    onShownChanged: {
        if (root.shown) {
            root.lastPointer = Qt.point(-1, -1);
            root.opened();
        }
    }

    Behavior on reveal {
        id: revealBehavior

        // From the target, not `shown`: the order of two bindings is not fixed.
        Reveal {
            opening: revealBehavior.targetValue > 0
        }
    }

    visible: root.reveal > 0
    // Closing drops input, so a fading tile cannot fire twice.
    mask: root.shown ? null : passThrough

    WlrLayershell.namespace: "ummitos-" + root.name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shown ? root.focusMode : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Theme.scrim(root.scrim * Math.min(1, root.reveal))

    Region {
        id: passThrough
    }
}
