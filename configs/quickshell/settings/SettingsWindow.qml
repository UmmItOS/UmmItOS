pragma ComponentBehavior: Bound

import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".."

// UmmItOS Settings: a panel under the bar; a click outside it closes it.
OverlayWindow {
    id: win

    shown: Settings.open
    name: "settings"
    focusMode: WlrKeyboardFocus.OnDemand

    onOpened: {
        Settings.refresh();
        panel.forceActiveFocus();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Settings.open = false
    }

    FocusScope {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.barHeight + Theme.spacing.small
        width: Math.min(Theme.settings.width, parent.width - Theme.padding.extraLarge * 2)
        height: Math.min(Theme.settings.height, parent.height - anchors.topMargin - Theme.padding.extraLarge)
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal
        transformOrigin: Item.Top

        Keys.onEscapePressed: Settings.open = false

        Surface {
            anchors.fill: parent
            radius: Theme.rounding.extraExtraLarge
            tone: Theme.scrim(Theme.panelTint)
            lift: 1.12
        }

        // Swallow clicks so they do not reach the dismiss handler.
        MouseArea {
            anchors.fill: parent
            onClicked: panel.forceActiveFocus()
        }

        RowLayout {
            anchors {
                fill: parent
                margins: Theme.padding.extraLarge
            }
            spacing: Theme.spacing.extraLarge

            ColumnLayout {
                Layout.preferredWidth: Theme.settings.sidebar
                Layout.fillHeight: true
                spacing: Theme.spacing.extraSmall

                Text {
                    Layout.bottomMargin: Theme.spacing.large
                    text: "Settings"
                    color: Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.large
                    font.weight: Theme.weight.bold
                }

                Repeater {
                    model: Settings.pages

                    FlyoutRow {
                        id: entry

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        active: Settings.page === entry.index

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: Theme.padding.medium
                                rightMargin: Theme.padding.medium
                            }
                            spacing: Theme.spacing.medium

                            MaterialIcon {
                                text: entry.modelData.icon
                                color: entry.active ? Theme.fg : Theme.dim
                                size: Theme.icon.small
                                fill: entry.active ? 1 : 0
                            }

                            Text {
                                Layout.fillWidth: true
                                text: entry.modelData.name
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.normal
                                font.weight: entry.active ? Theme.weight.medium : Theme.weight.regular
                            }
                        }

                        TapHandler {
                            onTapped: Settings.page = entry.index
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: Settings.page

                RecordPage {}

                AboutPage {}
            }
        }
    }
}
