pragma ComponentBehavior: Bound

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
    property var keyboardRows: []
    property bool keyboardNavigation: false
    // Never taller than the screen; long content scrolls inside.
    readonly property real maxHeight: (root.screen?.height ?? Theme.fallbackScreen.height) - Theme.barHeight - Theme.spacing.small * 2

    signal toggled
    signal closeRequested

    function registerKeyboardStop(row: Item): void {
        if (!root.keyboardRows.includes(row))
            root.keyboardRows = root.keyboardRows.concat([row]);
    }

    function unregisterKeyboardStop(row: Item): void {
        root.keyboardRows = root.keyboardRows.filter(item => item !== row);
    }

    function keyboardStops(item: Item): var {
        let stops = [];
        for (const child of item.children) {
            if (!child.visible || !child.enabled)
                continue;
            if (root.keyboardRows.includes(child)) {
                if (child.keyboardActivatable)
                    stops.push(child);
            } else if (child instanceof ListView && root.keyboardRows.some(row => row.ListView.view === child)) {
                stops.push(child);
            } else if (child instanceof TextInput || child instanceof TextEdit || child.activeFocusOnTab) {
                stops.push(child);
            } else {
                stops = stops.concat(root.keyboardStops(child));
            }
        }
        return stops;
    }

    function focusStop(item: Item): void {
        root.keyboardNavigation = true;
        item.forceActiveFocus(Qt.TabFocusReason);
        // Tray menus use a Flickable instead of a ListView.
        for (let parent = item.parent; parent; parent = parent.parent) {
            if (!(parent instanceof Flickable))
                continue;
            const top = item.mapToItem(parent.contentItem, 0, 0).y;
            const bottom = top + item.height;
            if (top < parent.contentY)
                parent.contentY = top;
            else if (bottom > parent.contentY + parent.height)
                parent.contentY = bottom - parent.height;
        }
    }

    function focusListRow(view: ListView, start: int, direction: int): bool {
        for (let index = start; index >= 0 && index < view.count; index += direction) {
            // Instantiate offscreen delegates before looking for their keyboard stop.
            view.positionViewAtIndex(index, ListView.Contain);
            view.forceLayout();
            const row = view.itemAtIndex(index);
            if (row && root.keyboardRows.includes(row) && row.keyboardActivatable) {
                root.focusStop(row);
                return true;
            }
        }
        return false;
    }

    function moveFocus(direction: int): bool {
        const stops = root.keyboardStops(sheet);
        if (stops.length === 0)
            return false;
        const focused = sheet.Window.window?.activeFocusItem;
        const view = focused?.ListView.view;
        let current = stops.indexOf(focused);
        if (view && stops.includes(view)) {
            current = stops.indexOf(view);
            for (let index = 0; index < view.count; ++index) {
                if (view.itemAtIndex(index) === focused) {
                    if (root.focusListRow(view, index + direction, direction))
                        return true;
                    break;
                }
            }
        }
        if (current < 0)
            current = direction > 0 ? -1 : stops.length;
        for (let step = 1; step <= stops.length; ++step) {
            const stop = stops[(current + direction * step + stops.length) % stops.length];
            if (stop instanceof ListView) {
                if (root.focusListRow(stop, direction > 0 ? 0 : stop.count - 1, direction))
                    return true;
            } else {
                root.focusStop(stop);
                return true;
            }
        }
        return false;
    }

    function handleKey(event: var): void {
        const focused = sheet.Window.window?.activeFocusItem;
        const tab = event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab;
        // Editing keys belong to the field, including Space and unhandled arrows.
        if (!tab && (focused instanceof TextInput || focused instanceof TextEdit))
            return;
        if (tab || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            const backwards = event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (tab && (event.modifiers & Qt.ShiftModifier));
            event.accepted = root.moveFocus(backwards ? -1 : 1);
        } else if (root.keyboardRows.includes(focused) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            event.accepted = true;
            if (!event.isAutoRepeat)
                focused.activate();
        }
    }

    function release(): void {
        if (Notifs.flyout === root)
            Notifs.flyout = null;
    }

    // Same path as an outside click: users reset the flag their visible binds to; a plain visible is cleared after.
    function dismiss(): void {
        root.closeRequested();
        if (root.visible)
            root.visible = false;
    }

    // The grab closes the window itself, so hand the state back.
    onVisibleChanged: {
        root.keyboardNavigation = false;
        if (root.visible) {
            entrance.restart();
            // Kept on screen, as the compositor would slide it.
            const screenWidth = root.anchorItem.Window.width;
            const centre = root.anchorItem.mapToItem(null, root.anchorItem.width / 2, 0).x;
            const left = Math.max(0, Math.min(centre - root.implicitWidth / 2, screenWidth - root.implicitWidth));
            Notifs.flyoutLeft = left;
            Notifs.flyoutRight = left + root.implicitWidth;
            Notifs.flyoutScreen = root.anchorItem.QsWindow.window?.screen?.name ?? "";
            Notifs.flyout = root;
        } else {
            sheet.forceActiveFocus();
            root.release();
            root.closeRequested();
        }
    }

    // A dropdown destroyed while open (its screen unplugged) lets go too.
    Component.onDestruction: release()

    anchor {
        item: root.anchorItem
        edges: Edges.Bottom
        gravity: Edges.Bottom
        margins.top: Theme.spacing.small
    }

    implicitWidth: Theme.control.flyout
    implicitHeight: root.hug ? Math.min(column.implicitHeight + Theme.spacing.large * 2, root.maxHeight) : Theme.control.flyoutHeight
    color: "transparent"

    // Not HyprlandFocusGrab: it only owns layer surfaces, not popups.
    grabFocus: true

    Surface {
        id: sheet

        Keys.onEscapePressed: root.dismiss()
        Keys.onPressed: event => root.handleKey(event)

        // Focus here, not on a sibling: a text field's unhandled Escape bubbles up to this item.
        focus: true
        layer.enabled: opacity < 1

        layer.effect: MotionBlur {
            settled: sheet.opacity
        }

        anchors.fill: parent
        radius: Theme.rounding.extraLarge

        // Opening only: an outside click unmaps the popup at once.
        transformOrigin: Item.Top
        tone: Theme.bg
        lift: Theme.lift.panel

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

        ColumnLayout {
            id: column

            anchors {
                fill: parent
                margins: Theme.spacing.large
            }

            spacing: Theme.spacing.medium

            RowLayout {
                id: head

                Layout.fillWidth: true
                spacing: Theme.spacing.medium

                Text {
                    // Not fillWidth: sharing with the spinner cut short long tray titles.
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
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
                    onToggled: root.toggled()

                    visible: root.toggleVisible
                    checked: root.checked
                    keyboardFocusVisible: activeFocus && root.keyboardNavigation
                    Accessible.name: root.title
                }
            }

            ColumnLayout {
                id: body

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.spacing.medium
            }
        }

        Connections {
            // A removed or disabled row can return focus to the window, outside the sheet.
            function onActiveFocusItemChanged(): void {
                if (root.visible && sheet.Window.window.activeFocusItem === sheet.Window.window.contentItem)
                    sheet.forceActiveFocus();
            }

            target: sheet.Window.window
        }

        TapHandler {
            onPressedChanged: if (pressed)
                root.keyboardNavigation = false

            acceptedButtons: Qt.AllButtons
        }
    }
}
