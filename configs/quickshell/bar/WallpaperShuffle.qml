pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

// Click for a random wallpaper; right-click to choose the folder it is drawn from.
BarButton {
    id: root

    property bool popupOpen: false
    // Only a change of folder while open slides the pill, not the first placement.
    property bool settled: false

    icon: "wallpaper"
    label: "Random wallpaper · right-click to choose a folder"
    rightClickable: true
    onClicked: Wallpapers.setRandom()
    onRightClicked: popupOpen = !popupOpen
    onPopupOpenChanged: {
        if (!popupOpen)
            return;
        settled = false;
        Qt.callLater(() => {
            list.positionViewAtIndex(list.currentIndex, ListView.Contain);
            settled = true;
        });
    }

    // Says the shuffle is narrowed to one folder, without recolouring the button.
    Rectangle {
        anchors {
            top: parent.top
            right: parent.right
        }
        width: Theme.bar.badge
        height: width
        radius: width / 2
        color: Theme.accentText
        scale: Wallpapers.filtered ? 1 : 0
        opacity: Wallpapers.filtered ? 1 : 0

        Behavior on scale {
            enabled: Wallpapers.ready

            NumberAnimation {
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Wallpapers.filtered ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
            }
        }
        Behavior on opacity {
            enabled: Wallpapers.ready

            NumberAnimation {
                duration: Theme.duration.expressiveFastEffects
            }
        }
    }

    Flyout {
        anchorItem: root
        visible: root.popupOpen
        title: I18n.t("Shuffle from")
        toggleVisible: false
        hug: true
        onCloseRequested: root.popupOpen = false

        FlyoutEmpty {
            visible: Wallpapers.list.length === 0
            searching: Wallpapers.scanning
            icon: "hide_image"
            text: Wallpapers.scanning ? I18n.t("Looking for wallpapers") : I18n.t("No wallpapers in ~/.wallpaper")
        }

        ListView {
            id: list

            readonly property var rows: [
                {
                    path: "",
                    name: "",
                    depth: 0,
                    count: Wallpapers.list.length
                }
            ].concat(Wallpapers.folders)

            Layout.fillWidth: true
            // As tall as its rows; the flyout stops at the screen, and past that the list scrolls.
            Layout.fillHeight: true
            implicitHeight: contentHeight
            visible: Wallpapers.list.length > 0
            interactive: contentHeight > height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Theme.spacing.extraSmall
            // A chosen folder that is gone falls back to everything, so the pill does too.
            readonly property int chosen: Math.max(0, rows.findIndex(r => r.path === Wallpapers.folder && Wallpapers.filtered))

            // ListView shifts currentIndex on inserts before it, so set it again after each change.
            onChosenChanged: Qt.callLater(() => currentIndex = chosen)
            Component.onCompleted: currentIndex = chosen
            highlightFollowsCurrentItem: false
            // ScriptModel diffs by path, so a new scan keeps the rows that are still there.
            model: ScriptModel {
                objectProp: "path"
                values: list.rows
            }

            // One accent pill that slides to the chosen folder.
            highlight: Rectangle {
                width: list.width
                height: Theme.control.row
                radius: Theme.rounding.large
                color: Theme.accent
                y: list.currentItem?.y ?? 0

                Behavior on y {
                    enabled: root.settled

                    NumberAnimation {
                        duration: Theme.duration.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasized
                    }
                }
            }

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
            }
            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Theme.duration.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.standard
                }
            }

            delegate: FlyoutRow {
                id: row

                required property var modelData
                required property int index
                readonly property bool all: row.modelData.path === ""

                width: list.width
                active: Wallpapers.filtered ? row.modelData.path === Wallpapers.folder : row.all
                // The pill is the fill; a row only shows its hover.
                color: row.hovered && !row.active ? Theme.bgTray : "transparent"
                scale: press.pressed ? Theme.pressScale : 1

                Behavior on scale {
                    PressAnim {}
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Theme.spacing.medium + row.modelData.depth * Theme.spacing.large
                        rightMargin: Theme.spacing.medium
                    }
                    spacing: Theme.spacing.medium

                    MaterialIcon {
                        text: row.all ? "photo_library" : row.active ? "folder_open" : "folder"
                        color: row.active ? row.ink : row.inkDim
                        size: Theme.icon.small
                        fill: row.active ? 1 : 0
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.all ? I18n.t("All wallpapers") : row.modelData.name
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: row.ink
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.smaller
                        font.weight: row.active ? Theme.weight.medium : Theme.weight.regular
                    }

                    Text {
                        text: row.modelData.count
                        color: row.inkDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                        font.features: ({
                                tnum: 1
                            })
                    }
                }

                TapHandler {
                    id: press
                    onTapped: Wallpapers.setFolder(row.modelData.path)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Wallpapers.list.length > 0
            text: I18n.t("Click the wallpaper button to shuffle from the chosen folder.")
            wrapMode: Text.Wrap
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }
    }
}
