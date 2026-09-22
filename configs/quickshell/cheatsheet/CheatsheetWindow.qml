pragma ComponentBehavior: Bound

import QtQuick
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
