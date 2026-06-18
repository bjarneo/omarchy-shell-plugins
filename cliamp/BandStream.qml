import QtQuick
import Quickshell.Io

// Long-lived `cliamp visstream` process that parses one NDJSON frame per line.
Item {
    id: root

    property int fps: 30
    property bool enabled: true
    property var bands: []
    property string mode: ""

    function parseLine(line) {
        if (!line) return;
        try {
            const response = JSON.parse(line);
            if (!response || !response.ok) return;
            if (response.bands) root.bands = response.bands;
            if (response.visualizer) root.mode = response.visualizer;
        } catch (_) {}
    }

    Process {
        id: proc
        command: ["cliamp", "visstream", "--fps", String(root.fps)]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root.parseLine(line); }
        }
    }

    Component.onCompleted: if (root.enabled) proc.running = true
    onEnabledChanged: proc.running = root.enabled

    Timer {
        interval: 2000
        running: root.enabled && !proc.running
        repeat: true
        onTriggered: proc.running = true
    }
}
