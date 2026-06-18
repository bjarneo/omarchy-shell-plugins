import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.Commons

// Persistent Omarchy shell overlay for cliamp's MPRIS player. The plugin stays
// loaded, then briefly maps a top-right card whenever cliamp starts or changes
// tracks.
Item {
    id: root

    property var shell: null
    property var manifest: null
    readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "cliamp"

    property bool showing: false
    property int autoHideMs: 4500
    readonly property int topMargin: Style.gapsOut + 40
    readonly property int rightMargin: Style.gapsOut + 24
    readonly property bool opened: showing && cliampPlayer !== null

    readonly property var cliampPlayer: {
        for (let i = 0; i < Mpris.players.values.length; ++i) {
            const player = Mpris.players.values[i];
            if (player.dbusName === "cliamp" || player.identity === "Cliamp")
                return player;
        }
        return null;
    }

    onCliampPlayerChanged: {
        if (cliampPlayer) reveal();
        else {
            hideTimer.stop();
            showing = false;
        }
    }

    Component.onCompleted: if (cliampPlayer) reveal()

    function reveal() {
        if (!cliampPlayer) return;
        showing = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: root.autoHideMs
        repeat: false
        onTriggered: root.showing = false
    }

    Connections {
        target: root.cliampPlayer
        function onTrackTitleChanged() { root.reveal(); }
        function onTrackArtistChanged() { root.reveal(); }
    }

    function open(_payloadJson) {
        reveal();
        return "ok";
    }

    function close() {
        hideTimer.stop();
        showing = false;
        return "ok";
    }

    function toggle(payloadJson) {
        return root.opened ? close() : open(payloadJson || "{}");
    }

    function refresh() {
        reveal();
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
                top: true
                right: true
            }
            margins {
                top: root.topMargin
                right: root.rightMargin
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "omarchy-cliamp"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            implicitWidth: 360
            implicitHeight: 96
            color: "transparent"
            visible: root.opened

            NowPlaying {
                anchors.fill: parent
                player: root.cliampPlayer
                active: panel.visible
                focus: true
                onDismissRequested: root.close()
            }
        }
    }
}
