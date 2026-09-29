pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

// Click for a random wallpaper; right-click to choose the folder it is drawn from.
BarButton {
    id: root

    property bool popupOpen: false

    icon: "wallpaper"
    onClicked: Wallpapers.setRandom()
    onRightClicked: popupOpen = !popupOpen

    Flyout {
        anchorItem: root
        visible: root.popupOpen
        title: I18n.t("Shuffle from")
        toggleVisible: false
        hug: true
        onCloseRequested: root.popupOpen = false

        ListView {
            id: list

            Layout.fillWidth: true
            implicitHeight: contentHeight
            interactive: false
            spacing: Theme.spacing.extraSmall
            // ScriptModel diffs by path, so a rescan keeps the rows that are still there.
            model: ScriptModel {
                objectProp: "path"
                values: [
                    {
                        path: "",
                        name: "",
                        depth: 0,
                        count: Wallpapers.list.length
                    }
                ].concat(Wallpapers.folders)
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
                readonly property bool all: row.modelData.path === ""

                width: list.width
                active: Wallpapers.folder === row.modelData.path
                scale: press.pressed ? Theme.pressScale : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.duration.expressiveFastEffects
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.standard
                    }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Theme.padding.medium + row.modelData.depth * Theme.spacing.large
                        rightMargin: Theme.padding.medium
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
            text: I18n.t("Click the wallpaper button to shuffle from the chosen folder.")
            wrapMode: Text.Wrap
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }
    }
}
