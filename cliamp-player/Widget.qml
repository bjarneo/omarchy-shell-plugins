import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "cliamp-player"

  property bool opened: false
  property var registeredBar: null

  readonly property int maxLabelWidth: Number(setting("maxWidth", 200))
  readonly property bool showArtist: setting("showArtist", true) !== false
  readonly property int autoHideMs: Number(setting("autoHideMs", 4500))
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property bool tooltipHovered: pointer.hoverEnabled && pointer.containsMouse

  function barLabel() {
    var label = player.title || "cliamp"
    if (showArtist && player.artist) label += " · " + player.artist
    return label
  }

  function open() {
    opened = true
    overlay.dismiss()
    player.poll()
    player.loadVisualizers()
  }

  function close() { opened = false }
  function toggle() { opened ? close() : open() }

  function triggerPress(button) {
    if (bar) bar.hideTooltip(root)
    if (button === Qt.MiddleButton) player.nextTrack()
    else if (button === Qt.RightButton) player.togglePlayback()
    else root.toggle()
  }

  function registerBar() {
    if (registeredBar === bar) return
    if (registeredBar && registeredBar.unregisterClickTarget)
      registeredBar.unregisterClickTarget(root)
    registeredBar = bar
    if (registeredBar && registeredBar.registerClickTarget)
      registeredBar.registerClickTarget(root)
  }

  onBarChanged: {
    registerBar()
    player.poll()
    Qt.callLater(function() {
      if (bar && player.trackKey && (player.playing || player.paused)) overlay.reveal()
    })
  }

  onVisibleChanged: if (!visible && bar) bar.hideTooltip(root)

  Component.onCompleted: registerBar()
  Component.onDestruction: {
    if (registeredBar && registeredBar.unregisterClickTarget)
      registeredBar.unregisterClickTarget(root)
  }

  visible: player.running
  implicitWidth: vertical ? barSize : barRow.implicitWidth + Style.space(12)
  implicitHeight: vertical ? Style.space(26) : barSize

  PlayerController {
    id: player
    captureEnabled: root.bar !== null
    spectrumEnabled: root.opened || overlay.showing
  }

  Connections {
    target: player
    function onRunningChanged() {
      if (!player.running) {
        root.close()
        overlay.dismiss()
      }
    }
  }

  Row {
    id: barRow
    anchors.centerIn: parent
    spacing: root.vertical ? 0 : Style.space(5)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: ""
      color: root.foreground
      opacity: player.playing ? 1 : 0.5
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      renderType: Text.NativeRendering

      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: 160 }
      }
      Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    Text {
      visible: !root.vertical
      anchors.verticalCenter: parent.verticalCenter
      text: root.barLabel()
      color: root.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
      width: Math.min(implicitWidth, root.maxLabelWidth)
    }
  }

  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

    onClicked: function(mouse) { root.triggerPress(mouse.button) }
    onWheel: function(wheel) {
      var delta = wheel.angleDelta.y
      if (delta === 0) {
        wheel.accepted = false
        return
      }
      player.changeVolume(delta > 0 ? 1 : -1)
      wheel.accepted = true
    }
    onEntered: if (root.bar) root.bar.showTooltip(
      root,
      "Cliamp player\nLeft-click: controls · Right-click: play/pause\nMiddle-click: next · Scroll: volume")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PlayerPopup {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    controller: player
    open: root.opened
  }

  NowPlayingOverlay {
    id: overlay
    screen: root.QsWindow.window ? root.QsWindow.window.screen : null
    bar: root.bar
    controller: player
    autoHideMs: root.autoHideMs
    onOpenRequested: root.open()
  }
}
