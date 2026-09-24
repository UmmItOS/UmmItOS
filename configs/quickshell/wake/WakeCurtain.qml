import QtQuick
import ".."

// Waking as eyelids opening: the black splits at a glowing line across the
// middle and parts up and down, each edge carrying a soft light in the
// accent colour that fades as it opens. `dark` is 1 closed, 0 open.
Item {
    id: root

    property real dark: 0
    readonly property real half: height / 2 * dark
    // Brightest while the line is thin; gone by the time it is open.
    readonly property real glow: Math.min(1, dark * 1.4)
    readonly property color light: Qt.alpha(Theme.accentText, 0.55)

    visible: dark > 0

    // The lids first, then every edge's light over both, so neither lid
    // covers the other's glow while they meet in the middle.
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

    component Edge: Item {
        id: edge

        // The y of the lid's edge, and which way its light spills.
        required property real at
        required property bool down

        anchors.left: parent.left
        anchors.right: parent.right
        y: edge.down ? edge.at : edge.at - height
        height: Theme.wakeGlow
        opacity: root.glow

        Rectangle {
            anchors.fill: parent
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

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            y: edge.down ? 0 : parent.height - height
            height: Theme.spacing.hair
            color: Theme.accent2
        }
    }

    Edge {
        at: root.half
        down: true
    }

    Edge {
        at: root.height - root.half
        down: false
    }
}
