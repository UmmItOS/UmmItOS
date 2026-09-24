import Quickshell
import QtQuick
import QtQuick.Layouts

// The bar's drop-down: a titled panel hanging off a bar item, carrying a radio
// switch in its header and closing on a click anywhere outside it.
//
// Wi-Fi and Bluetooth are the same object with different contents, so the shell
// holds one of these rather than two near-identical windows.
PopupWindow {
    id: root

    default property alias content: body.data

    required property Item anchorItem
    property string title
    property bool busy: false
    property bool checked: false
    property bool toggleVisible: true
    // Size to the content instead of the default panel height. A list that
    // scrolls wants the fixed height; a stack of rows does not.
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
    implicitHeight: root.hug ? head.implicitHeight + body.implicitHeight + Theme.spacing.medium + Theme.padding.large * 2 : 420
    color: "transparent"

    // PopupWindow's own grab, not HyprlandFocusGrab: the Hyprland grab owns
    // layer surfaces, and an xdg-popup it cannot own never closes on an
    // outside click.
    grabFocus: true

    // The grab closes the window itself, which leaves the caller still thinking
    // it is open until the state is handed back.
    onVisibleChanged: {
        if (root.visible) {
            entrance.restart();
            // Centred under its item, but kept on screen the way the
            // compositor slides a popup that would overflow.
            const screenWidth = root.anchorItem.Window.width;
            const centre = root.anchorItem.mapToItem(null, root.anchorItem.width / 2, 0).x;
            const left = Math.max(0, Math.min(centre - root.implicitWidth / 2, screenWidth - root.implicitWidth));
            Notifs.flyoutLeft = left;
            Notifs.flyoutRight = left + root.implicitWidth;
            Notifs.flyoutScreen = root.anchorItem.Window.window?.screen?.name ?? "";
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

        // Drops out of the bar. Opening only: an outside click dismisses the
        // popup in the compositor, which unmaps it before anything could play.
        // Restarted from the start on every open, so a quick reopen never
        // picks up where a hidden animation left off.
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
                    text: root.title
                    color: Theme.fg
                    font {
                        family: Theme.fontDisplay
                        pixelSize: Theme.fontSize.larger
                        weight: Theme.weight.bold
                    }
                }

                // The spinner sits next to the title rather than in the list, so
                // a slow scan reads as work in progress and not as an empty box.
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
