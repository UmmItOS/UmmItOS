import Quickshell
import QtQuick
import QtQuick.Layouts

// The bar's dropdown, shared by Wi-Fi, Bluetooth, Volume and the tray.
PopupWindow {
    id: root

    default property alias content: body.data

    required property Item anchorItem
    property string title
    property bool busy: false
    property bool checked: false
    property bool toggleVisible: true
    // Size to the content; a scrolling list wants the fixed height.
    property bool hug: false

    signal toggled
    signal closeRequested

    anchor {
        item: root.anchorItem
        edges: Edges.Bottom
        gravity: Edges.Bottom
        margins.top: Theme.spacing.small
    }

    implicitWidth: 380
    implicitHeight: root.hug ? Math.min(head.implicitHeight + body.implicitHeight + Theme.spacing.medium + Theme.padding.large * 2, root.maxHeight) : 420
    // Never taller than the screen; long content scrolls inside.
    readonly property real maxHeight: (root.screen?.height ?? 1080) - Theme.barHeight - Theme.spacing.small * 2
    color: "transparent"

    // Not HyprlandFocusGrab: it only owns layer surfaces, not popups.
    grabFocus: true

    // The grab closes the window itself, so hand the state back.
    onVisibleChanged: {
        if (root.visible) {
            entrance.restart();
            // Kept on screen, as the compositor would slide it.
            const screenWidth = root.anchorItem.Window.width;
            const centre = root.anchorItem.mapToItem(null, root.anchorItem.width / 2, 0).x;
            const left = Math.max(0, Math.min(centre - root.implicitWidth / 2, screenWidth - root.implicitWidth));
            Notifs.flyoutLeft = left;
            Notifs.flyoutRight = left + root.implicitWidth;
            Notifs.flyout = root;
        } else {
            root.release();
            root.closeRequested();
        }
    }

    // A dropdown destroyed while open (its screen unplugged) lets go too.
    Component.onDestruction: release()

    function release(): void {
        if (Notifs.flyout === root)
            Notifs.flyout = null;
    }

    Surface {
        id: sheet

        anchors.fill: parent
        radius: Theme.rounding.extraLarge

        // Opening only: an outside click unmaps the popup at once.
        transformOrigin: Item.Top

        ParallelAnimation {
            id: entrance

            Reveal {
                opening: true
                target: sheet
                property: "opacity"
                from: 0
                to: 1
            }
            Reveal {
                opening: true
                target: sheet
                property: "scale"
                from: Theme.popScale
                to: 1
            }
        }
        tone: Theme.bg
        lift: 1.12

        ColumnLayout {
            anchors {
                fill: parent
                margins: Theme.padding.large
            }
            spacing: Theme.spacing.medium

            RowLayout {
                id: head

                Layout.fillWidth: true
                spacing: Theme.spacing.medium

                Text {
                    // A tray menu's title is the app's tooltip, any length.
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    elide: Text.ElideRight
                    text: root.title
                    color: Theme.fg
                    font {
                        family: Theme.fontDisplay
                        pixelSize: Theme.fontSize.larger
                        weight: Theme.weight.bold
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 1

                    Spinner {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.busy
                    }
                }

                Toggle {
                    visible: root.toggleVisible
                    checked: root.checked
                    onToggled: root.toggled()
                }
            }

            ColumnLayout {
                id: body

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.spacing.medium
            }
        }
    }
}
