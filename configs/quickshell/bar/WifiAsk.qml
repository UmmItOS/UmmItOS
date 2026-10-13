pragma Singleton

import Quickshell
import Quickshell.Networking
import QtQuick
import ".."

// The Wi-Fi password dialog: out of the network list, which every scan rebuilds mid-typing.
Singleton {
    id: root

    property var network: null
    // Kept after closing, so the dialog's exit still shows the name.
    property string name: ""
    property string error: ""
    // The network last given a password, to ask again if it is rejected.
    property var pending: null

    readonly property bool open: network !== null

    function ask(target: var, why: string): void {
        name = target.name;
        error = why;
        network = target;
    }

    function connect(psk: string): void {
        pending = network;
        network = null;
        pending?.connectWithPsk(psk);
    }

    function cancel(): void {
        network = null;
    }

    Connections {
        function onConnectionFailed(reason: int): void {
            const rejected = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiClientDisconnected || reason === ConnectionFailReason.WifiAuthTimeout;
            if (rejected)
                root.ask(root.pending, I18n.t("Wrong password"));
            root.pending = null;
        }

        function onConnectedChanged(): void {
            if (root.pending?.connected)
                root.pending = null;
        }

        target: root.pending
        ignoreUnknownSignals: true
    }
}
