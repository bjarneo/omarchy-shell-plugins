import QtQuick

// Search row: magnifier glyph, current query (or mode-specific
// placeholder), and a blinking caret.
Item {
    id: input
    required property var omni

    width: parent ? parent.width : 0
    height: 34

    Text {
        id: searchPrompt
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: input.omni.fileMode ? "󰉖"
              : input.omni.githubMode ? "󰊤"
              : input.omni.themeMode ? "󰸌"
              : "󰍉"
        color: input.omni.selectedForeground
        font.family: input.omni.mono
        font.pixelSize: 16 * input.omni.fontScale
    }

    Text {
        id: queryText
        anchors.left: searchPrompt.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: {
            const o = input.omni;
            if (o.query.length > 0) return o.query;
            if (o.fileMode)  return "Type to search files in ~ …";
            if (o.githubMode) return "Your PRs · type to search GitHub repos";
            if (o.themeMode) return "Type to filter themes…";
            return "Type to search apps, themes, settings…";
        }
        color: input.omni.query.length === 0 ? input.omni.mutedForeground : input.omni.foreground
        opacity: input.omni.query.length === 0 ? 0.5 : 1.0
        font.family: input.omni.mono
        font.pixelSize: 14 * input.omni.fontScale
        font.letterSpacing: 1
        elide: Text.ElideRight
        clip: true
    }

    // Blinking caret riding the end of the query.
    Rectangle {
        id: caret
        width: 2
        height: 16
        color: input.omni.selectedForeground
        anchors.verticalCenter: parent.verticalCenter
        x: input.omni.query.length === 0
           ? searchPrompt.x + searchPrompt.width + 10
           : Math.min(queryText.x + queryText.contentWidth + 2,
                      input.width - caret.width)
        visible: input.omni.visible_
        SequentialAnimation on opacity {
            running: input.omni.visible_
            loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.2; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.2; to: 1; duration: 600; easing.type: Easing.InOutSine }
        }
    }
}
