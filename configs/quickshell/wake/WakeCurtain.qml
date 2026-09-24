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

    readonly property real glow: 1 - open

    // Out-cubic for the line (quick, then settling); in-out-sine for the
    // lids, whose start is gentle but never a standstill.
    function ease(t: real, lids: bool): real {
        if (!lids)
            return 1 - Math.pow(1 - t, 3);
        return (1 - Math.cos(Math.PI * t)) / 2;
    }

    visible: dark > 0

    // Each lid is the black plus the deep, wide shadow its edge melts into
    // the opening with. It keeps its size and slides away with a transform
    // (geometry changes every frame jank), all the way off screen, shadow
    // included, so nothing is left to vanish at the end.
    component Lid: Item {
        id: lid

        required property bool upper

        anchors.left: parent.left
        anchors.right: parent.right
        height: root.height / 2 + Theme.wakeFeather
        y: lid.upper ? 0 : root.height / 2 - Theme.wakeFeather

        transform: Translate {
            y: (lid.upper ? -1 : 1) * lid.height * root.open
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
            // The shadow only exists once the lids part; closed, the line
            // sits on plain black.
            opacity: Math.min(1, root.open * 4)
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
