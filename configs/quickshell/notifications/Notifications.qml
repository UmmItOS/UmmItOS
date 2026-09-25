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

        // Without tracked = true the notification is dropped at once.
        onNotification: notification => {
            // Apps that play their own sound stay quiet.
            const app = (notification.appName || "").toLowerCase();
            const entry = (notification.desktopEntry || "").toLowerCase();
            const hints = notification.hints ?? {};
            const ownSound = ["vesktop", "discord", "telegram", "telegramdesktop", "org.telegram.desktop"].some(a => app.includes(a) || entry.includes(a)) || hints["suppress-sound"] || hints["sound-file"] || hints["sound-name"];
            const charging = app === "battery" && notification.summary === "Charging";
            let sound = "";
            // The screenshot tool has its own shutter, like an app with its own sound.
            if (app === "screenshot")
                sound = "/screenshot/shutter.ogg";
            else if (["color picker", "screen recording", "update", "wi-fi", "bluetooth"].includes(app))
                sound = "/toast/pop.ogg";
            else if (!ownSound && !charging)
                sound = "/notifications/chime.ogg";
            if (sound !== "" && !Notifs.dnd)
                Quickshell.execDetached(["pw-play", Quickshell.shellDir + sound]);
            // Transient notices (the update nag) show but are not kept.
            if (!notification.transient)
                Notifs.record(notification);
            notification.tracked = !Notifs.dnd;
        }
    }

    PanelWindow {
        id: toasts

        readonly property int toastWidth: 420
        // The toast column's edges in screen x when not stepped aside.
        readonly property real columnRight: width - Theme.padding.medium
        readonly property real columnLeft: columnRight - toastWidth + Theme.padding.medium * 2
        // Only for a dropdown over the column, and never off screen.
        readonly property real clearance: {
            const f = Notifs.flyout;
            if (!f || Notifs.flyoutRight <= columnLeft)
                return 0;
            const needed = columnRight - Notifs.flyoutLeft + Theme.spacing.small;
            return Math.max(0, Math.min(needed, columnLeft - Theme.padding.medium));
        }

        WlrLayershell.namespace: "ummitos-notifications"
        anchors {
            top: true
            right: true
        }
        // Do not reserve screen space, and stay out of the way when empty.
        exclusionMode: ExclusionMode.Ignore
        margins.top: Theme.barHeight + Theme.spacing.small
        margins.right: Theme.spacing.small
        // Always mapped: an unmapped view skips its add transition.
        visible: true
        // Full width, so toasts step left without the surface moving.
        implicitWidth: screen?.width ?? 1920
        // Fixed height: shrinking it clipped a toast mid-slide.
        implicitHeight: (screen?.height ?? 1080) - Theme.barHeight - Theme.spacing.small * 2
        // On the list itself; a contentItem region missed it moving.
        mask: Region {
            x: list.x
            y: list.y
            width: list.width
            height: list.contentHeight
        }
        color: "transparent"

        // A ListView, so removals animate instead of snapping.
        ListView {
            id: list

            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
                margins: Theme.padding.medium
                rightMargin: Theme.padding.medium + toasts.clearance
            }
            width: toasts.toastWidth - Theme.padding.medium * 2
            spacing: Theme.spacing.small
            interactive: false

            Behavior on anchors.rightMargin {
                NumberAnimation {
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                }
            }
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
                // A displaced toast otherwise stays half faded.
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

                // Copied while alive: the object dies before the exit ends.
                property var kept: ({})

                function keep(): void {
                    const n = card.modelData;
                    // A destroyed notification reads empty, not null.
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

                // Replaced notifications update the same object in place.
                Connections {
                    target: card.modelData
                    ignoreUnknownSignals: true

                    function onSummaryChanged(): void {
                        card.keep();
                    }
                    function onBodyChanged(): void {
                        card.keep();
                    }
                    function onImageChanged(): void {
                        card.keep();
                    }
                }

                readonly property bool critical: card.kept.critical ?? false
                readonly property string appIcon: card.kept.appIcon ? Quickshell.iconPath(card.kept.appIcon, true) : ""
                // Delegates are created on arrival, so this is the arrival time.
                readonly property string time: Qt.formatDateTime(new Date(), "HH:mm")
                readonly property var defaultAction: card.modelData?.actions?.find(a => a.identifier === "default") ?? null

                width: list.width
                implicitHeight: body.implicitHeight + Theme.padding.large * 2
                radius: Theme.rounding.extraLarge
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

                // In ms: -1 is ours to choose, 0 never expires.
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
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacing.small
                        spacing: Theme.spacing.small
                        visible: card.modelData?.actions?.some(a => a.identifier !== "default") ?? false

                        Repeater {
                            model: card.modelData?.actions?.filter(a => a.identifier !== "default") ?? []

                            Rectangle {
                                id: action
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.maximumWidth: implicitWidth
                                // Measured apart from the label, which is squeezed to this width.
                                implicitWidth: Math.ceil(measure.advanceWidth) + Theme.padding.large * 2
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

                                TextMetrics {
                                    id: measure
                                    text: label.text
                                    font: label.font
                                }

                                Text {
                                    id: label
                                    anchors.centerIn: parent
                                    width: Math.min(implicitWidth, action.width - Theme.padding.large * 2)
                                    elide: Text.ElideRight
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
