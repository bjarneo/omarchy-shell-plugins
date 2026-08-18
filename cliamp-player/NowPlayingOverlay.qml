import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

PanelWindow {
  id: root

  required property var controller
  property QtObject bar: null
  property int autoHideMs: 4500
  property bool showing: false

  readonly property color accent: Color.accent
  readonly property string playerFont: bar ? bar.fontFamily : Style.font.family

  signal openRequested()

  function reveal() {
    if (!bar || !screen || !controller.running || (!controller.playing && !controller.paused)) return
    showing = true
    hideTimer.interval = Math.max(1500, autoHideMs)
    if (cardHover.hovered) hideTimer.stop()
    else hideTimer.restart()
  }

  function dismiss() {
    showing = false
    hideTimer.stop()
  }

  function dismissIfInactive() {
    Qt.callLater(function() {
      if (!root.controller.playing && !root.controller.paused) root.dismiss()
    })
  }

  visible: showing && controller.running
  color: "transparent"
  implicitWidth: Style.space(390)
  implicitHeight: Style.space(174)
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omarchy-cliamp-player"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  anchors {
    top: true
    right: true
  }
  margins {
    top: root.bar && root.bar.position === "top" ? root.bar.barSize + Style.gapsOut : Style.gapsOut
    right: root.bar && root.bar.position === "right" ? root.bar.barSize + Style.gapsOut : Style.gapsOut
  }

  onBarChanged: if (!bar) dismiss()
  onScreenChanged: if (!screen) dismiss()

  Connections {
    target: root.controller
    function onTrackChanged() { root.reveal() }
    function onRunningChanged() { if (!root.controller.running) root.dismiss() }
    function onPlayingChanged() { root.dismissIfInactive() }
    function onPausedChanged() { root.dismissIfInactive() }
  }

  Timer {
    id: hideTimer
    interval: 4500
    repeat: false
    onTriggered: root.showing = false
  }

  BorderSurface {
    id: card
    anchors.fill: parent
    color: Color.popups.background
    borderSpec: Border.localOrSurfaceSpec(
      "popups", "border", Color.popups.border, Color.popups.border,
      Math.max(1, Style.space(1)))
    radius: Style.cornerRadius
    padding: Style.space(12)

    ColumnLayout {
      anchors.fill: parent
      anchors.topMargin: card.contentTopInset
      anchors.rightMargin: card.contentRightInset
      anchors.bottomMargin: card.contentBottomInset
      anchors.leftMargin: card.contentLeftInset
      spacing: Style.space(6)

      RowLayout {
        Layout.fillWidth: true
        Text {
          text: root.controller.playing ? "NOW PLAYING" : "PAUSED"
          color: root.accent
          font.family: root.playerFont
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        Item { Layout.fillWidth: true }
        Text {
          text: root.controller.formatTime(root.controller.positionSeconds)
            + " / " + root.controller.formatTime(root.controller.durationSeconds)
          color: Qt.darker(Color.popups.text, 1.4)
          font.family: root.playerFont
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        Layout.fillWidth: true
        text: root.controller.displayTitle()
        color: Color.popups.text
        font.family: root.playerFont
        font.pixelSize: Style.font.title
        font.bold: true
        elide: Text.ElideRight
      }
      Text {
        Layout.fillWidth: true
        text: root.controller.displayArtist()
        visible: text !== ""
        color: Qt.darker(Color.popups.text, 1.32)
        font.family: root.playerFont
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Spectrum {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(58)
        bands: root.controller.bands
        mode: root.controller.visualizerMode
        lowColor: root.accent
        midColor: Color.popups.text
        highColor: Color.urgent
        peakColor: Color.popups.text
        visible: root.controller.playing
          && root.controller.visualizerMode.toLowerCase() !== "none"
          && root.controller.bands.length > 0
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(4)
        color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.15)
        radius: 0
        Rectangle {
          width: parent.width * root.controller.progress
          height: parent.height
          color: root.accent
          radius: 0
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.dismiss()
        root.openRequested()
      }
    }

    HoverHandler {
      id: cardHover
      onHoveredChanged: {
        if (hovered) hideTimer.stop()
        else if (root.showing) hideTimer.restart()
      }
    }
  }
}
