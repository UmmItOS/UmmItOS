pragma ComponentBehavior: Bound

import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

OverlayWindow {
    id: win

    readonly property int inset: Theme.spacing.small
    readonly property int maxHeight: (screen?.height ?? Theme.fallbackScreen.height) - Theme.barHeight - inset * 2
    // What the list may take once the header has had its share.
    readonly property int listRoom: maxHeight - inset * 2 - Theme.spacing.large * 2 - header.implicitHeight - Theme.spacing.medium

    shown: Notifs.panelOpen
    name: "notification-panel"
    focusMode: WlrKeyboardFocus.OnDemand

    anchors.bottom: false
    anchors.left: false
    margins.top: Theme.barHeight
    implicitWidth: Theme.notification.width
    // Add back the margins, or the panel clips them.
    implicitHeight: Math.min(shell.implicitHeight + (Theme.spacing.large + inset) * 2, maxHeight)
    color: "transparent"

    // Same dismissal as the bar's flyouts: a click outside closes it.
    HyprlandFocusGrab {
        id: grab

        // The screenshot overlay takes the keyboard, which clears the grab; the panel stays for the picture.
        onCleared: if (!Screenshot.holding)
            Notifs.panelOpen = false

        windows: [win]
        active: Notifs.panelOpen
    }

    // A cleared grab stays off; arm it again once the screenshot is done, so an outside click still closes.
    Connections {
        function onHoldingChanged(): void {
            if (!Screenshot.holding && Notifs.panelOpen)
                grab.active = Qt.binding(() => Notifs.panelOpen);
        }

        target: Screenshot
    }

    Surface {
        id: sheet

        anchors {
            fill: parent
            margins: win.inset
        }

        radius: Theme.rounding.extraExtraLarge
        // Glass, like the toasts: the blur behind should show.
        tone: Theme.scrim(Theme.panelTint)
        lift: Theme.lift.sheet

        // Translate, not `x`: the anchors own x.
        opacity: Math.min(1, win.reveal)

        transform: Translate {
            x: (1 - win.reveal) * sheet.width
        }

        ColumnLayout {
            id: shell

            anchors {
                fill: parent
                margins: Theme.spacing.large
            }

            spacing: Theme.spacing.medium

            RowLayout {
                id: header

                Layout.fillWidth: true
                spacing: Theme.spacing.medium

                Text {
                    Layout.leftMargin: Theme.spacing.hair
                    text: I18n.t("Notifications")
                    color: Theme.fg

                    font {
                        family: Theme.fontDisplay
                        pixelSize: Theme.fontSize.large
                        weight: Theme.weight.bold
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Notifs.history.count === 0 ? "" : Notifs.history.count
                    color: Theme.dim

                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.smaller

                        features: ({
                                tnum: 1
                            })
                    }
                }

                // Left of both buttons, so they stay side by side.
                Text {
                    id: clearLabel

                    text: I18n.t("Clear all?")
                    color: Theme.urgent

                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.smaller
                        weight: Theme.weight.medium
                    }

                    opacity: clear.armed ? 1 : 0
                    layer.enabled: opacity < 1

                    layer.effect: MotionBlur {
                        settled: clearLabel.opacity
                    }

                    transform: Translate {
                        x: clear.armed ? 0 : Theme.spacing.large

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.duration.expressiveFastSpatial
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: clear.armed ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                            }
                        }
                    }

                    Behavior on opacity {
                        FastFade {}
                    }
                }

                // Do not disturb still records; it only stops the toast.
                Rectangle {
                    implicitWidth: Theme.control.button
                    implicitHeight: Theme.control.button
                    radius: width / 2
                    color: Notifs.dnd ? (dndHover.hovered ? Theme.accentText : Theme.accent) : Theme.bgTray
                    scale: dndTap.pressed ? Theme.pressScale : 1

                    Behavior on color {
                        FastColor {}
                    }

                    Behavior on scale {
                        PressAnim {}
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: Notifs.dnd ? "notifications_off" : "notifications_active"
                        color: Notifs.dnd ? (dndHover.hovered ? Theme.scrim(1) : Theme.accentOn) : dndHover.hovered ? Theme.accent2 : Theme.fg
                        fill: Notifs.dnd ? 1 : 0
                        size: Theme.icon.small

                        Behavior on color {
                            FastColor {}
                        }
                    }

                    HoverHandler {
                        id: dndHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: dndTap

                        onTapped: Notifs.dnd = !Notifs.dnd
                    }
                }

                // Two steps: the first click arms it, the second clears.
                Rectangle {
                    id: clear

                    property bool armed: false

                    onArmedChanged: if (armed)
                        disarm.restart()

                    implicitWidth: Theme.control.button
                    implicitHeight: Theme.control.button
                    radius: width / 2
                    color: clear.armed || clearHover.hovered ? Theme.urgent : Theme.bgTray
                    scale: clearTap.pressed ? Theme.pressScale : 1
                    visible: Notifs.history.count > 0

                    Behavior on color {
                        FastColor {}
                    }

                    Behavior on scale {
                        PressAnim {}
                    }

                    Timer {
                        id: disarm

                        onTriggered: clear.armed = false

                        interval: Theme.duration.confirmHold
                    }

                    Connections {
                        function onOpened(): void {
                            clear.armed = false;
                        }

                        target: win
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "delete_sweep"
                        color: Theme.fg
                        size: Theme.icon.small
                    }

                    HoverHandler {
                        id: clearHover

                        onHoveredChanged: if (!hovered)
                            clear.armed = false

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: clearTap

                        onTapped: {
                            if (clear.armed)
                                Notifs.clear();
                            clear.armed = !clear.armed;
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing.small
                Layout.bottomMargin: Theme.spacing.large
                horizontalAlignment: Text.AlignHCenter
                visible: Notifs.history.count === 0
                text: Notifs.dnd ? I18n.t("Nothing here. Do not disturb is on.") : I18n.t("Nothing here.")
                color: Theme.dim

                font {
                    family: Theme.font
                    pixelSize: Theme.fontSize.normal
                }
            }

            SlideList {
                Layout.fillWidth: true
                // Not fillHeight: it stretched an empty list to the bottom.
                Layout.preferredHeight: Math.min(contentHeight, win.listRoom)
                visible: Notifs.history.count > 0
                clip: true
                model: Notifs.history

                section.property: "appName"

                section.delegate: Item {
                    id: head

                    required property string section

                    readonly property int count: {
                        void Notifs.history.count;
                        let c = 0;
                        for (let i = 0; i < Notifs.history.count; i++)
                            if (Notifs.history.get(i).appName === head.section)
                                c++;
                        return c;
                    }

                    readonly property bool open: Notifs.expanded[head.section] ?? false

                    width: ListView.view.width
                    implicitHeight: headRow.implicitHeight + Theme.spacing.small

                    Row {
                        id: headRow

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacing.small
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing.small

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.PlainText
                            text: head.section + (head.count > 1 ? "  ·  " + head.count : "")
                            color: Theme.dim

                            font {
                                family: Theme.font
                                pixelSize: Theme.fontSize.smaller
                                weight: Theme.weight.medium
                                letterSpacing: Theme.tracking.wide
                            }
                        }

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: head.count > 1
                            text: "expand_more"
                            color: Theme.dim
                            size: Theme.icon.small
                            rotation: head.open ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Theme.duration.expressiveFastSpatial
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curve.standard
                                }
                            }
                        }
                    }

                    TapHandler {
                        onTapped: Notifs.toggleGroup(head.section)

                        enabled: head.count > 1
                    }
                }

                delegate: Item {
                    id: card

                    // Read with fallbacks: a delegate outlives its row while removed.
                    required property var model

                    // Collapsed groups show their newest card only.
                    readonly property bool shownInGroup: (Notifs.expanded[card.model.appName ?? ""] ?? false) || card.ListView.previousSection !== card.ListView.section

                    layer.enabled: opacity < 1

                    layer.effect: MotionBlur {
                        settled: card.opacity
                    }

                    width: ListView.view.width
                    // Height snaps: animating it re-blurred the window every frame.
                    implicitHeight: shownInGroup ? surface.implicitHeight + Theme.spacing.small : 0
                    visible: shownInGroup
                    opacity: shownInGroup ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultEffects
                        }
                    }

                    Surface {
                        id: surface

                        width: parent.width
                        implicitHeight: body.implicitHeight + Theme.spacing.large * 2
                        radius: Theme.rounding.extraLarge
                        tone: Theme.scrim(Theme.shade.card)

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
                                    source: Notifs.iconFor(card.model.appIcon ?? "")
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
                                    text: I18n.t(card.model.appName ?? "")
                                    color: Theme.dim

                                    font {
                                        family: Theme.font
                                        pixelSize: Theme.fontSize.smaller
                                        weight: Theme.weight.medium
                                        letterSpacing: Theme.tracking.wide
                                    }

                                    elide: Text.ElideRight
                                }

                                Text {
                                    textFormat: Text.PlainText
                                    text: card.model.time ?? ""
                                    color: Theme.dim

                                    font {
                                        family: Theme.font
                                        pixelSize: Theme.fontSize.small

                                        features: ({
                                                tnum: 1
                                            })
                                    }
                                }

                                MaterialIcon {
                                    text: "close"
                                    color: cardHover.hovered ? Theme.fg : Theme.dim
                                    size: Theme.icon.small

                                    Behavior on color {
                                        FastColor {}
                                    }

                                    MouseArea {
                                        onClicked: Notifs.forget(card.model.key)

                                        anchors.fill: parent
                                        anchors.margins: -Theme.hitSlop
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.spacing.extraSmall
                                textFormat: Text.PlainText
                                text: card.model.summary ?? ""
                                color: card.model.critical ? Theme.urgent : Theme.accentText

                                font {
                                    family: Theme.fontDisplay
                                    pixelSize: Theme.fontSize.larger
                                    weight: Theme.weight.bold
                                }

                                wrapMode: Text.Wrap
                            }

                            Text {
                                id: bodyText

                                // Collapsed until the body is clicked; the Binding restores "no cap".
                                property bool open: false
                                readonly property bool togglable: truncated || open

                                onLinkActivated: link => Notifs.openLink(link)

                                Layout.fillWidth: true
                                text: card.model.body ?? ""
                                color: Theme.fg

                                font {
                                    family: Theme.font
                                    pixelSize: Theme.fontSize.normal
                                }

                                textFormat: Text.StyledText
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                visible: text !== ""

                                Binding on maximumLineCount {
                                    when: !bodyText.open
                                    value: Theme.notification.collapsedLines
                                }

                                HoverHandler {
                                    cursorShape: bodyText.hoveredLink !== "" || bodyText.togglable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                }

                                TapHandler {
                                    onTapped: (point, button) => {
                                        if (bodyText.linkAt(point.position.x, point.position.y) === "")
                                            bodyText.open = !bodyText.open;
                                    }

                                    enabled: bodyText.togglable
                                }
                            }

                            // Only once loaded: the server's temporary path can be gone.
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
                                    source: card.model.image ? card.model.image : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: Theme.control.thumbWidth * 2
                                    sourceSize.height: Theme.control.thumbHeight * 2
                                }
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
}
