import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "Data.js" as Data
import "components" as Omni

// Omni-menu palette. Fuses installed apps (.desktop scan) with every
// `omarchy-menu` action, scored against title, category, and per-entry
// synonyms (so "wallpaper" finds Background, "reboot" finds Restart).
// Drill-down rows pivot the list to a category, fd file search, GitHub repo
// search, processes, or themes. Toggle via:
//   omarchy-shell shell toggle omni '{}'
//
// Source layout: this file is the entry and keeps all state (search
// index, scoring, mode flags, IPC, shortcuts, the keyboard handler,
// and the panel chrome). Visual subtrees live alongside in `components/`:
//   components/HeaderBar.qml       title + count + hint
//   components/SearchInput.qml     prompt glyph + query text + caret
//   components/ResultList.qml      ListView + row delegate
//   components/PreviewPane.qml     preview header + body for all modes
//   components/Footer.qml          exec line for the selected item
//   components/Format.js           markdown formatters (tldr, chat)
Item {
    id: root

    property var shell: null
    property var manifest: null
    readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "omni"

    Theme { id: themeState }
    property var theme: themeState

    // Kept as an optional extension point for users who embed Omni beside a
    // compatible telemetry provider. The repo plugin runs standalone and does
    // not require the desktop/navbar quickshell config.
    property var navbar: null

    readonly property color background: theme.background
    readonly property color foreground: theme.foreground
    readonly property color mutedForeground: theme.mutedForeground
    readonly property color accent: theme.accent
    readonly property color hoverForeground: theme.hoverForeground
    readonly property color selectedForeground: theme.selectedForeground
    readonly property color selectionForeground: theme.selectionForeground
    readonly property color border: theme.border
    readonly property color hoverFill: theme.hoverFill
    readonly property color selectedFill: theme.selectedFill

    // Scoring weights and result cap. omarchy-menu has ~125 entries plus the
    // 12 nav rows plus ~80-200 .desktop apps, so the cap lets a quick
    // page-down still reach near-matches without overdrawing.
    readonly property int scPrefix: 100
    readonly property int scTitle:  60
    readonly property int scKw:     20
    readonly property int scCat:    10
    readonly property int maxResults: 250

    readonly property string mono:  theme.mono
    readonly property string serif: theme.serif

    readonly property int cornerRadius: theme.cornerRadius

    // Sources that feed `allItems`. AppScan reads .desktop files;
    // NavbarApps probes the navbar shell for its IpcHandler widgets and
    // surfaces only the ones it actually exposes (so users on a
    // navbar-less setup see nothing instead of broken rows).
    AppScan { id: appScan }
    OmarchyMenuScan {
        id: omarchyMenu
        onScanned: root.omarchy = omarchyMenu.items
    }
    NavbarApps { id: navbarApps }
    Tuis { id: tuis }
    readonly property alias appsLoaded: appScan.loaded

    // ---------- Visibility / state ----------
    // Trailing underscore avoids shadowing Item.visible — read by the
    // PanelWindow's visibility binding below.
    property bool visible_: false
    property bool opened: false
    property string query: ""
    property int selectedIndex: 0
    // Active drill-down. "" means root (category navigators + everything
    // searchable); any other value pins the list to that category. Set by
    // activating a category nav row; cleared by Esc / Backspace-on-empty.
    property string categoryFilter: ""

    // File and GitHub search drills reuse the category machinery: the
    // Files/GitHub nav rows set categoryFilter to one of Data's sentinels,
    // filteredItems pivots to the matching results array, and goUp/Esc
    // unwind via the same path as any other category.
    readonly property bool fileMode: root.categoryFilter === Data.fileCategory
    readonly property bool githubMode: root.categoryFilter === Data.githubCategory
    readonly property bool favMode:  root.categoryFilter === Data.favCategory
    readonly property bool histMode: root.categoryFilter === Data.histCategory
    readonly property bool procMode:  root.categoryFilter === Data.procCategory
    readonly property bool themeMode: root.categoryFilter === Data.themeCategory
    // In the standalone plugin, Quick is a normal command category. The rich
    // live-tile grid belongs to the personal desktop config because it depends
    // on that bar's telemetry object.
    readonly property bool quickMode: false
    // Query-shape modes. Each triggers off the query string directly,
    // so the user can pivot in from any drill without going back to
    // root.
    //   `tldr <name>` -> inline tldr preview
    //   `? <q>`       -> local Ollama chat preview (qwen3.5:0.8b)
    //   `$ <task>`    -> same model, but constrained to emit a shell
    //                    command for the described task
    readonly property bool tldrMode:
        root.query === "tldr" || root.query.substring(0, 5) === "tldr "
    readonly property bool chatMode: root.query.charAt(0) === "?"
    readonly property bool cmdMode:  root.query.charAt(0) === "$"
    // Either of the two LLM-backed modes - share the single OllamaChat
    // instance below, differing only by system prompt.
    readonly property bool llmMode:  root.chatMode || root.cmdMode
    // Live font multiplier — every `font.pixelSize` binding in this
    // file multiplies its base by this value. Ctrl++ / Ctrl+- nudge
    // it in 0.1 steps; Ctrl+= resets to 1.0. Clamped to keep the
    // panel usable at extremes.
    property real fontScale: 1.0
    function bumpFontScale(delta) {
        const next = Math.max(0.7, Math.min(2.0, root.fontScale + delta));
        // Snap to one decimal so successive bumps don't drift on
        // floating-point round-off.
        root.fontScale = Math.round(next * 10) / 10;
    }
    // null = no expansion; otherwise the tile object whose detail panel
    // is currently revealed under the grid.
    property var expandedTile: null
    // Single source of truth for "in Quick mode with a tile open" — the
    // grid column count, the compressed-tile flag, and the side-panel
    // visibility all key off it.
    readonly property bool quickExpanded: quickMode && expandedTile !== null
    readonly property int  quickGridCols: quickExpanded ? 1 : 4
    function expandTile(t) {
        if (!t) { root.expandedTile = null; return; }
        // Click same tile to collapse; click a different tile to swap.
        root.expandedTile = (root.expandedTile && root.expandedTile.key === t.key)
                            ? null : t;
    }
    function collapseTile() { root.expandedTile = null; }

    Bookmarks { id: bookmarks }

    // ---------- Quick tile compatibility stubs ----------
    // The upstream desktop version uses these for its telemetry grid. Keep
    // inert versions so the key handler/state machine can stay shared.
    readonly property var quickTilesBase: []
    property var _quickTilesDynCache: ({})
    readonly property var quickTilesDyn: ({})

    // Resolve the dynamic side of a base tile. Returns an empty object
    // (not undefined) so delegate bindings can chain `.glyph` / `.sub`
    // without an `?.` chain on every read.
    function tileDyn(t) { return (t && root.quickTilesDyn[t.key]) || ({}); }

    // No search field in quickMode — tiles are always the full set so
    // grid arithmetic (gridCols * row) stays predictable. Kept as a
    // separate property so non-quick code paths don't need to branch.
    readonly property var filteredQuickTiles: []

    // Same launch envelope as activate() so popup IPCs (qs ipc call …)
    // get fired off-process and quickshell can close immediately.
    function activateQuickTile(t) {}

    // Long-press / right-click hook. Stays open so a "refresh weather"
    // or "reset display" doesn't dismiss the panel mid-glance.
    function longQuickTile(t) {}

    // GitHub CLI-backed repo search and pull-request preview.
    GitHubSearch {
        id: githubSearch
        query: root.query
        active: root.githubMode && !root.tldrMode && !root.llmMode
        selectedItem: root.filteredItems[root.selectedIndex] || null
    }
    readonly property alias githubReady:        githubSearch.ready
    readonly property alias githubItems:        githubSearch.items
    readonly property alias githubRunning:      githubSearch.running
    readonly property alias githubPreviewTitle: githubSearch.previewTitle
    readonly property alias githubPreviewUrl:   githubSearch.previewUrl
    readonly property alias githubPreviewText:  githubSearch.previewText

    readonly property string sectionIcon: {
        if (root.categoryFilter === "") return "";
        for (let i = 0; i < Data.categoryNav.length; i++) {
            if (Data.categoryNav[i].target === root.categoryFilter)
                return Data.categoryNav[i].icon;
        }
        return "";
    }

    // fd-backed file search + file preview. Aliases mirror the prior root
    // properties so the panel UI doesn't have to change wholesale.
    FileSearch {
        id: fileSearch
        query: root.query
        queryTokens: root.queryTokens
        active: root.fileMode && !root.tldrMode && !root.llmMode
        selectedItem: root.filteredItems[root.selectedIndex] || null
    }
    readonly property alias fileItems:    fileSearch.items
    readonly property alias fdRunning:    fileSearch.running
    readonly property alias previewPath:  fileSearch.previewPath
    readonly property alias previewText:  fileSearch.previewText
    readonly property alias previewMeta:  fileSearch.previewMeta
    readonly property alias previewKind:  fileSearch.previewKind

    Processes {
        id: processes
        active: root.procMode && !root.tldrMode && !root.llmMode
        selectedItem: root.filteredItems[root.selectedIndex] || null
    }
    readonly property alias procItems:    processes.items
    readonly property alias procRunning:  processes.running
    readonly property alias procPreviewText: processes.previewText
    readonly property alias procPreviewPid:  processes.previewPid

    Themes {
        id: themes
        active: root.themeMode && !root.tldrMode && !root.llmMode
    }
    readonly property alias themeItems:   themes.items
    readonly property alias themeLoaded:  themes.loaded

    // tldr-backed CLI help preview. Triggered by `$ <name>` in the query.
    TldrSearch {
        id: tldrSearch
        query: root.query
        active: root.tldrMode
    }
    readonly property alias tldrItems:    tldrSearch.items
    readonly property alias tldrRunning:  tldrSearch.running
    readonly property alias tldrPreview:  tldrSearch.previewText
    readonly property alias tldrTool:     tldrSearch.toolName

    // Local-LLM preview. Triggered by `? <question>` (chat) or
    // `$ <task>` (command). The mode property steers the system
    // prompt and the placeholder copy; everything else (probe,
    // streaming, unload-on-leave) is shared.
    OllamaChat {
        id: ollamaChat
        query: root.query
        active: root.llmMode
        mode: root.cmdMode ? "command" : "chat"
    }
    readonly property alias chatItems:     ollamaChat.items
    readonly property alias chatRunning:   ollamaChat.running
    readonly property alias chatPreview:   ollamaChat.previewText
    readonly property alias chatStatus:    ollamaChat.status
    readonly property alias chatPrompt:    ollamaChat.prompt
    readonly property alias chatSubmitted: ollamaChat.submitted
    readonly property alias chatModel:     ollamaChat.model_

    readonly property bool previewActive: root.tldrMode || root.llmMode || root.fileMode || root.githubMode || root.procMode || root.themeMode
    readonly property bool previewHasContent: {
        if (root.tldrMode) return root.tldrPreview !== "";
        if (root.llmMode) {
            // Probing: no content yet. Status != "ok": show the
            // install/start/pull hint as content. OK + not submitted:
            // empty (the placeholder hint shows). OK + submitted:
            // there's a streaming or completed answer.
            if (root.chatStatus === "") return false;
            if (root.chatStatus !== "ok") return true;
            if (!root.chatSubmitted) return false;
            return root.chatPreview !== "";
        }
        if (root.fileMode || root.githubMode)
            return root.previewPath !== "" || root.githubPreviewUrl !== "";
        if (root.procMode) return processes.previewPid !== "";
        if (root.themeMode) {
            const it = root.filteredItems[root.selectedIndex];
            return !!(it && it.swatches && it.swatches.length > 0);
        }
        return false;
    }

    readonly property string homeDir: Quickshell.env("HOME")

    function open(payloadJson) {
        let payload = ({});
        try { payload = JSON.parse(payloadJson || "{}"); } catch (e) { payload = ({}); }

        root.query = payload.query ? String(payload.query) : "";
        root.selectedIndex = 0;
        root.categoryFilter = payload.category ? String(payload.category)
                            : payload.categoryFilter ? String(payload.categoryFilter)
                            : "";
        root.opened = true;
        root.visible_ = true;
        omarchyMenu.refreshGuards();
        navbarApps.probe();
    }
    function close() {
        root.opened = false;
        root.visible_ = false;
        // Cancel any in-flight stream and zero chat state so the next
        // session starts fresh. The ollama daemon itself is left
        // running — we don't manage its lifecycle, only our use of it.
        ollamaChat.clear();
    }
    function dismiss() {
        root.close();
        if (shell && typeof shell.hide === "function") shell.hide(pluginId);
    }
    function toggle(payloadJson) { if (root.visible_) dismiss(); else open(payloadJson || "{}"); }
    function openCategory(cat) {
        root.open(JSON.stringify({ category: String(cat || "") }));
        return "ok";
    }
    function refresh() {
        appScan.refresh();
        omarchyMenu.refresh();
        return "ok";
    }
    function goUp() {
        // Step back one level. At root this is a no-op so the caller can
        // chain "goUp or close" without a branch.
        if (root.categoryFilter !== "") {
            root.categoryFilter = "";
            root.query = "";
            root.selectedIndex = 0;
            return true;
        }
        return false;
    }

    // Entering or leaving file mode resets fd state. Other category drills
    // share the same handler — clearing both is a free no-op for other drills.
    onCategoryFilterChanged: {
        fileSearch.clear();
        githubSearch.clear();
        tldrSearch.clear();
        ollamaChat.clear();
        // Processes/Themes own their own clear()-on-deactivate via their
        // `active` binding, so the shell doesn't have to nudge them when
        // the filter changes — they react automatically.
    }

    // ---------- Icon resolution ----------
    // `.desktop` Icon field is either a URL, an absolute path, or an
    // icon-theme name. Match Omarchy's launcher resolver so themed icons
    // use the shell's configured fallback path instead of dropping to glyphs.
    function resolveIconUrl(raw) {
        const value = String(raw || "");
        if (value.length === 0) return "";
        if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value;
        if (value.charAt(0) === "/") return "file://" + value;
        return Quickshell.iconPath(value, true);
    }

    // ---------- Search index annotation ----------
    // Annotated indexes. Assigned in Component.onCompleted and in the
    // appScan handler so they stay plain `var` assignments rather than
    // re-evaluating bindings whose dependency graph would re-allocate the
    // 200+ entry array on unrelated property touches.
    property var omarchy: []
    property var nav: []
    readonly property var allItems: root.omarchy.concat(appScan.apps).concat(navbarApps.items).concat(tuis.items).concat(themes.items)

    // ---------- Launcher ----------
    // Matches omarchy's launch convention (see omarchy-launch-or-focus):
    //   setsid -f          fork into a new session, returning immediately
    //                      so quickshell's Process completes; the spawned
    //                      app fully detaches from quickshell's lifetime
    //   uwsm-app -- <cmd>  registers the spawn under a systemd-user scope
    //                      (omarchy convention; gives the app a managed
    //                      unit, proper cgroup, clean logout teardown)
    //   bash -c "<exec>"   lets exec lines with shell syntax (pipes,
    //                      ||, &&, redirects) work alongside plain
    //                      argv-style commands without a special case
    Process { id: runner; running: false }
    function activate(item) {
        if (!item) return;
        if (item.isCategory) {
            root.categoryFilter = item.target;
            root.query = "";
            root.selectedIndex = 0;
            return;
        }
        // Process kill — refresh stays in-mode so you can chain kills.
        if (item.isProcess) {
            processes.killPid(item.pid, false);
            return;
        }
        // Theme apply — fire and forget; omarchy-theme-set rebuilds
        // configs and reloads all the live apps that listen for it.
        if (item.isTheme) {
            runner.command = ["sh", "-c",
                "setsid -f uwsm-app -- omarchy-theme-set \"$1\" >/dev/null 2>&1",
                "sh", item.themeName];
            runner.running = false;
            runner.running = true;
            root.dismiss();
            return;
        }
        // tldr → open a floating terminal with the user's typed text
        // pre-filled at the readline prompt, ready to edit and run.
        // Builds runner.command as argv (no shell-quoting layer) so
        // backticks / $vars / metachars in the query land as literal
        // text in $1 inside the inner bash, never as code. Bypasses
        // bookmarks.record() — tldr lookups aren't apps and shouldn't
        // pollute history or favourites.
        // ollama chat → Enter behaviour depends on the readiness state:
        //   no-ollama  no-op (user installs themselves; we don't run a
        //              package manager unprompted)
        //   no-daemon  start the daemon in a floating terminal
        //   no-model   pull qwen3.5:0.8b in a floating terminal
        //   ok+!sub    submit the prompt; preview streams inline,
        //              panel stays open
        //   ok+sub     no-op; user can edit and resubmit, or Esc out
        if (item.isOllama) {
            const status = ollamaChat.status;
            if (status === "no-ollama") {
                // Don't auto-install. The preview body has already
                // told the user what to do.
                return;
            }
            if (status === "no-daemon") {
                runner.command = ["setsid", "-f", "uwsm-app", "--",
                    "xdg-terminal-exec",
                    "--app-id=org.omarchy.terminal",
                    "--title=Omarchy",
                    "-e", "bash", "-c",
                    "echo 'Starting ollama daemon...'; "
                    + "systemctl --user start ollama 2>/dev/null "
                    + "|| sudo systemctl start ollama 2>/dev/null "
                    + "|| ollama serve; "
                    + "echo; echo '[done — close to return]'; exec bash"];
                runner.running = false;
                runner.running = true;
                root.dismiss();
                return;
            }
            if (status === "no-model") {
                // Pull the model in a held-open terminal. The model id
                // is passed positionally as $1 so shell metacharacters
                // in it can never re-interpret the script (same
                // hardening as the probe in OllamaChat.qml). `exec bash`
                // at the end keeps the window up so the user can read
                // the pull output (and any errors) before closing.
                runner.command = ["setsid", "-f", "uwsm-app", "--",
                    "xdg-terminal-exec",
                    "--app-id=org.omarchy.terminal",
                    "--title=Omarchy",
                    "-e", "bash", "-c",
                    "ollama pull \"$1\"; "
                    + "echo; echo '[done — close to return]'; exec bash",
                    "--", ollamaChat.model_];
                runner.running = false;
                runner.running = true;
                root.dismiss();
                return;
            }
            if (status === "ok" && !ollamaChat.submitted) {
                ollamaChat.submit();
                // Keep the panel open so the response streams in.
                return;
            }
            // status === "ok" && submitted: stay open, no-op. User
            // can edit the prompt and the new submit fires on Enter.
            return;
        }
        if (item.isTldr) {
            runner.command = ["setsid", "-f", "uwsm-app", "--",
                "xdg-terminal-exec",
                "--app-id=org.omarchy.terminal",
                "--title=Omarchy",
                "-e", "bash", "-c",
                "read -e -i \"$1 \" line; eval \"$line\"; exec bash",
                "_", item.tldrPreFill || item.tldrName || ""];
            runner.running = false;
            runner.running = true;
            root.dismiss();
            return;
        }
        bookmarks.record(item);
        // TUI commands need a real terminal — fzf, sudo prompts, and bash
        // `read` fail when launched detached. `item.tui` holds the wrapper
        // command name (omarchy-launch-tui or omarchy-launch-floating-…).
        const cmd = item.tui ? item.tui + " " + item.exec : item.exec;
        runner.command = ["sh", "-c",
                          "setsid -f uwsm-app -- bash -c "
                          + JSON.stringify(cmd)
                          + " >/dev/null 2>&1"];
        runner.running = false;
        runner.running = true;
        root.dismiss();
    }

    // ---------- Search ----------
    // Each query token must match somewhere in the item for the item to
    // qualify; scores stack so "thm dark" finds Theme even though neither
    // token is a prefix on its own. Uses precomputed lowercased fields
    // (`_t`/`_k`/`_c`) so a 200+ item × N-token scoring pass doesn't
    // re-lowercase the same strings on every keystroke.
    // Title-only score for the primary sort axis. When the typed query
    // hits the title, that's a strong "user wants THIS" signal and the
    // bucket competition (App vs omarchy vs theme) should happen here,
    // before keyword/category bonuses can flip the ranking.
    function primaryScore(item, tokens) {
        const title = item._t;
        let total = 0;
        for (let i = 0; i < tokens.length; i++) {
            const t = tokens[i];
            if (title.indexOf(t) === 0) total += root.scPrefix;
            else if (title.indexOf(t) >= 0) total += root.scTitle;
        }
        return total;
    }

    // Kind rank used as a tie-break after primaryScore+isCategory. Lower wins.
    // Categories chosen to satisfy "Apps before omarchy/navbar before
    // niche (TUIs, themes)" without source-tagging — the relevant
    // category strings are stable across sources.
    function kindRank(item) {
        const c = item.category;
        if (c === "App") return 1;
        if (c === "TUI") return 3;
        if (c === "THEME" || c === "ACTIVE") return 4;
        return 2;
    }

    function scoreItem(item, tokens) {
        const title = item._t;
        const kw = item._k;
        const cat = item._c;
        let total = 0;
        for (let i = 0; i < tokens.length; i++) {
            const t = tokens[i];
            let sub = 0;
            if (title.indexOf(t) === 0) sub += root.scPrefix;
            else if (title.indexOf(t) >= 0) sub += root.scTitle;
            if (kw.indexOf(t) >= 0) sub += root.scKw;
            if (cat.indexOf(t) >= 0) sub += root.scCat;
            if (sub === 0) return 0; // any token miss disqualifies
            total += sub;
        }
        return total;
    }

    readonly property var queryTokens: {
        const q = root.query.trim().toLowerCase();
        return q.length === 0 ? [] : q.split(/\s+/);
    }

    // Cached at root-level so it isn't reallocated on every keystroke.
    // Only depends on `nav` and `githubReady`, so re-evaluates once when the
    // auth probe finishes.
    readonly property var navRows: root.githubReady
        ? root.nav
        : root.nav.filter(it => it.target !== Data.githubCategory)

    readonly property var filteredItems: {
        // tldr mode owns the query entirely — its synthetic row is the
        // only thing the list should show, scoring doesn't apply.
        if (root.tldrMode) return root.tldrItems;
        // LLM modes are the other query-shape modes; same one-row
        // pivot for both chat (`?`) and command (`$`).
        if (root.llmMode) return root.chatItems;
        // File and GitHub modes are their own worlds: fd and GitHub CLI already
        // did the filtering, so we just pass their results through.
        if (root.fileMode) return root.fileItems;
        if (root.githubMode) return root.githubItems;

        const tokens = root.queryTokens;
        const filter = root.categoryFilter;
        const cap = root.maxResults;

        // Favourites/history/proc/theme drill-ins draw from their
        // owning component; scoring still applies so typing inside the
        // drill filters live.
        let pool;
        if (root.favMode)        pool = bookmarks.favouriteItems;
        else if (root.histMode)  pool = bookmarks.historyItems;
        else if (root.procMode)  pool = root.procItems;
        else if (root.themeMode) pool = root.themeItems;
        else if (filter !== "")  pool = root.allItems.filter(it => it.category === filter);
        else                     pool = root.navRows.concat(root.allItems);

        // Empty query, default view: drill-ins first, then up to 5
        // favourites, then leaf actions/apps. TUIs and themes are
        // skipped from this view to keep the cold open scannable -
        // they stay in `allItems` so the scored branch below still
        // finds them when typed. Drill-in modes (fav/hist/proc/theme)
        // and category filters keep their existing pool unchanged.
        if (tokens.length === 0) {
            if (root.favMode || root.histMode || root.procMode
                || root.themeMode || filter !== "") {
                return pool.length <= cap ? pool : pool.slice(0, cap);
            }
            const favs = bookmarks.favouriteItems.slice(0, 5);
            const favKeys = {};
            for (let i = 0; i < favs.length; i++) {
                favKeys[Data.itemKey(favs[i])] = true;
            }
            const tail = [];
            for (let i = 0; i < root.allItems.length; i++) {
                const it = root.allItems[i];
                const c = it.category;
                if (c === "TUI" || c === "THEME" || c === "ACTIVE") continue;
                if (favKeys[Data.itemKey(it)]) continue;
                tail.push(it);
            }
            const out = root.navRows.concat(favs).concat(tail);
            return out.length <= cap ? out : out.slice(0, cap);
        }

        const scored = [];
        for (let i = 0; i < pool.length; i++) {
            const it = pool[i];
            const s = root.scoreItem(it, tokens);
            if (s > 0) {
                scored.push({
                    s: s,
                    p: root.primaryScore(it, tokens),
                    item: it
                });
            }
        }
        scored.sort((a, b) => {
            // Primary axis: how well the TITLE matched. Items with a
            // title hit always rank above items that only matched via
            // keyword/category, regardless of bonus stacking.
            if (b.p !== a.p) return b.p - a.p;
            // Drill-ins above leaves on the same title score, so a
            // typed "setup" surfaces the Setup drill-in row above any
            // Setup-category leaf.
            const aCat = a.item.isCategory ? 0 : 1;
            const bCat = b.item.isCategory ? 0 : 1;
            if (aCat !== bCat) return aCat - bCat;
            // Kind: App > omarchy/navbar > TUI > Theme. This is where
            // Apps win against omarchy/theme rows that share a title
            // prefix (e.g. typing "aether" surfaces the Aether app
            // ahead of "Aether Themes" and the aether theme entry).
            const ka = root.kindRank(a.item);
            const kb = root.kindRank(b.item);
            if (ka !== kb) return ka - kb;
            // Within the same kind, fall back to total score (keyword
            // and category bonuses) and finally alpha.
            if (b.s !== a.s) return b.s - a.s;
            return a.item.title.localeCompare(b.item.title);
        });
        const lim = Math.min(scored.length, cap);
        const out = new Array(lim);
        for (let j = 0; j < lim; j++) out[j] = scored[j].item;
        return out;
    }

    onFilteredItemsChanged: {
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex,
                                                  root.filteredItems.length - 1));
    }

    // ---------- Selection movement ----------
    // Single entry point for keyboard nav so arrow/Tab/Page bindings stay
    // one-liners. `wrap` toggles modulo behaviour vs. clamp — arrow + Tab
    // wrap, paging clamps (matches list-widget convention everywhere else).
    function moveSelection(delta, wrap) {
        const n = root.filteredItems.length;
        if (n === 0) return;
        let next = root.selectedIndex + delta;
        next = wrap ? ((next % n) + n) % n
                    : Math.max(0, Math.min(n - 1, next));
        root.selectedIndex = next;
        resultListInstance.list.positionViewAtIndex(next, ListView.Contain);
    }

    // Grid-aware step for Quick mode. `delta` may exceed ±1 (arrow Up/Down
    // moves by gridCols). Clamps rather than wraps so Up from the top row
    // doesn't jump to the last row of a partial bottom row.
    function moveQuickSelection(delta) {
        const n = root.filteredQuickTiles.length;
        if (n === 0) return;
        const next = Math.max(0, Math.min(n - 1, root.selectedIndex + delta));
        root.selectedIndex = next;
    }

    Component.onCompleted: {
        root.omarchy = omarchyMenu.items;
        root.nav     = Data.annotate(Data.categoryNav);
    }

    // ---------- IPC ----------
    IpcHandler {
        target: "omni"
        function toggle(): void { root.toggle() }
        function open(): void { root.open() }
        function close(): void { root.dismiss() }
        function refresh(): string { return root.refresh(); }
        // Open OmniMenu pre-pivoted to a drill-down category (e.g. "Quick").
        // Lets Hyprland bind a shortcut straight into a category without
        // exposing the visual grid as a separate surface.
        function openCategory(cat: string): void {
            root.open();
            root.categoryFilter = cat;
        }
    }

    // ---------- Panel ----------
    PanelWindow {
        id: panel
        visible: root.visible_
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "omarchy-omni"
        WlrLayershell.keyboardFocus: root.visible_ ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Drawn before the dismiss MouseArea so clicks still reach the close
        // handler. This is intentionally static: opening and closing Omni must
        // not wait on a fade, reveal, or scale transition.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
        }

        // Outside-click dismiss.
        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }

        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            // Card sits slightly above visual centre so the result list grows
            // downward without dragging the search field out of the eyeline.
            y: parent.height * 0.18
            // Wide in any preview-bearing mode (file, github, processes,
            // themes) so a ~520px preview pane fits next to the result
            // list; narrow 640 elsewhere — including Quick mode whether
            // collapsed or expanded — so opening a tile doesn't cause any
            // horizontal jump. The tile column compresses to 64px on the
            // left of the same 640 card, leaving ~509px for the detail
            // panel.
            width: root.previewActive ? 1000 : 640
            Behavior on width {
                NumberAnimation { duration: 60; easing.type: Easing.OutCubic }
            }
            // Cap the card so it never exceeds the screen even on small
            // displays; cardCol implicitHeight covers the search + list +
            // footer block.
            height: Math.min(cardCol.implicitHeight + 34, parent.height * 0.72)
            color: root.background
            border.color: root.border
            border.width: 1
            radius: root.cornerRadius

            // Swallow clicks so the underlying dismiss MouseArea doesn't fire.
            MouseArea { anchors.fill: parent }

            focus: root.visible_
            Keys.onPressed: function(event) {
                // hjkl → arrow translation (Vim-style nav). Only active
                // in quickMode, where there is no typing buffer and the
                // tile grid is the sole input surface. In the main omni
                // search h/j/k/l are letters first; remapping them — even
                // conditionally on empty query — surprised users who
                // expected to start typing immediately.
                const _hjklMap = {};
                _hjklMap[Qt.Key_H] = Qt.Key_Left;
                _hjklMap[Qt.Key_J] = Qt.Key_Down;
                _hjklMap[Qt.Key_K] = Qt.Key_Up;
                _hjklMap[Qt.Key_L] = Qt.Key_Right;
                const _wrap = (e) => {
                    if (_hjklMap[e.key] === undefined) return e;
                    if (!root.quickMode) return e;
                    return { key: _hjklMap[e.key], modifiers: e.modifiers, text: e.text };
                };
                const e2 = _wrap(event);

                // When a quick tile is expanded, give its body first crack
                // at the key so arrow/Tab/Enter drive the body's own focus
                // chain (volume slider, wi-fi list, bluetooth list, …)
                // instead of the tile grid. Bodies return true from
                // kbdHandle() to swallow the event; anything they leave
                // unhandled (e.g. Esc) bubbles to the cascade below.
                const bodyItem = null;
                if (root.quickExpanded
                    && bodyItem
                    && typeof bodyItem.kbdHandle === "function"
                    && bodyItem.kbdHandle(e2)) {
                    event.accepted = true;
                    return;
                }
                if (e2.key === Qt.Key_Escape) {
                    // Esc cascade: collapse the quick-tile detail panel
                    // first (if open), then clear the typed query, then
                    // unwind drill-down, then close. Each Esc undoes
                    // exactly one layer of state so the palette never
                    // exits with a half-typed query on screen.
                    if (root.quickExpanded) {
                        root.expandedTile = null;
                    } else if (root.query.length > 0) {
                        root.query = "";
                        root.selectedIndex = 0;
                    } else if (!root.goUp()) {
                        root.dismiss();
                    }
                    event.accepted = true;
                } else if (root.quickMode && e2.key === Qt.Key_Left) {
                    root.moveQuickSelection(-1);
                    event.accepted = true;
                } else if (root.quickMode && e2.key === Qt.Key_Right) {
                    root.moveQuickSelection(1);
                    event.accepted = true;
                } else if (root.quickMode && e2.key === Qt.Key_Up) {
                    root.moveQuickSelection(-root.quickGridCols);
                    event.accepted = true;
                } else if (root.quickMode && e2.key === Qt.Key_Down) {
                    root.moveQuickSelection(root.quickGridCols);
                    event.accepted = true;
                } else if (root.quickMode
                           && (e2.key === Qt.Key_Tab && !(e2.modifiers & Qt.ShiftModifier))) {
                    root.moveQuickSelection(1);
                    event.accepted = true;
                } else if (root.quickMode
                           && (e2.key === Qt.Key_Backtab
                               || (e2.key === Qt.Key_Tab && (e2.modifiers & Qt.ShiftModifier)))) {
                    root.moveQuickSelection(-1);
                    event.accepted = true;
                } else if (root.llmMode && root.previewHasContent
                           && (e2.key === Qt.Key_Up || e2.key === Qt.Key_Down
                               || e2.key === Qt.Key_PageUp || e2.key === Qt.Key_PageDown
                               || e2.key === Qt.Key_Home || e2.key === Qt.Key_End
                               || e2.key === Qt.Key_Tab || e2.key === Qt.Key_Backtab)) {
                    // chat / command mode: same scroll routing as
                    // tldr mode below.
                    // List nav is a no-op here (single synthetic row).
                    const f = previewPaneInstance.chatFlickable;
                    const max = Math.max(0, f.contentHeight - f.height);
                    const line = 18;
                    const page = Math.max(line, f.height * 0.9);
                    let dy = 0;
                    if (e2.key === Qt.Key_Up
                        || (e2.key === Qt.Key_Tab && (e2.modifiers & Qt.ShiftModifier))
                        || e2.key === Qt.Key_Backtab) dy = -line;
                    else if (e2.key === Qt.Key_Down
                             || (e2.key === Qt.Key_Tab && !(e2.modifiers & Qt.ShiftModifier))) dy = line;
                    else if (e2.key === Qt.Key_PageUp)   dy = -page;
                    else if (e2.key === Qt.Key_PageDown) dy = page;
                    else if (e2.key === Qt.Key_Home) { f.contentY = 0; event.accepted = true; return; }
                    else if (e2.key === Qt.Key_End)  { f.contentY = max; event.accepted = true; return; }
                    f.contentY = Math.max(0, Math.min(max, f.contentY + dy));
                    event.accepted = true;
                } else if (root.tldrMode && root.tldrPreview !== ""
                           && (e2.key === Qt.Key_Up || e2.key === Qt.Key_Down
                               || e2.key === Qt.Key_PageUp || e2.key === Qt.Key_PageDown
                               || e2.key === Qt.Key_Home || e2.key === Qt.Key_End
                               || e2.key === Qt.Key_Tab || e2.key === Qt.Key_Backtab)) {
                    // tldr mode has a single synthetic row, so list nav is
                    // a no-op. Route arrow/page/home/end (and Tab/Shift+Tab,
                    // which would otherwise wrap the same row to itself) to
                    // the preview Flickable instead.
                    const f = previewPaneInstance.tldrFlickable;
                    const max = Math.max(0, f.contentHeight - f.height);
                    const line = 18;
                    const page = Math.max(line, f.height * 0.9);
                    let dy = 0;
                    if (e2.key === Qt.Key_Up
                        || (e2.key === Qt.Key_Tab && (e2.modifiers & Qt.ShiftModifier))
                        || e2.key === Qt.Key_Backtab) dy = -line;
                    else if (e2.key === Qt.Key_Down
                             || (e2.key === Qt.Key_Tab && !(e2.modifiers & Qt.ShiftModifier))) dy = line;
                    else if (e2.key === Qt.Key_PageUp)   dy = -page;
                    else if (e2.key === Qt.Key_PageDown) dy = page;
                    else if (e2.key === Qt.Key_Home) { f.contentY = 0; event.accepted = true; return; }
                    else if (e2.key === Qt.Key_End)  { f.contentY = max; event.accepted = true; return; }
                    f.contentY = Math.max(0, Math.min(max, f.contentY + dy));
                    event.accepted = true;
                } else if (e2.key === Qt.Key_Down
                           || (e2.key === Qt.Key_Tab && !(e2.modifiers & Qt.ShiftModifier))) {
                    // Tab + Down step forward, Shift+Tab + Up step backward,
                    // both wrap. Paging clamps (see Key_PageDown). Matches
                    // launcher convention everywhere else.
                    root.moveSelection(1, true);
                    event.accepted = true;
                } else if (e2.key === Qt.Key_Up
                           || e2.key === Qt.Key_Backtab
                           || (e2.key === Qt.Key_Tab && (e2.modifiers & Qt.ShiftModifier))) {
                    root.moveSelection(-1, true);
                    event.accepted = true;
                } else if (e2.key === Qt.Key_PageDown) {
                    root.moveSelection(8, false);
                    event.accepted = true;
                } else if (e2.key === Qt.Key_PageUp) {
                    root.moveSelection(-8, false);
                    event.accepted = true;
                } else if (e2.key === Qt.Key_Home) {
                    root.selectedIndex = 0;
                    resultListInstance.list.positionViewAtIndex(0, ListView.Beginning);
                    event.accepted = true;
                } else if (e2.key === Qt.Key_End) {
                    root.selectedIndex = Math.max(0, root.filteredItems.length - 1);
                    resultListInstance.list.positionViewAtIndex(root.selectedIndex, ListView.End);
                    event.accepted = true;
                } else if (e2.key === Qt.Key_Return || e2.key === Qt.Key_Enter) {
                    if (root.quickMode) {
                        const t = root.filteredQuickTiles[root.selectedIndex];
                        if (t) root.expandTile(t);
                    } else {
                        const it = root.filteredItems[root.selectedIndex];
                        if (it) root.activate(it);
                    }
                    event.accepted = true;
                } else if (e2.key === Qt.Key_Backspace) {
                    // Backspace deletes a char first; once the query is
                    // empty it walks back up one level so the same key
                    // unwinds both the typed query and the breadcrumb.
                    if (root.query.length > 0) root.query = root.query.slice(0, -1);
                    else root.goUp();
                    event.accepted = true;
                } else if (e2.key === Qt.Key_S && (e2.modifiers & Qt.ControlModifier)) {
                    const it = root.filteredItems[root.selectedIndex];
                    if (it && !it.isCategory && !it.isTldr && !it.isOllama) bookmarks.toggleFavourite(it);
                    event.accepted = true;
                } else if ((e2.modifiers & Qt.ControlModifier)
                           && (e2.key === Qt.Key_Plus || e2.key === Qt.Key_Equal
                               || e2.key === Qt.Key_Minus)) {
                    // Ctrl++ / Ctrl+- nudge the omni-menu font scale;
                    // Ctrl+= resets to default. Plus is reached via
                    // Shift+= on US layouts (Qt delivers Qt.Key_Plus),
                    // and via a dedicated key on numpads / EU layouts.
                    if (e2.key === Qt.Key_Plus) root.bumpFontScale(+0.1);
                    else if (e2.key === Qt.Key_Minus) root.bumpFontScale(-0.1);
                    else /* Key_Equal without Shift */ root.fontScale = 1.0;
                    event.accepted = true;
                } else if (e2.key === Qt.Key_C && (e2.modifiers & Qt.ControlModifier)
                           && root.llmMode && root.chatPreview !== "") {
                    // Ctrl+C: if the user dragged a selection in the
                    // rendered RichText edit, copy that (lossy — Qt
                    // strips inline `code` backticks during conversion,
                    // but it's what they asked for). With no selection,
                    // copy the full raw markdown from the hidden plain-
                    // text shadow so pasted commands keep their syntax.
                    if (previewPaneInstance.chatEdit.selectedText.length > 0) {
                        previewPaneInstance.chatEdit.copy();
                    } else {
                        previewPaneInstance.chatPlain.selectAll();
                        previewPaneInstance.chatPlain.copy();
                        previewPaneInstance.chatPlain.deselect();
                    }
                    event.accepted = true;
                } else if (e2.key === Qt.Key_C && (e2.modifiers & Qt.ControlModifier)
                           && root.tldrMode && root.tldrPreview !== "") {
                    // Ctrl+C in tldr mode: copy the active selection if
                    // there is one, otherwise copy the whole rendered
                    // preview. The TextEdit's `copy()` works without
                    // active focus, so the search input keeps keystrokes.
                    if (previewPaneInstance.tldrEdit.selectedText.length > 0) {
                        previewPaneInstance.tldrEdit.copy();
                    } else {
                        previewPaneInstance.tldrEdit.selectAll();
                        previewPaneInstance.tldrEdit.copy();
                        previewPaneInstance.tldrEdit.deselect();
                    }
                    event.accepted = true;
                } else if (!root.quickMode && event.text && event.text.length === 1) {
                    const ch = event.text;
                    // Printable range; lets letters, digits, and spaces in,
                    // keeps modifier-driven control codes out. Skipped in
                    // quickMode — there's no search field to feed.
                    if (ch.charCodeAt(0) >= 32 && ch.charCodeAt(0) !== 127) {
                        root.query += ch;
                        root.selectedIndex = 0;
                        event.accepted = true;
                    }
                }
            }

            Column {
                id: cardCol
                anchors.fill: parent
                anchors.margins: 17
                spacing: 12

                Omni.HeaderBar {
                    id: headerBar
                    omni: root
                    processes: processes
                    themes: themes
                    bookmarks: bookmarks
                }

                Rectangle { width: parent.width; height: 1; color: root.border }

                Omni.SearchInput { omni: root }

                Rectangle {
                    visible: !root.quickMode
                    width: parent.width
                    height: 1
                    color: root.border
                }

                // Fixed row height in the delegate keeps positionViewAtIndex
                // honest under fast keyboard navigation; the wrapping Item's
                // clip prevents the bottom row bleeding into the footer
                // hairline mid-scroll.
                Item {
                    id: listArea
                    visible: !root.quickMode
                    width: parent.width
                    height: visible
                        ? Math.max(60, card.height - 34 - headerBar.height - 34 - 12 * 4)
                        : 0
                    clip: true

                    // In file mode the list shrinks to ~44% of the card so
                    // a 520px-ish preview pane fits alongside it. The 1px
                    // hairline + 1px inverse hairline divider sits between
                    // them. animated alongside card.width for a single
                    // smooth widen-and-split motion.
                    readonly property real listFraction: root.previewActive ? 0.44 : 1.0

                    Omni.ResultList {
                        id: resultListInstance
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        // Follows card.width's Behavior animation — adding a
                        // second Behavior here would animate to a moving
                        // target and produce staggered motion.
                        width: parent.width * listArea.listFraction
                        omni: root
                        bookmarks: bookmarks
                        processes: processes
                        themes: themes
                        ollamaChat: ollamaChat
                    }

                    Rectangle {
                        visible: root.previewActive
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: resultListInstance.right
                        width: 1
                        color: root.border
                    }

                    Omni.PreviewPane {
                        id: previewPaneInstance
                        visible: root.previewActive
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: resultListInstance.right
                        anchors.leftMargin: 13
                        anchors.right: parent.right
                        omni: root
                        ollamaChat: ollamaChat
                    }
                }

            }
        }
    }
}
