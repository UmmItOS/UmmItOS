import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects

// The lock screen's look, logging in through greetd instead of unlocking.
Item {
    id: root

    // Kept current by the user's shell: the greeter user cannot read their home.
    readonly property string shared: "/var/lib/ummitos-greeter"
    property string user: ""
    // A name typed here, not read from the shared file, can be retyped after a failure.
    property bool typedUser: false
    property bool busy: false
    property string message: ""
    property string pending: ""
    property bool hasWall: false

    function submit(password: string): void {
        if (busy || password === "" || user === "")
            return;
        busy = true;
        message = "";
        pending = password;
        if (Greetd.available)
            Greetd.createSession(user);
        else
            preview.restart();
    }

    function refuse(text: string): void {
        // Only an open session: cancelling an idle one could raise an error that lands back here.
        if (Greetd.available && Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        if (typedUser) {
            user = "";
            name.forceActiveFocus();
        }
        busy = false;
        pending = "";
        message = text;
        no.restart();
    }

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

    component Power: Rectangle {
        id: power

        property string icon
        property var command

        implicitWidth: Theme.control.button
        implicitHeight: Theme.control.button
        radius: width / 2
        color: powerHover.hovered ? Theme.lock.glassStrong : Theme.lock.glass

        MaterialIcon {
            anchors.centerIn: parent
            text: power.icon
            color: "white"
        }

        HoverHandler {
            id: powerHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: Quickshell.execDetached(power.command)
        }
    }

    FileView {
        onLoaded: root.user = text().trim()

        path: root.shared + "/user"
        printErrors: false
    }

    FileView {
        onLoaded: Theme.savedAccent = text().trim()

        path: root.shared + "/accent"
        printErrors: false
    }

    // Checked first, so a fresh install without one logs no error.
    Process {
        onExited: code => root.hasWall = code === 0

        running: true
        command: ["test", "-r", root.shared + "/wallpaper"]
    }

    Connections {
        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            if (responseRequired) {
                Greetd.respond(root.pending);
                root.pending = "";
            } else if (error) {
                root.message = message;
            }
        }

        function onAuthFailure(message: string): void {
            root.refuse("Wrong password");
        }

        // UMMITOS_GREETER_SESSION swaps the session, for testing a login without a second Hyprland.
        function onReadyToLaunch(): void {
            Greetd.launch((Quickshell.env("UMMITOS_GREETER_SESSION") || "start-hyprland").split(" "));
        }

        function onError(error: string): void {
            root.refuse(error);
        }

        target: Greetd
    }

    // Outside greetd (qs -p for a look), nothing can log in.
    Timer {
        id: preview

        onTriggered: root.refuse("Preview only: greetd is not running")

        interval: Theme.duration.normal
    }

    Image {
        id: wall

        anchors.fill: parent
        source: root.hasWall ? "file://" + root.shared + "/wallpaper" : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: root.width
        sourceSize.height: root.height
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wall
        visible: wall.status === Image.Ready
        blurEnabled: true
        blurMax: Theme.lock.blurMax
        blur: Theme.lock.blur
        contrast: Theme.lock.contrast
    }

    Rectangle {
        anchors.fill: parent
        color: wall.status === Image.Ready ? "black" : Theme.bg
        opacity: wall.status === Image.Ready ? Theme.lock.veil : 1
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // One centred column, so nothing overlaps on a short screen.
    Column {
        anchors.centerIn: parent
        spacing: Theme.spacing.medium

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
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
            anchors.horizontalCenter: parent.horizontalCenter
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

        Item {
            width: 1
            height: Theme.spacing.extraLarge
        }

        // The ring is a deliberate border, as on the lock screen.
        ClippingRectangle {
            anchors.horizontalCenter: parent.horizontalCenter
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
                source: Qt.resolvedUrl("avatar.webp")
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width * 2
                sourceSize.height: height * 2
            }
        }

        // The name, or a field for one when no user has been set up yet.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.user !== ""
            textFormat: Text.PlainText
            text: root.user
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

        TextInput {
            id: name

            Keys.onReturnPressed: {
                if (text.trim() === "")
                    return;
                root.user = text.trim();
                root.typedUser = true;
                input.forceActiveFocus();
            }

            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.user === ""
            width: root.width * Theme.lock.fieldWidth
            horizontalAlignment: TextInput.AlignHCenter
            color: Theme.lock.userInk
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.user
            font.weight: Theme.weight.medium
            focus: visible

            Text {
                anchors.centerIn: parent
                visible: name.text === ""
                text: "User name"
                color: Theme.lock.placeholderInk
                font: name.font
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: root.message !== "" ? root.message : root.busy ? "Signing in…" : "Enter your password to log in"
            color: root.message !== "" ? Theme.urgent : Theme.lock.hintInk
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.hint
            layer.enabled: true

            layer.effect: Shade {
                size: Theme.lock.shadowText
                passes: 1
            }
        }

        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width * Theme.lock.fieldWidth
            height: Theme.lock.field
            radius: height / 2
            color: root.busy ? Theme.lock.glassStrong : root.message !== "" ? Theme.lock.failed : Theme.lock.glass

            transform: Translate {
                id: shake
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.duration.expressiveFastEffects
                }
            }

            // A wrong password shakes the field, like a head saying no.
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

            TextInput {
                id: input

                onTextEdited: root.message = ""

                Keys.onReturnPressed: {
                    root.submit(text);
                    text = "";
                }

                Keys.onEscapePressed: text = ""

                anchors.fill: parent
                anchors.leftMargin: Theme.spacing.large
                anchors.rightMargin: Theme.spacing.large
                focus: root.user !== ""
                echoMode: TextInput.Password
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                // Typing is drawn by the dots below.
                color: "transparent"
                cursorDelegate: Item {}
                enabled: !root.busy
            }

            // Never more dots than fit in the field.
            Row {
                readonly property int fits: Math.max(1, Math.floor((field.width - Theme.spacing.large * 2 + spacing) / (Theme.spacing.medium + spacing)))

                anchors.centerIn: parent
                spacing: Theme.spacing.small

                Repeater {
                    model: Math.min(input.text.length, parent.fits)

                    Rectangle {
                        width: Theme.spacing.medium
                        height: width
                        radius: width / 2
                        color: "white"
                    }
                }
            }
        }
    }

    Row {
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: Theme.spacing.extraLarge
        }

        spacing: Theme.spacing.medium

        Power {
            icon: "restart_alt"
            command: ["systemctl", "reboot"]
        }

        Power {
            icon: "power_settings_new"
            command: ["systemctl", "poweroff"]
        }
    }
}
