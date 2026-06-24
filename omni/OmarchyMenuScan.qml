import QtQuick
import Quickshell
import Quickshell.Io
import "Data.js" as Data

// Watches the same JSONC menu sources as the first-party Omarchy menu and
// converts them into Omni rows. The old static index remains a fallback when
// the menu files cannot be parsed.
Item {
    id: menuScan

    property var items: Data.annotate(Data.omarchyItems)
    property bool loaded: false

    readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || (Quickshell.env("HOME") + "/.local/share/omarchy")
    readonly property string defaultMenuPath: omarchyPath + "/default/omarchy/omarchy-menu.jsonc"
    readonly property string userMenuPath: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"

    property var defaultMenuItems: []
    property var userMenuItems: []
    property var menuItems: ({})
    property var itemOrder: []
    property var whenResults: ({})
    property var checkedResults: ({})
    property int guardRevision: 0

    signal scanned()

    function refresh() {
        defaultMenuFile.reload();
        userMenuFile.reload();
    }

    function refreshGuards() {
        menuScan.evaluateGuards();
    }

    function shellQuote(value) {
        return "'" + String(value || "").replace(/'/g, "'\\''") + "'";
    }

    function rebuildItemsFromSources() {
        const merged = Data.mergeMenuSources(menuScan.defaultMenuItems,
                                             menuScan.userMenuItems);
        menuScan.menuItems = merged.items;
        menuScan.itemOrder = merged.itemOrder;
        menuScan.loaded = true;
        menuScan.evaluateGuards();
    }

    function applyRows() {
        const rows = Data.omarchyMenuRows(menuScan.menuItems,
                                          menuScan.itemOrder,
                                          menuScan.whenResults,
                                          menuScan.checkedResults);
        const source = rows.length > 0
            ? rows.concat(Data.omniExtraItems())
            : Data.omarchyItems;
        menuScan.items = Data.annotate(source);
        menuScan.scanned();
    }

    function evaluateGuards() {
        let script = "";
        for (let i = 0; i < menuScan.itemOrder.length; i++) {
            const id = menuScan.itemOrder[i];
            const entry = menuScan.menuItems[id];
            if (!entry) continue;
            const quotedId = menuScan.shellQuote(id);
            if (entry.when) {
                script += "if " + entry.when + " >/dev/null 2>&1; then printf '%s\\tw\\t1\\n' " + quotedId + "; else printf '%s\\tw\\t0\\n' " + quotedId + "; fi\n";
            }
            if (entry.checked) {
                script += "if " + entry.checked + " >/dev/null 2>&1; then printf '%s\\tc\\t1\\n' " + quotedId + "; else printf '%s\\tc\\t0\\n' " + quotedId + "; fi\n";
            }
        }

        menuScan.guardRevision += 1;
        if (script.length === 0) {
            menuScan.whenResults = ({});
            menuScan.checkedResults = ({});
            menuScan.applyRows();
            return;
        }

        guardProc.running = false;
        guardProc.revision = menuScan.guardRevision;
        guardProc.command = ["bash", "-lc", script];
        guardProc.running = true;
    }

    function applyGuardResults(text, revision) {
        if (revision !== menuScan.guardRevision) return;
        const nextWhen = ({});
        const nextChecked = ({});
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;
            const parts = line.split("\t");
            if (parts.length < 3) continue;
            const value = parts[2] === "1";
            if (parts[1] === "w") nextWhen[parts[0]] = value;
            else if (parts[1] === "c") nextChecked[parts[0]] = value;
        }
        menuScan.whenResults = nextWhen;
        menuScan.checkedResults = nextChecked;
        menuScan.applyRows();
    }

    Process {
        id: guardProc
        property int revision: 0
        running: false
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: menuScan.applyGuardResults(this.text, guardProc.revision)
        }
    }

    FileView {
        id: defaultMenuFile
        path: menuScan.defaultMenuPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            menuScan.defaultMenuItems = Data.parseMenuJsonc(text());
            menuScan.rebuildItemsFromSources();
        }
        onLoadFailed: {
            menuScan.defaultMenuItems = [];
            menuScan.rebuildItemsFromSources();
        }
        onFileChanged: reload()
    }

    FileView {
        id: userMenuFile
        path: menuScan.userMenuPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            menuScan.userMenuItems = Data.parseMenuJsonc(text());
            menuScan.rebuildItemsFromSources();
        }
        onLoadFailed: {
            menuScan.userMenuItems = [];
            menuScan.rebuildItemsFromSources();
        }
        onFileChanged: reload()
    }
}
