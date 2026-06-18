.pragma library

// Markdown-ish formatters for OmniMenu's preview panes. Both take a
// `palette` argument carrying the four live colors so a theme swap
// re-renders without these functions having to know about the QML root.
//   palette = { ink, inkDeep, indigo, seal }
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
//   `> text`      description (ink), inline `code` in indigo
//   `- text:`     example label (inkDeep), inline `code` in indigo
//   `` `cmd` ``   example command (indigo); {{placeholders}} seal
//   other         fallthrough (e.g. "documentation not available")
function formatTldrHtml(raw, palette) {
    if (!raw) return "";
    const ink = hex(palette.ink);
    const inkDeep = hex(palette.inkDeep);
    const indigo = hex(palette.indigo);
    const seal = hex(palette.seal);

    // Inline `code` spans inside prose: split on backticks so the
    // intervening code segments switch to indigo without changing
    // the surrounding base colour.
    function styleProse(s, base) {
        let out = "", i = 0;
        while (i < s.length) {
            const j = s.indexOf("`", i);
            if (j < 0) { out += wrap(base, s.substring(i)); break; }
            if (j > i) out += wrap(base, s.substring(i, j));
            const k = s.indexOf("`", j + 1);
            if (k < 0) { out += wrap(base, s.substring(j)); break; }
            out += wrap(indigo, s.substring(j + 1, k));
            i = k + 1;
        }
        return out;
    }
    // Code lines: most of the string is indigo, {{placeholders}} pop in
    // seal so the user sees what they need to fill in.
    function styleCode(s) {
        let out = "", i = 0;
        while (i < s.length) {
            const j = s.indexOf("{{", i);
            if (j < 0) { out += wrap(indigo, s.substring(i)); break; }
            if (j > i) out += wrap(indigo, s.substring(i, j));
            const k = s.indexOf("}}", j + 2);
            if (k < 0) { out += wrap(indigo, s.substring(j)); break; }
            out += wrap(seal, s.substring(j + 2, k));
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
        if (c === ">") { out.push(styleProse(line.substring(1).trim(), ink)); continue; }
        // Require a space after `-` so markdown rules (`---`) and any
        // future hyphen-led prose don't get parsed as a tldr example
        // label (which is always `- text:`).
        if (c === "-" && line.charAt(1) === " ") { out.push(styleProse(line.substring(1).trim(), inkDeep)); continue; }
        if (c === "`") {
            let body = line;
            if (body.charAt(0) === "`") body = body.substring(1);
            if (body.charAt(body.length - 1) === "`") body = body.substring(0, body.length - 1);
            out.push(styleCode(body));
            continue;
        }
        out.push(styleProse(line, inkDeep));
    }
    return out.join("<br>");
}

// Renders the LLM's markdown output as palette-aware RichText. Lean
// (not CommonMark-spec): handles fenced code blocks, headings (# / ##
// / ###), inline `code`, and `-`/`*` bullets. Anything fancier (bold,
// italic, links, tables) falls back to plain prose. baseColor lets
// callers tint the whole block - used by the chat preview pane to dim
// status messages in `inkDeep`.
function formatChatHtml(raw, palette, baseColor) {
    if (!raw) return "";
    const ink = baseColor ? hex(baseColor) : hex(palette.ink);
    const indigo = hex(palette.indigo);
    const seal = hex(palette.seal);

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
            out += wrap(indigo, s.substring(j + 1, k));
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
            // Preserve indentation; render whole line in indigo.
            out.push(wrap(indigo, line));
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
                    out.push("<b>" + styleInline(body, ink) + "</b>");
                    continue;
                }
            }
        }
        // Bullets - accept `- ` or `* ` with the required space so bare
        // hyphens / asterisks in prose don't get eaten.
        if ((line.charAt(0) === "-" || line.charAt(0) === "*")
            && line.charAt(1) === " ") {
            out.push(wrap(seal, "• ") + styleInline(line.substring(2), ink));
            continue;
        }
        // Numbered lists: `1.` `2.` ... with a space after.
        const nm = line.match(/^(\d+)\.\s+(.*)$/);
        if (nm) {
            out.push(wrap(seal, nm[1] + ". ") + styleInline(nm[2], ink));
            continue;
        }
        out.push(styleInline(line, ink));
    }
    return out.join("<br>");
}
