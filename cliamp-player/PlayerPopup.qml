import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

PopupCard {
  id: root

  required property var controller

  readonly property color foreground: Color.popups.text
  readonly property color accent: Color.accent
  readonly property string playerFont: bar ? bar.fontFamily : Style.font.family

  contentWidth: fittedContentWidth(Style.space(410), Style.space(520))
  contentHeight: fittedContentHeight(playerColumn.implicitHeight, Style.space(540))

  ColumnLayout {
    id: playerColumn
    anchors.fill: parent
    spacing: Style.space(10)

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: "CLIAMP"
          color: root.accent
          font.family: root.playerFont
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        Text {
          Layout.fillWidth: true
          text: root.controller.playing ? "LIVE OUTPUT" : (root.controller.paused ? "PAUSED" : "STOPPED")
          color: Qt.darker(root.foreground, 1.45)
          font.family: root.playerFont
          font.pixelSize: Style.font.caption
        }
      }

      Button {
        text: "×"
        foreground: root.foreground
        horizontalPadding: Style.space(8)
        verticalPadding: Style.space(3)
        onClicked: root.close()
      }
    }

    Dropdown {
      id: visualizerPicker
      Layout.fillWidth: true
      label: "VISUALIZER"
      value: root.controller.visualizerMode
      options: root.controller.visualizerOptions
      foreground: root.foreground
      background: Color.popups.background
      popupBorder: Color.popups.border
      accent: root.accent
      fontFamily: root.playerFont
      onChanged: function(value) { root.controller.setVisualizer(value) }
    }

    BorderSurface {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(138)
      color: "transparent"
      borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18), 1)
      radius: 0
      padding: Style.space(8)

      Spectrum {
        anchors.fill: parent
        anchors.topMargin: parent.contentTopInset
        anchors.rightMargin: parent.contentRightInset
        anchors.bottomMargin: parent.contentBottomInset
        anchors.leftMargin: parent.contentLeftInset
        bands: root.controller.bands
        mode: root.controller.visualizerMode
        lowColor: root.accent
        midColor: root.foreground
        highColor: Color.urgent
        peakColor: root.foreground
        visible: root.controller.playing
          && root.controller.visualizerMode.toLowerCase() !== "none"
          && root.controller.bands.length > 0
      }

      Text {
        anchors.centerIn: parent
        visible: !root.controller.playing
          || root.controller.visualizerMode.toLowerCase() === "none"
          || root.controller.bands.length === 0
        text: root.controller.paused
          ? "PAUSED"
          : (root.controller.visualizerMode.toLowerCase() === "none"
              ? "VISUALIZER OFF"
              : (root.controller.running ? "NO LIVE AUDIO" : "CLIAMP NOT RUNNING"))
        color: Qt.darker(root.foreground, 1.45)
        font.family: root.playerFont
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(2)

      Text {
        Layout.fillWidth: true
        text: root.controller.displayTitle()
        color: root.foreground
        font.family: root.playerFont
        font.pixelSize: Style.font.heading
        font.bold: true
        elide: Text.ElideRight
      }
      Text {
        Layout.fillWidth: true
        text: root.controller.displayArtist()
        visible: text !== ""
        color: Qt.darker(root.foreground, 1.35)
        font.family: root.playerFont
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(4)

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(7)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
        radius: 0

        Rectangle {
          width: parent.width * root.controller.progress
          height: parent.height
          color: root.accent
          radius: 0
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: function(mouse) {
            root.controller.seekFraction(mouse.x / Math.max(1, width))
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Text {
          text: root.controller.formatTime(root.controller.positionSeconds)
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.playerFont
          font.pixelSize: Style.font.caption
        }
        Item { Layout.fillWidth: true }
        Text {
          text: root.controller.formatTime(root.controller.durationSeconds)
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.playerFont
          font.pixelSize: Style.font.caption
        }
      }
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: Style.space(8)

      Button {
        iconText: "⏮"
        foreground: root.foreground
        iconSize: Style.font.iconLarge
        tooltipText: "Previous"
        onClicked: root.controller.previousTrack()
      }
      Button {
        iconText: root.controller.playIcon
        foreground: root.foreground
        iconSize: Style.font.iconLarge
        horizontalPadding: Style.space(12)
        bordered: true
        tooltipText: root.controller.playing ? "Pause" : "Play"
        onClicked: root.controller.togglePlayback()
      }
      Button {
        iconText: "⏭"
        foreground: root.foreground
        iconSize: Style.font.iconLarge
        tooltipText: "Next"
        onClicked: root.controller.nextTrack()
      }
      Button {
        iconText: "■"
        foreground: root.foreground
        iconSize: Style.font.icon
        tooltipText: "Stop"
        onClicked: root.controller.stopPlayback()
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Button {
        text: "SHUFFLE"
        foreground: root.foreground
        fontSize: Style.font.caption
        active: root.controller.shuffle
        onClicked: root.controller.toggleShuffle()
      }
      Button {
        text: "REPEAT " + root.controller.repeatMode.toUpperCase()
        foreground: root.foreground
        fontSize: Style.font.caption
        active: root.controller.repeatMode.toLowerCase() !== "off"
        onClicked: root.controller.cycleRepeat()
      }
      Item { Layout.fillWidth: true }
      Button {
        text: "−"
        foreground: root.foreground
        horizontalPadding: Style.space(7)
        onClicked: root.controller.changeVolume(-1)
      }
      Text {
        text: root.controller.volume + " dB"
        color: root.foreground
        font.family: root.playerFont
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        Layout.preferredWidth: Style.space(48)
      }
      Button {
        text: "+"
        foreground: root.foreground
        horizontalPadding: Style.space(7)
        onClicked: root.controller.changeVolume(1)
      }
    }

    Connections {
      target: root.controller
      function onVisualizerModeChanged() {
        visualizerPicker.value = root.controller.visualizerMode
      }
    }
  }
}
