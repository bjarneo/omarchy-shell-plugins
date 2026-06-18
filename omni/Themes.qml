import QtQuick
import Quickshell
import Quickshell.Io
import "Data.js" as Data
import "Palette.js" as Palette

// Theme switcher. Probes both $OMARCHY_PATH/themes (official) and
// ~/.config/omarchy/themes (user) for theme directories, parses each
// theme's colors.toml into a swatch list, and marks the one whose
// colors.toml is byte-identical to ~/.config/omarchy/current/theme as
// active.
//
// The probe runs once per mode entry (cheap on a 24-theme machine).
// Selection drives the swatch preview through `swatches` on the
// selected item; Enter calls `omarchy-theme-set` via the parent's
// activate() special-case.
Item {
    id: themes

    required property bool active

    property var items: []
    property bool loaded: false
    readonly property bool running: probeProc.running

    function clear() {
        themes.items = [];
        themes.loaded = false;
    }

    function refresh() {
        // Emit one record per theme separated by a known sentinel so
        // JS only has to do one Process call + split. Header carries
        // name + marker (" " inactive, "*" active) + preview path, then
        // the colors.toml body. Preview is preview.png when the theme
        // ships one, otherwise the first file in the backgrounds/
        // subdir (sort+head for deterministic pick).
        probeProc.command = ["sh", "-c",
              "cur=$(cat \"$HOME/.config/omarchy/current/theme/colors.toml\" 2>/dev/null); "
            + "for d in \"$OMARCHY_PATH/themes\"/*/ \"$HOME/.local/share/omarchy/themes\"/*/ \"$HOME/.config/omarchy/themes\"/*/; do "
            + "  [ -d \"$d\" ] || continue; "
            + "  name=$(basename \"$d\"); "
            + "  c=$(cat \"$d/colors.toml\" 2>/dev/null); "
            + "  marker=' '; [ -n \"$c\" ] && [ \"$c\" = \"$cur\" ] && marker='*'; "
            + "  prev=''; "
            + "  if [ -f \"$d/preview.png\" ]; then prev=\"$d/preview.png\"; "
            + "  elif [ -f \"$d/preview.jpg\" ]; then prev=\"$d/preview.jpg\"; "
            + "  elif [ -d \"$d/backgrounds\" ]; then "
            + "    prev=$(find \"$d/backgrounds\" -maxdepth 1 -type f -size +0c \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.gif' \\) 2>/dev/null | sort | head -n1); "
            + "  fi; "
            + "  printf '===%s\\t%s\\t%s\\n%s\\n' \"$name\" \"$marker\" \"$prev\" \"$c\"; "
            + "done"];
        probeProc.running = false;
        probeProc.running = true;
    }

    // Background + foreground anchor the swatch pair; color1..color6 fan
    // out the accents. Falls back to whatever colorN keys exist if the
    // theme is missing the canonical names.
    function paletteOf(toml) {
        const map = Palette.parseAll(toml);
        const want = ["background", "foreground", "color1", "color2", "color3", "color4", "color5", "color6"];
        const out = [];
        for (let i = 0; i < want.length; i++) {
            if (map[want[i]]) out.push(map[want[i]]);
        }
        if (out.length === 0) {
            for (let i = 0; i < 16 && out.length < 8; i++) {
                if (map["color" + i]) out.push(map["color" + i]);
            }
        }
        return out;
    }

    function ingest(text) {
        const chunks = (text || "").split("===");
        const out = [];
        const seen = {};
        for (let i = 0; i < chunks.length; i++) {
            const chunk = chunks[i];
            if (!chunk) continue;
            const nl = chunk.indexOf("\n");
            if (nl < 0) continue;
            const head = chunk.substring(0, nl);
            // header format: name<TAB>marker<TAB>previewPath
            const parts = head.split("\t");
            const name = parts[0] || "";
            const marker = parts[1] || " ";
            const previewImage = parts[2] || "";
            if (!name) continue;
            // User dir wins over official with the same name. The shell
            // loop emits official first, so a second hit overwrites.
            const body = chunk.substring(nl + 1);
            const swatches = themes.paletteOf(body);
            const active = marker === "*";
            const kw = name + " theme palette" + (active ? " active current" : "");
            const entry = {
                title: name,
                category: active ? "ACTIVE" : "THEME",
                keywords: kw,
                icon: active ? "󰸌" : "󰋩",
                exec: "",
                themeName: name,
                isTheme: true,
                isActive: active,
                swatches: swatches,
                previewImage: previewImage,
                rawCategory: false,
                _t: name.toLowerCase(),
                _k: kw.toLowerCase(),
                _c: "theme"
            };
            if (seen[name] !== undefined) out[seen[name]] = entry;
            else { seen[name] = out.length; out.push(entry); }
        }
        // Active theme floats to the top so the user sees what they've
        // got before scrolling. Otherwise alphabetical.
        out.sort((a, b) => {
            if (a.isActive !== b.isActive) return a.isActive ? -1 : 1;
            return a.title.localeCompare(b.title);
        });
        themes.items = out;
        themes.loaded = true;
    }

    // Refresh on entering the mode so the active marker stays honest
    // after the user swaps themes. Outside the mode we keep items
    // around so themes remain searchable from root without entering the
    // Themes drill first.
    onActiveChanged: { if (themes.active) themes.refresh(); }

    // Preload once at startup. Cheap (~24 small file reads), and means
    // theme rows are present in root search the first time the user
    // opens the palette, not just after entering the Themes drill-in.
    Component.onCompleted: themes.refresh()

    Process {
        id: probeProc
        running: false
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: { themes.ingest(this.text || ""); }
        }
    }
}
