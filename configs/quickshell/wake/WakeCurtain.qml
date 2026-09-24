import QtQuick
import QtQuick.Effects
import ".."

// The black, and the wake drawn on it in two beats (timed by Wake): a soft
// line of light draws out from the centre, then opens outward, a slit
// rounding into a circle whose edge is a wide shadow rather than a line.
// Both are painted once and only scaled, so nothing is re-drawn or resized
// per frame.
Item {
    id: root

    property real dark: 0

    // The hole's scale that makes its fully open core span a length.
    function scaleFor(length: real): real {
        return length / 2 / (hole.width / 2 * hole.inner);
    }

    // As a slit it spans the line; at the end the circle's soft edge has
    // left the corners.
    readonly property real startX: scaleFor(width)
    readonly property real endScale: scaleFor(Math.hypot(width, height))

    visible: dark > 0

    Rectangle {
        id: black

        anchors.fill: parent
        color: "black"
        visible: false
        layer.enabled: true
    }

    // The hole: opaque in the middle, fading to nothing at its rim; the
    // mask is inverted, so the black shows where this is clear. Kept
    // visible (a Canvas under a hidden item never paints) and taken into
    // the mask by the ShaderEffectSource below.
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
            visible: Wake.open > 0
            transform: Scale {
                origin.x: hole.width / 2
                origin.y: hole.height / 2
                xScale: root.startX + (root.endScale - root.startX) * Wake.open
                yScale: root.endScale * Wake.open
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

    // The line: a pill of light blurred once at full width and grown by
    // stretching it from the centre. It fades as the slit opens under it.
    Rectangle {
        id: pill

        anchors.centerIn: parent
        width: parent.width
        height: Theme.spacing.small
        radius: height / 2
        color: Theme.accent2
        visible: false
        layer.enabled: true
    }

    component Glow: MultiEffect {
        anchors.fill: pill
        source: pill
        autoPaddingEnabled: true
        blurEnabled: true
        visible: Wake.draw > 0 && Wake.open < 1
        transform: Scale {
            origin.x: root.width / 2
            xScale: Wake.draw
        }
    }

    // A wide soft halo…
    Glow {
        blurMax: Theme.wakeGlow
        blur: 1
        brightness: 0.2
        opacity: 1 - Wake.open * 2
    }

    // …and a tighter core, so it reads as light, not haze.
    Glow {
        blurMax: Theme.spacing.large
        blur: 0.6
        opacity: (1 - Wake.open * 2) * 0.8
    }
}
