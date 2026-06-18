import QtQuick
import qs.Commons

// Compact now-playing card for cliamp. Dense Winamp-style layout driven by
// MPRIS, with visualizer frames from `cliamp visstream`.
Item {
    id: root

    property var player: null
    property bool active: true
    signal dismissRequested()

    readonly property color bg: Color.popups.background
    readonly property color edge: Color.popups.border
    readonly property color fg: Color.popups.text
    readonly property color dim: Color.muted
    readonly property color accent: Color.accent
    readonly property color green: Color.muted
    readonly property color yellow: Color.accent
    readonly property color red: Color.urgent

    readonly property bool ready: player !== null
    readonly property bool playing: ready && player.isPlaying
    readonly property real len: ready && player.lengthSupported ? player.length : 0
    readonly property real progress: len > 0 ? Math.min(1, livePosition / len) : 0
    property real livePosition: 0

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
            root.dismissRequested();
            event.accepted = true;
        }
    }

    Timer {
        interval: 250
        running: root.active && root.ready && root.playing
        repeat: true
        onTriggered: root.livePosition = root.player.position
    }

    Connections {
        target: root.player
        function onPlaybackStateChanged() { root.livePosition = root.player.position; }
        function onTrackTitleChanged() { root.livePosition = root.player.position; }
        function onPositionChanged() { root.livePosition = root.player.position; }
    }

    function fmt(seconds) {
        if (!isFinite(seconds) || seconds < 0) return "--:--";
        const s = Math.floor(seconds);
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    BandStream {
        id: stream
        fps: 30
        enabled: root.active && root.ready
    }

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.94)
        border.color: root.edge
        border.width: 1
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 5
        anchors.bottomMargin: 5

        Text {
            id: titleT
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: timeT.left
            anchors.rightMargin: 8
            height: 13
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: root.ready ? (root.player.trackTitle || "Unknown title") : "cliamp: not running"
            color: root.fg
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            textFormat: Text.PlainText
        }

        Text {
            id: timeT
            anchors.top: parent.top
            anchors.right: parent.right
            height: 13
            verticalAlignment: Text.AlignVCenter
            text: root.fmt(root.livePosition) + "/" + root.fmt(root.len)
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }

        Row {
            id: transport
            anchors.top: titleT.bottom
            anchors.topMargin: 2
            anchors.right: parent.right
            width: timeT.width
            height: 16
            spacing: Math.max(2, (width - 52) / 2)

            TransportButton {
                width: 16; height: 16
                shape: "prev"
                iconSize: 10
                enabled: root.ready && root.player.canGoPrevious
                fgColor: root.dim
                hoverColor: root.yellow
                onActivated: root.player.previous()
            }

            TransportButton {
                width: 20; height: 16
                shape: root.playing ? "pause" : "play"
                iconSize: 12
                enabled: root.ready && root.player.canTogglePlaying
                fgColor: root.accent
                hoverColor: root.green
                onActivated: root.player.togglePlaying()
            }

            TransportButton {
                width: 16; height: 16
                shape: "next"
                iconSize: 10
                enabled: root.ready && root.player.canGoNext
                fgColor: root.dim
                hoverColor: root.yellow
                onActivated: root.player.next()
            }
        }

        Text {
            id: artistT
            anchors.top: titleT.bottom
            anchors.topMargin: 2
            anchors.left: parent.left
            anchors.right: transport.left
            anchors.rightMargin: 8
            height: 16
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: root.ready ? (root.player.trackArtist || "") : ""
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            textFormat: Text.PlainText
        }

        Visualizer {
            id: vis
            anchors.top: artistT.bottom
            anchors.topMargin: 2
            anchors.left: parent.left
            anchors.right: parent.right
            height: 22
            bands: stream.bands
            barColor: root.green
            accentColor: root.yellow
            warnColor: root.red
            segH: 2
            segGap: 1
        }

        Item {
            id: barWrap
            anchors.top: vis.bottom
            anchors.topMargin: 3
            anchors.left: parent.left
            anchors.right: parent.right
            height: 4

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: root.dim
                opacity: 0.45
                radius: 0
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                width: parent.width * root.progress
                color: root.accent
                radius: 0
            }

            Rectangle {
                visible: root.ready && root.len > 0
                width: 4
                height: 4
                radius: 0
                color: root.accent
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width,
                    parent.width * root.progress - width / 2))
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -4
                anchors.bottomMargin: -4
                enabled: root.ready && root.player.canSeek && root.len > 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: function(mouse) {
                    const frac = Math.max(0, Math.min(1, mouse.x / width));
                    const target = frac * root.len;
                    root.player.position = target;
                    root.livePosition = target;
                }
            }
        }
    }
}
