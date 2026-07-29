import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root

  ipcTarget: "codex-usage"

  readonly property var codexUsage: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property var primaryWindow: codexUsage ? codexUsage.primaryWindow : null
  readonly property var secondaryWindow: codexUsage ? codexUsage.secondaryWindow : null
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property double now: Date.now()

  readonly property string buttonTooltip: {
    if (primaryWindow) return qsTr("Codex: %1 remaining").arg(Model.remainingText(primaryWindow))
    if (codexUsage && codexUsage.lastError !== "") return codexUsage.statusText
    return qsTr("Loading Codex capacity")
  }

  function syncServiceSettings() {
    if (codexUsage && typeof codexUsage.configure === "function") codexUsage.configure(settings)
  }

  function colorChannelLuminance(value) {
    var channel = Number(value)
    if (!isFinite(channel)) return 0
    return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
  }

  function colorLuminance(color) {
    return 0.2126 * colorChannelLuminance(color.r)
      + 0.7152 * colorChannelLuminance(color.g)
      + 0.0722 * colorChannelLuminance(color.b)
  }

  function logoSource(surfaceColor) {
    return colorLuminance(surfaceColor || Color.background) >= 0.5
      ? Qt.resolvedUrl("assets/OpenAI-black-monoblossom.svg")
      : Qt.resolvedUrl("assets/OpenAI-white-monoblossom.svg")
  }

  function capacityColor(rateWindow) {
    var remaining = Model.remainingPercent(rateWindow)
    return remaining !== null && remaining <= 20 ? urgent : Color.accent
  }

  function resetText(rateWindow) {
    var seconds = Model.resetAfterSeconds(rateWindow, now)
    return seconds === null
      ? qsTr("Reset time unavailable")
      : qsTr("Resets in %1").arg(Model.durationText(seconds))
  }

  function windowText(rateWindow) {
    return rateWindow && rateWindow.windowDurationMins !== null
      ? qsTr("%1-minute window").arg(rateWindow.windowDurationMins)
      : qsTr("Usage window")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onCodexUsageChanged: syncServiceSettings()
  onSettingsChanged: syncServiceSettings()
  onOpenedChanged: {
    if (!opened) return
    syncServiceSettings()
    if (codexUsage) codexUsage.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = Date.now()
  }

  Item {
    id: button

    readonly property bool vertical: root.bar ? root.bar.vertical : false
    readonly property int barSize: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal
    readonly property bool loading: root.codexUsage && root.codexUsage.refreshing
    property var registeredBar: null

    implicitWidth: vertical ? barSize : chipRow.implicitWidth + Style.space(12)
    implicitHeight: vertical ? Math.max(barSize, chipColumn.implicitHeight + Style.space(2)) : barSize

    function triggerPress(buttonCode) {
      if (root.bar) root.bar.hideTooltip(button)
      if (buttonCode === Qt.MiddleButton) {
        if (root.codexUsage) root.codexUsage.refresh()
      } else {
        root.toggle()
      }
    }

    function syncClickRegistration() {
      if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(button)
      registeredBar = root.bar
      if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(button)
    }

    Component.onCompleted: syncClickRegistration()
    Component.onDestruction: if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(button)

    Connections {
      target: root
      function onBarChanged() { button.syncClickRegistration() }
    }

    Row {
      id: chipRow

      visible: !button.vertical
      anchors.centerIn: parent
      spacing: Style.space(5)

      Image {
        source: root.logoSource(root.bar ? root.bar.background : Color.bar.background)
        width: Style.space(15)
        height: Style.space(15)
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        opacity: button.loading ? 0.45 : 1
      }

      Text {
        text: Model.remainingText(root.primaryWindow)
        color: root.primaryWindow && Model.remainingPercent(root.primaryWindow) <= 20 ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Column {
      id: chipColumn

      visible: button.vertical
      anchors.centerIn: parent
      spacing: Style.space(1)

      Image {
        source: root.logoSource(root.bar ? root.bar.background : Color.bar.background)
        width: Style.space(14)
        height: Style.space(14)
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        opacity: button.loading ? 0.45 : 1
        anchors.horizontalCenter: parent.horizontalCenter
      }

      Text {
        width: button.barSize
        text: Model.remainingText(root.primaryWindow)
        color: root.primaryWindow && Model.remainingPercent(root.primaryWindow) <= 20 ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: if (root.bar) root.bar.showTooltip(button, root.buttonTooltip)
      onExited: if (root.bar) root.bar.hideTooltip(button)
      onClicked: function(mouse) { button.triggerPress(mouse.button) }
    }
  }

  KeyboardPanel {
    id: panel

    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(480))

    PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      onActivateRequested: if (root.codexUsage) root.codexUsage.refresh()
      onCloseRequested: root.close()
      onTextKey: function(text) {
        if ((text === "r" || text === "R") && root.codexUsage) root.codexUsage.refresh()
      }

      Column {
        id: content

        width: parent.width
        spacing: Style.space(12)

        Item {
          width: parent.width
          implicitHeight: Math.max(hero.implicitHeight, refresh.implicitHeight)

          PanelHero {
            id: hero

            anchors.left: parent.left
            anchors.right: refresh.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            title: qsTr("Codex capacity")
            meta: root.codexUsage && root.codexUsage.planType !== "" ? root.codexUsage.planType : qsTr("ChatGPT plan")
            detail: root.primaryWindow ? qsTr("%1 remaining").arg(Model.remainingText(root.primaryWindow)) : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Item {
                implicitWidth: Style.space(34)
                implicitHeight: Style.space(34)

                Image {
                  anchors.centerIn: parent
                  width: Style.space(30)
                  height: Style.space(30)
                  source: root.logoSource(Color.popups.background)
                  sourceSize.width: width
                  sourceSize.height: height
                  fillMode: Image.PreserveAspectFit
                }
              }
            }
          }

          PanelActionButton {
            id: refresh

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "R"
            tooltipText: qsTr("Refresh capacity")
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: root.codexUsage && !root.codexUsage.refreshing
            onClicked: root.codexUsage.refresh()
          }
        }

        Text {
          visible: root.codexUsage && !root.primaryWindow
          width: parent.width
          text: root.codexUsage ? root.codexUsage.statusText : qsTr("Starting Codex capacity service...")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          visible: root.codexUsage && root.codexUsage.lastError !== ""
          width: parent.width
          text: root.codexUsage ? root.codexUsage.lastError : ""
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        CapacityCard {
          width: parent.width
          title: qsTr("Primary window")
          rateWindow: root.primaryWindow
          visible: rateWindow !== null
        }

        CapacityCard {
          width: parent.width
          title: qsTr("Secondary window")
          rateWindow: root.secondaryWindow
          visible: rateWindow !== null
        }

        Text {
          visible: root.codexUsage && root.primaryWindow && root.codexUsage.limitReached
          width: parent.width
          text: qsTr("Codex reports that this limit has been reached.")
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          visible: root.primaryWindow !== null
          width: parent.width
          text: qsTr("Press R to refresh")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }

  component CapacityCard: BorderSurface {
    id: capacityCard

    property string title: ""
    property var rateWindow: null
    readonly property real remaining: Model.remainingPercent(rateWindow) || 0
    readonly property bool lowCapacity: remaining <= 20
    readonly property color capacityColor: root.capacityColor(rateWindow)

    implicitHeight: cardContent.implicitHeight + Style.space(24)
    color: Style.normalFillFor(root.foreground, Color.accent)
    borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
    radius: Style.cornerRadius

    Column {
      id: cardContent

      anchors.fill: parent
      anchors.margins: Style.space(12)
      spacing: Style.space(7)

      Item {
        width: parent.width
        implicitHeight: Math.max(windowTitle.implicitHeight, remainingValue.implicitHeight)

        Column {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)

          Text {
            id: windowTitle

            text: capacityCard.title
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            text: root.windowText(capacityCard.rateWindow)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Column {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0

          Text {
            id: remainingValue

            text: Model.remainingText(capacityCard.rateWindow)
            color: capacityCard.capacityColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
            horizontalAlignment: Text.AlignRight
          }

          Text {
            text: qsTr("remaining")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
          }
        }
      }

      Rectangle {
        width: parent.width
        height: Style.space(8)
        radius: height / 2
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)

        Rectangle {
          width: parent.width * capacityCard.remaining / 100
          height: parent.height
          radius: height / 2
          color: capacityCard.capacityColor
        }
      }

      Item {
        width: parent.width
        implicitHeight: Math.max(reset.implicitHeight, capacityWarning.implicitHeight)

        Text {
          id: reset

          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: root.resetText(capacityCard.rateWindow)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          id: capacityWarning

          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          visible: capacityCard.lowCapacity
          text: qsTr("Low capacity")
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }
  }
}
