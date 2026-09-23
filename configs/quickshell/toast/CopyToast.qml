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

    function show(kind: string): void {
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

        visible: pills.count > 0 || linger.running
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        WlrLayershell.namespace: "ummitos-copy-toast"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            bottom: true
            right: true
        }
        implicitWidth: 260
        implicitHeight: (Theme.control.pill + Theme.spacing.small) * 5 + Theme.padding.large
        color: "transparent"
        mask: Region {}

        // Mapped until the last pill has finished sliding out.
        Timer {
            id: linger
            interval: Theme.duration.normal
        }

        Connections {
            target: pills

            function onCountChanged(): void {
                if (pills.count === 0)
                    linger.restart();
            }
        }

        ListView {
            id: list

            anchors {
                fill: parent
                rightMargin: Theme.padding.large
                bottomMargin: Theme.padding.large
            }
            verticalLayoutDirection: ListView.BottomToTop
            spacing: Theme.spacing.small
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
                height: Theme.control.pill

                Timer {
                    running: true
                    interval: Theme.duration.extraLarge * 2
                    onTriggered: root.drop(slot.key)
                }

                Surface {
                    anchors.right: parent.right
                    width: row.implicitWidth + Theme.padding.large * 2
                    height: parent.height
                    radius: Theme.rounding.full
                    tone: Theme.bgTray

                    Row {
                        id: row

                        anchors.centerIn: parent
                        spacing: Theme.spacing.small

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: slot.icon
                            color: Theme.accentText
                            fill: 1
                            size: Theme.icon.small
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: slot.label
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.normal
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
