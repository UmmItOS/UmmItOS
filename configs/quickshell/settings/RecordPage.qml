pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

// wl-screenrec's options, and the recordings they made.
ColumnLayout {
    id: page

    spacing: Theme.spacing.large

    // A title and a hint on the left, its control on the right.
    component Setting: RowLayout {
        id: setting

        property string title
        property string hint
        default property alias control: slot.data

        Layout.fillWidth: true
        spacing: Theme.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: setting.title
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.normal
                font.weight: Theme.weight.medium
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: setting.hint
                color: Theme.dim
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.small
            }
        }

        Item {
            id: slot
            Layout.preferredWidth: Theme.settings.choice
            implicitHeight: Theme.control.field
        }
    }

    SystemClock {
        id: clock
        enabled: Recorder.recording
        precision: SystemClock.Seconds
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.medium

        Rectangle {
            implicitWidth: Theme.spacing.medium
            implicitHeight: implicitWidth
            radius: width / 2
            color: Recorder.recording ? Theme.urgent : Theme.good
        }

        Text {
            Layout.fillWidth: true
            text: Recorder.recording ? "Recording · " + Recorder.elapsed(clock.date) : "Ready to record"
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.larger
            font.weight: Theme.weight.bold
            font.features: ({
                    tnum: 1
                })
        }

        Action {
            primary: true
            icon: Recorder.recording ? "stop" : "radio_button_checked"
            label: Recorder.recording ? "Stop and save" : "Start recording"
            onClicked: {
                if (Recorder.recording) {
                    Recorder.stop();
                } else if (!Recorder.busy) {
                    Settings.open = false;
                    Recorder.open = true;
                }
            }
        }

        Action {
            icon: "folder_open"
            label: "Open folder"
            onClicked: Settings.openFolder()
        }
    }

    Setting {
        title: "Save to"
        hint: "Type a folder, then Enter"

        Rectangle {
            anchors.fill: parent
            radius: Theme.rounding.full
            color: Theme.bgTray

            TextInput {
                id: folder

                anchors {
                    fill: parent
                    leftMargin: Theme.padding.large
                    rightMargin: Theme.padding.large
                }
                verticalAlignment: TextInput.AlignVCenter
                text: Settings.folder.replace(Settings.home, "~")
                color: Theme.fg
                selectByMouse: true
                clip: true
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                Keys.onReturnPressed: Settings.setFolder(text)
                Keys.onEnterPressed: Settings.setFolder(text)
                // Leaving the field unsaved puts the saved folder back.
                onActiveFocusChanged: if (!activeFocus)
                    text = Qt.binding(() => Settings.folder.replace(Settings.home, "~"))
            }
        }
    }

    Setting {
        title: "Quality"
        hint: "Higher looks sharper and makes bigger files"

        Segmented {
            anchors.fill: parent
            values: ["2 MB", "5 MB", "10 MB"]
            labels: ["Small", "Balanced", "Sharp"]
            current: Settings.bitrate
            onPicked: value => Settings.set("bitrate", value)
        }
    }

    Setting {
        title: "Frame rate"
        hint: "The most frames per second it records"

        Segmented {
            anchors.fill: parent
            values: [30, 60, 120, 0]
            labels: ["30", "60", "120", "No cap"]
            current: Settings.fps
            onPicked: value => Settings.set("fps", value)
        }
    }

    Setting {
        title: "Codec"
        hint: "H.264 plays everywhere; HEVC and AV1 are smaller"

        Segmented {
            anchors.fill: parent
            values: ["auto", "avc", "hevc", "av1"]
            labels: ["Auto", "H.264", "HEVC", "AV1"]
            current: Settings.codec
            onPicked: value => Settings.set("codec", value)
        }
    }

    Setting {
        title: "Show the cursor"

        Toggle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Settings.cursor
            onToggled: Settings.set("cursor", !Settings.cursor)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacing.small

        Text {
            Layout.fillWidth: true
            text: "Recordings"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
            font.weight: Theme.weight.medium
            font.letterSpacing: Theme.tracking.wider
        }

        Text {
            text: Settings.files.length
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }
    }

    ListView {
        id: files

        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Theme.spacing.extraSmall
        boundsBehavior: Flickable.StopAtBounds
        model: Settings.files

        Text {
            anchors.centerIn: parent
            visible: files.count === 0
            text: "No recordings yet"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
        }

        delegate: FlyoutRow {
            id: file

            required property var modelData
            // The first click on the bin asks; the second moves it to the Trash.
            property bool confirming: false

            width: files.width
            onHoveredChanged: if (!hovered)
                confirming = false

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Theme.padding.medium
                    rightMargin: Theme.padding.small
                }
                spacing: Theme.spacing.medium

                MaterialIcon {
                    text: "movie"
                    color: Theme.dim
                    size: Theme.icon.small
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: file.modelData.name
                        color: Theme.fg
                        elide: Text.ElideMiddle
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.smaller
                        font.weight: Theme.weight.medium
                    }

                    Text {
                        text: Settings.size(file.modelData.size) + " · " + Qt.formatDateTime(new Date(file.modelData.time), "d MMM, HH:mm")
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                    }
                }

                Text {
                    visible: file.confirming
                    text: "Move to Trash?"
                    color: Theme.urgent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    font.weight: Theme.weight.medium
                }

                MaterialIcon {
                    text: "delete"
                    color: file.confirming || binHover.hovered ? Theme.urgent : Theme.dim
                    size: Theme.icon.small
                    opacity: file.hovered ? 1 : 0

                    HoverHandler {
                        id: binHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            if (file.confirming)
                                Settings.trash(file.modelData.path);
                            file.confirming = !file.confirming;
                        }
                    }
                }
            }

            // Both handlers see a tap on the bin; that one is the bin's alone.
            TapHandler {
                onTapped: if (!binHover.hovered)
                    Settings.openFile(file.modelData.path)
            }
        }
    }
}
