pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

// A column down the right edge, under the bar: notifications arrive there, so
// their history belongs in the same place rather than in a centred dialog.
//
// It hugs its contents rather than running the height of the screen. An empty
// centre used to be a full-height slab with two words stranded in the middle
// of it; now it is a header and a line, and it grows as the history does.
OverlayWindow {
    id: win

    shown: Notifs.panelOpen
    name: "notification-panel"
    focusMode: WlrKeyboardFocus.OnDemand

    anchors.bottom: false
    anchors.left: false
    margins.top: Theme.barHeight
    implicitWidth: 440
    // The column reports its content only; its own anchor margins and
    // the surface inset have to be added back or the panel clips them.
    implicitHeight: Math.min(shell.implicitHeight + (Theme.padding.large + inset) * 2, maxHeight)
    color: "transparent"

    readonly property int inset: Theme.spacing.small
    readonly property int maxHeight: (screen?.height ?? 1080) - Theme.barHeight - inset * 2
    // What the list may take once the header has had its share.
    readonly property int listRoom: maxHeight - inset * 2 - Theme.padding.large * 2 - header.implicitHeight - Theme.spacing.medium

    // Same dismissal as the bar's flyouts: a click outside closes it.
    HyprlandFocusGrab {
        windows: [win]
        active: Notifs.panelOpen
        onCleared: Notifs.panelOpen = false
    }

    Surface {
        id: sheet
        anchors {
            fill: parent
            margins: win.inset
        }
        radius: Theme.rounding.extraExtraLarge
        // Glass, like the toasts: the blur behind should show.
        tone: Theme.scrim(0.45)
        lift: 1.1

        // Slides in from the edge it lives on. A translate, not `x`: the
        // anchors own `x`, so a binding on it is silently ignored.
        opacity: Math.min(1, win.reveal)
        transform: Translate {
            x: (1 - win.reveal) * sheet.width
        }

        ColumnLayout {
            id: shell
            anchors {
                fill: parent
                margins: Theme.padding.large
            }
            spacing: Theme.spacing.medium

            RowLayout {
                id: header
                Layout.fillWidth: true
                spacing: Theme.spacing.medium

                Text {
                    Layout.leftMargin: Theme.spacing.hair
                    text: "Notifications"
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

                // Do not disturb still records; it only stops the toast.
                Rectangle {
                    implicitWidth: Theme.control.button
                    implicitHeight: Theme.control.button
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
                    implicitWidth: Theme.control.button
                    implicitHeight: Theme.control.button
                    radius: width / 2
                    color: clearHover.hovered ? Theme.urgent : Theme.bgTray
                    visible: Notifs.history.count > 0

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
                Layout.topMargin: Theme.spacing.small
                Layout.bottomMargin: Theme.spacing.large
                horizontalAlignment: Text.AlignHCenter
                visible: Notifs.history.count === 0
                text: Notifs.dnd ? "Nothing here. Do not disturb is on." : "Nothing here."
                color: Theme.dim
                font {
                    family: Theme.font
                    pixelSize: Theme.fontSize.normal
                }
            }

            ListView {
                Layout.fillWidth: true
                // Tall enough for the history, never taller than the screen.
                // fillHeight would have stretched an empty list to the bottom.
                Layout.preferredHeight: Math.min(contentHeight, win.listRoom)
                visible: Notifs.history.count > 0
                clip: true
                model: Notifs.history

                // One header per app; its cards stack under it, collapsed to
                // the newest until the header is tapped.
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
                                }
                            }
                        }
                    }

                    TapHandler {
                        enabled: head.count > 1
                        onTapped: Notifs.toggleGroup(head.section)
                    }
                }
                boundsBehavior: Flickable.StopAtBounds

                // The same movement as the toasts, so a dismissed card leaves
                // and the rest close the gap instead of snapping.
                add: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.duration.expressiveDefaultEffects
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
                        to: Theme.spacing.extraLarge * 2
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
                    // A card displaced mid-entrance keeps whatever opacity the
                    // cancelled add left it at unless this finishes the job.
                    NumberAnimation {
                        property: "opacity"
                        to: 1
                        duration: Theme.duration.expressiveFastEffects
                    }
                }

                delegate: Item {
                    id: card

                    // Roles of the history ListModel. Read with a fallback: a
                    // delegate outlives its row while the remove transition plays.
                    required property var model

                    // Collapsed groups show their newest card only.
                    readonly property bool shownInGroup: (Notifs.expanded[card.model.appName ?? ""] ?? false) || card.ListView.previousSection !== card.ListView.section

                    width: ListView.view.width
                    // Height snaps and the card fades in. Animating the height
                    // resized the panel window every frame (the window hugs the
                    // list), and Hyprland re-blurring it each time was the lag.
                    // The gap under a card is its own: ListView adds its spacing
                    // after hidden (collapsed) cards too, which left a gap under
                    // a collapsed group that grew with every card in it.
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
                        implicitHeight: body.implicitHeight + Theme.padding.large * 2
                        radius: Theme.rounding.extraLarge
                        tone: Theme.scrim(0.35)

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
                                    source: card.model.appIcon ? Quickshell.iconPath(card.model.appIcon, true) : ""
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
                                    text: card.model.appName ?? ""
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
                                        onClicked: Notifs.forget(card.model.key)
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.spacing.extraSmall
                                text: card.model.summary ?? ""
                                color: card.model.critical ? Theme.urgent : Theme.accentText
                                font {
                                    family: Theme.fontDisplay
                                    pixelSize: Theme.fontSize.larger
                                    weight: Theme.weight.bold
                                }
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: card.model.body ?? ""
                                color: Theme.fg
                                font {
                                    family: Theme.font
                                    pixelSize: Theme.fontSize.normal
                                }
                                textFormat: Text.StyledText
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                visible: text !== ""
                                onLinkActivated: link => Notifs.openLink(link)
                            }

                            // The same preview the toast showed: album art, a
                            // screenshot, an avatar. Shown only once the file has
                            // actually loaded — the server hands out a temporary
                            // path, and a history entry can outlive it.
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
                                    sourceSize.width: 240
                                    sourceSize.height: 136
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
