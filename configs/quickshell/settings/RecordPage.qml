pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

// wl-screenrec's options, and the recordings they made.
ColumnLayout {
    id: page

    // The typed folder was not a full path; the hint says so until the next edit.
    property bool folderRejected: false

    spacing: Theme.spacing.large

    // A title and a hint on the left, its control on the right.
    component Setting: RowLayout {
        id: setting

        property string title
        property string hint
        property bool warn: false
        default property alias control: slot.data

        Layout.fillWidth: true
        spacing: Theme.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                textFormat: Text.PlainText
                text: setting.title
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.normal
                font.weight: Theme.weight.medium
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                textFormat: Text.PlainText
                text: setting.hint
                color: setting.warn ? Theme.urgent : Theme.dim
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.small

                Behavior on color {
                    FastColor {}
                }
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
            id: dot

            implicitWidth: Theme.spacing.medium
            implicitHeight: implicitWidth
            radius: width / 2
            color: Recorder.recording ? Theme.urgent : Theme.good

            // A halo that breathes out from the dot; scaled, never resized.
            Rectangle {
                id: halo

                anchors.fill: parent
                z: -1
                radius: width / 2
                color: dot.color

                ParallelAnimation {
                    running: Settings.open && page.visible
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: halo
                        property: "scale"
                        from: 1
                        to: Theme.pulse.haloScale
                        duration: Theme.duration.glow
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }
                    NumberAnimation {
                        target: halo
                        property: "opacity"
                        from: Theme.pulse.haloOpacity
                        to: 0
                        duration: Theme.duration.glow
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: Recorder.recording ? I18n.t("Recording · %1").arg(Recorder.elapsed(clock.date)) : I18n.t("Ready to record")
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
            label: Recorder.recording ? I18n.t("Stop and save") : I18n.t("Start recording")
            enabled: Recorder.recording || !Recorder.busy
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
            label: I18n.t("Open folder")
            onClicked: Settings.openFolder()
        }
    }

    Setting {
        title: I18n.t("Save to")
        hint: page.folderRejected ? I18n.t("Use a full path, like ~/Videos") : I18n.t("Type a folder, then Enter")
        warn: page.folderRejected

        Rectangle {
            anchors.fill: parent
            radius: Theme.rounding.full
            color: Theme.bgTray

            TextInput {
                id: folder

                anchors {
                    fill: parent
                    leftMargin: Theme.spacing.large
                    rightMargin: Theme.spacing.large
                }
                verticalAlignment: TextInput.AlignVCenter
                text: Settings.tilde(Settings.folder)
                color: Theme.fg
                selectByMouse: true
                clip: true
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                Keys.onReturnPressed: page.folderRejected = !Settings.setFolder(text)
                Keys.onEnterPressed: page.folderRejected = !Settings.setFolder(text)
                onTextEdited: page.folderRejected = false
                // Leaving the field unsaved puts the saved folder back.
                onActiveFocusChanged: if (!activeFocus) {
                    page.folderRejected = false;
                    text = Qt.binding(() => Settings.tilde(Settings.folder));
                }
            }
        }
    }

    Setting {
        title: I18n.t("Quality")
        hint: I18n.t("Higher looks sharper and makes bigger files")

        Segmented {
            anchors.fill: parent
            values: ["2 MB", "5 MB", "10 MB"]
            labels: [I18n.t("Small"), I18n.t("Balanced"), I18n.t("Sharp")]
            current: Settings.bitrate
            onPicked: value => Settings.set("bitrate", value)
        }
    }

    Setting {
        title: I18n.t("Frame rate")
        hint: I18n.t("The most frames per second it records")

        Segmented {
            anchors.fill: parent
            values: [30, 60, 120, 0]
            labels: ["30", "60", "120", I18n.t("No cap")]
            current: Settings.fps
            onPicked: value => Settings.set("fps", value)
        }
    }

    Setting {
        title: I18n.t("Codec")
        hint: I18n.t("H.264 plays everywhere; HEVC and AV1 are smaller")

        Segmented {
            anchors.fill: parent
            values: ["auto", "avc", "hevc", "av1"]
            labels: [I18n.t("Auto"), "H.264", "HEVC", "AV1"]
            current: Settings.codec
            onPicked: value => Settings.set("codec", value)
        }
    }

    Setting {
        title: I18n.t("Show the cursor")

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
            text: I18n.t("Recordings")
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
            text: I18n.t("No recordings yet")
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
                    leftMargin: Theme.spacing.medium
                    rightMargin: Theme.spacing.small
                }
                spacing: Theme.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: Qt.formatDateTime(new Date(file.modelData?.time ?? 0), I18n.t("d MMM, HH:mm"))
                        color: Theme.fg
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.smaller
                        font.weight: Theme.weight.medium
                        font.features: ({
                                tnum: 1
                            })
                    }

                    Text {
                        text: Settings.size(file.modelData?.size ?? 0)
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                        font.features: ({
                                tnum: 1
                            })
                    }
                }

                Text {
                    visible: file.confirming
                    text: I18n.t("Move to Trash?")
                    color: Theme.urgent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    font.weight: Theme.weight.medium
                }

                MaterialIcon {
                    text: "delete"
                    color: file.confirming || binHover.hovered ? Theme.urgent : Theme.dim
                    size: Theme.icon.small

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
