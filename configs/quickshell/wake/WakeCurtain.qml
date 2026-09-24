import QtQuick
import QtQuick.Effects
import ".."

// The black, with a soft circle opening out of its centre. The circle's
// edge is a wide shadow rather than a line: a radial gradient painted once,
// then only scaled, so nothing is re-drawn or resized per frame. `dark`
// runs 1 → 0 linearly; `open` is its eased progress.
Item {
    id: root

    property real dark: 0
    // Out-cubic: the circle blooms quickly and settles gently.
    readonly property real open: 1 - Math.pow(dark, 3)
    // The scale at which the fully open core reaches the corners, so the
    // soft edge has left the screen by the end.
    readonly property real reach: Math.hypot(width, height) / 2 / (hole.width / 2 * hole.inner)

    visible: dark > 0

    Rectangle {
        id: black

        anchors.fill: parent
        color: "black"
        visible: false
        layer.enabled: true
    }

    // The hole: opaque in the middle, fading to nothing at its rim. The
    // mask is inverted, so the black shows where this is clear.
    // Visible, not hidden: a Canvas under a hidden item never paints. The
    // ShaderEffectSource below takes its picture and hides it instead.
    Item {
        id: mask

        anchors.fill: parent

        Canvas {
            id: hole

            // The fraction of the radius that is fully open; the rest is
            // the shadow of the edge.
            readonly property real inner: 0.55

            anchors.centerIn: parent
            width: Theme.wakeHole
            height: width
            transform: Scale {
                origin.x: hole.width / 2
                origin.y: hole.height / 2
                xScale: root.open * root.reach
                yScale: root.open * root.reach
            }
            onPaint: {
                const ctx = getContext("2d");
                const r = width / 2;
                const g = ctx.createRadialGradient(r, r, 0, r, r, r);
                g.addColorStop(0, "white");
                g.addColorStop(hole.inner, "white");
                g.addColorStop(1, "transparent");
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, width, height);
            }
        }
    }

    ShaderEffectSource {
        id: maskShot

        anchors.fill: parent
        sourceItem: mask
        hideSource: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: black
        maskEnabled: true
        maskSource: maskShot
        maskInverted: true
        maskThresholdMin: 0
        maskSpreadAtMin: 1
    }
}
