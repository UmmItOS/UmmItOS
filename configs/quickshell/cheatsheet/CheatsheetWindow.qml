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

        // Hyprland's active border, as a ring round the sheet: its four colours
        // in a linear gradient turning about the centre, darkened, one turn
        // every 5s like borderangle 50. The sheet is translucent, so the
        // gradient is drawn off screen and cut to a thin outline by a mask.
        Item {
            id: ringFill

            anchors {
                fill: sheet
                margins: -ring.thickness
            }
            visible: false
            layer.enabled: true
            clip: true

            Rectangle {
                anchors.centerIn: parent
                width: Math.hypot(parent.width, parent.height)
                height: width
                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Theme.ring[0]
                    }
                    GradientStop {
                        position: 0.33
                        color: Theme.ring[1]
                    }
                    GradientStop {
                        position: 0.66
                        color: Theme.ring[2]
                    }
                    GradientStop {
                        position: 1
                        color: Theme.ring[3]
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
        }

        // The same turning gradient, faint, through the whole sheet: the glass
        // takes on the colours as they pass, but stays dark.
        Item {
            id: fillMask

            anchors.fill: ringFill
            visible: false
            layer.enabled: true

            Rectangle {
                anchors {
                    fill: parent
                    margins: ring.thickness
                }
                radius: sheet.radius
                color: "white"
            }
        }

        MultiEffect {
            anchors.fill: ringFill
            source: ringFill
            maskEnabled: true
            maskSource: fillMask
            opacity: 0.35
        }

        Surface {
            id: sheet

            anchors.fill: parent
            implicitHeight: body.implicitHeight + Theme.padding.extraLarge * 2
            radius: Theme.rounding.extraLarge
            tone: Theme.bg
            lift: 1.1
            clip: true

            HoverHandler {
                id: pointer
            }

            // A soft light under the pointer, eased so it trails a little, and
            // gone when the pointer leaves: the sheet notices where you are.
            Item {
                id: spot

                readonly property int size: 360

                width: spot.size
                height: spot.size
                x: pointer.point.position.x - spot.size / 2
                y: pointer.point.position.y - spot.size / 2
                opacity: pointer.hovered ? 1 : 0

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.duration.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.duration.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.duration.expressiveDefaultEffects
                    }
                }

                Rectangle {
                    id: glow

                    anchors.centerIn: parent
                    width: spot.size / 2
                    height: width
                    radius: width / 2
                    color: Theme.accentText
                    opacity: 0.22
                    visible: false
                    layer.enabled: true
                }

                MultiEffect {
                    anchors.fill: parent
                    source: glow
                    blurEnabled: true
                    blurMax: 64
                    blur: 1
                    autoPaddingEnabled: true
                    opacity: glow.opacity
                }
            }

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
