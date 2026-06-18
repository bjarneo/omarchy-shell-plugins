.pragma library

// Markdown-ish formatters for OmniMenu's preview panes. Both take a
// `palette` argument carrying the live Omarchy colors so a theme swap
// re-renders without these functions having to know about the QML root.
//   palette = { text, muted, code, accent }
// Library pragma keeps a single shared copy across all OmniMenu instances
// (there's only ever one, but it also prevents leaking outer-QML
// references — these are pure string ops by design).

// Qt color.toString() returns `#AARRGGBB` for non-opaque colors (alpha
// first), which Qt's RichText parser misinterprets as `#RRGGBB` for the
// first six digits. Trim to `#RRGGBB` so translucent palette entries
// still render their nominal hue, even if alpha is dropped.
function hex(c) {
    const s = c.toString();
    return s.length === 9 ? "#" + s.substring(3) : s;
}

function esc(s) {
    return s.replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
}

function wrap(color, text) {
    return '<span style="color:' + color + '">' + esc(text) + '</span>';
}

// Parses the small markdown dialect tldr emits with `-m` and returns
// RichText HTML coloured against the live palette. Patterns:
//   `# name`      title - skipped (header shows the tool name)
//   `> text`      description (text), inline `code` in code
//   `- text:`     example label (muted), inline `code` in code
//   `` `cmd` ``   example command (code); {{placeholders}} accent
//   other         fallthrough (e.g. "documentation not available")
function formatTldrHtml(raw, palette) {
    if (!raw) return "";
    const text = hex(palette.text);
    const muted = hex(palette.muted);
    const code = hex(palette.code);
    const accent = hex(palette.accent);

        // Inline `code` spans inside prose: split on backticks so the
        // intervening code segments switch to the code color without changing
    // the surrounding base colour.
    function styleProse(s, base) {
        let out = "", i = 0;
        while (i < s.length) {
            const j = s.indexOf("`", i);
            if (j < 0) { out += wrap(base, s.substring(i)); break; }
            if (j > i) out += wrap(base, s.substring(i, j));
            const k = s.indexOf("`", j + 1);
            if (k < 0) { out += wrap(base, s.substring(j)); break; }
            out += wrap(code, s.substring(j + 1, k));
            i = k + 1;
        }
        return out;
    }
    // Code lines: most of the string is code-colored, {{placeholders}} pop in
    // accent so the user sees what they need to fill in.
    function styleCode(s) {
        let out = "", i = 0;
        while (i < s.length) {
            const j = s.indexOf("{{", i);
            if (j < 0) { out += wrap(code, s.substring(i)); break; }
            if (j > i) out += wrap(code, s.substring(i, j));
            const k = s.indexOf("}}", j + 2);
            if (k < 0) { out += wrap(code, s.substring(j)); break; }
            out += wrap(accent, s.substring(j + 2, k));
            i = k + 2;
        }
        return out;
    }

    const lines = raw.split("\n");
    const out = [];
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.length === 0) { out.push(""); continue; }
        const c = line.charAt(0);
        if (c === "#") continue;
        if (c === ">") { out.push(styleProse(line.substring(1).trim(), text)); continue; }
        // Require a space after `-` so markdown rules (`---`) and any
        // future hyphen-led prose don't get parsed as a tldr example
        // label (which is always `- text:`).
        if (c === "-" && line.charAt(1) === " ") { out.push(styleProse(line.substring(1).trim(), muted)); continue; }
        if (c === "`") {
            let body = line;
            if (body.charAt(0) === "`") body = body.substring(1);
            if (body.charAt(body.length - 1) === "`") body = body.substring(0, body.length - 1);
            out.push(styleCode(body));
            continue;
        }
        out.push(styleProse(line, muted));
    }
    return out.join("<br>");
}

// Renders the LLM's markdown output as palette-aware RichText. Lean
// (not CommonMark-spec): handles fenced code blocks, headings (# / ##
// / ###), inline `code`, and `-`/`*` bullets. Anything fancier (bold,
// italic, links, tables) falls back to plain prose. baseColor lets
// callers tint the whole block - used by the chat preview pane to dim
// status messages in the muted foreground color.
function formatChatHtml(raw, palette, baseColor) {
    if (!raw) return "";
    const text = baseColor ? hex(baseColor) : hex(palette.text);
    const code = hex(palette.code);
    const accent = hex(palette.accent);

    // Inline `code` only - keep bold/italic out so the LLM's stray
    // asterisks (common in prose) don't get eaten.
    function styleInline(s, base) {
        let out = "", i = 0;
        while (i < s.length) {
            const j = s.indexOf("`", i);
            if (j < 0) { out += wrap(base, s.substring(i)); break; }
            if (j > i) out += wrap(base, s.substring(i, j));
            const k = s.indexOf("`", j + 1);
            if (k < 0) { out += wrap(base, s.substring(j)); break; }
            out += wrap(code, s.substring(j + 1, k));
            i = k + 1;
        }
        return out;
    }

    const lines = raw.split("\n");
    const out = [];
    let inCode = false;
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const trimmed = line.replace(/^\s+/, "");
        // Fenced code block delimiter - toggle state, drop the fence
        // line itself.
        if (trimmed.indexOf("```") === 0) {
            inCode = !inCode;
            continue;
        }
        if (inCode) {
            // Preserve indentation; render whole line in code color.
            out.push(wrap(code, line));
            continue;
        }
        if (line.length === 0) { out.push(""); continue; }
        // Headings
        if (line.charAt(0) === "#") {
            let level = 0;
            while (level < line.length && line.charAt(level) === "#") level++;
            if (level <= 4) {
                const body = line.substring(level).trim();
                if (body.length > 0) {
                    out.push("<b>" + styleInline(body, text) + "</b>");
                    continue;
                }
            }
        }
        // Bullets - accept `- ` or `* ` with the required space so bare
        // hyphens / asterisks in prose don't get eaten.
        if ((line.charAt(0) === "-" || line.charAt(0) === "*")
            && line.charAt(1) === " ") {
            out.push(wrap(accent, "• ") + styleInline(line.substring(2), text));
            continue;
        }
        // Numbered lists: `1.` `2.` ... with a space after.
        const nm = line.match(/^(\d+)\.\s+(.*)$/);
        if (nm) {
            out.push(wrap(accent, nm[1] + ". ") + styleInline(nm[2], text));
            continue;
        }
        out.push(styleInline(line, text));
    }
    return out.join("<br>");
}
