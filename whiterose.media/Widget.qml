import QtQuick
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

// Now playing. Prefers the actively playing MPRIS player, falls back to
// the first one with a track. Absent media, absent widget.
BarWidget {
  id: root
  moduleName: "whiterose.media"

  readonly property var player: {
    var players = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < players.length; i++) {
      if (players[i] && players[i].isPlaying) return players[i]
    }
    for (var j = 0; j < players.length; j++) {
      if (players[j] && players[j].trackTitle) return players[j]
    }
    return null
  }

  readonly property string title: player && player.trackTitle ? player.trackTitle : ""
  readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
  readonly property bool playing: player !== null && player.isPlaying
  readonly property string label: artist ? artist + " - " + title : title
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property real maxLabelWidth: Style.space(Math.max(120, Number(setting("maxWidth", 220)) || 220))
  readonly property color pillFill: Color.background
  readonly property color pillBorder: Style.controlBorder(false, button.tooltipHovered, foreground, Color.accent)

  Timer {
    id: marqueeStart
    interval: 180
    onTriggered: {
      labelText.x = 0
      if (labelClip.overflow > 0) marquee.restart()
    }
  }

  onLabelChanged: marqueeStart.restart()

  visible: !vertical && title !== ""
  implicitWidth: visible ? content.implicitWidth + Style.space(18) : 0
  implicitHeight: barSize

  Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: " "
    dimmed: !root.playing
    tooltipText: root.artist ? root.artist + " - " + root.title : root.title
    onPressed: function(mouseButton) {
      if (!root.player) return
      if (mouseButton === Qt.RightButton && root.player.canGoNext) root.player.next()
      else if (mouseButton === Qt.MiddleButton && root.player.canGoPrevious) root.player.previous()
      else root.player.togglePlaying()
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.topMargin: 2
      anchors.bottomMargin: 2
      z: -1
      radius: height / 2
      color: root.pillFill
      border.width: Style.controlBorderWidth(false, button.tooltipHovered)
      border.color: root.pillBorder

      Behavior on color { ColorAnimation { duration: 120 } }
      Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    Row {
      id: content
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        id: glyph
        anchors.verticalCenter: parent.verticalCenter
        text: root.playing ? "\u{f03e4}" : "\u{f040a}"
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Item {
        id: labelClip
        width: Math.min(root.maxLabelWidth, labelText.implicitWidth)
        height: glyph.implicitHeight
        clip: true
        anchors.verticalCenter: parent.verticalCenter
        readonly property real overflow: Math.max(0, labelText.implicitWidth - width)

        Text {
          id: labelText
          anchors.verticalCenter: parent.verticalCenter
          text: root.label
          color: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          renderType: Text.NativeRendering
        }

        SequentialAnimation {
          id: marquee

          PauseAnimation { duration: 650 }
          NumberAnimation {
            target: labelText
            property: "x"
            from: 0
            to: -labelClip.overflow
            duration: Math.max(1600, labelClip.overflow * 24)
            easing.type: Easing.InOutSine
          }
          PauseAnimation { duration: 900 }
          NumberAnimation {
            target: labelText
            property: "x"
            from: -labelClip.overflow
            to: 0
            duration: Math.max(1200, labelClip.overflow * 18)
            easing.type: Easing.InOutSine
          }
        }

        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(Style.space(24), parent.width)
          height: parent.height
          visible: labelText.implicitWidth > parent.width
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(root.pillFill.r, root.pillFill.g, root.pillFill.b, 0) }
            GradientStop { position: 1; color: root.pillFill }
          }
        }
      }
    }
  }
}
