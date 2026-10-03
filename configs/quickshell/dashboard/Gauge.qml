import QtQuick
import QtQuick.Shapes
import ".."

// Circular gauge: a full ring in the dim colour with the filled arc on top.
Item {
    id: root

    property real value: 0          // 0-1
    // Snap to the first reading, or every open sweeps up from zero.
    property bool animated: false
    property string primary: ""
    property string label: ""

    readonly property real ring: Theme.dashboard.gaugeRing
    // Clamped: a negative radius crashes the shell.
    readonly property real radius: Math.max(1, Math.min(width, height) / 2 - ring / 2)

    onValueChanged: {
        if (value > 0 && !animated)
            Qt.callLater(() => animated = true);
    }

    implicitWidth: Theme.dashboard.gauge
    implicitHeight: Theme.dashboard.gauge

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
                startAngle: Theme.dashboard.gaugeStart
                sweepAngle: Theme.dashboard.gaugeSweep
            }
        }

        ShapePath {
            strokeColor: Theme.accentText
            strokeWidth: root.ring
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                id: arc

                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: Theme.dashboard.gaugeStart
                sweepAngle: Theme.dashboard.gaugeSweep * Math.max(0, Math.min(1, root.value))

                Behavior on sweepAngle {
                    enabled: root.animated

                    NumberAnimation {
                        duration: Theme.duration.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacing.hair

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
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
            textFormat: Text.PlainText
            text: root.label
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
        }
    }
}
