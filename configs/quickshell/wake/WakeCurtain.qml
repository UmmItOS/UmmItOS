import QtQuick
import QtQuick.Effects
import ".."

// Waking as eyes opening, in two beats. A soft line of light first draws
// itself out from the centre of the black; then the black parts up and down
// from it like eyelids, their edges soft shadow while the line fades. `dark` runs 1 → 0, linearly; each beat eases on
// its own here.
Item {
    id: root

    property real dark: 0
    readonly property real progress: 1 - dark

    // The line draws over the first 40%; the lids start at 25%, while it is
    // still finishing, so the two beats flow into one another instead of
    // stopping between them.
    readonly property real draw: ease(Math.min(1, progress / 0.4), false)
    readonly property real open: ease(Math.max(0, (progress - 0.25) / 0.75), true)

    readonly property real half: height / 2 * (1 - open)
    readonly property real glow: 1 - open

    // Out-cubic for the line (quick, then settling); in-out-sine for the
    // lids, whose start is gentle but never a standstill.
    function ease(t: real, lids: bool): real {
        if (!lids)
            return 1 - Math.pow(1 - t, 3);
        return (1 - Math.cos(Math.PI * t)) / 2;
    }

    visible: dark > 0

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.half
        color: "black"
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.half
        color: "black"
    }

    // Each lid's edge melts into the opening as a deep, wide shadow, so the
    // parting is soft rather than two hard bars. Only the line is light.
    component Edge: Item {
        id: edge

        // The y of the lid's edge, and which way it spills into the opening.
        required property real at
        required property bool down

        anchors.left: parent.left
        anchors.right: parent.right
        y: edge.down ? edge.at : edge.at - height
        height: Theme.wakeFeather

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: edge.down ? "black" : "transparent"
                }
                GradientStop {
                    position: 1
                    color: edge.down ? "transparent" : "black"
                }
            }
        }
    }

    Edge {
        at: root.half
        down: true
        visible: root.open > 0
    }

    Edge {
        at: root.height - root.half
        down: false
        visible: root.open > 0
    }

    // The line itself: a pill of light, blurred so its ends and edges glow
    // instead of cutting. Blurred once at full width and grown by stretching
    // it from the centre: resizing it rebuilt the blur every frame, which
    // stuttered.
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

    MultiEffect {
        anchors.fill: pill
        source: pill
        autoPaddingEnabled: true
        blurEnabled: true
        blurMax: Theme.wakeGlow
        blur: 1
        brightness: 0.2
        opacity: root.glow
        visible: root.draw > 0
        transform: Scale {
            origin.x: root.width / 2
            xScale: root.draw
        }
    }

    // A thinner, less blurred core, so the line reads as light, not haze.
    MultiEffect {
        anchors.fill: pill
        source: pill
        autoPaddingEnabled: true
        blurEnabled: true
        blurMax: Theme.spacing.large
        blur: 0.6
        opacity: root.glow * 0.8
        visible: root.draw > 0
        transform: Scale {
            origin.x: root.width / 2
            xScale: root.draw
        }
    }
}
