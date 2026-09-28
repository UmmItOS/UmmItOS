pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// Every QR code found on the screen, washed in the accent, with what it holds beside it.
OverlayWindow {
    id: win

    shown: Scan.open
    name: "scan"
    screen: Scan.screen
    scrim: Theme.shade.normal

    // The code Enter acts on; Tab and the arrows move it.
    property int current: 0
    readonly property int count: Scan.codes.length

    function step(by: int): void {
        current = (current + by + count) % Math.max(1, count);
    }

    function actOnCurrent(): void {
        const code = Scan.codes[current];
        if (code)
            Scan.act(code);
    }

    function glyph(kind: string): string {
        return ({
                link: "link",
                mailto: "mail",
                tel: "call",
                geo: "location_on",
                wifi: "wifi"
            })[kind] ?? "notes";
    }

    function verb(kind: string): string {
        return ({
                link: "Open",
                mailto: "Write",
                tel: "Call",
                geo: "Map",
                wifi: "Connect"
            })[kind] ?? "Copy";
    }

    Binding {
        target: Scan
        property: "showing"
        value: win.visible
    }

    onOpened: {
        current = 0;
        keys.forceActiveFocus();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Scan.open = false
    }

    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Scan.open = false
        Keys.onTabPressed: win.step(1)
        Keys.onBacktabPressed: win.step(-1)
        Keys.onRightPressed: win.step(1)
        Keys.onLeftPressed: win.step(-1)
        Keys.onReturnPressed: win.actOnCurrent()
        Keys.onEnterPressed: win.actOnCurrent()
    }

    Item {
        anchors.fill: parent
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        Repeater {
            model: Scan.codes

            Item {
                id: found

                required property var modelData
                required property int index

                readonly property bool picked: win.current === found.index

                anchors.fill: parent
                z: found.picked ? 1 : 0

                // The layer rule blurs the screen behind, so the card, not the code, identifies it.
                Rectangle {
                    id: wash

                    x: found.modelData.x - Theme.scan.reach
                    y: found.modelData.y - Theme.scan.reach
                    width: found.modelData.w + Theme.scan.reach * 2
                    height: found.modelData.h + Theme.scan.reach * 2
                    radius: Theme.rounding.large
                    color: Theme.accent
                    opacity: found.picked ? Theme.scan.tintPeak : Theme.scan.tint

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }
                }

                Surface {
                    id: card

                    readonly property real below: wash.y + wash.height + Theme.spacing.small
                    readonly property real above: wash.y - height - Theme.spacing.small

                    x: Math.max(Theme.padding.large, Math.min(wash.x + wash.width / 2 - width / 2, win.width - width - Theme.padding.large))
                    // Below the code, above it when the screen ends first, and never off screen.
                    y: Math.max(Theme.padding.large, Math.min(below + height > win.height - Theme.padding.large ? above : below, win.height - height - Theme.padding.large))
                    width: Theme.scan.card
                    height: content.implicitHeight + Theme.padding.large * 2
                    radius: Theme.rounding.extraLarge
                    tone: found.picked ? Theme.bgTray : Theme.bgAlt
                    lift: Theme.lift.panel

                    Behavior on tone {
                        ColorAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }

                    // Swallow clicks so they do not reach the dismiss handler.
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: event => {
                            if (win.pointerMoved(card, event.x, event.y))
                                win.current = found.index;
                        }
                    }

                    ColumnLayout {
                        id: content

                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: Theme.padding.large
                        }
                        spacing: Theme.spacing.medium

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.small

                            MaterialIcon {
                                Layout.alignment: Qt.AlignTop
                                text: win.glyph(found.modelData.kind)
                                color: Theme.accentText
                                size: Theme.icon.small
                            }

                            // Plain text: a code is untrusted, and rich text could load a remote image.
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing.hair

                                Text {
                                    Layout.fillWidth: true
                                    text: found.modelData.title
                                    textFormat: Text.PlainText
                                    color: Theme.fg
                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.normal
                                    font.weight: Theme.weight.medium
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: found.modelData.detail
                                    textFormat: Text.PlainText
                                    color: Theme.dim
                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.smaller
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: Theme.spacing.small

                            Action {
                                visible: found.modelData.kind !== "text" && (found.modelData.kind !== "wifi" || found.modelData.password !== "")
                                icon: "content_copy"
                                label: found.modelData.kind === "wifi" ? "Copy password" : "Copy"
                                onClicked: Scan.copy(found.modelData.kind === "wifi" ? found.modelData.password : found.modelData.data)
                            }

                            Action {
                                primary: found.picked
                                icon: found.modelData.kind === "text" ? "content_copy" : "open_in_new"
                                label: win.verb(found.modelData.kind)
                                onClicked: Scan.act(found.modelData)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            opacity: found.picked ? 1 : 0
                            text: "Enter to " + win.verb(found.modelData.kind).toLowerCase() + (win.count > 1 ? " · Tab for the next" : "") + " · Esc to close"
                            color: Theme.dim
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.small

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.duration.expressiveFastEffects
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
