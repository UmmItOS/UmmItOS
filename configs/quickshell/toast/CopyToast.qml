pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import ".."

// Clipboard "Copied" pills, bottom-right.
Scope {
    id: root

    property int serial: 0

    function show(kind: string): void {
        const image = kind === "image";
        // Text and images have their own sounds, so the two are never confused.
        if (!image)
            Sounds.play("text-copied");
        else if (Date.now() - Screenshot.delivered > Theme.duration.shotCopy)
            Sounds.play("image-copied");
        // Newest at index 0, which the bottom-to-top list draws lowest.
        pills.insert(0, {
            key: ++serial,
            label: image ? "Image copied" : "Text copied",
            icon: image ? "image" : "content_copy"
        });
            if (pills.count > Theme.toast.max)
            pills.remove(Theme.toast.max, pills.count - Theme.toast.max);
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

        // Always mapped: an unmapped view skips its add transition.
        visible: true
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        WlrLayershell.namespace: "ummitos-copy-toast"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            bottom: true
            right: true
        }
        implicitWidth: Theme.toast.width + Theme.windowInset
        implicitHeight: (Theme.control.row * 2 + Theme.spacing.medium) * Theme.toast.max + Theme.windowInset + Theme.spacing.medium
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
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.emphasizedDecel
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
                    to: list.width * Theme.toast.exit
                    duration: Theme.duration.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.emphasizedAccel
                }
            }

            delegate: Item {
                id: slot

                layer.enabled: opacity < 1
                layer.effect: MotionBlur {
                    settled: slot.opacity
                }
                required property int key
                required property string label
                required property string icon

                width: list.width
                height: Theme.control.row * 2

                Timer {
                    // Held while a screenshot is being taken, so the pill can be in it.
                    running: !Screenshot.holding
                    interval: Theme.duration.extraLarge * 2
                    onTriggered: root.drop(slot.key)
                }

                Surface {
                    anchors.right: parent.right
                    width: row.implicitWidth + Theme.spacing.extraLarge * 3
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
                            textFormat: Text.PlainText
                            text: I18n.t(slot.label)
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
