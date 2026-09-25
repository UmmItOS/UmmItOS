import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "../bar"
import ".."
import "../wake"

// hyprlock's layout, offset for offset.
Item {
    id: root

    // Which screen this is, for its picture of the desktop.
    required property string screenName

    function at(fraction: real): real {
        return -fraction * height;
    }

    // 0 is the desktop, 1 the lock; both ways fade.
    property real haze: 0
    property bool snapping: false

    // Hold on the desktop picture until the blur has drawn once.
    function enter(): void {
        snapping = true;
        haze = 0;
        snapping = false;
        begin.restart();
    }

    Timer {
        id: begin

        property int tries: 0

        interval: 16
        onTriggered: {
            // Two frames once the wallpaper is ready; never more than ~300ms.
            if ((wall.status !== Image.Ready && tries < 18) || tries < 2) {
                tries++;
                restart();
                return;
            }
            tries = 0;
            root.haze = 1;
        }
    }

    Component.onCompleted: enter()

    Connections {
        target: Lock

        function onUnlockingChanged(): void {
            if (Lock.unlocking)
                root.haze = 0;
        }

        function onShownChanged(): void {
            if (Lock.shown && !Lock.unlocking)
                root.enter();
        }
    }

    Behavior on haze {
        enabled: !root.snapping

        NumberAnimation {
            duration: Lock.unlocking ? Theme.duration.expressiveDefaultSpatial : Theme.duration.extraLarge
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Lock.unlocking ? Theme.curve.emphasizedAccel : Theme.curve.standardDecel
        }
    }

    Image {
        id: wall
        anchors.fill: parent
        source: Wallpapers.current ? "file://" + Wallpapers.current : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.width
        sourceSize.height: root.height
        visible: false
    }

    // hyprlock's background: light blur, some contrast, brightness 0.8.
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blurMax: 32
        blur: 0.3
        contrast: 0.08
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.2
    }

    Image {
        anchors.fill: parent
        source: Lock.shot > 0 && root.screenName !== "" ? Lock.shotOf(root.screenName) : ""
        // From the cache the lock filled before it opened: already decoded.
        cache: true
        fillMode: Image.PreserveAspectCrop
        opacity: 1 - root.haze
    }

    Item {
        anchors.fill: parent
        opacity: root.haze

        // hyprlock's per-element shadow.
        component Shade: MultiEffect {
            required property int size
            required property int passes

            shadowEnabled: true
            shadowColor: "black"
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 16
            shadowBlur: Math.min(1, size * passes / 16)
            shadowOpacity: passes > 1 ? 1 : 0.85
            shadowScale: 1.02
        }

        // Battery: the bar's own glyph and figure, plus the state in words.
        Row {
            anchors {
                top: parent.top
                right: parent.right
                margins: parent.width * 0.01
            }
            spacing: Theme.spacing.small
            layer.enabled: true
            layer.effect: Shade {
                size: 3
                passes: 2
            }

            Battery {
                id: battery
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: battery.full ? "full" : battery.charging ? "charging" : battery.pct < 0.15 ? "critical" : battery.low ? "low" : ""
                visible: text !== ""
                color: Qt.rgba(1, 1, 1, 0.8)
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.lock.battery
                font.weight: Theme.weight.bold
            }
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.at(0.15)
            text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
            color: Qt.rgba(1, 1, 1, 0.8)
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.date
            font.weight: Theme.weight.medium
            layer.enabled: true
            layer.effect: Shade {
                size: 3
                passes: 2
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.at(0.05)
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: "white"
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.clock
            font.weight: Font.Light
            layer.enabled: true
            layer.effect: Shade {
                size: 4
                passes: 2
            }
        }

        // The ring is a deliberate border, by request.
        ClippingRectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.at(-0.15)
            width: Theme.lock.avatar
            height: width
            radius: width / 2
            color: Theme.bgAlt
            border.width: Theme.lock.ring
            border.color: Qt.rgba(1, 1, 1, 0.3)
            layer.enabled: true
            layer.effect: Shade {
                size: 3
                passes: 2
            }

            Image {
                anchors.fill: parent
                // ~/.face when there is one, the bundled picture otherwise.
                source: "file://" + Quickshell.env("HOME") + "/.face"
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                onStatusChanged: {
                    if (status === Image.Error)
                        source = Qt.resolvedUrl("avatar.webp");
                }
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.at(-0.21)
            text: Quickshell.env("USER")
            color: Qt.rgba(1, 1, 1, 0.9)
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.user
            font.weight: Theme.weight.medium
            layer.enabled: true
            layer.effect: Shade {
                size: 2
                passes: 2
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.at(-0.24)
            text: "Enter your Password to unlock"
            color: Qt.rgba(1, 1, 1, 0.6)
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.hint
            layer.enabled: true
            layer.effect: Shade {
                size: 2
                passes: 1
            }
        }
    }

    // The field, outside the shadowed layer so typing is never delayed by it.
    Rectangle {
        id: field

        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.at(-0.29)
        width: parent.width * 0.15
        height: Theme.lock.field
        radius: height / 2
        opacity: root.haze * (input.text === "" && !Lock.failed && !Lock.checking ? 0 : 1)
        // hyprlock's check_color while PAM works, fail_color after a miss.
        color: Lock.checking ? Qt.rgba(212 / 255, 30 / 255, 30 / 255, 0.6) : Lock.failed ? Qt.rgba(1, 69 / 255, 69 / 255, 0.7) : Qt.rgba(1, 1, 1, 0.1)

        transform: Translate {
            id: shake
        }

        // In at once, out slowly: a slow fade-in read as lag.
        Behavior on opacity {
            NumberAnimation {
                duration: field.opacity < 0.5 ? Theme.duration.expressiveFastEffects : Theme.duration.extraLarge
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.duration.expressiveFastEffects
            }
        }

        // A wrong password shakes the field, briefly, like a head saying no.
        SequentialAnimation {
            id: no

            NumberAnimation {
                target: shake
                property: "x"
                to: Theme.spacing.medium
                duration: 50
            }
            NumberAnimation {
                target: shake
                property: "x"
                to: -Theme.spacing.medium
                duration: 90
            }
            NumberAnimation {
                target: shake
                property: "x"
                to: Theme.spacing.small
                duration: 80
            }
            NumberAnimation {
                target: shake
                property: "x"
                to: 0
                duration: 60
            }
        }

        Connections {
            target: Lock

            function onWrong(): void {
                no.restart();
            }
        }

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: Theme.padding.large
            anchors.rightMargin: Theme.padding.large
            focus: true
            echoMode: TextInput.Password
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            // Typing is drawn by the dots below.
            color: "transparent"
            font.pixelSize: Theme.fontSize.larger
            font.letterSpacing: Theme.spacing.extraSmall
            enabled: !Lock.checking
            // The dots are the whole display; focus would still draw a caret.
            cursorDelegate: Item {}

            Component.onCompleted: forceActiveFocus()

            Keys.onReturnPressed: {
                Lock.submit(text);
                text = "";
            }
            Keys.onEscapePressed: text = ""
        }

        // Never more dots than fit in the field.
        Row {
            readonly property int fits: Math.max(1, Math.floor((field.width - Theme.padding.large * 2 + spacing) / (Theme.spacing.medium + spacing)))

            anchors.centerIn: parent
            spacing: Theme.spacing.small

            Repeater {
                model: Math.min(input.text.length, parent.fits)

                Rectangle {
                    id: dot

                    width: Theme.spacing.medium
                    height: width
                    radius: width / 2
                    color: "white"
                    scale: 0

                    Component.onCompleted: scale = 1

                    Behavior on scale {
                        SpringAnimation {
                            spring: Theme.spring.stiffness
                            damping: Theme.spring.damping * 0.6
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: input.text === "" && Lock.failed
            // hyprlock's fail_text: italic, the count in bold.
            textFormat: Text.StyledText
            text: "<i>Password is incorrect <b>(" + Lock.attempts + ")</b></i>"
            color: "white"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.normal
        }
    }

    // The lock covers every layer, so it draws the wake itself.
    WakeCurtain {
        anchors.fill: parent
        dark: Wake.dark
    }
}
