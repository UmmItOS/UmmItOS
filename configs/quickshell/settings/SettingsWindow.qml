pragma ComponentBehavior: Bound

import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".."

// UmmItOS Settings: a panel under the bar; a click outside it closes it.
OverlayWindow {
    id: win

    // Only a change of page while open animates; the page picked before opening just shows.
    property bool settled: false
    // 1 when the new page is below the old one in the list, -1 when above.
    property int travel: 1

    onOpened: {
        Settings.refresh();
        panel.forceActiveFocus();
        swap.stop();
        stack.opacity = 1;
        shift.y = 0;
        stack.currentIndex = Settings.page;
        settled = false;
        Qt.callLater(() => settled = true);
    }

    shown: Settings.open
    name: "settings"
    focusMode: WlrKeyboardFocus.OnDemand

    Connections {
        function onPageChanged(): void {
            if (!win.settled) {
                stack.currentIndex = Settings.page;
                return;
            }
            win.travel = Settings.page > stack.currentIndex ? 1 : -1;
            swap.restart();
        }

        target: Settings
    }

    // The old page leaves the way the pill goes, then the new one arrives from the other side.
    SequentialAnimation {
        id: swap

        ParallelAnimation {
            NumberAnimation {
                target: stack
                property: "opacity"
                to: 0
                duration: Theme.duration.expressiveFastEffects
            }

            NumberAnimation {
                target: shift
                property: "y"
                to: -win.travel * Theme.settings.pageShift
                duration: Theme.duration.expressiveFastEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.emphasizedAccel
            }
        }

        ScriptAction {
            script: stack.currentIndex = Settings.page
        }

        PropertyAction {
            target: shift
            property: "y"
            value: win.travel * Theme.settings.pageShift
        }

        ParallelAnimation {
            NumberAnimation {
                target: stack
                property: "opacity"
                to: 1
                duration: Theme.duration.expressiveDefaultEffects
            }

            NumberAnimation {
                target: shift
                property: "y"
                to: 0
                duration: Theme.duration.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.emphasizedDecel
            }
        }
    }

    MouseArea {
        onClicked: Settings.open = false

        anchors.fill: parent
    }

    FocusScope {
        id: panel

        Keys.onEscapePressed: Settings.open = false

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.barHeight + Theme.spacing.small
        width: Math.min(Theme.settings.width, parent.width - Theme.spacing.extraLarge * 2)
        height: Math.min(Theme.settings.height, parent.height - anchors.topMargin - Theme.spacing.extraLarge)
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal
        transformOrigin: Item.Top

        Surface {
            anchors.fill: parent
            radius: Theme.rounding.extraExtraLarge
            tone: Theme.scrim(Theme.panelTint)
            lift: Theme.lift.panel
        }

        // Swallow clicks so they do not reach the dismiss handler.
        MouseArea {
            onClicked: panel.forceActiveFocus()

            anchors.fill: parent
        }

        RowLayout {
            anchors {
                fill: parent
                margins: Theme.spacing.extraLarge
            }

            spacing: Theme.spacing.extraLarge

            ColumnLayout {
                Layout.preferredWidth: Theme.settings.sidebar
                Layout.fillHeight: true
                spacing: Theme.spacing.extraSmall

                Text {
                    Layout.bottomMargin: Theme.spacing.large
                    text: I18n.t("Settings")
                    color: Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.large
                    font.weight: Theme.weight.bold
                }

                // One accent pill slides to the page in use, instead of each row filling on its own.
                Item {
                    Layout.fillWidth: true
                    implicitHeight: entries.implicitHeight

                    Rectangle {
                        width: entries.width
                        height: Theme.control.row
                        radius: Theme.rounding.large
                        color: Theme.accent

                        transform: Translate {
                            // Through count: itemAt() in a binding runs once otherwise.
                            y: tabs.count > 0 ? tabs.itemAt(Settings.page)?.y ?? 0 : 0

                            Behavior on y {
                                enabled: win.settled

                                NumberAnimation {
                                    duration: Theme.duration.expressiveFastSpatial
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curve.emphasized
                                }
                            }
                        }
                    }

                    Column {
                        id: entries

                        width: parent.width
                        spacing: Theme.spacing.extraSmall

                        Repeater {
                            id: tabs

                            model: Settings.pages

                            FlyoutRow {
                                id: entry

                                required property var modelData
                                required property int index

                                width: entries.width
                                active: Settings.page === entry.index
                                // The pill is the fill; a row only shows its hover.
                                color: entry.hovered && !entry.active ? Theme.bgTray : "transparent"
                                scale: press.pressed ? Theme.pressScale : 1

                                Behavior on scale {
                                    PressAnim {}
                                }

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: Theme.spacing.medium
                                        rightMargin: Theme.spacing.medium
                                    }

                                    spacing: Theme.spacing.medium

                                    MaterialIcon {
                                        text: entry.modelData.icon
                                        color: entry.active ? entry.ink : entry.inkDim
                                        size: Theme.icon.small
                                        fill: entry.active ? 1 : 0
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.t(entry.modelData.name)
                                        color: entry.ink
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize.normal
                                        font.weight: entry.active ? Theme.weight.medium : Theme.weight.regular
                                    }
                                }

                                TapHandler {
                                    id: press

                                    onTapped: Settings.page = entry.index
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            StackLayout {
                id: stack

                Layout.fillWidth: true
                Layout.fillHeight: true

                transform: Translate {
                    id: shift
                }

                layer.enabled: opacity < 1

                layer.effect: MotionBlur {
                    settled: stack.opacity
                }

                RecordPage {}

                PackagesPage {}

                UpdatePage {}

                PrivacyPage {}

                LanguagePage {}

                AboutPage {}
            }
        }
    }
}
