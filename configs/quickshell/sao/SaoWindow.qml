pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import ".."

// The SAO menu: round buttons drop down the left side; Profile and Skills swing a card open beside them,
// Logout flips down the anime's ○ / × dialog. Its look is Sword Art Online's, apart from the shell's on purpose.
OverlayWindow {
    id: win

    readonly property int slot: Theme.sao.button + (Theme.sao.ringGap + Theme.sao.ring) * 2
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: (battery?.isLaptopBattery ?? false) && (battery?.isPresent ?? false)
    readonly property real hp: hasBattery ? battery.percentage : 1
    readonly property real mp: SysInfo.memTotal > 0 ? 1 - SysInfo.memRatio : 0
    // The last card shown, kept while it swings shut.
    property string shownCard: ""

    // Latin in the anime's Rationale; anything past it (Chinese) in the CJK face.
    function family(text: string): string {
        return /[^\u0000-ɏ]/.test(text) ? Theme.fontCjk : rationale.name;
    }

    // Enter acts once per press: a held key must never repeat into the dialog's ○.
    function enter(event: var): void {
        event.accepted = true;
        if (event.isAutoRepeat)
            return;
        if (!Sao.asking)
            Sao.pick(Sao.selected);
        else if (dialog.reveal === 1)
            Sao.answer();
    }

    onOpened: stage.forceActiveFocus()

    shown: Sao.open
    name: "sao"
    screen: Sao.screen

    // A labelled bar in the anime's HP style: the fill scales, it is never resized.
    component Gauge: Column {
        id: gauge

        property string title
        property real ratio
        property color tint
        property string readout
        // Off until the first sample, so the bar does not sweep down from an empty default.
        property bool ready: true

        width: parent.width
        spacing: Theme.spacing.extraSmall

        Row {
            width: parent.width

            Text {
                width: parent.width / 2
                textFormat: Text.PlainText
                text: gauge.title
                color: Theme.sao.inkDeep
                font.family: rationale.name
                font.pixelSize: Theme.fontSize.larger
                font.letterSpacing: Theme.tracking.wider
            }

            Text {
                width: parent.width / 2
                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
                text: gauge.readout
                color: Theme.sao.inkDeep
                font.family: win.family(text)
                font.pixelSize: Theme.fontSize.larger
            }
        }

        Rectangle {
            width: parent.width
            height: Theme.sao.bar
            radius: height / 2
            color: Theme.sao.inkDeep

            Rectangle {
                width: parent.width
                height: parent.height
                radius: height / 2
                color: gauge.tint

                transform: Scale {
                    xScale: gauge.ready ? Math.max(0, Math.min(1, gauge.ratio)) : 0

                    Behavior on xScale {
                        enabled: gauge.ready

                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.emphasizedDecel
                        }
                    }
                }

                Behavior on color {
                    FastColor {}
                }
            }
        }
    }

    // The dialog's round ○ / × buttons; the focused one wears a ring in its colour.
    component Choice: Item {
        id: choice

        property color tint
        property bool focused: false
        signal chosen
        signal hovered

        width: Theme.sao.choice + (Theme.sao.choiceRing + Theme.sao.ring) * 2
        height: width

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Theme.sao.ring
            border.color: choice.tint
            opacity: choice.focused ? 1 : 0

            Behavior on opacity {
                FastFade {}
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Theme.sao.choice
            height: Theme.sao.choice
            radius: width / 2
            color: choice.tint
            scale: choiceTap.pressed ? Theme.pressScale : 1

            Behavior on scale {
                PressAnim {}
            }
        }

        // Movement, not entry: the dialog flips in under a resting pointer, which must not move the focus to ○.
        HoverHandler {
            onPointChanged: if (win.pointerMoved(choice, point.position.x, point.position.y))
                choice.hovered()

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: choiceTap

            onTapped: choice.chosen()
        }
    }

    FontLoader {
        id: rationale

        source: Qt.resolvedUrl("Rationale-Regular.ttf")
    }

    // Polling runs only while the Profile card shows the numbers.
    Binding {
        target: SysInfo
        property: "onProfile"
        value: win.visible && Sao.card === "profile"
    }

    Connections {
        function onCardChanged(): void {
            if (Sao.card !== "")
                win.shownCard = Sao.card;
        }

        target: Sao
    }

    // A click on nothing backs out one step.
    MouseArea {
        onClicked: {
            if (Sao.asking)
                Sao.asking = false;
            else
                Sao.open = false;
        }

        anchors.fill: parent
    }

    Item {
        id: stage

        Keys.onUpPressed: if (!Sao.asking)
            Sao.select((Sao.selected + Sao.items.length - 1) % Sao.items.length)

        Keys.onDownPressed: if (!Sao.asking)
            Sao.select((Sao.selected + 1) % Sao.items.length)

        Keys.onLeftPressed: {
            if (Sao.asking)
                Sao.choice = 0;
            else
                Sao.card = "";
        }

        // Right opens a card; it never runs an action the way Enter does.
        Keys.onRightPressed: {
            if (Sao.asking)
                Sao.choice = 1;
            else if (["profile", "skills"].includes(Sao.items[Sao.selected].id) && Sao.card !== Sao.items[Sao.selected].id)
                Sao.pick(Sao.selected);
        }

        Keys.onReturnPressed: event => win.enter(event)
        Keys.onEnterPressed: event => win.enter(event)

        Keys.onEscapePressed: {
            if (Sao.asking)
                Sao.asking = false;
            else if (Sao.card !== "")
                Sao.card = "";
            else
                Sao.open = false;
        }

        anchors.fill: parent
        focus: true

        Column {
            id: column

            x: Theme.sao.inset
            y: Theme.barHeight + Theme.sao.top
            spacing: Theme.sao.gap

            Repeater {
                id: buttons

                model: Sao.items

                Item {
                    id: button

                    required property var modelData
                    required property int index
                    readonly property bool active: Sao.selected === index

                    // Falls into place one after another, like the anime; rises together on close.
                    property real drop: Sao.open ? 1 : 0

                    width: win.slot
                    height: win.slot
                    opacity: drop

                    transform: Translate {
                        y: (1 - button.drop) * -Theme.sao.drop
                    }

                    Behavior on drop {
                        id: falling

                        // From the target, not Sao.open: which of two bindings updates first is not fixed.
                        SequentialAnimation {
                            PauseAnimation {
                                duration: falling.targetValue > 0 ? button.index * Theme.sao.stagger : 0
                            }

                            NumberAnimation {
                                duration: falling.targetValue > 0 ? Theme.duration.expressiveDefaultSpatial : Theme.duration.expressiveFastSpatial
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: falling.targetValue > 0 ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                            }
                        }
                    }

                    RectangularShadow {
                        anchors.fill: disc
                        radius: disc.radius
                        blur: Theme.sao.shadowBlur
                        color: Theme.sao.shadow
                    }

                    // The ring is the one border here: it is the anime's button.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: Theme.sao.ring
                        border.color: button.active ? Theme.sao.orange : Theme.sao.paper

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.duration.expressiveFastEffects
                            }
                        }
                    }

                    Rectangle {
                        id: disc

                        anchors.centerIn: parent
                        width: Theme.sao.button
                        height: Theme.sao.button
                        radius: width / 2
                        color: button.active ? Theme.sao.orange : Theme.sao.paper
                        scale: tap.pressed ? Theme.pressScale : 1

                        Behavior on color {
                            FastColor {}
                        }

                        Behavior on scale {
                            PressAnim {}
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: button.modelData.icon
                            color: button.active ? Theme.sao.inkDeep : Theme.sao.ink
                            size: Theme.icon.large
                            fill: 1

                            Behavior on color {
                                FastColor {}
                            }
                        }
                    }

                    HoverHandler {
                        onPointChanged: if (!Sao.asking && win.pointerMoved(button, point.position.x, point.position.y))
                            Sao.select(button.index)

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: tap

                        onTapped: Sao.pick(button.index)
                    }
                }
            }
        }

        // The orange ribbon naming the selected button; it slides to each one.
        Item {
            id: ribbon

            // Through count: itemAt() in a binding runs once otherwise.
            readonly property real target: buttons.count > 0 ? (buttons.itemAt(Sao.selected)?.y ?? 0) : 0
            property real reveal: Sao.open ? 1 : 0

            x: column.x + win.slot + Theme.sao.gap
            y: column.y + (win.slot - Theme.sao.ribbon) / 2
            width: Theme.sao.ribbonWidth
            height: Theme.sao.ribbon
            opacity: reveal

            transform: [
                Scale {
                    xScale: ribbon.reveal
                },
                Translate {
                    y: ribbon.target

                    Behavior on y {
                        enabled: win.visible

                        NumberAnimation {
                            duration: Theme.duration.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.emphasizedDecel
                        }
                    }
                }
            ]

            Behavior on reveal {
                id: unrolling

                NumberAnimation {
                    duration: unrolling.targetValue > 0 ? Theme.duration.expressiveDefaultSpatial : Theme.duration.expressiveFastEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: unrolling.targetValue > 0 ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: Theme.sao.orange
                    strokeColor: "transparent"
                    startX: 0
                    startY: 0

                    PathLine {
                        x: ribbon.width - Theme.sao.ribbonTip
                        y: 0
                    }

                    PathLine {
                        x: ribbon.width
                        y: ribbon.height / 2
                    }

                    PathLine {
                        x: ribbon.width - Theme.sao.ribbonTip
                        y: ribbon.height
                    }

                    PathLine {
                        x: 0
                        y: ribbon.height
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: Theme.spacing.large
                width: parent.width - Theme.spacing.large - Theme.sao.ribbonTip
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: I18n.t(Sao.items[Sao.selected]?.label ?? "")
                color: Theme.sao.inkDeep
                font.family: win.family(text)
                font.pixelSize: Theme.fontSize.large
                font.letterSpacing: Theme.tracking.wider
            }
        }

        // Profile and Skills: a paper card that swings open beside the ribbon, like a door.
        // Padded by the shadow's reach, so the blur-in layer never cuts the shadow off.
        Item {
            id: card

            property real reveal: Sao.open && Sao.card !== "" ? 1 : 0

            x: ribbon.x + Theme.sao.ribbonWidth + Theme.sao.gap - Theme.sao.shadowBlur
            y: column.y - Theme.sao.shadowBlur
            width: Theme.sao.panel + Theme.sao.shadowBlur * 2
            height: paper.height + Theme.sao.shadowBlur * 2
            visible: reveal > 0
            opacity: reveal
            layer.enabled: opacity < 1

            layer.effect: MotionBlur {
                settled: card.reveal
            }

            transform: Rotation {
                origin.x: Theme.sao.shadowBlur
                origin.y: card.height / 2

                axis {
                    x: 0
                    y: 1
                    z: 0
                }

                angle: (1 - card.reveal) * Theme.sao.swing
            }

            Behavior on reveal {
                id: swinging

                NumberAnimation {
                    duration: swinging.targetValue > 0 ? Theme.duration.expressiveDefaultSpatial : Theme.duration.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: swinging.targetValue > 0 ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                }
            }

            RectangularShadow {
                anchors.fill: paper
                radius: paper.radius
                blur: Theme.sao.shadowBlur
                color: Theme.sao.shadow
            }

            Rectangle {
                id: paper

                x: Theme.sao.shadowBlur
                y: Theme.sao.shadowBlur
                width: Theme.sao.panel
                height: win.shownCard === "skills" ? Theme.sao.panelMax : profile.implicitHeight + Theme.spacing.extraLarge * 2
                radius: Theme.rounding.extraSmall
                color: Theme.sao.paper

                // Clicks on the card stay on it.
                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: profile

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Theme.spacing.extraLarge
                    }

                    visible: win.shownCard === "profile"
                    spacing: Theme.spacing.large

                    Row {
                        width: parent.width
                        spacing: Theme.spacing.large

                        ClippingRectangle {
                            width: Theme.sao.avatar
                            height: Theme.sao.avatar
                            radius: width / 2
                            color: Theme.sao.paperDeep

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl("../lock/avatar.webp")
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: Theme.sao.avatar * 2
                                sourceSize.height: Theme.sao.avatar * 2
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.sao.avatar - parent.spacing
                            spacing: Theme.spacing.small

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: Quickshell.env("USER")
                                color: Theme.sao.inkDeep
                                font.family: win.family(text)
                                font.pixelSize: Theme.fontSize.extraLarge
                            }

                            // The level on an orange chip: orange text on paper is under 2:1.
                            Rectangle {
                                width: level.implicitWidth + Theme.spacing.medium * 2
                                height: level.implicitHeight + Theme.spacing.small
                                radius: height / 2
                                color: Theme.sao.orange

                                Text {
                                    id: level

                                    anchors.centerIn: parent
                                    textFormat: Text.PlainText
                                    // A level for every day the machine has been up.
                                    text: I18n.t("Lv. %1").arg(Math.floor(SysInfo.uptimeSeconds / 86400) + 1)
                                    color: Theme.sao.inkDeep
                                    font.family: win.family(text)
                                    font.pixelSize: Theme.fontSize.larger
                                    font.letterSpacing: Theme.tracking.wider
                                }
                            }
                        }
                    }

                    Gauge {
                        title: "HP"
                        ratio: win.hp
                        // A desktop's bar is neutral, so it never reads as a full battery.
                        tint: !win.hasBattery ? Theme.sao.ink : win.hp < Theme.sao.hpDanger ? Theme.sao.hpLow : win.hp < Theme.sao.hpWarn ? Theme.sao.hpMid : Theme.sao.hpHigh
                        readout: win.hasBattery ? I18n.t("%1 / 100").arg(Math.round(win.hp * 100)) : I18n.t("On mains")
                    }

                    Gauge {
                        title: "MP"
                        ratio: win.mp
                        tint: Theme.sao.mp
                        ready: SysInfo.memTotal > 1
                        readout: ready ? I18n.t("%1 / %2 free").arg(SysInfo.formatBytes(SysInfo.memTotal - SysInfo.memUsed)).arg(SysInfo.formatBytes(SysInfo.memTotal)) : ""
                    }
                }

                // Skills: the agent skills Claude Code has here; a click copies its command.
                Item {
                    anchors.fill: parent
                    anchors.margins: Theme.spacing.extraLarge
                    visible: win.shownCard === "skills"

                    Text {
                        id: skillsTitle

                        textFormat: Text.PlainText
                        text: Sao.skills.length > 0 ? I18n.t("Skills · %1").arg(Sao.skills.length) : I18n.t("Skills")
                        color: Theme.sao.inkDeep
                        font.family: win.family(text)
                        font.pixelSize: Theme.fontSize.large
                        font.letterSpacing: Theme.tracking.wider
                    }

                    Text {
                        id: skillsHint

                        anchors.top: skillsTitle.bottom
                        textFormat: Text.PlainText
                        text: I18n.t("Click one to copy its command")
                        color: Theme.sao.ink
                        font.family: win.family(text)
                        font.pixelSize: Theme.fontSize.smaller
                    }

                    ListView {
                        id: skillList

                        // Not dragging: the wheel and touchpad never set it; movementStarted comes from every scroll but code's own.
                        onMovementStarted: Sounds.play("sao-scroll")

                        anchors {
                            top: skillsHint.bottom
                            topMargin: Theme.spacing.medium
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }

                        clip: true
                        spacing: Theme.spacing.extraSmall
                        boundsBehavior: Flickable.StopAtBounds
                        model: Sao.skills

                        ScrollBar.vertical: ScrollBar {
                            contentItem: Rectangle {
                                implicitWidth: Theme.sao.scroll
                                radius: width / 2
                                color: Theme.sao.ink
                            }
                        }

                        delegate: Rectangle {
                            id: skill

                            required property var modelData
                            property bool copied: false

                            width: skillList.width
                            height: skillText.implicitHeight + Theme.spacing.medium * 2
                            radius: Theme.rounding.extraSmall
                            color: skill.copied ? Theme.sao.orange : skillHover.hovered ? Theme.sao.paperDeep : "transparent"
                            scale: skillTap.pressed ? Theme.pressScale : 1

                            Behavior on color {
                                FastColor {}
                            }

                            Behavior on scale {
                                PressAnim {}
                            }

                            Column {
                                id: skillText

                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: Theme.spacing.medium
                                    rightMargin: Theme.spacing.medium
                                }

                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    text: "/" + skill.modelData.name
                                    color: Theme.sao.inkDeep
                                    font.family: rationale.name
                                    font.pixelSize: Theme.fontSize.larger
                                }

                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    text: skill.modelData.about
                                    color: skill.copied ? Theme.sao.inkDeep : Theme.sao.ink
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.smaller
                                }
                            }

                            HoverHandler {
                                id: skillHover

                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                id: skillTap

                                onTapped: {
                                    Sao.copySkill(skill.modelData.name);
                                    skill.copied = true;
                                    unflash.restart();
                                }
                            }

                            Timer {
                                id: unflash

                                onTriggered: skill.copied = false

                                interval: Theme.duration.osdHide
                            }
                        }
                    }

                    // Outside the list: inside it, an empty list's content has no height and clips this in half.
                    Column {
                        anchors.centerIn: skillList
                        visible: skillList.count === 0
                        spacing: Theme.spacing.medium

                        Spinner {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: Sao.scanning
                            color: Theme.sao.ink
                            size: Theme.icon.large
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            textFormat: Text.PlainText
                            text: Sao.scanning ? I18n.t("Searching…") : Sao.scanFailed ? I18n.t("Could not read the skills") : I18n.t("No agent skills found")
                            color: Theme.sao.inkDeep
                            font.family: win.family(text)
                            font.pixelSize: Theme.fontSize.normal
                        }
                    }
                }
            }
        }

        // Logout: the anime's dialog, flipping down from the top, with ○ to accept and × to decline.
        Item {
            id: dialog

            property real reveal: Sao.open && Sao.asking ? 1 : 0

            anchors.centerIn: parent
            width: Theme.sao.dialog + Theme.sao.shadowBlur * 2
            height: dialogBody.implicitHeight + Theme.sao.shadowBlur * 2
            visible: reveal > 0
            opacity: reveal
            layer.enabled: opacity < 1

            layer.effect: MotionBlur {
                settled: dialog.reveal
            }

            transform: Rotation {
                origin.x: dialog.width / 2
                origin.y: Theme.sao.shadowBlur

                axis {
                    x: 1
                    y: 0
                    z: 0
                }

                angle: (1 - dialog.reveal) * Theme.sao.flip
            }

            Behavior on reveal {
                id: flipping

                NumberAnimation {
                    duration: flipping.targetValue > 0 ? Theme.duration.expressiveDefaultSpatial : Theme.duration.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: flipping.targetValue > 0 ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                }
            }

            RectangularShadow {
                anchors.fill: sheet
                blur: Theme.sao.shadowBlur
                color: Theme.sao.shadow
            }

            Rectangle {
                id: sheet

                x: Theme.sao.shadowBlur
                y: Theme.sao.shadowBlur
                width: Theme.sao.dialog
                height: dialogBody.implicitHeight
                color: Theme.sao.paper

                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: dialogBody

                    width: parent.width

                    Text {
                        width: parent.width
                        topPadding: Theme.spacing.large
                        bottomPadding: Theme.spacing.large
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                        text: I18n.t("Logout")
                        color: Theme.sao.inkDeep
                        font.family: win.family(text)
                        font.pixelSize: Theme.fontSize.large
                        font.letterSpacing: Theme.tracking.wider
                    }

                    Rectangle {
                        width: parent.width
                        height: question.implicitHeight + Theme.spacing.extraLarge * 2
                        color: Theme.sao.paperDeep

                        // The anime's inset shadow along the top and bottom of the well.
                        Rectangle {
                            anchors.fill: parent

                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: Theme.sao.well
                                }

                                GradientStop {
                                    position: Theme.sao.wellFade
                                    color: "transparent"
                                }

                                GradientStop {
                                    position: 1 - Theme.sao.wellFade
                                    color: "transparent"
                                }

                                GradientStop {
                                    position: 1
                                    color: Theme.sao.well
                                }
                            }
                        }

                        Text {
                            id: question

                            anchors.centerIn: parent
                            width: parent.width - Theme.spacing.extraLarge * 2
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            text: I18n.t("Are you sure you want to log out?")
                            color: Theme.sao.inkDeep
                            font.family: win.family(text)
                            font.pixelSize: Theme.fontSize.larger
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: Theme.spacing.large
                        bottomPadding: Theme.spacing.large
                        spacing: Theme.sao.choiceGap

                        Choice {
                            onHovered: Sao.choice = 0
                            onChosen: Sao.logout()

                            tint: Theme.sao.accept
                            focused: Sao.choice === 0

                            // The anime's ○: a ring inside the disc.
                            Rectangle {
                                anchors.centerIn: parent
                                width: Theme.sao.choiceMark
                                height: Theme.sao.choiceMark
                                radius: width / 2
                                color: "transparent"
                                border.width: Theme.sao.choiceStroke
                                border.color: Theme.sao.mark
                            }
                        }

                        Choice {
                            onHovered: Sao.choice = 1
                            onChosen: Sao.asking = false

                            tint: Theme.sao.decline
                            focused: Sao.choice === 1

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                color: Theme.sao.mark
                                size: Theme.icon.normal
                            }
                        }
                    }
                }
            }
        }
    }
}
