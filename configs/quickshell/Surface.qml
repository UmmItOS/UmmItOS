import QtQuick

// A top-edge gradient is the only depth cue; there are no borders.
Rectangle {
    id: root

    property color tone: Theme.bgAlt
    // Larger surfaces take less, or the gradient shows as a band.
    property real lift: 1.22

    gradient: Gradient {
        GradientStop {
            position: 0
            color: Qt.lighter(root.tone, root.lift)
        }
        GradientStop {
            position: 0.6
            color: root.tone
        }
    }
}
