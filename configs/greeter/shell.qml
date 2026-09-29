import Quickshell
import QtQuick

// The login screen: run by greetd inside cage (one fullscreen window, no desktop behind it).
ShellRoot {
    FloatingWindow {
        color: "black"

        Greeter {
            anchors.fill: parent
        }
    }
}
