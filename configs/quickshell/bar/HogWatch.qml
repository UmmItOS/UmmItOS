pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// A process that keeps the CPU or GPU busy: warning glyph, its name, the kind and the share. Fades when it calms.
Item {
    id: root

    readonly property var hog: ProcWatch.top
    // Keeps the last words on screen while the label fades out.
    property string words: ""

    onHogChanged: if (hog)
        words = hog.name + " " + hog.kind + " " + Math.round(hog.share) + "%"

    Accessible.role: Accessible.StaticText
    Accessible.name: I18n.t("Heavy process") + " " + words
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    opacity: hog ? 1 : 0
    visible: opacity > 0
    layer.enabled: opacity < 1
    layer.effect: MotionBlur {
        settled: root.opacity
    }
    transform: Translate {
        x: root.hog ? 0 : -Theme.spacing.small

        Behavior on x {
            NumberAnimation {
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.hog ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
            }
        }
    }

    Behavior on opacity {
        FastFade {}
    }

    RowLayout {
        id: row

        spacing: Theme.spacing.extraSmall

        MaterialIcon {
            text: "warning"
            color: Theme.warn
            size: Theme.icon.tiny
        }

        Text {
            Layout.maximumWidth: Theme.bar.fileWatch
            textFormat: Text.PlainText
            text: root.words
            color: Theme.warn
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
        }
    }

    Tip {
        anchorItem: root
        text: I18n.t("Heavy process") + ": " + root.words
        wanted: hover.hovered
    }

    HoverHandler {
        id: hover
    }
}
