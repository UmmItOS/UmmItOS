import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// A short label under an icon-only control, after the pointer rests on it.
PopupWindow {
    id: root

    required property Item anchorItem
    property string text
    // A list instead of a label: { text, glyph } or { text, image } per row, the icon before the words.
    property var rows: []
    // Anything else, such as a chart, in place of the label or the list.
    property Component body: null
    // The control is hovered; the tip follows after a pause.
    property bool wanted: false
    property bool showing: false

    onWantedChanged: {
        if (wanted && (text !== "" || rows.length > 0 || body !== null)) {
            delay.restart();
        } else {
            delay.stop();
            showing = false;
        }
    }

    anchor {
        item: root.anchorItem
        edges: Edges.Bottom
        gravity: Edges.Bottom
        margins.top: Theme.spacing.small
    }

    implicitWidth: sheet.width + Theme.windowInset
    implicitHeight: sheet.height + Theme.windowInset
    color: "transparent"
    visible: showing || sheet.opacity > 0
    // Never takes the pointer, so it cannot cover what it describes or flicker under the cursor.
    mask: Region {}

    Timer {
        id: delay

        onTriggered: root.showing = true

        interval: Theme.duration.tipDelay
    }

    Rectangle {
        id: sheet

        anchors.centerIn: parent
        readonly property bool custom: root.body !== null
        readonly property bool listed: !custom && root.rows.length > 0
        // One line of any kind is a pill.
        readonly property bool single: !custom && root.rows.length <= 1 && label.lineCount <= 1

        width: (custom ? body.implicitWidth : listed ? list.implicitWidth : label.implicitWidth) + Theme.spacing.medium * 2
        height: (custom ? body.implicitHeight + Theme.spacing.medium * 2 : listed ? list.implicitHeight + (single ? Theme.spacing.small : Theme.spacing.medium) * 2 : label.implicitHeight + Theme.spacing.small * 2)
        radius: single ? Theme.rounding.full : Theme.rounding.medium
        color: Theme.bgTray
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : Theme.popScale
        layer.enabled: opacity < 1

        layer.effect: MotionBlur {
            settled: sheet.opacity
        }

        Behavior on opacity {
            FastFade {}
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.showing ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
            }
        }

        ColumnLayout {
            id: list

            anchors.centerIn: parent
            visible: sheet.listed
            spacing: Theme.spacing.small

            Repeater {
                model: root.rows

                RowLayout {
                    id: entry

                    required property var modelData

                    spacing: Theme.spacing.small

                    IconImage {
                        Layout.alignment: Qt.AlignVCenter
                        visible: (entry.modelData.image ?? "") !== ""
                        implicitSize: Theme.icon.small
                        source: entry.modelData.image ?? ""
                    }

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        visible: (entry.modelData.image ?? "") === "" && (entry.modelData.glyph ?? "") !== ""
                        text: entry.modelData.glyph ?? ""
                        color: Theme.accentText
                        size: Theme.icon.small
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: Theme.tipWidth
                        text: entry.modelData.text
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.smaller
                    }
                }
            }
        }

        // Built only while the tip shows, so a chart paints nothing in the dark.
        Loader {
            id: body

            anchors.centerIn: parent
            active: sheet.custom && root.visible
            sourceComponent: root.body
        }

        Text {
            id: label

            anchors.centerIn: parent
            visible: !sheet.listed && !sheet.custom
            text: root.text
            textFormat: Text.PlainText
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
        }
    }
}
