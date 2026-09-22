import QtQuick
import QtQuick.Shapes
import ".."

// Circular gauge: a full ring in the dim colour with the filled arc on top.
Item {
    id: root

    property real value: 0          // 0-1
    // Snap to the first reading; animate only subsequent changes. Otherwise
    // every open sweeps the arc up from zero.
    property bool animated: false

    onValueChanged: {
        if (value > 0 && !animated)
            Qt.callLater(() => animated = true);
    }
    property string primary: ""
    property string label: ""
    property color fill: Theme.accentText

    readonly property real ring: 10
    // Clamped: a layout that squeezes the gauge below the ring width would
    // otherwise hand Shape a negative radius, which takes the whole shell down.
    readonly property real radius: Math.max(1, Math.min(width, height) / 2 - ring / 2)

    implicitWidth: 170
    implicitHeight: 170

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.bgAlt
            strokeWidth: root.ring
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 130
                sweepAngle: 280
            }
        }

        ShapePath {
            strokeColor: root.fill
            strokeWidth: root.ring
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                id: arc
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 130
                sweepAngle: 280 * Math.max(0, Math.min(1, root.value))

                Behavior on sweepAngle {
                    enabled: root.animated
                    NumberAnimation {
                        duration: Theme.duration.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                    }
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.primary
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.extraLarge
            font.features: ({
                    tnum: 1
                })
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
        }
    }
}
