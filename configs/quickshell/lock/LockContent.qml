import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "../bar"
import ".."

// What the lock shows, laid out as hyprlock was: the blurred wallpaper, the
// battery top right, and a centred column of date, time, avatar, name, hint
// and password field. Each piece sits at hyprlock's offset from the centre.
Item {
    id: root

    // Which screen this is, for its picture of the desktop.
    required property string screenName

    function at(fraction: real): real {
        return -fraction * height;
    }

    // 0 is the plain wallpaper, 1 the lock. Locking runs it up (the desktop's
    // own wallpaper blurring and dimming, the text fading in); a right
    // password runs it back down before the lock lets go, so both ways are a
    // fade rather than a cut.
    property real haze: 0
    property bool snapping: false

    // Every showing starts from the plain wallpaper, including the preview,
    // whose content outlives each opening.
    function enter(): void {
        snapping = true;
        haze = 0;
        snapping = false;
        haze = 1;
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

    // hyprlock's background: a light blur (size 1, 2 passes), a little
    // contrast, and brightness 0.8 as a multiply, which is a 20% black veil.
    // Vibrancy only touched the colourful parts, so saturation is left alone.
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

    // The desktop as it was, on top, fading out as the lock comes in and back
    // in before it lets go: both ways start and end on what was on screen.
    Image {
        anchors.fill: parent
        source: Lock.shot > 0 ? Lock.shotOf(root.screenName) : ""
        cache: false
        fillMode: Image.PreserveAspectCrop
        opacity: 1 - root.haze
    }

    Item {
        anchors.fill: parent
        opacity: root.haze

        // One shadow for all the text, as hyprlock gave every label its own.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowBlur: 0.4
            shadowOpacity: 0.6
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }

        // Battery: the bar's own glyph and figure, plus the state in words.
        Row {
            anchors {
                top: parent.top
                right: parent.right
                margins: parent.width * 0.01
            }
            spacing: Theme.spacing.small

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
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.at(0.05)
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: "white"
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.clock
            font.weight: Font.Light
        }

        // The avatar keeps hyprlock's thin ring, by request: the one other
        // border in the shell besides the cheat sheet's.
        ClippingRectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.at(-0.15)
            width: Theme.lock.avatar
            height: width
            radius: width / 2
            color: Theme.bgAlt
            border.width: Theme.lock.ring
            border.color: Qt.rgba(1, 1, 1, 0.3)

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
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.at(-0.24)
            text: "Enter your Password to unlock"
            color: Qt.rgba(1, 1, 1, 0.6)
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.hint
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

        // Appears at once when typing starts, and only takes its time going
        // away again (hyprlock's fade_on_empty): a slow fade-in read as lag.
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
            // The typing is drawn by the dots below, so each can arrive with
            // its own little spring; the input itself stays invisible.
            color: "transparent"
            font.pixelSize: Theme.fontSize.larger
            font.letterSpacing: Theme.spacing.extraSmall
            enabled: !Lock.checking
            cursorVisible: false

            Component.onCompleted: forceActiveFocus()

            Keys.onReturnPressed: {
                Lock.submit(text);
                text = "";
            }
            Keys.onEscapePressed: text = ""
        }

        // One dot per character, each popping in on a spring as it is typed.
        Row {
            anchors.centerIn: parent
            spacing: Theme.spacing.small

            Repeater {
                model: input.text.length

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
            text: "Password is incorrect (" + Lock.attempts + ")"
            color: "white"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.normal
        }
    }
}
