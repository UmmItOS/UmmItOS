pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import ".."

// Full-bleed grid rather than a centred panel: at this size the icons do the
// identifying, so the apps are the content and the chrome is one query line.
// Tiles are bare — only the focused one takes a surface, so the grid reads as
// content instead of a wall of buttons.
PanelWindow {
    id: win

    property string filter: ""

    readonly property var results: {
        const f = filter.toLowerCase();
        const apps = [...DesktopEntries.applications.values].filter(a => !a.noDisplay);
        // keywords and categories are lists, not strings: calling toLowerCase()
        // on one throws and takes the whole binding down, emptying the list.
        const hits = f === "" ? apps : apps.filter(a => [a.name, a.genericName ?? "", ...(a.keywords ?? [])].join(" ").toLowerCase().includes(f));
        return hits.sort((a, b) => a.name.localeCompare(b.name));
    }

    visible: Launcher.open && Launcher.mode === "apps"
    onVisibleChanged: {
        if (visible) {
            filter = "";
            search.text = "";
            grid.currentIndex = 0;
            search.forceActiveFocus();
        }
    }

    WlrLayershell.namespace: "ummitos-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.82)

    function accept(): void {
        const item = results[grid.currentIndex];
        if (item)
            Launcher.launch(item);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Launcher.open = false
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        // The query line. Oversized and left-anchored, so the eye starts at the
        // same place whether you are typing or scanning.
        ColumnLayout {
            id: head

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: Theme.padding.extraLarge * 2
                leftMargin: Theme.padding.extraLarge * 3
                rightMargin: Theme.padding.extraLarge * 3
            }
            spacing: Theme.spacing.small

            TextInput {
                id: search

                Layout.fillWidth: true
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: 54
                font.weight: Theme.weight.bold
                focus: true

                onTextChanged: {
                    win.filter = text;
                    grid.currentIndex = 0;
                }

                Keys.onEscapePressed: Launcher.open = false
                Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                Keys.onRightPressed: grid.moveCurrentIndexRight()
                Keys.onUpPressed: grid.moveCurrentIndexUp()
                Keys.onDownPressed: grid.moveCurrentIndexDown()
                Keys.onReturnPressed: win.accept()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: search.text === ""
                    text: "Search"
                    color: Theme.dim
                    font: search.font
                }
            }

            // A drawn rule that follows the query rather than a boxed input.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 2
                radius: 1
                color: search.text === "" ? Theme.bgTray : Theme.accentText

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.duration.expressiveDefaultEffects
                    }
                }
            }

            Text {
                Layout.topMargin: Theme.spacing.extraSmall
                text: win.results.length === 0 ? "Nothing matches" : win.results.length + (win.results.length === 1 ? " application" : " applications")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                font.weight: Theme.weight.medium
                font.letterSpacing: Theme.tracking.wide
            }
        }

        GridView {
            id: grid

            anchors {
                top: head.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: Theme.padding.extraLarge * 2
                leftMargin: Theme.padding.extraLarge * 3 - Theme.spacing.medium
                rightMargin: Theme.padding.extraLarge * 3 - Theme.spacing.medium
                bottomMargin: Theme.padding.extraLarge
            }
            clip: true
            cellWidth: Math.floor(width / Math.max(4, Math.floor(width / 190)))
            cellHeight: 168
            model: win.results
            currentIndex: 0
            // Keep the focused tile in view when arrowing past the fold.
            highlightMoveDuration: Theme.duration.expressiveFastEffects
            highlightRangeMode: GridView.ApplyRange
            preferredHighlightBegin: cellHeight
            preferredHighlightEnd: height - cellHeight * 2

            delegate: Item {
                id: cell
                required property var modelData
                required property int index

                readonly property bool active: GridView.isCurrentItem

                width: grid.cellWidth
                height: grid.cellHeight

                Surface {
                    anchors {
                        fill: parent
                        margins: Theme.spacing.medium
                    }
                    radius: Theme.rounding.extraLarge
                    tone: Theme.bgTray
                    opacity: cell.active ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }

                    layer.enabled: cell.active
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.accent
                        shadowBlur: 1
                        shadowOpacity: 0.5
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacing.extraLargeIncreased
                    spacing: Theme.spacing.medium

                    IconImage {
                        id: appIcon
                        Layout.alignment: Qt.AlignHCenter
                        implicitSize: 60
                        visible: status === Image.Ready
                        source: Quickshell.iconPath(cell.modelData.icon, true)
                    }

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !appIcon.visible
                        text: "widgets"
                        color: Theme.dim
                        size: 60
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        color: cell.active ? Theme.fg : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.smaller
                        font.weight: cell.active ? Theme.weight.medium : Theme.weight.regular
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }
                }

                scale: cell.active ? 1.04 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.duration.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: grid.currentIndex = cell.index
                    onClicked: win.accept()
                }
            }
        }
    }
}
