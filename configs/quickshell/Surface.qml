import QtQuick

// A top-edge gradient is the only depth cue; there are no borders.
Rectangle {
    id: root

    property color tone: Theme.bgAlt
    // Larger surfaces take less, or the gradient shows as a band.
    property real lift: Theme.lift.card

    gradient: Gradient {
        GradientStop {
            position: 0
            color: Qt.lighter(root.tone, root.lift)
        }
        GradientStop {
            position: Theme.lift.reach
            color: root.tone
        }
    }
}
