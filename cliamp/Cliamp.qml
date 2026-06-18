import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.Commons

// Persistent Omarchy shell overlay for cliamp's MPRIS player. The plugin stays
// loaded, but the panel maps only while cliamp is present and not manually
// hidden through IPC.
Item {
    id: root

    property var shell: null
    property var manifest: null
    readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "cliamp"

    property bool manuallyHidden: false
    readonly property bool opened: !manuallyHidden && cliampPlayer !== null

    readonly property var cliampPlayer: {
        for (let i = 0; i < Mpris.players.values.length; ++i) {
            const player = Mpris.players.values[i];
            if (player.dbusName === "cliamp" || player.identity === "Cliamp")
                return player;
        }
        return null;
    }

    function open(_payloadJson) {
        manuallyHidden = false;
        return "ok";
    }

    function close() {
        manuallyHidden = true;
        return "ok";
    }

    function toggle(payloadJson) {
        return root.opened ? close() : open(payloadJson || "{}");
    }

    function refresh() {
        manuallyHidden = false;
        return "ok";
    }

    IpcHandler {
        target: "cliamp"
        function open(): string { return root.open("{}"); }
        function close(): string { return root.close(); }
        function toggle(): string { return root.toggle("{}"); }
        function refresh(): string { return root.refresh(); }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData

            anchors {
                bottom: true
                left: true
                right: true
            }
            margins { bottom: Style.gapsOut + 8 }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "omarchy-cliamp"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            implicitHeight: 72
            color: "transparent"
            visible: root.opened

            NowPlaying {
                width: 300
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                player: root.cliampPlayer
                active: panel.visible
                focus: true
                onDismissRequested: root.close()
            }
        }
    }
}
