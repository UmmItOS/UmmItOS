import Quickshell
import Quickshell.Wayland
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
        implicitWidth: 380
        implicitHeight: Math.max(1, column.implicitHeight + 20)
        color: "transparent"

        ColumnLayout {
            id: column
            anchors {
                top: parent.top
                right: parent.right
                margins: 10
            }
            spacing: Theme.spacing.small

            Repeater {
                model: server.trackedNotifications

                Rectangle {
                    id: card
                    required property Notification modelData

                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical

                    Layout.preferredWidth: 360
                    implicitHeight: body.implicitHeight + 24
                    radius: Theme.rounding.extraLarge
                    color: Theme.bgAlt
                    border.color: critical ? Theme.urgent : Theme.border
                    border.width: 1

                    ColumnLayout {
                        id: body
                        anchors {
                            fill: parent
                            margins: 12
                        }
                        spacing: 4

                        Text {
                            text: card.modelData.summary
                            color: card.critical ? Theme.urgent : Theme.accent
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.normal
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: card.modelData.body
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.normal.smaller
                            wrapMode: Text.Wrap
                            visible: text !== ""
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: card.modelData.dismiss()
                    }

                    Timer {
                        running: true
                        interval: card.critical ? 15000 : 5000
                        onTriggered: card.modelData.expire()
                    }
                }
            }
        }
    }
}
