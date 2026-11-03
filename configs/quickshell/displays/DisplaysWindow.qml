pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

// The Win+P chooser: four ways to use the connected screens, then the screens themselves.
OverlayWindow {
    id: win

    property int current: 0
    // True while the keyboard moved the selection last; a real pointer move clears it.
    property bool keyboard: false
    // False until the pointer really moves after opening, so a card under a still pointer does not look hovered.
    property bool pointerLive: false

    // a and b: how much of the first and second screen's ink is drawn; stacked: the second sits behind the first.
    readonly property var modes: [
        {
            id: "single",
            label: "This screen only",
            a: 1,
            b: Theme.displays.screenOff,
            stacked: false
        },
        {
            id: "mirror",
            label: "Duplicate",
            a: 1,
            b: 1 - Theme.displays.screenOff,
            stacked: true
        },
        {
            id: "extend",
            label: "Extend",
            a: 1,
            b: 1,
            stacked: false
        },
        {
            id: "second",
            label: "Second screen only",
            a: Theme.displays.screenOff,
            b: 1,
            stacked: false
        }
    ]

    // The card for what is on now.
    readonly property int modeIndex: Math.max(0, modes.findIndex(m => m.id === Displays.mode))

    onOpened: {
        current = modeIndex;
        keyboard = false;
        pointerLive = false;
        scope.forceActiveFocus();
    }

    shown: Displays.open
    name: "displays"
    scrim: Theme.shade.normal

    // A screen of the little picture on a card.
    component Screen: Rectangle {
        property real level: 1
        property color ink

        implicitWidth: Theme.displays.screenWidth
        implicitHeight: Theme.displays.screenHeight
        radius: Theme.rounding.extraSmall
        color: Qt.alpha(ink, level)

        Behavior on color {
            FastColor {}
        }
    }

    // After an apply, or once the outputs are first read, the selection follows what is on.
    Connections {
        function onModeChanged(): void {
            win.current = win.modeIndex;
        }

        target: Displays
    }

    MouseArea {
        onClicked: Displays.open = false

        anchors.fill: parent
    }

    FocusScope {
        id: scope

        Keys.onEscapePressed: Displays.open = false
        Keys.onLeftPressed: {
            win.keyboard = true;
            win.current = (win.current - 1 + win.modes.length) % win.modes.length;
        }
        Keys.onRightPressed: {
            win.keyboard = true;
            win.current = (win.current + 1) % win.modes.length;
        }
        Keys.onReturnPressed: {
            win.keyboard = true;
            Displays.apply(win.modes[win.current].id);
        }

        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        anchors.fill: parent
        focus: true

        Surface {
            id: sheet

            anchors.centerIn: parent
            width: form.implicitWidth + Theme.spacing.extraLarge * 2
            height: form.implicitHeight + Theme.spacing.extraLarge * 2
            radius: Theme.rounding.extraLarge
            tone: Theme.bg
            lift: Theme.lift.panel

            // Swallows clicks so they do not close the panel; a real move anywhere on it ends the keyboard cue.
            MouseArea {
                onPositionChanged: mouse => {
                    if (win.pointerMoved(this, mouse.x, mouse.y))
                        win.keyboard = false;
                        win.pointerLive = true;
                }

                anchors.fill: parent
                hoverEnabled: true
            }

            ColumnLayout {
                id: form

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: Theme.spacing.extraLarge
                }

                spacing: Theme.spacing.large

                Text {
                    text: I18n.t("Displays")
                    color: Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.extraLarge
                    font.bold: true
                }

                RowLayout {
                    spacing: Theme.spacing.large

                    Repeater {
                        model: win.modes

                        Rectangle {
                            id: card

                            required property var modelData
                            required property int index

                            readonly property bool chosen: Displays.mode === modelData.id
                            // Qt 6 still sends hover to a disabled item, so a card that cannot apply never lights.
                            readonly property bool hovered: card.enabled && press.containsMouse && win.pointerLive
                            readonly property bool picked: win.keyboard && win.current === index
                            readonly property color ink: chosen ? Theme.accentOn : Theme.fg
                            // Duplicating puts the second screen behind and above the first.
                            readonly property real pairLeft: (Theme.displays.screenWidth + Theme.spacing.small - Theme.displays.screenShift) / 2

                            Layout.preferredWidth: Theme.displays.card
                            Layout.preferredHeight: Theme.displays.cardHeight
                            enabled: Displays.outputs.length > 1
                            opacity: enabled ? 1 : Theme.disabledOpacity
                            radius: Theme.rounding.largeIncreased
                            color: chosen ? Theme.accent : hovered || picked ? Theme.bgTray : Theme.glass
                            scale: press.pressed ? Theme.pressScale : hovered ? Theme.displays.activeScale : 1

                            Behavior on color {
                                FastColor {}
                            }

                            Behavior on opacity {
                                FastFade {}
                            }

                            Behavior on scale {
                                PressAnim {}
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - Theme.spacing.large * 2
                                spacing: Theme.spacing.large

                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: Theme.displays.screenWidth * 2 + Theme.spacing.small
                                    implicitHeight: Theme.displays.screenHeight + Theme.displays.screenShift

                                    Screen {
                                        x: card.modelData.stacked ? card.pairLeft + Theme.displays.screenShift : Theme.displays.screenWidth + Theme.spacing.small
                                        y: card.modelData.stacked ? 0 : Theme.displays.screenShift / 2
                                        level: card.modelData.b
                                        ink: card.ink
                                    }

                                    Screen {
                                        x: card.modelData.stacked ? card.pairLeft : 0
                                        y: card.modelData.stacked ? Theme.displays.screenShift : Theme.displays.screenShift / 2
                                        level: card.modelData.a
                                        ink: card.ink
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    text: I18n.t(card.modelData.label)
                                    color: card.ink
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.normal
                                    font.bold: card.chosen
                                }
                            }

                            MouseArea {
                                id: press

                                onPositionChanged: mouse => {
                                    if (win.pointerMoved(this, mouse.x, mouse.y)) {
                                        win.keyboard = false;
                                        win.pointerLive = true;
                                        win.current = card.index;
                                    }
                                }

                                onClicked: Displays.apply(card.modelData.id)

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: card.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: Displays.outputs.length === 1
                    spacing: Theme.spacing.medium

                    MaterialIcon {
                        text: "info"
                        color: Theme.dim
                    }

                    Text {
                        Layout.fillWidth: true
                        text: I18n.t("Only one display is connected")
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                    }
                }

                SlideList {
                    Layout.fillWidth: true
                    implicitHeight: contentHeight
                    interactive: false
                    spacing: Theme.spacing.small

                    model: ScriptModel {
                        values: Displays.outputs
                        objectProp: "name"
                    }

                    delegate: Rectangle {
                        id: row

                        required property var modelData

                        readonly property bool off: modelData?.disabled ?? false
                        readonly property string mirrors: modelData?.mirrorOf ?? "none"

                        width: ListView.view.width
                        height: Theme.control.row
                        radius: Theme.rounding.large
                        color: Theme.glass

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: Theme.spacing.large
                                rightMargin: Theme.spacing.large
                            }

                            spacing: Theme.spacing.medium

                            MaterialIcon {
                                text: "monitor"
                                color: row.off ? Theme.dim : Theme.fg
                                fill: row.off ? 0 : 1
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    textFormat: Text.PlainText
                                    text: row.modelData?.name ?? ""
                                    color: row.off ? Theme.dim : Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.normal
                                    font.weight: Theme.weight.medium
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.PlainText
                                    text: row.modelData?.description ?? ""
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.small
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                visible: !row.off
                                text: I18n.t("%1 × %2 @ %3 Hz").arg(row.modelData?.width ?? 0).arg(row.modelData?.height ?? 0).arg(Math.round(row.modelData?.refreshRate ?? 0))
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.smaller
                            }

                            Text {
                                visible: row.off || row.mirrors !== "none"
                                textFormat: Text.PlainText
                                text: row.off ? I18n.t("Off") : I18n.t("Mirrors %1").arg(row.mirrors)
                                color: row.off ? Theme.dim : Theme.accentText
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.smaller
                                font.weight: Theme.weight.medium
                            }
                        }
                    }
                }

                // Its space opens only while a change waits to be kept.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Displays.confirming ? ask.implicitHeight : 0
                    visible: opacity > 0
                    opacity: Displays.confirming ? 1 : 0

                    Behavior on Layout.preferredHeight {
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

                    RowLayout {
                        id: ask

                        width: parent.width
                        spacing: Theme.spacing.medium

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: I18n.t("Keep these display settings?")
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.normal
                                font.weight: Theme.weight.medium
                            }

                            Text {
                                text: I18n.t("Reverting in %1 s").arg(Displays.remaining)
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.small
                            }
                        }

                        Action {
                            onClicked: Displays.revert()

                            label: I18n.t("Revert")
                        }

                        Action {
                            onClicked: Displays.keep()

                            label: I18n.t("Keep")
                            primary: true
                        }
                    }
                }
            }
        }
    }
}
