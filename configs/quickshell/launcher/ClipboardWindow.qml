pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

// Clipboard entries are arbitrary content, so a row of elided single lines
// throws most of them away. Two panes instead: scan the list on the left,
// confirm the whole entry — text or the actual image — on the right.
PanelWindow {
    id: win

    property string filter: ""
    property string previewPath: ""

    readonly property var results: {
        const f = filter.toLowerCase();
        return f === "" ? Launcher.clipboard : Launcher.clipboard.filter(c => c.preview.toLowerCase().includes(f));
    }
    readonly property var focusedEntry: results[list.currentIndex] ?? null

    visible: Launcher.open && Launcher.mode === "clipboard"
    onVisibleChanged: {
        if (visible) {
            filter = "";
            search.text = "";
            list.currentIndex = 0;
            search.forceActiveFocus();
        }
    }

    // Decoding is deferred so holding a cursor key does not spawn a process
    // per entry passed.
    onFocusedEntryChanged: decodeDebounce.restart()

    Timer {
        id: decodeDebounce
        interval: 120
        onTriggered: {
            const entry = win.focusedEntry;
            win.previewPath = entry && entry.image ? Launcher.decode(entry.id) : "";
        }
    }

    WlrLayershell.namespace: "ummitos-clipboard"
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
        if (focusedEntry)
            Launcher.copy(focusedEntry.id);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Launcher.open = false
    }

    FocusScope {
        anchors.centerIn: parent
        width: 900
        height: 540
        focus: true

        Keys.onEscapePressed: Launcher.open = false

        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Left: the index. Narrow on purpose — it is for scanning, not reading.
            Rectangle {
                Layout.preferredWidth: 330
                Layout.fillHeight: true
                topLeftRadius: Theme.rounding.extraLargeIncreased
                bottomLeftRadius: Theme.rounding.extraLargeIncreased
                color: Theme.bg

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: Theme.padding.large
                    }
                    spacing: Theme.spacing.medium

                    TextInput {
                        id: search

                        Layout.fillWidth: true
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
                            text: win.results.length + " in history"
                            color: Theme.dim
                            font: search.font
                        }
                    }

                    ListView {
                        id: list

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Theme.spacing.extraSmall
                        model: win.results
                        currentIndex: 0

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index

                            readonly property bool active: ListView.isCurrentItem

                            width: list.width
                            height: 40
                            radius: Theme.rounding.medium
                            color: active ? Theme.bgTray : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.duration.expressiveFastEffects
                                }
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: Theme.padding.medium
                                    rightMargin: Theme.padding.medium
                                }
                                spacing: Theme.spacing.medium

                                MaterialIcon {
                                    text: row.modelData.image ? "image" : "notes"
                                    color: row.active ? Theme.accentText : Theme.dim
                                    size: Theme.fontSize.larger
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.image ? row.modelData.kind.toUpperCase() + "  " + row.modelData.detail : row.modelData.preview
                                    color: row.active ? Theme.fg : Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.smaller
                                    elide: Text.ElideRight
                                }
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

            // Right: the entry itself, at the size it deserves.
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                topRightRadius: Theme.rounding.extraLargeIncreased
                bottomRightRadius: Theme.rounding.extraLargeIncreased
                color: Theme.bgAlt

                Text {
                    anchors.centerIn: parent
                    visible: !win.focusedEntry
                    text: win.filter === "" ? "Clipboard is empty" : "No match"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.larger
                }

                // Image entries: the thing you actually copied.
                ClippingRectangle {
                    anchors {
                        fill: parent
                        margins: Theme.padding.extraLarge
                    }
                    visible: win.focusedEntry?.image ?? false
                    radius: Theme.rounding.large
                    color: "transparent"

                    Image {
                        anchors.fill: parent
                        source: win.previewPath === "" ? "" : "file://" + win.previewPath
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        sourceSize.width: 1100
                    }
                }

                // Text entries: the whole thing, wrapped, scrollable.
                Flickable {
                    anchors {
                        fill: parent
                        margins: Theme.padding.extraLarge
                    }
                    visible: (win.focusedEntry !== null) && !(win.focusedEntry?.image ?? false)
                    contentHeight: fullText.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Text {
                        id: fullText
                        width: parent.width
                        text: win.focusedEntry?.preview ?? ""
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                        wrapMode: Text.Wrap
                        lineHeight: 1.35
                    }
                }

                // Enter is the action; say so once instead of drawing a button.
                Text {
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        margins: Theme.padding.large
                    }
                    visible: win.focusedEntry !== null
                    text: "Enter to copy"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                }
            }
        }
    }
}
