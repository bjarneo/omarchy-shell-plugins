import QtQuick
import QtQuick.Effects

// Vertical result list. Row delegate handles icon resolution (image
// fallback to glyph), title with drill-in chevron, favourite star, and
// category label. `list` is aliased so the parent's key handler can
// call positionViewAtIndex without reaching through child ids.
Item {
    id: rl

    required property var omni
    required property var bookmarks
    required property var processes
    required property var themes
    required property var ollamaChat

    property alias list: resultList

    ListView {
        id: resultList
        anchors.fill: parent
        model: rl.omni.filteredItems
        currentIndex: rl.omni.selectedIndex
        highlightFollowsCurrentItem: false
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 200
        // Snap pixel-perfect so the row outline doesn't shimmer during
        // arrow-key scroll.
        pixelAligned: true

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            width: ListView.view.width
            height: 38
            readonly property bool isSelected: rl.omni.selectedIndex === index

            Rectangle {
                anchors.fill: parent
                color: row.isSelected ? rl.omni.rowSel
                                      : rowMouse.containsMouse ? rl.omni.rowHi
                                                               : "transparent"
                Behavior on color { ColorAnimation { duration: 40 } }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 2
                color: rl.omni.seal
                visible: row.isSelected
            }

            // Icon slot: tinted .desktop image when one resolves,
            // nerd-font glyph fallback otherwise. hasImageIcon flips
            // on Image.Ready so the swap happens in one frame, no
            // broken-icon flash.
            Item {
                id: iconText
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22

                readonly property string iconUrl: rl.omni.resolveIconUrl(row.modelData.rawIcon)
                readonly property bool hasImageIcon: appImg.status === Image.Ready && iconUrl !== ""
                readonly property color tint: row.isSelected ? rl.omni.seal : rl.omni.inkDeep

                Text {
                    anchors.centerIn: parent
                    visible: !iconText.hasImageIcon
                    text: row.modelData.icon || "·"
                    color: iconText.tint
                    font.family: rl.omni.mono
                    font.pixelSize: 16 * rl.omni.fontScale
                }

                // Hidden because MultiEffect draws the recoloured copy;
                // layer.enabled hands it a texture to sample without
                // committing a full FBO until an icon actually resolves.
                Image {
                    id: appImg
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    visible: false
                    source: iconText.iconUrl
                    sourceSize.width: 36
                    sourceSize.height: 36
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    cache: true
                    layer.enabled: iconText.hasImageIcon
                }
                // colorization: 1.0 paints solid colour through the
                // source's alpha - a flat tinted silhouette in the
                // ink/seal palette.
                MultiEffect {
                    anchors.fill: appImg
                    visible: iconText.hasImageIcon
                    source: appImg
                    colorization: 1.0
                    colorizationColor: iconText.tint
                    Behavior on colorizationColor { ColorAnimation { duration: 40 } }
                }
            }
            Text {
                id: titleText
                anchors.left: iconText.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                // Trailing chevron flags drill-in rows so you can tell
                // at a glance which Enters drill in vs. which Enters
                // execute.
                text: row.modelData.isCategory
                      ? row.modelData.title + "  ›"
                      : row.modelData.title
                color: row.isSelected ? rl.omni.ink : rl.omni.fg
                font.family: rl.omni.mono
                font.pixelSize: 13 * rl.omni.fontScale
                font.weight: row.isSelected ? Font.Medium : Font.Light
                font.letterSpacing: 1
                elide: Text.ElideRight
                width: row.width - iconText.width - catText.implicitWidth - 60
            }
            Text {
                id: starText
                anchors.right: catText.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: rl.bookmarks.isFavourite(row.modelData)
                text: "󰓎"
                color: rl.omni.seal
                font.family: rl.omni.mono
                font.pixelSize: 11 * rl.omni.fontScale
            }
            Text {
                id: catText
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                // File rows show the dirname here, which shouldn't be
                // uppercased or letter-spaced. Cap the width so a deep
                // path doesn't push the title text off the row.
                text: row.modelData.rawCategory
                      ? (row.modelData.category || "")
                      : (row.modelData.category || "").toUpperCase()
                color: row.isSelected ? rl.omni.seal : rl.omni.inkDeep
                opacity: row.isSelected ? 0.95 : 0.65
                font.family: rl.omni.mono
                font.pixelSize: 10 * rl.omni.fontScale
                font.letterSpacing: row.modelData.rawCategory ? 0 : 2
                elide: Text.ElideLeft
                horizontalAlignment: Text.AlignRight
                width: row.modelData.rawCategory
                       ? Math.min(implicitWidth, row.width * 0.45)
                       : implicitWidth
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // onPositionChanged fires only on actual cursor
                // movement; onEntered would also fire when rows shift
                // under a stationary cursor (after a query change,
                // drill-in, or rescore), stealing keyboard focus.
                onPositionChanged: rl.omni.selectedIndex = row.index
                onClicked: rl.omni.activate(row.modelData)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: resultList.count === 0
            text: {
                const o = rl.omni;
                if (o.tldrMode) {
                    if (o.tldrTool.length === 0) return "TLDR COMMAND  ·  TYPE TOOL NAME";
                    if (o.tldrRunning) return "FETCHING TLDR…";
                    return "NO TLDR PAGE";
                }
                if (o.llmMode) {
                    const cmd = o.cmdMode;
                    if (o.chatPrompt.length === 0)
                        return cmd ? "$ SHELL TASK  ·  LOCAL AI"
                                   : "? QUESTION  ·  LOCAL AI";
                    if (o.chatStatus === "")    return "CHECKING OLLAMA…";
                    if (o.chatStatus !== "ok")  return "OLLAMA SETUP NEEDED";
                    if (!o.chatSubmitted)        return cmd ? "↵ TO GENERATE" : "↵ TO ASK";
                    if (o.chatRunning)           return "STREAMING…";
                    return cmd ? "READY  ·  EDIT TO REGENERATE"
                               : "READY  ·  EDIT TO ASK AGAIN";
                }
                if (o.fileMode) {
                    if (o.query.length === 0) return "TYPE TO SEARCH ~";
                    if (o.fdRunning) return "SEARCHING…";
                    return "NO FILES MATCH";
                }
                if (o.ghMode) {
                    if (o.query.length === 0) {
                        return o.ghRunning ? "LOADING PRS…" : "NO OPEN PRS";
                    }
                    if (o.ghRunning) return "SEARCHING GITHUB…";
                    return "NO REPOS MATCH";
                }
                if (o.favMode)  return "NO FAVOURITES — CTRL+S TO STAR";
                if (o.histMode) return "NO HISTORY YET";
                if (o.procMode)  return rl.processes.running ? "LOADING…" : "NO PROCESSES";
                if (o.themeMode) return rl.themes.loaded ? "NO THEMES MATCH" : "LOADING THEMES…";
                return o.appsLoaded ? "NOTHING MATCHES" : "INDEXING APPS…";
            }
            color: rl.omni.inkDeep
            font.family: rl.omni.mono
            font.pixelSize: 11 * rl.omni.fontScale
            font.letterSpacing: 3
            opacity: 0.6
        }
    }
}
