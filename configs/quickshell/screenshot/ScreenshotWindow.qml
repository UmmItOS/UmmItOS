pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import ".."

OverlayWindow {
    id: win

    shown: Screenshot.open
    name: "screenshot"
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    property point from: Qt.point(width / 2, height / 2)
    property point to: from
    property bool dragging: false
    // A release with no press here (from the keys) takes nothing.
    property bool pressed: false
    // Corners jump instead of springing while set.
    property bool snap: false
    // The window being cut out for a window shot.
    property var cutting: null
    // 0 while picking, 1 once released.
    property real release: 0
    property string pendingGeometry: ""

    property real phase: 0
    // view = screen * zoom + t.
    property real zoom: 1
    property real tx: 0
    property real ty: 0

    function toScreenX(v: real): real {
        return (v - tx) / zoom;
    }
    function toScreenY(v: real): real {
        return (v - ty) / zoom;
    }

    // Zoom about the pointer, keeping the screen covering the view.
    function zoomAt(px: real, py: real, steps: real): void {
        const z = Math.max(1, Math.min(4, zoom * Math.pow(1.15, steps)));
        const w = screen?.width ?? width, h = screen?.height ?? height;
        tx = Math.max(w - w * z, Math.min(0, px - (px - tx) * z / zoom));
        ty = Math.max(h - h * z, Math.min(0, py - (py - ty) * z / zoom));
        zoom = z;
    }
    property real haze: 0

    NumberAnimation {
        id: hazeIn
        target: win
        property: "haze"
        to: 1
        duration: Theme.duration.extraLarge * 2
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curve.standardDecel
    }

    NumberAnimation on phase {
        running: win.visible
        from: 0
        to: 1
        duration: 2600
        loops: Animation.Infinite
    }

    readonly property real rootWidth: Theme.spacing.medium + 2
    readonly property real tipWidth: 4

    property real sprout: 0

    readonly property int sproutDelay: Theme.duration.expressiveSlowEffects
    readonly property int sproutDuration: Theme.duration.extraLarge + Theme.duration.small

    SequentialAnimation {
        id: sproutIn

        PauseAnimation {
            duration: win.sproutDelay
        }
        NumberAnimation {
            target: win
            property: "sprout"
            from: 0
            to: 1
            duration: win.sproutDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.standard
        }
    }

    // All four grow together; a stagger rushed the first ones.
    function grownOf(order: int): real {
        return sprout;
    }

    function tendril(ax: real, ay: real, cx: real, cy: real, t0: real, seed: real, grow: real): list<point> {
        const x1 = ax + (cx - ax) * 0.7, y1 = ay;
        const x2 = cx, y2 = ay + (cy - ay) * 0.4;
        const reach = Math.hypot(cx - ax, cy - ay);
        const sway = Math.min(18, reach * 0.04);
        const n = 40;
        const left = [], right = [];
        for (let i = 0; i <= n; i++) {
            // Only the grown part is drawn; its end tapers like a tip.
            const t = Math.max(0.001, grow) * i / n, u = 1 - t;
            const bx = u * u * u * ax + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * cx;
            const by = u * u * u * ay + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * cy;
            let dx = 3 * u * u * (x1 - ax) + 6 * u * t * (x2 - x1) + 3 * t * t * (cx - x2);
            let dy = 3 * u * u * (y1 - ay) + 6 * u * t * (y2 - y1) + 3 * t * t * (cy - y2);
            const d = Math.hypot(dx, dy) || 1;
            const nx = -dy / d, ny = dx / d;
            const wave = sway * Math.sin(Math.PI * t) * Math.sin(2 * Math.PI * (1.6 * t - t0) + seed);
            const half = (rootWidth * u + tipWidth * t) / 2;
            const px = bx + nx * wave, py = by + ny * wave;
            left.push(Qt.point(px + nx * half, py + ny * half));
            right.push(Qt.point(px - nx * half, py - ny * half));
        }
        return left.concat(right.reverse());
    }

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

    // Starts a little outside the window and springs in.
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

    // A close mid-finish cancels the shot.
    onShownChanged: {
        if (!shown) {
            finishing.stop();
            cutting = null;
        }
    }

    onOpened: {
        cutting = null;
        // Only a closed overlay captures, or it photographs itself.
        if (!visible) {
            frozen.captureFrame();
            haze = 0;
        }
        hazeIn.restart();
        sprout = 0;
        sproutIn.restart();
        zoom = 1;
        tx = ty = 0;
        finishing.stop();
        release = 0;
        dragging = false;
        picked = null;
        pressed = false;
        // The screen's size: the window may be unsized yet.
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
        // After the opening has played in full, so Print shows it too.
        interval: win.sproutDelay + win.sproutDuration + Theme.duration.normal
        onTriggered: win.commit()
    }

    function commit(): void {
        if (finishing.running || !win.shown)
            return;
        // A window shot needs a window: nothing is taken before one is picked.
        if (mode === "window" && !picked)
            return;
        if (selW < 4 || selH < 4) {
            wholeScreen();
            return;
        }
        const x = Math.round(win.screen.x + toScreenX(selX));
        const y = Math.round(win.screen.y + toScreenY(selY));
        pendingGeometry = `${x},${y} ${Math.round(selW / zoom)}x${Math.round(selH / zoom)}`;
        finishing.start();
    }

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
            // A region's corners are the pointer, no spring.
            enabled: !win.snap && win.mode !== "region"

            SpringAnimation {
                spring: Theme.spring.stiffness
                damping: Theme.spring.damping
            }
        }
        Behavior on y {
            // A region's corners are the pointer, no spring.
            enabled: !win.snap && win.mode !== "region"

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
        Keys.onReturnPressed: win.commit()

        ScreencopyView {
            id: frozen
            anchors.fill: parent
            captureSource: win.screen
            live: false
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            transform: [
                Scale {
                    xScale: win.zoom
                    yScale: win.zoom
                },
                Translate {
                    x: win.tx
                    y: win.ty
                }
            ]
            source: frozen
            blurEnabled: true
            blurMax: 64
            blur: win.haze * (1 - win.release) * (win.mode === "window" ? 0.25 : 0.45)
        }

        // The selection itself stays sharp: what you frame is what you get.
        Item {
            x: tl.x
            y: tl.y
            width: Math.max(0, br.x - tl.x)
            height: Math.max(0, br.y - tl.y)
            clip: true

            ShaderEffectSource {
                x: win.tx - parent.x
                y: win.ty - parent.y
                width: frozen.width * win.zoom
                height: frozen.height * win.zoom
                sourceItem: frozen
            }
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

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // Filled, not stroked, so it can taper.
            component Thread: ShapePath {
                required property real sx
                required property real sy
                required property QtObject corner
                // Offsets the wave so the four do not move in step.
                property real seed: 0
                property int order: 0

                readonly property real ax: win.anchorOf(sx, corner.x)
                readonly property real ay: win.anchorOf(sy, corner.y)

                strokeColor: "transparent"
                strokeWidth: 0
                fillColor: Theme.accentText

                PathPolyline {
                    path: win.tendril(ax, ay, corner.x, corner.y, win.phase, seed, win.grownOf(order))
                }
            }

            Thread {
                sx: 0
                sy: 0
                corner: tl
                seed: 0
            }
            Thread {
                sx: win.width
                sy: 0
                corner: tr
                seed: 1.7
                order: 1
            }
            Thread {
                sx: 0
                sy: win.height
                corner: bl
                seed: 3.1
                order: 2
            }
            Thread {
                sx: win.width
                sy: win.height
                corner: br
                seed: 4.6
                order: 3
            }

            ShapePath {
                strokeColor: Theme.accentText
                strokeWidth: win.tipWidth
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
                required property int index

                x: modelData.x - width / 2
                y: modelData.y - height / 2
                readonly property real arrived: {
                    const x = Math.max(0, Math.min(1, (win.grownOf(index) - 0.6) / 0.4));
                    return x * x * (3 - 2 * x);
                }
                scale: (1 + 0.2 * Math.sin(2 * Math.PI * (win.phase * 2) + index)) * arrived
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
            // Scroll to zoom the frozen screen for a precise region.
            onWheel: wheel => {
                if (win.mode === "region")
                    win.zoomAt(wheel.x, wheel.y, wheel.angleDelta.y / 120);
            }
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

    // Off screen, clipped to Hyprland's rounding; keeps transparency.
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
