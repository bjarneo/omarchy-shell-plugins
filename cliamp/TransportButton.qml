import QtQuick

// Borderless transport button with hover color shift.
Item {
    id: root

    property string shape: "play"
    property color fgColor: "#d4be98"
    property color hoverColor: "#d8a657"
    property bool enabled: true
    property real iconSize: 14
    property bool hovered: false

    signal activated()

    implicitWidth: iconSize + 12
    implicitHeight: iconSize + 8

    MediaIcon {
        anchors.centerIn: parent
        shape: root.shape
        size: root.iconSize
        color: root.hovered && root.enabled ? root.hoverColor : root.fgColor
        opacity: root.enabled ? 1.0 : 0.35
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: if (root.enabled) root.activated()
    }
}
