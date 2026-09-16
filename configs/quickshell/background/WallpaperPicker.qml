pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import ".."

PanelWindow {
    id: picker

    // Focused thumbnail; the rest scale down toward `shrink` at the edges.
    readonly property int focusedWidth: 340
    readonly property int focusedHeight: 191
    readonly property real shrink: 0.55

    property string filter: ""
    readonly property var shown: filter === "" ? Wallpapers.list : Wallpapers.list.filter(p => Wallpapers.name(p).toLowerCase().includes(filter.toLowerCase()))

    visible: Wallpapers.pickerOpen
    onVisibleChanged: {
        if (visible) {
            filter = "";
            search.text = "";
            list.currentIndex = Math.max(0, shown.indexOf(Wallpapers.actual));
            search.forceActiveFocus();
        } else {
            // Closing without pressing Enter restores the confirmed wallpaper.
            Wallpapers.clearPreview();
        }
    }

    WlrLayershell.namespace: "ummitos-wallpaper-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: 360
    color: "transparent"

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Wallpapers.pickerOpen = false
        Keys.onLeftPressed: list.decrementCurrentIndex()
        Keys.onRightPressed: list.incrementCurrentIndex()
        Keys.onReturnPressed: picker.apply(list.currentIndex)

        Rectangle {
            anchors {
                fill: parent
                leftMargin: Theme.padding.extraLarge * 4
                rightMargin: Theme.padding.extraLarge * 4
                bottomMargin: Theme.padding.largeIncreased
                topMargin: Theme.padding.small
            }
            radius: Theme.rounding.extraLargeIncreased
            color: Theme.bg
            border.color: Theme.border
            border.width: 1

            PathView {
                id: list

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: Theme.padding.largeIncreased
                }
                height: picker.focusedHeight + 54
                model: picker.shown
                clip: true

                // PathView wraps around at both ends; ListView cannot.
                pathItemCount: Math.max(3, Math.floor(width / (picker.focusedWidth + Theme.spacing.largeIncreased)))
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                snapMode: PathView.SnapToItem
                movementDirection: PathView.Shortest
                highlightMoveDuration: Theme.duration.expressiveDefaultSpatial

                // Moving through the carousel previews on the desktop; Enter or
                // a click is what actually commits it. Debounced so holding an
                // arrow key does not start a decode for every item passed.
                onCurrentIndexChanged: previewDebounce.restart()

                Timer {
                    id: previewDebounce
                    interval: 140
                    onTriggered: {
                        const path = picker.shown[list.currentIndex];
                        if (path)
                            Wallpapers.preview(path);
                    }
                }

                // Straight horizontal path; items grow as they reach the centre.
                path: Path {
                    startX: 0
                    startY: list.height / 2

                    PathAttribute {
                        name: "itemScale"
                        value: picker.shrink
                    }
                    PathLine {
                        x: list.width / 2
                        y: list.height / 2
                    }
                    PathAttribute {
                        name: "itemScale"
                        value: 1
                    }
                    PathLine {
                        x: list.width
                        y: list.height / 2
                    }
                    PathAttribute {
                        name: "itemScale"
                        value: picker.shrink
                    }
                }

                delegate: Item {
                    id: cell
                    required property string modelData
                    required property int index

                    readonly property bool focused: PathView.isCurrentItem
                    readonly property bool confirmed: modelData === Wallpapers.actual

                    width: picker.focusedWidth
                    height: list.height

                    scale: PathView.itemScale ?? picker.shrink
                    z: focused ? 1 : 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacing.small

                        ClippingRectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitWidth: picker.focusedWidth
                            implicitHeight: picker.focusedHeight
                            radius: Theme.rounding.large
                            color: "transparent"

                            Image {
                                anchors.fill: parent
                                source: "file://" + cell.modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: picker.focusedWidth
                                sourceSize.height: picker.focusedHeight
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: picker.focusedWidth
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: Wallpapers.name(cell.modelData)
                            color: cell.focused ? Theme.fg : cell.confirmed ? Theme.accent : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: cell.focused ? Theme.fontSize.normal : Theme.fontSize.small
                            font.bold: cell.focused

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.duration.expressiveDefaultEffects
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = cell.index
                        onClicked: picker.apply(cell.index)
                    }
                }
            }

            // Search row, like the filter field under caelestia's strip.
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: Theme.padding.large
                }
                height: 38
                radius: Theme.rounding.full
                color: Theme.bgAlt

                MaterialIcon {
                    id: magnifier
                    anchors {
                        left: parent.left
                        leftMargin: Theme.padding.large
                        verticalCenter: parent.verticalCenter
                    }
                    text: "search"
                    color: Theme.dim
                    size: Theme.fontSize.larger
                }

                TextInput {
                    id: search

                    anchors {
                        left: magnifier.right
                        right: clear.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: Theme.spacing.medium
                        rightMargin: Theme.spacing.medium
                    }
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    focus: true

                    onTextChanged: {
                        picker.filter = text;
                        list.currentIndex = 0;
                    }
                    Keys.onEscapePressed: Wallpapers.pickerOpen = false
                    Keys.onLeftPressed: list.decrementCurrentIndex()
                    Keys.onRightPressed: list.incrementCurrentIndex()
                    Keys.onReturnPressed: picker.apply(list.currentIndex)

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: search.text === ""
                        text: "Search wallpapers"
                        color: Theme.dim
                        font: search.font
                    }
                }

                MaterialIcon {
                    id: clear
                    anchors {
                        right: count.left
                        rightMargin: Theme.spacing.medium
                        verticalCenter: parent.verticalCenter
                    }
                    visible: search.text !== ""
                    text: "close"
                    color: Theme.dim
                    size: Theme.fontSize.larger

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: search.text = ""
                    }
                }

                Text {
                    id: count
                    anchors {
                        right: parent.right
                        rightMargin: Theme.padding.large
                        verticalCenter: parent.verticalCenter
                    }
                    text: picker.shown.length + " / " + Wallpapers.list.length
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                }
            }
        }
    }

    function apply(index: int): void {
        if (index >= 0 && index < shown.length) {
            previewDebounce.stop();
            Wallpapers.set(shown[index]);
            Wallpapers.pickerOpen = false;
        }
    }
}
