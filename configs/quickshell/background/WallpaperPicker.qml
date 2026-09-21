pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import ".."

// The wallpaper is the content, so there is no panel around it: the strip sits
// on the desktop under a gradient wash, with one metadata block anchored to the
// left. Typing replaces the wallpaper's name with the query rather than opening
// a search field, so there is no chrome until it is asked for.
PanelWindow {
    id: picker

    readonly property int focusedWidth: 420
    readonly property int focusedHeight: 236
    readonly property real shrink: 0.5

    property string filter: ""
    readonly property var shown: filter === "" ? Wallpapers.list : Wallpapers.list.filter(p => Wallpapers.name(p).toLowerCase().includes(filter.toLowerCase()))

    readonly property string focusedPath: shown[list.currentIndex] ?? ""

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
    implicitHeight: 460
    color: "transparent"

    function apply(index: int): void {
        if (index >= 0 && index < shown.length) {
            previewDebounce.stop();
            Wallpapers.set(shown[index]);
            Wallpapers.pickerOpen = false;
        }
    }

    // Enough wash to read type against any wallpaper, no edge, no card.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 0.45
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.72)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.94)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Wallpapers.pickerOpen = false
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Wallpapers.pickerOpen = false
        Keys.onLeftPressed: list.decrementCurrentIndex()
        Keys.onRightPressed: list.incrementCurrentIndex()
        Keys.onReturnPressed: picker.apply(list.currentIndex)

        // Metadata, bottom-left. The name doubles as the search field: type and
        // it becomes the query, which is why there is no separate input.
        Column {
            id: meta

            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: Theme.padding.extraLarge * 2
                bottomMargin: Theme.padding.extraLarge
            }
            spacing: Theme.spacing.extraSmall
            width: picker.width / 2

            Text {
                id: nameText

                width: parent.width
                visible: search.text === ""
                text: picker.focusedPath === "" ? "No match" : Wallpapers.name(picker.focusedPath)
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: 30
                font.bold: true
                elide: Text.ElideRight
            }

            TextInput {
                id: search

                width: parent.width
                visible: text !== ""
                color: Theme.accentText
                font.family: Theme.fontDisplay
                font.pixelSize: 30
                font.bold: true
                focus: true

                onTextChanged: {
                    picker.filter = text;
                    list.currentIndex = 0;
                }

                Keys.onEscapePressed: Wallpapers.pickerOpen = false
                Keys.onLeftPressed: list.decrementCurrentIndex()
                Keys.onRightPressed: list.incrementCurrentIndex()
                Keys.onReturnPressed: picker.apply(list.currentIndex)
            }

            Row {
                spacing: Theme.spacing.medium

                Text {
                    text: picker.shown.length === 0 ? "—" : (list.currentIndex + 1) + " of " + picker.shown.length
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    font.features: ({
                            tnum: 1
                        })
                }

                Text {
                    opacity: search.text === "" ? 1 : 0
                    text: "type to filter"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    font.weight: Theme.weight.medium
                    font.letterSpacing: Theme.tracking.wide

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }
                }
            }
        }

        PathView {
            id: list

            anchors {
                left: parent.left
                right: parent.right
                bottom: meta.top
                bottomMargin: Theme.spacing.extraLargeIncreased
            }
            height: picker.focusedHeight + 40
            model: picker.shown
            clip: true

            // PathView wraps around at both ends; ListView cannot.
            pathItemCount: Math.max(3, Math.floor(width / (picker.focusedWidth * 0.72)))
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            snapMode: PathView.SnapToItem
            movementDirection: PathView.Shortest
            highlightMoveDuration: Theme.duration.expressiveDefaultSpatial

            // Moving through the carousel previews on the desktop; Enter or a
            // click commits. Debounced so holding an arrow key does not start a
            // decode for every item passed.
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

            path: Path {
                startX: 0
                startY: list.height / 2

                PathAttribute {
                    name: "itemScale"
                    value: picker.shrink
                }
                PathAttribute {
                    name: "itemLift"
                    value: 0
                }
                PathLine {
                    x: list.width / 2
                    y: list.height / 2
                }
                PathAttribute {
                    name: "itemScale"
                    value: 1
                }
                PathAttribute {
                    name: "itemLift"
                    value: -18
                }
                PathLine {
                    x: list.width
                    y: list.height / 2
                }
                PathAttribute {
                    name: "itemScale"
                    value: picker.shrink
                }
                PathAttribute {
                    name: "itemLift"
                    value: 0
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
                y: PathView.itemLift ?? 0
                z: focused ? 1 : 0

                ClippingRectangle {
                    anchors.centerIn: parent
                    implicitWidth: picker.focusedWidth
                    implicitHeight: picker.focusedHeight
                    radius: Theme.rounding.large
                    color: "transparent"
                    opacity: cell.focused ? 1 : 0.62

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultEffects
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: "file://" + cell.modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: picker.focusedWidth
                        sourceSize.height: picker.focusedHeight
                    }

                    // The wallpaper currently applied, so you can find your way
                    // back while previewing others.
                    Rectangle {
                        anchors {
                            left: parent.left
                            bottom: parent.bottom
                            margins: Theme.padding.medium
                        }
                        visible: cell.confirmed
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: Theme.accentText
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
    }
}
