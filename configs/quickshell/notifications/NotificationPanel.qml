pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

// A column down the right edge, under the bar: notifications arrive there, so
// their history belongs in the same place rather than in a centred dialog.
PanelWindow {
    id: win

    visible: Notifs.panelOpen

    WlrLayershell.namespace: "ummitos-notification-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        right: true
    }
    margins.top: Theme.barHeight
    implicitWidth: 440
    color: "transparent"

    Surface {
        anchors {
            fill: parent
            margins: Theme.spacing.small
        }
        radius: Theme.rounding.extraExtraLarge
        tone: Theme.bg
        lift: 1.1

        // Slides from the edge it lives on.
        x: Notifs.panelOpen ? 0 : width
        Behavior on x {
            NumberAnimation {
                duration: Theme.duration.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.emphasizedDecel
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: Theme.padding.large
            }
            spacing: Theme.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.medium

                Text {
                    text: "Notifications"
                    color: Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.large
                    font.weight: Theme.weight.bold
                }

                Text {
                    Layout.fillWidth: true
                    text: Notifs.history.length === 0 ? "" : Notifs.history.length
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    font.features: ({
                            tnum: 1
                        })
                }

                // Do not disturb still records; it only stops the toast.
                Rectangle {
                    implicitWidth: 38
                    implicitHeight: 38
                    radius: width / 2
                    color: Notifs.dnd ? Theme.accent : Theme.bgTray

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: Notifs.dnd ? "notifications_off" : "notifications_active"
                        color: Theme.fg
                        fill: Notifs.dnd ? 1 : 0
                        size: Theme.icon.small
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                }

                Rectangle {
                    implicitWidth: 38
                    implicitHeight: 38
                    radius: width / 2
                    color: clearHover.hovered ? Theme.urgent : Theme.bgTray
                    visible: Notifs.history.length > 0

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }

                    HoverHandler {
                        id: clearHover
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "delete_sweep"
                        color: Theme.fg
                        size: Theme.icon.small
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Notifs.clear()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                visible: Notifs.history.length === 0
                text: Notifs.dnd ? "Nothing here. Do not disturb is on." : "Nothing here."
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.normal
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: Notifs.history.length > 0
                clip: true
                spacing: Theme.spacing.small
                model: Notifs.history
                boundsBehavior: Flickable.StopAtBounds

                delegate: Surface {
                    id: card
                    required property var modelData

                    width: ListView.view.width
                    implicitHeight: body.implicitHeight + Theme.padding.large * 2
                    radius: Theme.rounding.extraLarge
                    tone: Theme.bgAlt

                    ColumnLayout {
                        id: body
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: Theme.padding.large
                        }
                        spacing: Theme.spacing.extraSmall

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.small

                            IconImage {
                                id: icon
                                implicitSize: 16
                                source: card.modelData.appIcon ? Quickshell.iconPath(card.modelData.appIcon, true) : ""
                                visible: status === Image.Ready
                            }

                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.appName
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.small
                                font.weight: Theme.weight.medium
                                font.letterSpacing: Theme.tracking.wide
                                elide: Text.ElideRight
                            }

                            Text {
                                text: card.modelData.time
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.small
                                font.features: ({
                                        tnum: 1
                                    })
                            }

                            MaterialIcon {
                                text: "close"
                                color: Theme.dim
                                size: Theme.icon.small
                                opacity: cardHover.hovered ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.duration.expressiveFastEffects
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onClicked: Notifs.forget(card.modelData.key)
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.spacing.extraSmall
                            text: card.modelData.summary
                            color: card.modelData.critical ? Theme.urgent : Theme.accentText
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontSize.normal
                            font.weight: Theme.weight.bold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.body
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.smaller
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }

                    HoverHandler {
                        id: cardHover
                    }
                }
            }
        }
    }
}
