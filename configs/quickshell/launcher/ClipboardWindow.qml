pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

OverlayWindow {
    id: win

    property string filter: ""

    readonly property var results: {
        const f = filter.toLowerCase();
        return f === "" ? Launcher.clipboard : Launcher.clipboard.filter(c => c.preview.toLowerCase().includes(f));
    }

    readonly property var focusedEntry: results[list.currentIndex] ?? null

    function accept(): void {
        if (focusedEntry)
            Launcher.copy(focusedEntry.id);
    }

    onOpened: {
        filter = "";
        search.text = "";
        list.currentIndex = 0;
        search.forceActiveFocus();
    }

    // Deferred so a held key does not decode every entry.
    onFocusedEntryChanged: decodeDebounce.restart()

    shown: Launcher.open && Launcher.mode === "clipboard"
    name: "clipboard"
    scrim: Theme.shade.light

    Timer {
        id: decodeDebounce

        onTriggered: {
            const entry = win.focusedEntry;
            if (entry && entry.image)
                Launcher.decode(entry.id);
            else if (entry)
                Launcher.decodeText(entry.id);
            else
                Launcher.clearDecode();
        }

        interval: Theme.duration.decodeDebounce
    }

    MouseArea {
        onClicked: Launcher.open = false

        anchors.fill: parent
    }

    FocusScope {
        Keys.onEscapePressed: Launcher.open = false

        anchors.centerIn: parent
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        width: Theme.clipboard.width
        height: Theme.clipboard.height
        focus: true

        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Left: the index. Narrow on purpose — it is for scanning, not reading.
            Rectangle {
                Layout.preferredWidth: Theme.clipboard.index
                Layout.fillHeight: true
                topLeftRadius: Theme.rounding.extraLarge
                bottomLeftRadius: Theme.rounding.extraLarge

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.lighter(Theme.bg, Theme.lift.panel)
                    }

                    GradientStop {
                        position: Theme.lift.reach
                        color: Theme.bg
                    }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: Theme.spacing.large
                    }

                    spacing: Theme.spacing.medium

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Theme.control.pill
                        radius: Theme.rounding.full
                        color: "transparent"

                        Surface {
                            anchors.fill: parent
                            radius: parent.radius
                            tone: Theme.bgTray
                        }

                        TextInput {
                            id: search

                            onTextChanged: {
                                win.filter = text;
                                list.currentIndex = 0;
                            }

                            Keys.onEscapePressed: Launcher.open = false
                            Keys.onUpPressed: list.decrementCurrentIndex()
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            Keys.onReturnPressed: win.accept()

                            anchors {
                                fill: parent
                                leftMargin: Theme.spacing.large
                                rightMargin: Theme.spacing.large
                            }

                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.normal
                            focus: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: search.text === ""
                                text: I18n.t("%1 in history").arg(win.results.length)
                                color: Theme.dim
                                font: search.font
                            }
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
                            height: Theme.control.row
                            radius: Theme.rounding.full
                            color: active ? Theme.bgTray : "transparent"

                            Behavior on color {
                                FastColor {}
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: Theme.spacing.medium
                                    rightMargin: Theme.spacing.medium
                                }

                                spacing: Theme.spacing.medium

                                MaterialIcon {
                                    text: row.modelData.image ? "image" : "notes"
                                    color: row.active ? Theme.accentText : Theme.dim
                                    size: Theme.icon.normal
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.PlainText
                                    text: row.modelData.image ? row.modelData.kind.toUpperCase() + "  " + row.modelData.detail : row.modelData.preview
                                    color: row.active ? Theme.fg : Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.smaller
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                onPositionChanged: mouse => {
                                    if (win.pointerMoved(this, mouse.x, mouse.y))
                                        list.currentIndex = row.index;
                                }

                                onClicked: {
                                    list.currentIndex = row.index;
                                    win.accept();
                                }

                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                }
            }

            // Right: the entry itself, at the size it deserves.
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                topRightRadius: Theme.rounding.extraLarge
                bottomRightRadius: Theme.rounding.extraLarge
                color: Theme.bgAlt

                Text {
                    anchors.centerIn: parent
                    visible: !win.focusedEntry
                    text: win.filter === "" ? I18n.t("Clipboard is empty") : I18n.t("No match")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.larger
                }

                // Image entries: the thing you actually copied.
                ClippingRectangle {
                    anchors {
                        fill: parent
                        margins: Theme.spacing.extraLarge
                    }

                    visible: win.focusedEntry?.image ?? false
                    radius: Theme.rounding.large
                    color: "transparent"

                    Image {
                        anchors.fill: parent
                        source: Launcher.decodedPath === "" ? "" : "file://" + Launcher.decodedPath
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        sourceSize.width: Theme.clipboard.decode
                    }
                }

                // Text entries: the whole thing, wrapped, scrollable.
                Flickable {
                    anchors {
                        fill: parent
                        margins: Theme.spacing.extraLarge
                    }

                    visible: (win.focusedEntry !== null) && !(win.focusedEntry?.image ?? false)
                    contentHeight: fullText.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Text {
                        id: fullText

                        width: parent.width
                        // The list's preview is cut and collapsed; it stands in until the full text lands.
                        textFormat: Text.PlainText
                        text: Launcher.decodedTextId !== "" && Launcher.decodedTextId === win.focusedEntry?.id ? Launcher.decodedText : win.focusedEntry?.preview ?? ""
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                        wrapMode: Text.Wrap
                        lineHeight: Theme.clipboard.lineHeight
                    }
                }

                // Enter is the action; say so once instead of drawing a button.
                Text {
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        margins: Theme.spacing.large
                    }

                    visible: win.focusedEntry !== null
                    text: I18n.t("Enter to copy")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                }
            }
        }
    }
}
