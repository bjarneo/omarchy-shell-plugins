import QtQuick

// Top section of the OmniMenu card: title + live result count on a
// single row.
Item {
    id: header

    required property var omni
    property var processes: null
    property var themes:    null
    property var bookmarks: null

    width: parent ? parent.width : 0
    // Track the title's actual rendered height so user-driven font
    // scaling (Ctrl++ / Ctrl+-) doesn't clip ascenders/descenders.
    height: Math.max(30, title.implicitHeight + 4)

    Text {
        id: title
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: header.omni.categoryFilter === ""
              ? "OMNI"
              : "OMNI › " + header.omni.sectionIcon + "  " + header.omni.categoryFilter.toUpperCase()
        color: header.omni.ink
        font.family: header.omni.mono
        font.pixelSize: 19 * header.omni.fontScale
        font.letterSpacing: 4
        font.weight: Font.Medium
    }

    Text {
        anchors.left: title.right
        anchors.leftMargin: 18
        anchors.baseline: title.baseline
        text: {
            const o = header.omni;
            if (!o.appsLoaded) return "LOADING APPS…";
            if (o.fileMode) {
                if (o.query.length === 0) return "TYPE TO SEARCH ~";
                if (o.fdRunning) return "SEARCHING…";
                const total = o.filteredItems.length;
                return total === 0
                    ? "NO FILES MATCH"
                    : total + " FILE" + (total === 1 ? "" : "S");
            }
            if (o.ghMode) {
                const total = o.filteredItems.length;
                if (o.query.length === 0) {
                    if (o.ghRunning && total === 0) return "LOADING PRS…";
                    return total === 0
                        ? "NO OPEN PRS"
                        : total + " OPEN PR" + (total === 1 ? "" : "S");
                }
                if (o.ghRunning) return "SEARCHING GITHUB…";
                return total === 0
                    ? "NO REPOS MATCH"
                    : total + " REPO" + (total === 1 ? "" : "S");
            }
            if (o.favMode) {
                const total = o.filteredItems.length;
                return total === 0
                    ? "NO FAVOURITES YET  ·  CTRL+S TO STAR"
                    : total + " FAVOURITE" + (total === 1 ? "" : "S");
            }
            if (o.histMode) {
                const total = o.filteredItems.length;
                return total === 0
                    ? "NO HISTORY YET"
                    : total + " RECENT" + (total === 1 ? "" : "S");
            }
            if (o.procMode) {
                const total = o.filteredItems.length;
                if (header.processes && header.processes.running && total === 0) return "LOADING PROCESSES…";
                return total === 0
                    ? "NO PROCESSES"
                    : total + " PROCESS" + (total === 1 ? "" : "ES");
            }
            if (o.themeMode) {
                const total = o.filteredItems.length;
                if (header.themes && !header.themes.loaded && total === 0) return "LOADING THEMES…";
                return total === 0
                    ? "NO THEMES FOUND"
                    : total + " THEME" + (total === 1 ? "" : "S");
            }
            const total = o.filteredItems.length;
            if (o.query.length === 0) {
                return total + " ENTRIES  ·  " + o.allItems.length + " TOTAL";
            }
            return total === 0
                ? "NO MATCHES"
                : total + " MATCH" + (total === 1 ? "" : "ES");
        }
        color: header.omni.inkDeep
        font.family: header.omni.mono
        font.pixelSize: 11 * header.omni.fontScale
        font.letterSpacing: 2
    }
}
