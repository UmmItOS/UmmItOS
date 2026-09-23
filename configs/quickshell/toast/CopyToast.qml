import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import ".."

// "Copied" confirmations for the clipboard watcher, stacked in the bottom-
// right corner: each new one slides in at the bottom and pushes the ones
// before it up a slot; each leaves on its own after a moment. Replaces
// hyprctl notify, whose box cannot be placed or animated.
Scope {
    id: root

    property int serial: 0

    // The shell's own chime for small notices: an original two-note pop,
    // distinct from the charging chime (toast/pop.ogg).
    function pop(): void {
        Quickshell.execDetached(["pw-play", Qt.resolvedUrl("pop.ogg").toString().replace("file://", "")]);
    }

    function show(kind: string): void {
        pop();
        const image = kind === "image";
        // Newest at index 0, which the bottom-to-top list draws lowest.
        pills.insert(0, {
            key: ++serial,
            label: image ? "Image copied" : "Text copied",
            icon: image ? "image" : "content_copy"
        });
        // A burst of copies should not climb up the whole screen.
        if (pills.count > 5)
            pills.remove(5, pills.count - 5);
    }

    function drop(key: int): void {
        for (let i = 0; i < pills.count; i++) {
            if (pills.get(i).key === key)
                return pills.remove(i);
        }
    }

    ListModel {
        id: pills
    }

    PanelWindow {
        id: win

        // Always mapped: a view in an unmapped window skips its add
        // transition, so pills appeared without sliding in. Transparent and
        // input-free, so idle it shows nothing.
        visible: true
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        WlrLayershell.namespace: "ummitos-copy-toast"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            bottom: true
            right: true
        }
        implicitWidth: 620 + Theme.windowInset
        implicitHeight: (Theme.control.row * 2 + Theme.spacing.medium) * 5 + Theme.windowInset + Theme.spacing.medium
        color: "transparent"
        mask: Region {}

        ListView {
            id: list

            anchors {
                fill: parent
                // Inside the window border, not on top of it.
                rightMargin: Theme.windowInset + Theme.spacing.medium
                bottomMargin: Theme.windowInset + Theme.spacing.medium
            }
            verticalLayoutDirection: ListView.BottomToTop
            spacing: Theme.spacing.medium
            interactive: false
            model: pills

            add: Transition {
                NumberAnimation {
                    property: "x"
                    from: list.width
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.emphasizedDecel
                }
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.duration.expressiveDefaultEffects
                }
            }
            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Theme.duration.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.standard
                }
                // Finish an entrance that the push interrupted.
                NumberAnimation {
                    property: "x"
                    to: 0
                    duration: Theme.duration.expressiveFastSpatial
                }
                NumberAnimation {
                    property: "opacity"
                    to: 1
                    duration: Theme.duration.expressiveFastEffects
                }
            }
            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Theme.duration.normal
                }
                NumberAnimation {
                    property: "x"
                    to: list.width / 3
                    duration: Theme.duration.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.emphasizedAccel
                }
            }

            delegate: Item {
                id: slot

                required property int key
                required property string label
                required property string icon

                width: list.width
                height: Theme.control.row * 2

                Timer {
                    running: true
                    interval: Theme.duration.extraLarge * 2
                    onTriggered: root.drop(slot.key)
                }

                Surface {
                    anchors.right: parent.right
                    width: row.implicitWidth + Theme.padding.extraLarge * 3
                    height: parent.height
                    radius: Theme.rounding.full
                    tone: Theme.bgTray

                    Row {
                        id: row

                        anchors.centerIn: parent
                        spacing: Theme.spacing.medium

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: slot.icon
                            color: Theme.accentText
                            fill: 1
                            size: Theme.icon.extraLarge
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: slot.label
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.extraLarge
                            font.weight: Theme.weight.medium
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "copied"

        function text(): void {
            root.show("text");
        }

        function image(): void {
            root.show("image");
        }
    }
}
