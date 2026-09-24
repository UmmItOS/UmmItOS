import QtQuick
import QtQuick.Effects
import ".."

// The wake, drawn in three beats timed by Wake. A soft line of light draws
// out from the centre of the black; flat lids part up and down from it onto
// a dim, blurred screen; then a soft circle from the centre clears that
// haze to the sharp screen. The line and the circle's gradient are painted
// once and only scaled, and the lids only slide, so nothing is re-drawn or
// resized per frame.
Item {
    id: root

    property real dark: 0
    // The screen as it was before going black, shown blurred as the haze;
    // empty where there is none (the lock), which leaves the haze plain dim.
    property string picture: ""

    visible: dark > 0

    // The haze: the picture blurred, under a dimming veil. Captured below
    // and shown through the inverted circle, so the circle clears it.
    Item {
        id: haze

        anchors.fill: parent

        Image {
            id: shot

            anchors.fill: parent
            source: root.picture
            asynchronous: true
            cache: false
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: shot
            visible: shot.status === Image.Ready
            blurEnabled: true
            blurMax: Theme.blur.max
            blur: 1
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: Theme.wakeDim
        }
    }

    // The circle: opaque in the middle, fading to nothing at its rim; with
    // the mask inverted, the haze shows where this is clear. Kept visible
    // (a Canvas under a hidden item never paints) and taken in below.
    Item {
        id: mask

        anchors.fill: parent

        Canvas {
            id: hole

            // The fraction of the radius that is fully open; the rest is
            // the circle's soft edge.
            readonly property real inner: 0.55
            // Large enough that the soft edge has left the corners.
            readonly property real endScale: Math.hypot(root.width, root.height) / 2 / (width / 2 * inner)

            anchors.centerIn: parent
            width: Theme.wakeHole
            height: width
            visible: Wake.circle > 0
            transform: Scale {
                origin.x: hole.width / 2
                origin.y: hole.height / 2
                xScale: hole.endScale * Wake.circle
                yScale: hole.endScale * Wake.circle
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
        id: hazeShot

        anchors.fill: parent
        sourceItem: haze
        hideSource: true
        visible: false
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
        source: hazeShot
        maskEnabled: true
        maskSource: maskShot
        maskInverted: true
        maskThresholdMin: 0
        maskSpreadAtMin: 1
    }

    // Each lid is the black plus the soft shadow its edge melts into the
    // opening with. It keeps its size and slides fully off screen, shadow
    // included, so nothing is left to vanish at the end.
    component Lid: Item {
        id: lid

        required property bool upper

        anchors.left: parent.left
        anchors.right: parent.right
        height: root.height / 2 + Theme.wakeFeather
        y: lid.upper ? 0 : root.height / 2 - Theme.wakeFeather

        transform: Translate {
            y: (lid.upper ? -1 : 1) * lid.height * Wake.lids
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            y: lid.upper ? 0 : Theme.wakeFeather
            height: root.height / 2
            color: "black"
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            y: lid.upper ? root.height / 2 : 0
            height: Theme.wakeFeather
            // Only once the lids part; closed, the line sits on plain black.
            opacity: Math.min(1, Wake.lids * 4)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: lid.upper ? "black" : "transparent"
                }
                GradientStop {
                    position: 1
                    color: lid.upper ? "transparent" : "black"
                }
            }
        }
    }

    Lid {
        upper: true
    }

    Lid {
        upper: false
    }

    // The line: a pill of light blurred once at full width and grown by
    // stretching it from the centre. It fades as the lids part.
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
        visible: Wake.draw > 0 && Wake.lids < 0.5
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
        opacity: 1 - Wake.lids * 2
    }

    // …and a tighter core, so it reads as light, not haze.
    Glow {
        blurMax: Theme.spacing.large
        blur: 0.6
        opacity: (1 - Wake.lids * 2) * 0.8
    }
}
