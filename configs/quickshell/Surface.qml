import QtQuick

// A flat fill reads as a shape; a graded one reads as a material. Every raised
// surface in the shell catches a little more light along its top edge, which is
// the only depth cue here now that borders are gone.
Rectangle {
    id: root

    property color tone: Theme.bgAlt
    // How much light the top edge catches. Larger surfaces take less, or the
    // gradient becomes a visible band rather than a suggestion.
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
