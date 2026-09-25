pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import ".."

RowLayout {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var audio: root.sink ? root.sink.audio : null
    readonly property real level: root.audio ? root.audio.volume : 0
    readonly property bool muted: root.audio?.muted ?? false

    readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isSink && n.isStream)

    property bool popupOpen: false

    // Without a tracker the nodes' audio properties stay unbound and read empty.
    PwObjectTracker {
        objects: [...root.devices, ...root.streams]
    }

    function setVolume(value: real): void {
        if (root.audio)
            root.audio.volume = Math.max(0, Math.min(Audio.limit, value));
    }

    function glyphFor(level: real, muted: bool): string {
        if (muted)
            return "volume_off";
        if (level < 0.01)
            return "volume_mute";
        return level > 0.5 ? "volume_up" : "volume_down";
    }

    function labelFor(node: var): string {
        return node.properties["application.name"] || node.description || node.name;
    }

    // Browsers name every tab stream alike, so number them.
    function numberedLabel(node: var): string {
        const name = labelFor(node);
        const same = streams.filter(n => labelFor(n) === name);
        return same.length > 1 ? name + " " + (same.indexOf(node) + 1) : name;
    }

    // MPRIS is per app, not per stream.
    function titleFor(node: var): string {
        const name = labelFor(node).toLowerCase();
        const bin = (node.properties["application.process.binary"] || "").toLowerCase();
        const p = Mpris.players.values.find(p => (p.identity || "").toLowerCase() === name || (p.desktopEntry || "").toLowerCase() === bin);
        return p?.trackTitle ?? "";
    }

    // PipeWire rarely sets application.icon-name.
    function iconFor(node: var): string {
        const props = node.properties;
        const name = props["application.icon-name"] || props["application.process.binary"] || props["application.name"] || "";
        return name === "" ? "" : Quickshell.iconPath(name.toLowerCase(), true);
    }

    spacing: Theme.spacing.small

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        visible: root.audio
        text: root.glyphFor(root.level, root.muted)
        color: root.muted ? Theme.dim : Theme.fg
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        visible: root.audio
        text: !root.audio ? "" : root.muted ? "muted" : Math.round(root.level * 100) + " %"
        color: Theme.fg
        font {
            family: Theme.font
            pixelSize: Theme.fontSize.normal
            features: ({
                    tnum: 1
                })
        }
    }

    // Click opens the flyout; the wheel still works without opening anything.
    TapHandler {
        onTapped: root.popupOpen = !root.popupOpen
    }

    WheelHandler {
        onWheel: event => root.setVolume(root.level + (event.angleDelta.y > 0 ? 0.05 : -0.05))
    }

    Flyout {
        anchorItem: root
        visible: root.popupOpen
        title: "Audio"
        hug: true
        toggleVisible: false
        onCloseRequested: root.popupOpen = false

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.large

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Theme.control.button
                implicitHeight: Theme.control.button
                radius: width / 2
                color: root.muted ? Theme.accent : Theme.bgTray

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.duration.expressiveFastEffects
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.glyphFor(root.level, root.muted)
                    color: Theme.fg
                    fill: root.muted ? 1 : 0
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.audio)
                            root.audio.muted = !root.audio.muted;
                    }
                }
            }

            Slider {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                // The whole track is the chosen limit, not 100%.
                value: root.level / Audio.limit
                fill: root.muted ? Theme.dim : Theme.accentText
                onMoved: value => root.setVolume(value * Audio.limit)
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Theme.control.readout
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.level * 100) + " %"
                color: Theme.dim
                font {
                    family: Theme.font
                    pixelSize: Theme.fontSize.smaller
                    features: ({
                            tnum: 1
                        })
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            text: "Volume limit"
            color: Theme.dim
            font {
                family: Theme.font
                pixelSize: Theme.fontSize.small
                weight: Theme.weight.medium
                letterSpacing: Theme.tracking.wider
            }
        }

        // One choice of four: the accent pill slides to the picked one.
        Item {
            id: limits

            readonly property real cell: width / Audio.limits.length

            Layout.fillWidth: true
            implicitHeight: Theme.control.field

            Rectangle {
                anchors.fill: parent
                radius: Theme.rounding.full
                color: Theme.bgTray
            }

            Rectangle {
                width: limits.cell
                height: parent.height
                radius: Theme.rounding.full
                color: Theme.accent
                transform: Translate {
                    x: Audio.limits.indexOf(Audio.limit) * limits.cell

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.emphasized
                        }
                    }
                }
            }

            Row {
                anchors.fill: parent

                Repeater {
                    model: Audio.limits

                    Item {
                        id: choice

                        required property real modelData
                        readonly property bool picked: Audio.limit === choice.modelData

                        width: limits.cell
                        height: limits.height

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.rounding.full
                            color: Theme.glass
                            visible: choiceHover.hovered && !choice.picked
                        }

                        Text {
                            anchors.centerIn: parent
                            scale: choiceTap.pressed ? Theme.popScale : 1
                            text: Math.round(choice.modelData * 100) + "%"
                            color: choice.picked || choiceHover.hovered ? Theme.fg : Theme.dim
                            font {
                                family: Theme.font
                                pixelSize: Theme.fontSize.smaller
                                weight: choice.picked ? Theme.weight.medium : Theme.weight.regular
                                features: ({
                                        tnum: 1
                                    })
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.duration.expressiveFastEffects
                                }
                            }
                        }

                        HoverHandler {
                            id: choiceHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            id: choiceTap
                            onTapped: Audio.setLimit(choice.modelData)
                        }
                    }
                }
            }
        }

        // Output devices. Only worth showing when there is a choice to make.
        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            visible: root.devices.length > 1
            text: "Output"
            color: Theme.dim
            font {
                family: Theme.font
                pixelSize: Theme.fontSize.small
                weight: Theme.weight.medium
                letterSpacing: Theme.tracking.wider
            }
        }

        Repeater {
            model: ScriptModel {
                values: root.devices.length > 1 ? root.devices : []
            }

            Rectangle {
                id: device

                required property PwNode modelData

                readonly property bool current: device.modelData === root.sink

                Layout.fillWidth: true
                implicitHeight: Theme.control.button
                radius: Theme.rounding.large
                color: deviceHover.hovered || device.current ? Theme.bgTray : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.duration.expressiveFastEffects
                    }
                }

                HoverHandler {
                    id: deviceHover
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Theme.padding.medium
                        rightMargin: Theme.padding.medium
                    }
                    spacing: Theme.spacing.medium

                    MaterialIcon {
                        text: device.current ? "check_circle" : "speaker"
                        color: device.current ? Theme.accentText : Theme.dim
                        fill: device.current ? 1 : 0
                        size: Theme.icon.small
                    }

                    Text {
                        Layout.fillWidth: true
                        text: device.modelData.nickname || device.modelData.description
                        color: Theme.fg
                        elide: Text.ElideRight
                        font {
                            family: Theme.font
                            pixelSize: Theme.fontSize.smaller
                            weight: device.current ? Theme.weight.medium : Theme.weight.regular
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Pipewire.preferredDefaultAudioSink = device.modelData
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            visible: root.streams.length > 0
            text: "Playing"
            color: Theme.dim
            font {
                family: Theme.font
                pixelSize: Theme.fontSize.small
                weight: Theme.weight.medium
                letterSpacing: Theme.tracking.wider
            }
        }

        Repeater {
            // ScriptModel diffs, so surviving rows are kept, not rebuilt.
            model: ScriptModel {
                values: root.streams
            }

            RowLayout {
                id: stream

                required property PwNode modelData

                readonly property bool muted: stream.modelData.audio?.muted ?? false
                readonly property real level: stream.modelData.audio?.volume ?? 0

                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding.medium
                Layout.rightMargin: Theme.padding.medium
                spacing: Theme.spacing.medium

                // Recoloured to the shell; only the silhouette identifies it.
                Item {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Theme.icon.small
                    implicitHeight: Theme.icon.small

                    IconImage {
                        id: appIcon

                        anchors.fill: parent
                        source: root.iconFor(stream.modelData)
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: appIcon
                        visible: appIcon.status === Image.Ready
                        colorization: 1
                        colorizationColor: stream.muted ? Theme.dim : Theme.accentText
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: appIcon.status !== Image.Ready
                        text: stream.muted ? "volume_off" : "graphic_eq"
                        color: stream.muted ? Theme.dim : Theme.accentText
                        size: Theme.icon.small
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Theme.spacing.extraSmall
                        onClicked: stream.modelData.audio.muted = !stream.modelData.audio.muted
                    }
                }

                Column {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Theme.control.readout * 3

                    Text {
                        width: parent.width
                        text: root.numberedLabel(stream.modelData)
                        color: Theme.dim
                        elide: Text.ElideRight
                        font {
                            family: Theme.font
                            pixelSize: Theme.fontSize.smaller
                        }
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: root.titleFor(stream.modelData)
                        color: Theme.fg
                        elide: Text.ElideRight
                        font {
                            family: Theme.font
                            pixelSize: Theme.fontSize.small
                        }
                    }
                }

                Slider {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    value: stream.level
                    fill: stream.muted ? Theme.dim : Theme.accent2
                    onMoved: value => {
                        stream.modelData.audio.volume = value;
                        Osd.presentApp(root.iconFor(stream.modelData), root.labelFor(stream.modelData), value, stream.muted);
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Theme.control.readout
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(stream.level * 100) + " %"
                    color: Theme.dim
                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.smaller
                        features: ({
                                tnum: 1
                            })
                    }
                }
            }
        }
    }
}
