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
        // The record is taken here because the object itself does not survive
        // expiry, and the panel needs something that does.
        onNotification: notification => {
            // Every notification sounds, like a phone, unless something else
            // already does: the shell's own notices keep their pop, and apps
            // that play their own sound (or ask not to have one) stay quiet.
            const app = (notification.appName || "").toLowerCase();
            const entry = (notification.desktopEntry || "").toLowerCase();
            const hints = notification.hints ?? {};
            const ownSound = ["vesktop", "discord", "telegram", "telegramdesktop", "org.telegram.desktop"].some(a => app.includes(a) || entry.includes(a)) || hints["suppress-sound"] || hints["sound-file"] || hints["sound-name"];
            const charging = app === "battery" && notification.summary === "Charging";
            let sound = "";
            if (["color picker", "screen recording", "update"].includes(app))
                sound = "/toast/pop.ogg";
            else if (!ownSound && !charging)
                sound = "/notifications/chime.ogg";
            if (sound !== "" && !Notifs.dnd)
                Quickshell.execDetached(["pw-play", Quickshell.shellDir + sound]);
            Notifs.record(notification);
            notification.tracked = !Notifs.dnd;
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
        // Clear the bar. Ignoring the exclusion zone means this window starts
        // at y=0 and would otherwise sit on top of the tray and the clock.
        margins.top: Theme.barHeight + Theme.spacing.small
        margins.right: Theme.spacing.small
        // Always mapped: a view in an unmapped window skips its add
        // transition, so the first toast used to appear without sliding in.
        // Transparent, and the mask passes input through everywhere but the
        // toasts, so an idle window costs nothing visible.
        visible: true
        implicitWidth: 420
        // A fixed column, not the height of the toasts: shrinking the window
        // as one leaves clipped it mid-slide. Input only lands on the toasts.
        implicitHeight: (screen?.height ?? 1080) - Theme.barHeight - Theme.spacing.small * 2
        mask: Region {
            item: list.contentItem
        }
        color: "transparent"

        // A ListView, not a column of Repeater items: a toast that is removed
        // from a Layout simply stops existing, and the ones under it snap up.
        // add/remove/displaced are what make that a movement instead of a jump.
        ListView {
            id: list

            anchors {
                fill: parent
                margins: Theme.padding.medium
            }
            spacing: Theme.spacing.small
            interactive: false
            model: server.trackedNotifications


            add: Transition {
                id: entrance
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.duration.expressiveDefaultEffects
                }
                NumberAnimation {
                    property: "x"
                    from: 60
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.emphasizedDecel
                }
            }

            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Theme.duration.expressiveFastEffects
                }
                NumberAnimation {
                    property: "x"
                    to: 60
                    duration: Theme.duration.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.emphasizedAccel
                }
            }

            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Theme.duration.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.standard
                }
                // Displacing a toast cancels its add transition; without these
                // it would stay half faded and off to the side for good.
                NumberAnimation {
                    properties: "opacity"
                    to: 1
                    duration: Theme.duration.expressiveFastEffects
                }
                NumberAnimation {
                    properties: "x"
                    to: 0
                    duration: Theme.duration.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.emphasizedDecel
                }
            }

            delegate: Rectangle {
                id: card

                required property Notification modelData

                // A delegate outlives its model entry: the remove transition
                // still needs it on screen after the notification is gone, so
                // every read of modelData has to survive it being null.
                // What the card shows, copied while the notification is alive:
                // the object is gone before the exit animation ends, and
                // reading it live left an empty box fading out.
                property var kept: ({})

                function keep(): void {
                    const n = card.modelData;
                    // A destroyed notification is not null, it just reads
                    // empty; copying then wiped the text mid-exit.
                    if (n && n.appName !== undefined)
                        kept = {
                            appName: n.appName,
                            summary: n.summary,
                            body: Notifs.safeBody(n.body),
                            image: n.image,
                            appIcon: n.appIcon,
                            critical: n.urgency === NotificationUrgency.Critical
                        };
                }

                Component.onCompleted: keep()
                onModelDataChanged: keep()

                readonly property bool critical: card.kept.critical ?? false
                readonly property string appIcon: card.kept.appIcon ? Quickshell.iconPath(card.kept.appIcon, true) : ""
                // Delegates are created on arrival, so this is the arrival time.
                readonly property string time: Qt.formatDateTime(new Date(), "HH:mm")
                // Clicking the body invokes the "default" action, which is
                // how an app asks to be raised on the relevant view.
                readonly property var defaultAction: card.modelData?.actions?.find(a => a.identifier === "default") ?? null

                width: list.width
                implicitHeight: body.implicitHeight + Theme.padding.large * 2
                radius: Theme.rounding.extraLarge
                // Critical reads through its summary colour and its own
                // longer timeout, not an outline.
                // See-through enough that the compositor blur behind it reads
                // as frosted glass; bgAlt was near opaque and hid it.
                color: Theme.scrim(0.45)

                HoverHandler {
                    id: hover
                }

                TapHandler {
                    onTapped: {
                        if (card.defaultAction)
                        card.defaultAction.invoke();
                        card.modelData?.dismiss();
                    }
                }

                // What the sender asked for, in ms: -1 leaves it to us, 0 means
                // never. Critical ones never expire either; that is the spec.
                readonly property real timeout: card.modelData?.expireTimeout ?? -1

                // Reading a notification should not race its own timer.
                Timer {
                    running: !hover.hovered && card.modelData !== null && !card.critical && card.timeout !== 0
                    interval: card.timeout > 0 ? card.timeout : 6000
                    onTriggered: card.modelData?.expire()
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
                            implicitSize: Theme.icon.tiny
                            source: card.appIcon
                            visible: status === Image.Ready
                        }

                        MaterialIcon {
                            visible: !icon.visible
                            text: "notifications"
                            color: Theme.dim
                            size: Theme.icon.small
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.kept.appName ?? ""
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.small
                            font.weight: Theme.weight.medium
                            font.letterSpacing: Theme.tracking.wide
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
                            size: Theme.icon.small
                            opacity: hover.hovered ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.duration.expressiveFastEffects
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: card.modelData?.dismiss()
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacing.extraSmall
                        text: card.kept.summary ?? ""
                        color: card.critical ? Theme.urgent : Theme.accentText
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontSize.larger
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: card.kept.body ?? ""
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        maximumLineCount: 6
                        elide: Text.ElideRight
                        visible: text !== ""
                        onLinkActivated: link => Notifs.openLink(link)
                    }

                    // Album art, screenshot previews, and the like.
                    ClippingRectangle {
                        Layout.topMargin: Theme.spacing.small
                        implicitWidth: Theme.control.thumbWidth
                        implicitHeight: Theme.control.thumbHeight
                        radius: Theme.rounding.medium
                        color: "transparent"
                        visible: preview.status === Image.Ready

                        Image {
                            id: preview

                            anchors.fill: parent
                            source: card.kept.image ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 240
                            sourceSize.height: 136
                        }
                    }

                    RowLayout {
                        Layout.topMargin: Theme.spacing.small
                        spacing: Theme.spacing.small
                        visible: card.modelData?.actions?.some(a => a.identifier !== "default") ?? false

                        Repeater {
                            model: card.modelData?.actions?.filter(a => a.identifier !== "default") ?? []

                            Rectangle {
                                id: action
                                required property var modelData

                                implicitWidth: label.implicitWidth + Theme.padding.large * 2
                                implicitHeight: Theme.control.field
                                radius: Theme.rounding.full
                                color: actionHover.hovered ? Theme.accent : Theme.bgTray

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
