import QtQuick

// A turning icon, and nothing else. It is a separate component from the static
// icon it replaces because a RotationAnimation leaves `rotation` at whatever
// angle it stopped on: reuse one item for both states and the still icon
// renders tilted.
MaterialIcon {
    text: "progress_activity"
    color: Theme.dim
    size: Theme.icon.small

    RotationAnimation on rotation {
        running: visible
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: Theme.duration.spin
    }
}
