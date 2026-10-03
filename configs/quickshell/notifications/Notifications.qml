pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import ".."

Scope {
    id: root

    // One entry per toast, so a replaced notification can leave its old toast up.
    // Card state lives here: the view destroys delegates scrolled out of it.
    property var cards: []
    property int serial: 0

    function show(n: Notification): void {
        // Once per notification: a replacement is the same object.
        if (!root.cards.some(e => e.n === n))
            n.closed.connect(() => root.cards = root.cards.filter(e => e.n !== n || e.detached));
        root.cards = root.cards.concat([{
                key: root.serial++,
                n: n,
                detached: false,
                time: Qt.formatDateTime(new Date(), "HH:mm"),
                kept: root.snapshot(n)
            }]).slice(-Theme.notification.max);
    }

    function drop(entry: var): void {
        root.cards = root.cards.filter(e => e !== entry);
    }

    // Copied while alive: the object dies before the exit ends.
    function snapshot(n: Notification): var {
        return {
            appName: n.appName,
            summary: n.summary,
            body: Notifs.safeBody(n.body),
            image: n.image,
            appIcon: n.appIcon,
            critical: n.urgency === NotificationUrgency.Critical
        };
    }

    function chime(notification: Notification): void {
        // Apps that play their own sound stay quiet.
        const app = (notification.appName || "").toLowerCase();
        const entry = (notification.desktopEntry || "").toLowerCase();
        const hints = notification.hints ?? {};
        // Vesktop sends a desktop notice only while unfocused, when Discord plays nothing itself.
        const discord = ["vesktop", "discord"].some(a => app.includes(a) || entry.includes(a));
        const ownSound = !discord && !hints["x-ummitos-chime"] && (["telegram", "telegramdesktop", "org.telegram.desktop"].some(a => app.includes(a) || entry.includes(a)) || hints["suppress-sound"] || hints["sound-file"] || hints["sound-name"]);
        const charging = app === "battery" && notification.summary === I18n.t("Charging");
        let sound = "";
        // The screenshot tool has its own shutter, like an app with its own sound.
        if (app === "screenshot")
            sound = "screenshot";
        else if (["color picker", "screen recording", "update", "wi-fi", "bluetooth"].includes(app))
            sound = "notice";
        else if (!ownSound && !charging)
            sound = "notification";
        if (sound !== "" && !Notifs.dnd)
            Sounds.play(sound);
    }

    NotificationServer {
        id: server

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        keepOnReload: false

        // Without tracked = true the notification is dropped at once.
        onNotification: notification => {
            root.chime(notification);
            // Transient notices (the update nag) show but are not kept.
            if (!notification.transient)
                Notifs.record(notification);
            notification.tracked = !Notifs.dnd;
            if (notification.tracked)
                root.show(notification);
        }
    }

    PanelWindow {
        id: toasts

        readonly property int toastWidth: Theme.notification.width
        // The toast column's edges in screen x when not stepped aside.
        readonly property real columnRight: width - Theme.spacing.medium
        readonly property real columnLeft: columnRight - toastWidth + Theme.spacing.medium * 2
        // Only for a dropdown over the column, and never off screen.
        readonly property real clearance: {
            const f = Notifs.flyout;
            // Flyout edges are in its own screen's coordinates.
            if (!f || Notifs.flyoutScreen !== (screen?.name ?? "") || Notifs.flyoutRight <= columnLeft)
                return 0;
            const needed = columnRight - Notifs.flyoutLeft + Theme.spacing.small;
            return Math.max(0, Math.min(needed, columnLeft - Theme.spacing.medium));
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
        implicitWidth: screen?.width ?? Theme.fallbackScreen.width
        // Fixed height: shrinking it clipped a toast mid-slide.
        implicitHeight: (screen?.height ?? Theme.fallbackScreen.height) - Theme.barHeight - Theme.spacing.small * 2
        // On the list itself; a contentItem region missed it moving.
        mask: Region {
            x: list.x
            y: list.y
            width: list.width
            // contentHeight lags a card that grows after arrival, so count the cards' own extent too.
            height: Math.min(list.height, Math.max(list.contentHeight, list.contentItem.childrenRect.y + list.contentItem.childrenRect.height - list.contentY))
        }
        color: "transparent"

        // A ListView, so removals animate instead of snapping.
        ListView {
            id: list

            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
                margins: Theme.spacing.medium
                rightMargin: Theme.spacing.medium + toasts.clearance
            }
            width: toasts.toastWidth - Theme.spacing.medium * 2
            spacing: Theme.spacing.small
            interactive: false

            Behavior on anchors.rightMargin {
                NumberAnimation {
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                }
            }
            model: ScriptModel {
                values: root.cards
            }

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
                    from: Theme.notification.slide
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
                    to: Theme.notification.slide
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

                layer.enabled: opacity < 1
                layer.effect: MotionBlur {
                    settled: card.opacity
                }
                required property var modelData
                // Set once a replacement moved the notification to a new toast below this one.
                property bool detached: modelData?.detached ?? false
                readonly property Notification live: detached ? null : modelData?.n ?? null
                property var kept: modelData?.kept ?? ({})
                // Closed but still sliding out: a second click or the timer must not close it again.
                property bool gone: false

                function close(expire: bool): void {
                    if (card.gone)
                        return;
                    card.gone = true;
                    if (card.detached)
                        root.drop(card.modelData);
                    else if (expire)
                        card.live?.expire();
                    else
                        card.live?.dismiss();
                }

                // A destroyed notification reads empty, not null.
                function alive(): bool {
                    return card.live !== null && card.live.appName !== undefined;
                }

                function keep(): void {
                    card.kept = card.modelData.kept = root.snapshot(card.live);
                }

                // Rebuilt after its notification closed, which dropped only the old delegate.
                Component.onCompleted: {
                    if (!card.detached && !card.alive())
                        root.drop(card.modelData);
                }

                // A new message, not a progress update, gets its own toast; this one keeps the old text.
                function changed(): void {
                    if (!card.alive())
                        return;
                    const n = card.live;
                    const progress = n.hints.value !== undefined;
                    if (!progress && (n.summary !== card.kept.summary || Notifs.safeBody(n.body) !== card.kept.body)) {
                        card.detached = card.modelData.detached = true;
                        if (!n.transient)
                            Notifs.record(n);
                        root.chime(n);
                        root.show(n);
                    } else {
                        card.keep();
                    }
                }

                // Replaced notifications update the same object in place, one field signal at a time.
                Connections {
                    target: card.live
                    ignoreUnknownSignals: true

                    function onSummaryChanged(): void {
                        Qt.callLater(card.changed);
                    }
                    function onBodyChanged(): void {
                        Qt.callLater(card.changed);
                    }
                    function onImageChanged(): void {
                        Qt.callLater(card.changed);
                    }
                    function onClosed(): void {
                        card.gone = true;
                    }
                }

                readonly property bool critical: card.kept.critical ?? false
                readonly property string appIcon: Notifs.iconFor(card.kept.appIcon ?? "")
                readonly property string time: card.modelData?.time ?? ""
                readonly property var defaultAction: card.live?.actions?.find(a => a.identifier === "default") ?? null

                width: list.width
                implicitHeight: body.implicitHeight + Theme.spacing.large * 2
                radius: Theme.rounding.extraLarge
                color: Theme.scrim(Theme.panelTint)

                HoverHandler {
                    id: hover
                }

                // Before the body, so the close button, actions and links take their own clicks.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.gone)
                            return;
                        const action = card.defaultAction;
                        action?.invoke();
                        // invoke() already closes a notification that is not resident.
                        if (!action || card.live?.resident)
                            card.close(false);
                    }
                }

                // In ms: -1 is ours to choose, 0 never expires.
                readonly property real timeout: card.live?.expireTimeout ?? -1

                // Reading a notification should not race its own timer.
                Timer {
                    running: !card.gone && !hover.hovered && !Screenshot.holding && (card.detached || card.live !== null && !card.critical && card.timeout !== 0)
                    interval: card.timeout > 0 ? card.timeout : Theme.duration.toast
                    onTriggered: card.close(true)
                }

                ColumnLayout {
                    id: body
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Theme.spacing.large
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
                            textFormat: Text.PlainText
                            text: I18n.t(card.kept.appName ?? "")
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.small
                            font.weight: Theme.weight.medium
                            font.letterSpacing: Theme.tracking.wide
                            elide: Text.ElideRight
                        }

                        Text {
                            textFormat: Text.PlainText
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
                            color: hover.hovered ? Theme.fg : Theme.dim
                            size: Theme.icon.small

                            Behavior on color {
                                FastColor {}
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Theme.hitSlop
                                onClicked: card.close(false)
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacing.extraSmall
                        textFormat: Text.PlainText
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
                        maximumLineCount: Theme.notification.lines
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
                            sourceSize.width: Theme.control.thumbWidth * 2
                            sourceSize.height: Theme.control.thumbHeight * 2
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spacing.small
                        spacing: Theme.spacing.small
                        visible: card.live?.actions?.some(a => a.identifier !== "default") ?? false

                        Repeater {
                            model: card.live?.actions?.filter(a => a.identifier !== "default") ?? []

                            Rectangle {
                                id: action
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.maximumWidth: implicitWidth
                                // Measured apart from the label, which is squeezed to this width.
                                implicitWidth: Math.ceil(measure.advanceWidth) + Theme.spacing.large * 2
                                implicitHeight: Theme.control.field
                                radius: Theme.rounding.full
                                color: actionHover.hovered ? Theme.accentText : Theme.bgTray

                                Behavior on color {
                                    FastColor {}
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
                                    width: Math.min(implicitWidth, action.width - Theme.spacing.large * 2)
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    text: action.modelData.text
                                    color: actionHover.hovered ? Theme.scrim(1) : Theme.fg
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
