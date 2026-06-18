# Omni

Standalone Omarchy shell command palette.

Omni searches installed apps, Omarchy actions, files, themes, processes, GitHub repositories and pull requests, `tldr` pages, and local Ollama prompts from one overlay.

## Install

Install from this checkout:

```bash
mkdir -p ~/.config/omarchy/plugins
rm -rf ~/.config/omarchy/plugins/omni
cp -a omni ~/.config/omarchy/plugins/omni
omarchy plugin validate ~/.config/omarchy/plugins/omni
omarchy plugin rescan
omarchy plugin enable omni
omarchy-restart-shell
```

If this repository is added as a trusted plugin source:

```bash
omarchy plugin source add https://github.com/bjarneo/omarchy-shell-plugins --as bjarneo
omarchy plugin add omni --from bjarneo --enable
```

Omarchy rejects symlinked plugin folders. Use a real copied directory for local testing.

Suggested Alt+Space binding for `~/.config/hypr/bindings.lua`:

```lua
hl.unbind("ALT + SPACE")
hl.bind("ALT + SPACE", hl.dsp.exec_cmd([[omarchy-shell shell toggle omni '{}']]), { description = "Omni" })
```

## Usage

Toggle it through the shell plugin target:

```bash
omarchy-shell shell toggle omni '{}'
```

Open a category directly by passing a payload:

```bash
omarchy-shell shell toggle omni '{"category":"Quick"}'
```

Close it:

```bash
omarchy-shell shell hide omni
```

Once the shell has loaded the plugin, direct plugin calls also work:

```bash
omarchy-shell shell call omni toggle ""
omarchy-shell shell call omni openCategory Quick
```

Useful keys:

- Type to search.
- `Enter` launches the selected row.
- `Esc` clears the query, goes up a level, then closes.
- `Tab` / `Shift+Tab`, arrows, `j` / `k` navigate.
- `Ctrl+S` favourites the selected action.
- `Ctrl++` / `Ctrl+-` changes font scale.

## Styling

Omni uses Omarchy shell's shared `qs.Commons` styling: popup background/text, shell font, corner radius, and state fills from `Style`. Selection and borders use the shell foreground/text state color, so warning-colored theme accents do not make the palette look like an error dialog.

The Themes drill-down still reads theme `colors.toml` files to render swatches and identify the active theme. That is preview data, not the plugin's own styling source.

The standalone plugin treats `Quick` as a normal command category. The rich tile grid from the personal `desktop` quickshell config is intentionally not included because it depends on that bar's live telemetry object.

## Optional Tools

- `fd` for file search.
- `gh` for GitHub repo search and PR title/description previews.
- `tldr` for inline command docs.
- `ollama` with `qwen3.5:0.8b` for local chat and command generation.

## Files

- `manifest.json`: plugin metadata.
- `OmniMenu.qml`: overlay entry point and state machine.
- `Data.js`: searchable Omarchy action index.
- `Theme.qml`: adapter from Omarchy shell `qs.Commons` colors to Omni's semantic names.
- `Palette.js`: parser used by the Themes drill-down for swatch previews.
- `omni/*.qml`: visual subcomponents.
