import QtQuick

// A card whose fill fades out toward its edge instead of ending in a line.
ShaderEffect {
    property color color: Theme.softGlass
    property real radius: Theme.rounding.extraLarge
    property real spread: Theme.softSpread

    property size size: Qt.size(width, height)
    property color fill: color

    // Resolved here, or it resolves against the file that uses the card.
    fragmentShader: Qt.resolvedUrl("softfill.frag.qsb")
}
