import QtQuick

// Separate from the icon: RotationAnimation leaves `rotation` tilted.
MaterialIcon {
    id: root

    text: "progress_activity"
    color: Theme.dim
    size: Theme.icon.small

    RotationAnimation on rotation {
        running: root.visible
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: Theme.duration.spin
    }
}
