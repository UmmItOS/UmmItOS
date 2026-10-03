import QtQuick

// A list whose rows slide in from the right, leave the same way, and the rest close up.
ListView {
    boundsBehavior: Flickable.StopAtBounds

    add: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.duration.expressiveDefaultEffects
        }

        NumberAnimation {
            property: "x"
            from: Theme.spacing.extraLarge * 2
            duration: Theme.duration.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.emphasizedDecel
        }
    }

    remove: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: Theme.duration.expressiveFastEffects
        }

        NumberAnimation {
            property: "x"
            to: Theme.spacing.extraLarge * 2
            duration: Theme.duration.expressiveFastSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.emphasizedAccel
        }
    }

    displaced: Transition {
        NumberAnimation {
            property: "y"
            duration: Theme.duration.expressiveFastSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.standard
        }

        // A displaced row keeps the cancelled add's opacity otherwise.
        NumberAnimation {
            property: "opacity"
            to: 1
            duration: Theme.duration.expressiveFastEffects
        }
    }
}
