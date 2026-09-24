import QtQuick
import QtQuick.Effects
import ".."

// Waking as eyes opening, in two beats. A soft line of light first draws
// itself out from the centre of the black; then the black parts up and down
// from it like eyelids, each edge carrying a wide glow in the accent colour
// that fades as it opens. `dark` runs 1 → 0, linearly; each beat eases on
// its own here.
Item {
    id: root

    property real dark: 0
    readonly property real progress: 1 - dark

    // Share of the whole spent drawing the line before the lids move.
    readonly property real drawShare: 0.3
    readonly property real draw: ease(Math.min(1, progress / drawShare), false)
    readonly property real open: ease(Math.max(0, (progress - drawShare) / (1 - drawShare)), true)

    readonly property real half: height / 2 * (1 - open)
    readonly property real glow: 1 - open
    readonly property color light: Qt.alpha(Theme.accentText, 0.4)

    // Out-cubic for the line (quick, then settling); in-out-cubic for the
    // lids (a gentle start and a soft landing).
    function ease(t: real, both: bool): real {
        if (!both)
            return 1 - Math.pow(1 - t, 3);
        return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
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

    // Each lid's edge fades into the opening like a shadow, and carries a
    // wide, faint light, so the parting is soft rather than two hard bars.
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

        Rectangle {
            anchors.fill: parent
            opacity: root.glow
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: edge.down ? root.light : "transparent"
                }
                GradientStop {
                    position: 1
                    color: edge.down ? "transparent" : root.light
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

    // The line itself: a pill of light grown from the centre, blurred so its
    // ends and edges glow instead of cutting. Drawn off screen, shown blurred.
    Rectangle {
        id: pill

        anchors.centerIn: parent
        width: Math.max(1, parent.width * root.draw)
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
    }
}
