import Quickshell
import Quickshell.Wayland
import QtQuick

// Every surface that opens over the desktop: blur namespace, overlay layer,
// scrim, and an entrance and exit that play out instead of cutting.
//
// Open state belongs to a singleton; this only animates it. Per-open resets go
// in `onOpened`, not `onVisibleChanged`: the window stays mapped through its
// exit, so reopening while it fades never unmaps it and a visibility hook
// would silently not run.
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

    // Whether the pointer has actually moved since the last call. Enter
    // events fire when a surface opens under a still cursor and whenever
    // geometry shifts beneath it, so hover selection must not use them.
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

        // From the target, not from `shown`: two bindings on the same flag
        // update in an order nothing guarantees, and a close that picked up
        // the opening curve would overshoot below zero and unmap early.
        Reveal {
            opening: revealBehavior.targetValue > 0
        }
    }

    visible: root.reveal > 0
    // Closing, the surface lets go of the keyboard and the pointer at once: a
    // second click on a fading tile must not run its action twice.
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
