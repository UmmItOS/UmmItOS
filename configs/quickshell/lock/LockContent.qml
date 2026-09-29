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

        interval: Theme.duration.frame
        onTriggered: {
            // Two frames once the wallpaper is ready; never more than ~300ms.
            if ((wall.status !== Image.Ready && tries < Theme.lock.maxFrames) || tries < Theme.lock.settleFrames) {
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
            // A lock during the unlock fade cancels it: back in.
            else if (Lock.shown)
                root.haze = 1;
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

    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blurMax: Theme.lock.blurMax
        blur: Theme.lock.blur
        contrast: Theme.lock.contrast
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: Theme.lock.veil
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
            blurMax: Theme.lock.shadowBlurMax
            shadowBlur: Math.min(1, size * passes / Theme.lock.shadowBlurMax)
            shadowOpacity: passes > 1 ? 1 : Theme.lock.shadowOpacity
            shadowScale: Theme.lock.shadowScale
        }

        // Battery: the bar's own glyph and figure, plus the state in words.
        Row {
            anchors {
                top: parent.top
                right: parent.right
                margins: parent.width * Theme.lock.margin
            }
            spacing: Theme.spacing.small
            layer.enabled: true
            layer.effect: Shade {
                size: Theme.lock.shadow
                passes: Theme.lock.shadowPasses
            }

            Battery {
                id: battery
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: battery.full ? "full" : battery.charging ? "charging" : battery.low && battery.pct < Theme.battery.critical ? "critical" : battery.low ? "low" : ""
                visible: battery.present && text !== ""
                color: Theme.lock.dateInk
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
            anchors.verticalCenterOffset: root.at(Theme.lock.dateAt)
            text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
            color: Theme.lock.dateInk
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.date
            font.weight: Theme.weight.medium
            layer.enabled: true
            layer.effect: Shade {
                size: Theme.lock.shadow
                passes: Theme.lock.shadowPasses
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.at(Theme.lock.clockAt)
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: "white"
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.clock
            font.weight: Font.Light
            layer.enabled: true
            layer.effect: Shade {
                size: Theme.lock.shadowClock
                passes: Theme.lock.shadowPasses
            }
        }

        // The ring is a deliberate border, by request.
        ClippingRectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.at(Theme.lock.avatarAt)
            width: Theme.lock.avatar
            height: width
            radius: width / 2
            color: Theme.bgAlt
            border.width: Theme.lock.ring
            border.color: Theme.lock.ringInk
            layer.enabled: true
            layer.effect: Shade {
                size: Theme.lock.shadow
                passes: Theme.lock.shadowPasses
            }

            Image {
                anchors.fill: parent
                source: Lock.face
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width * 2
                sourceSize.height: height * 2
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.at(Theme.lock.userAt)
            text: Quickshell.env("USER")
            color: Theme.lock.userInk
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.user
            font.weight: Theme.weight.medium
            layer.enabled: true
            layer.effect: Shade {
                size: Theme.lock.shadowText
                passes: Theme.lock.shadowPasses
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.at(Theme.lock.hintAt)
            text: I18n.t("Enter your password to unlock")
            color: Theme.lock.hintInk
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.hint
            layer.enabled: true
            layer.effect: Shade {
                size: Theme.lock.shadowText
                passes: 1
            }
        }
    }

    // The field, outside the shadowed layer so typing is never delayed by it.
    Rectangle {
        id: field

        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.at(Theme.lock.fieldAt)
        width: parent.width * Theme.lock.fieldWidth
        height: Theme.lock.field
        radius: height / 2
        opacity: root.haze * (input.text === "" && !Lock.failed && !Lock.checking ? 0 : 1)
        // Neutral while PAM works; red only after a miss.
        color: Lock.checking ? Theme.lock.glassStrong : Lock.failed ? Theme.lock.failed : Theme.lock.glass

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
                duration: Theme.duration.shake[0]
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.standard
            }
            NumberAnimation {
                target: shake
                property: "x"
                to: -Theme.spacing.medium
                duration: Theme.duration.shake[1]
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.standard
            }
            NumberAnimation {
                target: shake
                property: "x"
                to: Theme.spacing.small
                duration: Theme.duration.shake[2]
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.standard
            }
            NumberAnimation {
                target: shake
                property: "x"
                to: 0
                duration: Theme.duration.shake[3]
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.standard
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
                            damping: Theme.spring.dotDamping
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: input.text === "" && Lock.failed
            text: I18n.t("Wrong password · attempt %1").arg(Lock.attempts)
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
