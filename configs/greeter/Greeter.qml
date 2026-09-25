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
    property bool busy: false
    property string message: ""
    property string pending: ""

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
        busy = false;
        pending = "";
        message = text;
        no.restart();
    }

    FileView {
        path: root.shared + "/user"
        printErrors: false
        onLoaded: root.user = text().trim()
    }

    FileView {
        path: root.shared + "/accent"
        printErrors: false
        onLoaded: Theme.savedAccent = text().trim()
    }

    Connections {
        target: Greetd

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
    }

    // Outside greetd (qs -p for a look), nothing can log in.
    Timer {
        id: preview
        interval: Theme.duration.normal
        onTriggered: root.refuse("Preview only: greetd is not running")
    }

    Image {
        id: wall
        anchors.fill: parent
        source: "file://" + root.shared + "/wallpaper"
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
        blurMax: 32
        blur: 0.3
        contrast: 0.08
    }

    Rectangle {
        anchors.fill: parent
        color: wall.status === Image.Ready ? "black" : Theme.bg
        opacity: wall.status === Image.Ready ? 0.2 : 1
    }

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
            anchors.horizontalCenter: parent.horizontalCenter
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
            border.color: Qt.rgba(1, 1, 1, 0.3)
            layer.enabled: true
            layer.effect: Shade {
                size: 3
                passes: 2
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
            text: root.user
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

        TextInput {
            id: name
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.user === ""
            width: root.width * 0.15
            horizontalAlignment: TextInput.AlignHCenter
            color: Qt.rgba(1, 1, 1, 0.9)
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.user
            font.weight: Theme.weight.medium
            focus: visible
            Keys.onReturnPressed: {
                root.user = text.trim();
                input.forceActiveFocus();
            }

            Text {
                anchors.centerIn: parent
                visible: name.text === ""
                text: "User name"
                color: Qt.rgba(1, 1, 1, 0.5)
                font: name.font
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.message !== "" ? root.message : root.busy ? "Signing in…" : "Enter your password to log in"
            color: root.message !== "" ? Theme.urgent : Qt.rgba(1, 1, 1, 0.6)
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lock.hint
            layer.enabled: true
            layer.effect: Shade {
                size: 2
                passes: 1
            }
        }

        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width * 0.15
            height: Theme.lock.field
            radius: height / 2
            color: root.busy ? Qt.rgba(1, 1, 1, 0.2) : root.message !== "" ? Qt.rgba(1, 69 / 255, 69 / 255, 0.7) : Qt.rgba(1, 1, 1, 0.1)
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

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: Theme.padding.large
                anchors.rightMargin: Theme.padding.large
                focus: root.user !== ""
                echoMode: TextInput.Password
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                // Typing is drawn by the dots below.
                color: "transparent"
                cursorDelegate: Item {}
                enabled: !root.busy
                onTextEdited: root.message = ""
                Keys.onReturnPressed: {
                    root.submit(text);
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
                        width: Theme.spacing.medium
                        height: width
                        radius: width / 2
                        color: "white"
                    }
                }
            }
        }
    }

    component Power: Rectangle {
        id: power

        property string icon
        property var command

        implicitWidth: Theme.control.button
        implicitHeight: Theme.control.button
        radius: width / 2
        color: powerHover.hovered ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)

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

    Row {
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: Theme.padding.extraLarge
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
