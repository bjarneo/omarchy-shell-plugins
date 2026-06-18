import QtQuick
import qs.Commons

// Compact now-playing card for cliamp. Clean notification layout driven by
// MPRIS, with visualizer frames from `cliamp visstream`.
Item {
    id: root

    property var player: null
    property bool active: true
    signal dismissRequested()

    readonly property color bg: Color.popups.background
    readonly property color fg: Color.popups.text
    readonly property color dim: Color.muted
    readonly property color accent: Color.foreground
    readonly property color edge: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.42)
    readonly property color softEdge: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
    readonly property color surface: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.045)
    readonly property color green: Color.muted
    readonly property color yellow: Color.foreground
    readonly property color red: Color.urgent
    readonly property int cardRadius: Math.max(0, Style.cornerRadius)

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

    BandStream {
        id: stream
        fps: 30
        enabled: root.active && root.ready
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.96)
        border.color: root.edge
        border.width: 1
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: root.accent
        opacity: 0.72
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 10
        anchors.bottomMargin: 9

        Text {
            id: sourceT
            anchors.top: parent.top
            anchors.left: parent.left
            height: 12
            verticalAlignment: Text.AlignVCenter
            text: "NOW PLAYING"
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1.2
            font.bold: true
            opacity: 0.78
        }

        Text {
            id: titleT
            anchors.top: sourceT.bottom
            anchors.topMargin: 5
            anchors.left: parent.left
            anchors.right: parent.right
            height: 22
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: root.ready ? (root.player.trackTitle || "Unknown title") : "cliamp: not running"
            color: root.fg
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
            textFormat: Text.PlainText
        }

        Text {
            id: artistT
            anchors.top: titleT.bottom
            anchors.topMargin: 1
            anchors.left: parent.left
            anchors.right: parent.right
            height: 16
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: root.ready ? (root.player.trackArtist || "") : ""
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            textFormat: Text.PlainText
            opacity: 0.88
        }

        Rectangle {
            id: visBack
            anchors.top: artistT.bottom
            anchors.topMargin: 7
            anchors.left: parent.left
            anchors.right: parent.right
            height: 26
            radius: Math.max(0, root.cardRadius - 2)
            color: root.surface
            border.color: root.softEdge
            border.width: 1
        }

        Visualizer {
            id: vis
            anchors.fill: visBack
            anchors.margins: 3
            bands: stream.bands
            barColor: root.green
            accentColor: root.yellow
            warnColor: root.red
            segH: 2
            segGap: 1
        }

        Item {
            id: barWrap
            anchors.top: visBack.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            height: 6

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: root.dim
                opacity: 0.28
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
