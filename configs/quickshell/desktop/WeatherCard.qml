pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// A medium macOS-style weather widget: place, temperature, today's range, the next hours.
Rectangle {
    id: card

    implicitWidth: Theme.widgetWidth
    implicitHeight: body.implicitHeight + Theme.spacing.large * 2
    radius: Theme.rounding.extraLarge
    color: Theme.scrim(Theme.panelTint)

    // Its window maps when the forecast arrives, so this runs on each appearance.
    opacity: Weather.ready ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.duration.expressiveDefaultEffects
        }
    }
    layer.enabled: opacity < 1
    layer.effect: MotionBlur {
        settled: card.opacity
    }

    ColumnLayout {
        id: body

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.spacing.large
        }
        spacing: Theme.spacing.extraSmall

        Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: Weather.location
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.normal
            font.weight: Theme.weight.medium
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.medium

            Text {
                textFormat: Text.PlainText
                text: Weather.temp + "°"
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSize.huge
                font.weight: Font.Light
            }

            Item {
                Layout.fillWidth: true
            }

            MaterialIcon {
                text: Weather.icon(Weather.code, Weather.hour)
                color: Theme.accentText
                fill: 1
                size: Theme.icon.large
            }
        }

        Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: I18n.t("%1   H:%2°  L:%3°").arg(Weather.condition).arg(Weather.high).arg(Weather.low)
            elide: Text.ElideRight
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
        }

        // Equal columns, however wide each time reads.
        Row {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.medium

            Repeater {
                model: Weather.hours

                Column {
                    id: slot

                    required property var modelData

                    width: parent.width / Math.max(1, Weather.hours.length)
                    spacing: Theme.spacing.extraSmall

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        textFormat: Text.PlainText
                        text: I18n.t(slot.modelData.label)
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                        font.features: ({
                                tnum: 1
                            })
                    }

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.icon(slot.modelData.code, slot.modelData.hour)
                        color: Theme.accentText
                        fill: 1
                        size: Theme.icon.small
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        textFormat: Text.PlainText
                        text: slot.modelData.temp + "°"
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.smaller
                        font.weight: Theme.weight.medium
                    }
                }
            }
        }
    }
}
