pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Shapes
import ".."

// Pick a region, a window or the whole screen over a frozen copy of it. The four corners of the
// selection hang from the four corners of the screen on curved threads, and
// every corner trails the pointer on a spring, so the selection is pulled
// into place rather than drawn.
OverlayWindow {
    id: win

    shown: Screenshot.open
    name: "screenshot"
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    // Where the drag started and where the pointer is. Before a drag the
    // selection is a point under the pointer, so the threads already follow it.
    property point from: Qt.point(width / 2, height / 2)
    property point to: from
    property bool dragging: false
    // A press seen inside the overlay. A release without one (left over from
    // the keys or a click elsewhere) must not take anything.
    property bool pressed: false
    // While set, corners jump instead of springing: used to place the frame
    // just outside a window before it settles onto it.
    property bool snap: false
    // The window being cut out for a window shot.
    property var cutting: null
    // 0 while picking; runs to 1 after release, reeling the threads into the
    // selection and lifting the dim before the shot is taken.
    property real release: 0
    property string pendingGeometry: ""

    // Where a thread starts: at its screen corner, sliding into its selection
    // corner as the release plays.
    function anchorOf(sx: real, corner: real): real {
        return sx + (corner - sx) * release;
    }

    readonly property real selX: Math.min(from.x, to.x)
    readonly property real selY: Math.min(from.y, to.y)
    readonly property real selW: Math.abs(to.x - from.x)
    readonly property real selH: Math.abs(to.y - from.y)

    readonly property string mode: Screenshot.mode
    // Window mode: the window the frame is on, in local coordinates.
    property var picked: null
    readonly property var boxes: Screenshot.windows.map(b => ({
                x: b.x - (win.screen?.x ?? 0),
                y: b.y - (win.screen?.y ?? 0),
                w: b.w,
                h: b.h,
                title: b.title,
                address: b.address
            }))

    // Pull the frame onto a box; the springs carry the corners there.
    function frame(b: var): void {
        from = Qt.point(b.x, b.y);
        to = Qt.point(b.x + b.w, b.y + b.h);
    }

    function boxAt(x: real, y: real): var {
        return boxes.find(b => x >= b.x && x <= b.x + b.w && y >= b.y && y <= b.y + b.h) ?? null;
    }

    function pick(b: var): void {
        if (!b)
            return;
        picked = b;
        frame(b);
    }

    // Opening onto a window: the frame appears a little outside it and
    // springs in to hug it, instead of flying there from the middle.
    function focusFirst(b: var): void {
        if (!b)
            return;
        const pad = Theme.spacing.extraLarge;
        snap = true;
        frame({
            x: b.x - pad,
            y: b.y - pad,
            w: b.w + pad * 2,
            h: b.h + pad * 2
        });
        snap = false;
        Qt.callLater(() => pick(b));
    }

    // The window list arrives after the overlay opens: start on the active one.
    onBoxesChanged: {
        if (shown && mode === "window" && !picked)
            focusFirst(boxes[0] ?? null);
    }



    onOpened: {
        cutting = null;
        frozen.captureFrame();
        finishing.stop();
        release = 0;
        dragging = false;
        picked = null;
        pressed = false;
        // Every mode starts as a point in the middle, so the frame is seen to
        // travel to what it takes. The screen's size, not the window's: the
        // window can still be unsized here, which put the point in the corner.
        from = to = Qt.point((screen?.width ?? width) / 2, (screen?.height ?? height) / 2);
        scope.forceActiveFocus();
        if (mode === "screen")
            Qt.callLater(wholeScreen);
        else if (mode === "window")
            Qt.callLater(() => focusFirst(boxes[0] ?? null));
    }

    // Spread the frame to the screen's edges, let it settle, then take it.
    function wholeScreen(): void {
        frame({
            x: 0,
            y: 0,
            w: screen?.width ?? width,
            h: screen?.height ?? height
        });
        settleThenCommit.restart();
    }

    Timer {
        id: settleThenCommit
        interval: Theme.duration.expressiveDefaultSpatial + Theme.duration.normal
        onTriggered: win.commit()
    }

    function commit(): void {
        if (finishing.running)
            return;
        // A window shot needs a window: nothing is taken before one is picked.
        if (mode === "window" && !picked)
            return;
        if (selW < 4 || selH < 4) {
            wholeScreen();
            return;
        }
        const x = Math.round(win.screen.x + selX);
        const y = Math.round(win.screen.y + selY);
        pendingGeometry = `${x},${y} ${Math.round(selW)}x${Math.round(selH)}`;
        finishing.start();
    }

    // Letting go is a movement too, not a cut: the threads reel in, the dim
    // lifts off the pick, and only then does the overlay leave.
    SequentialAnimation {
        id: finishing

        NumberAnimation {
            target: win
            property: "release"
            from: 0
            to: 1
            duration: Theme.duration.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.emphasized
        }
        ScriptAction {
            script: {
                // A window is cut from its own surface; anything else is grim.
                const top = win.mode === "window" && win.picked ? Hyprland.toplevels.values.find(t => t && (t.address === win.picked.address || "0x" + t.address === win.picked.address)) : null;
                if (top?.wayland)
                    win.cutting = {
                        toplevel: top.wayland,
                        w: win.picked.w,
                        h: win.picked.h
                    };
                else
                    Screenshot.region(win.pendingGeometry);
            }
        }
    }

    // A corner that trails its target on a spring.
    component Corner: QtObject {
        required property real tx
        required property real ty
        property real x: tx
        property real y: ty

        Behavior on x {
            enabled: !win.snap

            SpringAnimation {
                spring: Theme.spring.stiffness
                damping: Theme.spring.damping
            }
        }
        Behavior on y {
            enabled: !win.snap

            SpringAnimation {
                spring: Theme.spring.stiffness
                damping: Theme.spring.damping
            }
        }
    }

    Corner {
        id: tl
        tx: win.selX
        ty: win.selY
    }
    Corner {
        id: tr
        tx: win.selX + win.selW
        ty: win.selY
    }
    Corner {
        id: bl
        tx: win.selX
        ty: win.selY + win.selH
    }
    Corner {
        id: br
        tx: win.selX + win.selW
        ty: win.selY + win.selH
    }

    FocusScope {
        id: scope

        anchors.fill: parent
        focus: true
        opacity: Math.min(1, win.reveal)

        Keys.onEscapePressed: Screenshot.open = false
        // Enter takes what the frame is on; in region mode with nothing
        // dragged, that is the whole screen.
        Keys.onReturnPressed: win.commit()

        // The screen as it was when the overlay opened.
        ScreencopyView {
            id: frozen
            anchors.fill: parent
            captureSource: win.screen
            live: false
        }

        // Dim everything outside the selection.
        Item {
            anchors.fill: parent
            opacity: 1 - win.release

            Rectangle {
                width: parent.width
                height: tl.y
                color: Theme.scrim(0.6)
            }
            Rectangle {
                y: bl.y
                width: parent.width
                height: parent.height - bl.y
                color: Theme.scrim(0.6)
            }
            Rectangle {
                y: tl.y
                width: tl.x
                height: bl.y - tl.y
                color: Theme.scrim(0.6)
            }
            Rectangle {
                x: tr.x
                y: tr.y
                width: parent.width - tr.x
                height: br.y - tr.y
                color: Theme.scrim(0.6)
            }
        }

        // The threads: each leaves its screen corner along the edge and bends
        // down into its selection corner.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            component Thread: ShapePath {
                required property real sx
                required property real sy
                required property QtObject corner

                strokeColor: Theme.accentText
                strokeWidth: 1.5
                fillColor: "transparent"
                readonly property real ax: win.anchorOf(sx, corner.x)
                readonly property real ay: win.anchorOf(sy, corner.y)

                startX: ax
                startY: ay

                PathCubic {
                    x: corner.x
                    y: corner.y
                    control1X: ax + (corner.x - ax) * 0.7
                    control1Y: ay
                    control2X: corner.x
                    control2Y: ay + (corner.y - ay) * 0.4
                }
            }

            Thread {
                sx: 0
                sy: 0
                corner: tl
            }
            Thread {
                sx: win.width
                sy: 0
                corner: tr
            }
            Thread {
                sx: 0
                sy: win.height
                corner: bl
            }
            Thread {
                sx: win.width
                sy: win.height
                corner: br
            }

            // The selection's own edges.
            ShapePath {
                strokeColor: Theme.accentText
                strokeWidth: 1.5
                fillColor: "transparent"
                startX: tl.x
                startY: tl.y

                PathLine {
                    x: tr.x
                    y: tr.y
                }
                PathLine {
                    x: br.x
                    y: br.y
                }
                PathLine {
                    x: bl.x
                    y: bl.y
                }
                PathLine {
                    x: tl.x
                    y: tl.y
                }
            }
        }

        // A bead on every corner, where the thread is tied.
        Repeater {
            model: [tl, tr, bl, br]

            Rectangle {
                required property QtObject modelData

                x: modelData.x - width / 2
                y: modelData.y - height / 2
                width: Theme.spacing.medium
                height: width
                radius: width / 2
                color: Theme.accentText
            }
        }

        // Size, under the selection while dragging.
        Rectangle {
            visible: (win.dragging || win.mode !== "region") && win.selW > 0
            opacity: 1 - win.release
            x: Math.min(Math.max(bl.x, Theme.padding.large), parent.width - width - Theme.padding.large)
            y: Math.min(bl.y + Theme.spacing.medium, parent.height - height - Theme.padding.large)
            implicitWidth: sizeText.implicitWidth + Theme.padding.medium * 2
            implicitHeight: sizeText.implicitHeight + Theme.padding.small
            radius: height / 2
            color: Theme.bgTray

            Text {
                id: sizeText
                anchors.centerIn: parent
                text: win.mode === "window" && win.picked ? win.picked.title : Math.round(win.selW) + " × " + Math.round(win.selH)
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                font.features: ({
                        tnum: 1
                    })
            }
        }

        Text {
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: Theme.padding.extraLarge
            }
            visible: !win.dragging && win.mode !== "screen"
            text: win.mode === "window" ? "Point at a window  ·  Click or Enter to take it  ·  Esc to cancel" : "Drag to select  ·  Click or Enter for the whole screen  ·  Esc to cancel"
            color: Theme.fg
            opacity: 0.75
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.normal
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            cursorShape: win.mode === "window" ? Qt.PointingHandCursor : Qt.CrossCursor

            onPressed: mouse => {
                win.pressed = true;
                if (win.mode !== "region")
                    return;
                win.from = Qt.point(mouse.x, mouse.y);
                win.to = win.from;
                win.dragging = true;
            }
            onPositionChanged: mouse => {
                if (win.mode === "window") {
                    const b = win.boxAt(mouse.x, mouse.y);
                    if (b && b !== win.picked)
                        win.pick(b);
                } else if (win.mode === "region") {
                    if (win.dragging)
                        win.to = Qt.point(mouse.x, mouse.y);
                    else
                        win.from = win.to = Qt.point(mouse.x, mouse.y);
                }
            }
            enabled: !finishing.running
            onReleased: mouse => {
                if (!win.pressed)
                    return;
                // The window under the click, not wherever the frame is.
                if (win.mode === "window") {
                    const b = win.boxAt(mouse.x, mouse.y);
                    if (!b)
                        return;
                    win.pick(b);
                }
                win.commit();
            }
        }
    }

    // The window shot, rendered off screen: the window's own surface with
    // Hyprland's rounded corners, so what is saved is the window alone, with
    // transparent corners and whatever transparency the window has itself.
    ClippingRectangle {
        id: cutter

        x: -width - Theme.padding.extraLarge
        width: win.cutting?.w ?? 1
        height: win.cutting?.h ?? 1
        visible: win.cutting !== null
        // Hyprland's decoration:rounding (20).
        radius: Theme.rounding.largeIncreased
        color: "transparent"

        ScreencopyView {
            id: cutView

            anchors.fill: parent
            captureSource: win.cutting?.toplevel ?? null
            live: false

            onHasContentChanged: {
                if (!hasContent || !win.cutting)
                    return;
                const file = Screenshot.newFile();
                cutter.grabToImage(result => {
                    result.saveToFile(file);
                    win.cutting = null;
                    Screenshot.open = false;
                    Screenshot.saved(file);
                });
            }
        }
    }
}
