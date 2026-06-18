import QtQuick
import Quickshell
import Quickshell.Io
import "Data.js" as Data

// Persistent favourites + history under $XDG_CACHE. Ctrl+S stars,
// item activation records, both arrays serialize to one JSON file.
Item {
    id: bookmarks

    property var favourites: []
    property var history: []
    readonly property int historyCap: 50
    readonly property string statePath: Quickshell.env("HOME") + "/.cache/quickshell/omni-menu/state.json"

    readonly property var favouriteItems: Data.annotate(bookmarks.favourites)
    readonly property var historyItems: Data.annotate(bookmarks.history)

    // O(1) star check from row delegates — rebuilds only when the
    // favourites list itself changes, not on every binding eval.
    readonly property var favouriteKeys: {
        const out = {};
        for (let i = 0; i < bookmarks.favourites.length; i++) {
            out[Data.itemKey(bookmarks.favourites[i])] = true;
        }
        return out;
    }

    function snapshot(item) {
        return {
            title: item.title || "",
            icon: item.icon || "",
            category: item.category || "",
            exec: item.exec || "",
            path: item.path || "",
            keywords: item.keywords || "",
            rawCategory: !!item.rawCategory,
            tui: item.tui || ""
        };
    }

    function isFavourite(item) {
        return !!bookmarks.favouriteKeys[Data.itemKey(item)];
    }

    function toggleFavourite(item) {
        if (!item) return;
        const k = Data.itemKey(item);
        if (!k) return;
        const next = [];
        let found = false;
        for (let i = 0; i < bookmarks.favourites.length; i++) {
            if (Data.itemKey(bookmarks.favourites[i]) === k) found = true;
            else next.push(bookmarks.favourites[i]);
        }
        if (!found) next.unshift(bookmarks.snapshot(item));
        bookmarks.favourites = next;
        bookmarks.save();
    }

    function record(item) {
        // Drill-in nav rows recorded would just rehash the category list.
        if (!item || item.isCategory) return;
        const k = Data.itemKey(item);
        if (!k) return;
        const next = [bookmarks.snapshot(item)];
        for (let i = 0; i < bookmarks.history.length && next.length < bookmarks.historyCap; i++) {
            if (Data.itemKey(bookmarks.history[i]) !== k) {
                next.push(bookmarks.history[i]);
            }
        }
        bookmarks.history = next;
        bookmarks.save();
    }

    function clearHistory() {
        bookmarks.history = [];
        bookmarks.save();
    }

    function save() {
        const payload = JSON.stringify({
            favourites: bookmarks.favourites,
            history: bookmarks.history
        });
        // Positional argv keeps the path and JSON body argv-safe even
        // if a starred file path contains `$` or backticks.
        saveProc.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
            "sh", bookmarks.statePath, payload];
        saveProc.running = false;
        saveProc.running = true;
    }

    Process { id: saveProc; running: false; command: ["true"] }

    FileView {
        id: stateFile
        path: bookmarks.statePath
        onLoaded: {
            try {
                const data = JSON.parse(stateFile.text());
                bookmarks.favourites = data.favourites || [];
                bookmarks.history = data.history || [];
            } catch (_) {}
        }
    }
}
