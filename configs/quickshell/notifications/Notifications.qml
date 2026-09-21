pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import ".."

Scope {
    NotificationServer {
        id: server

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        keepOnReload: false

        // Without tracked = true the notification is dropped immediately.
        onNotification: notification => {
            notification.tracked = true;
        }
    }

    PanelWindow {
        WlrLayershell.namespace: "ummitos-notifications"
        anchors {
            top: true
            right: true
        }
        // Do not reserve screen space, and stay out of the way when empty.
        exclusionMode: ExclusionMode.Ignore
        visible: server.trackedNotifications.values.length > 0
        implicitWidth: 420
        implicitHeight: Math.max(1, column.implicitHeight + Theme.padding.largeIncreased)
        color: "transparent"

        ColumnLayout {
            id: column
            anchors {
                top: parent.top
                right: parent.right
                margins: Theme.padding.medium
            }
            spacing: Theme.spacing.small

            Repeater {
                model: server.trackedNotifications

                Rectangle {
                    id: card
                    required property Notification modelData

                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    readonly property string appIcon: modelData.appIcon ? Quickshell.iconPath(modelData.appIcon, true) : ""
                    // Delegates are created on arrival, so this is the arrival time.
                    readonly property string time: Qt.formatDateTime(new Date(), "HH:mm")
                    // Clicking the body invokes the "default" action, which is
                    // how an app asks to be raised on the relevant view.
                    readonly property var defaultAction: modelData.actions.find(a => a.identifier === "default") ?? null

                    Layout.preferredWidth: 390
                    implicitHeight: body.implicitHeight + Theme.padding.large * 2
                    radius: Theme.rounding.extraLarge
                    color: Theme.bgAlt
                    border.color: critical ? Theme.urgent : Theme.border
                    border.width: 1

                    // Slide in from the right rather than appearing.
                    x: 0
                    opacity: 0
                    Component.onCompleted: {
                        x = 60;
                        enter.start();
                    }
                    ParallelAnimation {
                        id: enter
                        NumberAnimation {
                            target: card
                            property: "x"
                            to: 0
                            duration: Theme.duration.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.emphasizedDecel
                        }
                        NumberAnimation {
                            target: card
                            property: "opacity"
                            to: 1
                            duration: Theme.duration.expressiveDefaultEffects
                        }
                    }

                    HoverHandler {
                        id: hover
                    }

                    TapHandler {
                        onTapped: {
                            if (card.defaultAction)
                                card.defaultAction.invoke();
                            card.modelData.dismiss();
                        }
                    }

                    // Reading a notification should not race its own timer.
                    Timer {
                        running: !hover.hovered
                        interval: card.critical ? 15000 : 6000
                        onTriggered: card.modelData.expire()
                    }

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
                                source: card.appIcon
                                visible: status === Image.Ready
                            }

                            MaterialIcon {
                                visible: !icon.visible
                                text: "notifications"
                                color: Theme.dim
                                size: Theme.fontSize.normal
                            }

                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.appName
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.small
                                elide: Text.ElideRight
                            }

                            Text {
                                text: card.time
                                color: Theme.dim
                                font.family: Theme.font
                                font.features: ({
                                        tnum: 1
                                    })
                                font.pixelSize: Theme.fontSize.small
                            }

                            MaterialIcon {
                                text: "close"
                                color: Theme.dim
                                size: Theme.fontSize.normal
                                opacity: hover.hovered ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.duration.expressiveFastEffects
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onClicked: card.modelData.dismiss()
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.spacing.extraSmall
                            text: card.modelData.summary
                            color: card.critical ? Theme.urgent : Theme.accentText
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontSize.larger
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.body
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.normal
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            visible: text !== ""
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }

                        // Album art, screenshot previews, and the like.
                        ClippingRectangle {
                            Layout.topMargin: Theme.spacing.small
                            implicitWidth: 120
                            implicitHeight: 68
                            radius: Theme.rounding.medium
                            color: "transparent"
                            visible: card.modelData.image !== ""

                            Image {
                                anchors.fill: parent
                                source: card.modelData.image
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 240
                                sourceSize.height: 136
                            }
                        }

                        RowLayout {
                            Layout.topMargin: Theme.spacing.small
                            spacing: Theme.spacing.small
                            visible: card.modelData.actions.some(a => a.identifier !== "default")

                            Repeater {
                                model: card.modelData.actions.filter(a => a.identifier !== "default")

                                Rectangle {
                                    id: action
                                    required property var modelData

                                    implicitWidth: label.implicitWidth + Theme.padding.large * 2
                                    implicitHeight: 30
                                    radius: Theme.rounding.full
                                    color: actionHover.hovered ? Theme.accent : Theme.bg
                                    border.color: Theme.border
                                    border.width: 1

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.duration.expressiveFastEffects
                                        }
                                    }

                                    HoverHandler {
                                        id: actionHover
                                    }

                                    Text {
                                        id: label
                                        anchors.centerIn: parent
                                        text: action.modelData.text
                                        color: actionHover.hovered ? Theme.bg : Theme.fg
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize.smaller
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: action.modelData.invoke()
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
