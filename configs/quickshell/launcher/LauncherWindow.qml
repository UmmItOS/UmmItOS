pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import ".."

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
            list.currentIndex = 0;
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
    color: Qt.rgba(0, 0, 0, 0.45)

    function accept(): void {
        const item = results[list.currentIndex];
        if (!item)
            return;
        Launcher.launch(item);
    }

    // Click outside to dismiss.
    MouseArea {
        anchors.fill: parent
        onClicked: Launcher.open = false
    }

    Surface {
        anchors.centerIn: parent
        width: 620
        height: 480
        radius: Theme.rounding.extraLargeIncreased
        tone: Theme.bg
        lift: 1.12

        // Swallow clicks so they do not reach the dismiss handler.
        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id: searchRow

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.padding.large
            }
            height: 48
            radius: Theme.rounding.full
            color: "transparent"

            Surface {
                anchors.fill: parent
                radius: parent.radius
                tone: Theme.bgTray
            }

            MaterialIcon {
                id: icon
                anchors {
                    left: parent.left
                    leftMargin: Theme.padding.large
                    verticalCenter: parent.verticalCenter
                }
                text: "search"
                color: Theme.accentText
                size: Theme.icon.normal
            }

            TextInput {
                id: search

                anchors {
                    left: icon.right
                    right: count.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: Theme.spacing.medium
                    rightMargin: Theme.spacing.medium
                }
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.larger
                focus: true

                onTextChanged: {
                    win.filter = text;
                    list.currentIndex = 0;
                }

                Keys.onEscapePressed: Launcher.open = false
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onReturnPressed: win.accept()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: search.text === ""
                    text: "Search applications"
                    color: Theme.dim
                    font: search.font
                }
            }

            Text {
                id: count
                anchors {
                    right: parent.right
                    rightMargin: Theme.padding.large
                    verticalCenter: parent.verticalCenter
                }
                text: win.results.length
                color: Theme.dim
                font.family: Theme.font
                font.features: ({
                        tnum: 1
                    })
                font.pixelSize: Theme.fontSize.small
            }
        }

        ListView {
            id: list

            anchors {
                top: searchRow.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: Theme.padding.small
                leftMargin: Theme.padding.large
                rightMargin: Theme.padding.large
                bottomMargin: Theme.padding.large
            }
            clip: true
            spacing: Theme.spacing.extraSmall
            model: win.results
            currentIndex: 0
            highlightMoveDuration: Theme.duration.expressiveFastEffects

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                readonly property bool active: ListView.isCurrentItem

                width: list.width
                height: 54
                radius: Theme.rounding.full
                color: active ? Theme.bgTray : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.duration.expressiveFastEffects
                    }
                }

                IconImage {
                    id: appIcon
                    anchors {
                        left: parent.left
                        leftMargin: Theme.padding.medium
                        verticalCenter: parent.verticalCenter
                    }
                    implicitSize: Theme.icon.large
                    visible: status === Image.Ready
                    source: Quickshell.iconPath(row.modelData.icon, true)
                }

                MaterialIcon {
                    anchors.fill: appIcon
                    visible: !appIcon.visible
                    text: "widgets"
                    color: Theme.dim
                    size: Theme.icon.normal
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    anchors {
                        left: appIcon.right
                        right: parent.right
                        leftMargin: Theme.spacing.large
                        rightMargin: Theme.padding.medium
                        verticalCenter: parent.verticalCenter
                    }
                    text: row.modelData.name
                    color: row.active ? Theme.fg : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.normal
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: list.currentIndex = row.index
                    onClicked: win.accept()
                }
            }
        }
    }
}
