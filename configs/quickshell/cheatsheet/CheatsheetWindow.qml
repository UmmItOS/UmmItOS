pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import ".."

// The keybinds, as a sheet rather than a terminal table: groups in columns,
// each bind a row of keycaps and what it does.
OverlayWindow {
    id: win

    shown: Cheatsheet.open
    name: "cheatsheet"
    scrim: 0.5

    onOpened: scope.forceActiveFocus()

    MouseArea {
        anchors.fill: parent
        onClicked: Cheatsheet.open = false
    }

    // A key, drawn as a key.
    component Keycap: Rectangle {
        required property string label

        implicitWidth: Math.max(implicitHeight, text.implicitWidth + Theme.padding.small * 2)
        implicitHeight: text.implicitHeight + Theme.spacing.extraSmall * 2
        radius: Theme.rounding.extraSmall
        color: Theme.bgTray

        Text {
            id: text
            anchors.centerIn: parent
            text: parent.label
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
            font.weight: Theme.weight.medium
        }
    }

    FocusScope {
        id: scope

        anchors.centerIn: parent
        width: Math.min(1400, parent.width - Theme.padding.extraLarge * 2)
        height: Math.min(sheet.implicitHeight, parent.height - Theme.padding.extraLarge * 2)
        focus: true
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        Keys.onEscapePressed: Cheatsheet.open = false

        // Clicks on the sheet stay on the sheet.
        MouseArea {
            anchors.fill: parent
        }

        // A comet orbiting the sheet: a dark ring in the accent's own hue, one
        // bright head with a fading tail, turning every 5s like borderangle 50.
        // The sheet is translucent, so the light is drawn off screen and cut to
        // a thin outline by a mask, leaving the inside the usual dark glass.
        Item {
            id: ringFill

            readonly property color base: Qt.darker(Theme.accent, 3)

            anchors {
                fill: sheet
                margins: -ring.thickness
            }
            visible: false
            layer.enabled: true
            clip: true

            // A square wider than the sheet's diagonal, dark except for one
            // edge: turning it sweeps that edge round the ring as the comet.
            Rectangle {
                anchors.centerIn: parent
                width: Math.hypot(parent.width, parent.height)
                height: width
                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Theme.accentText
                    }
                    GradientStop {
                        position: 0.12
                        color: Theme.accent
                    }
                    GradientStop {
                        position: 0.4
                        color: ringFill.base
                    }
                    GradientStop {
                        position: 1
                        color: ringFill.base
                    }
                }

                RotationAnimation on rotation {
                    running: win.visible
                    from: 0
                    to: 360
                    duration: 5000
                    loops: Animation.Infinite
                }
            }
        }

        // The outline the gradient shows through; a mask, never drawn.
        Rectangle {
            id: ring

            readonly property int thickness: Theme.spacing.hair + 1

            anchors.fill: ringFill
            visible: false
            layer.enabled: true
            radius: sheet.radius + ring.thickness
            color: "transparent"
            border.width: ring.thickness
            border.color: "white"
        }

        MultiEffect {
            anchors.fill: ringFill
            source: ringFill
            maskEnabled: true
            maskSource: ring
            // The head throws a little light off the edge.
            shadowEnabled: true
            shadowColor: Theme.accent
            shadowBlur: 0.6
            shadowOpacity: 0.7
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        Surface {
            id: sheet

            anchors.fill: parent
            implicitHeight: body.implicitHeight + Theme.padding.extraLarge * 2
            radius: Theme.rounding.extraLarge
            tone: Theme.bg
            lift: 1.1

            Flickable {
                anchors {
                    fill: parent
                    margins: Theme.padding.extraLarge
                }
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: body

                    width: parent.width
                    spacing: Theme.spacing.large

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: "Cheat sheet"
                            color: Theme.fg
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontSize.extraLarge
                            font.bold: true
                        }

                        MaterialIcon {
                            text: "close"
                            color: Theme.dim
                            size: Theme.icon.small

                            TapHandler {
                                onTapped: Cheatsheet.open = false
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: Math.max(1, Math.floor(width / 440))
                        columnSpacing: Theme.spacing.extraLarge
                        rowSpacing: Theme.spacing.extraLarge

                        Repeater {
                            model: Cheatsheet.groups

                            ColumnLayout {
                                id: group

                                required property var modelData

                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: Theme.spacing.small

                                Text {
                                    text: group.modelData.title
                                    color: Theme.accentText
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Theme.fontSize.large
                                    font.bold: true
                                }

                                Repeater {
                                    model: group.modelData.rows

                                    RowLayout {
                                        id: row

                                        required property var modelData

                                        Layout.fillWidth: true
                                        spacing: Theme.spacing.medium

                                        Row {
                                            Layout.preferredWidth: 180
                                            spacing: Theme.spacing.extraSmall

                                            Repeater {
                                                model: row.modelData.keys

                                                Keycap {
                                                    required property string modelData
                                                    label: modelData
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: row.modelData.description
                                            color: Theme.fg
                                            opacity: 0.75
                                            elide: Text.ElideRight
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize.normal
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
