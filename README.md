# Omarchy Shell Plugins

Personal third-party plugins for `omarchy-shell`.

## Quick Start

Local install from this checkout:

```bash
mkdir -p ~/.config/omarchy/plugins
rm -rf ~/.config/omarchy/plugins/omni
cp -a omni ~/.config/omarchy/plugins/omni
omarchy plugin validate ~/.config/omarchy/plugins/omni
omarchy plugin rescan
omarchy plugin enable omni
omarchy-restart-shell
```

Open Omni:

```bash
omarchy-shell shell toggle omni '{}'
```

Suggested Alt+Space binding for `~/.config/hypr/bindings.lua`:

```lua
hl.unbind("ALT + SPACE")
hl.bind("ALT + SPACE", hl.dsp.exec_cmd([[omarchy-shell shell toggle omni '{}']]), { description = "Omni" })
```

If this repository is added as a trusted plugin source, install with:

```bash
omarchy plugin source add https://github.com/bjarneo/omarchy-shell-plugins --as bjarneo
omarchy plugin add omni --from bjarneo --enable
```

Omarchy rejects symlinked plugin folders. Use a real copied directory for local testing.

## Plugins

### `omni`

Standalone Omarchy shell command palette for apps, Omarchy actions, files, themes, processes, GitHub search, `tldr`, and local Ollama prompts.

Features:

- Overlay plugin enabled with `omarchy plugin enable omni`
- Searches installed desktop apps and a bundled Omarchy action index
- Drill-down categories for Quick, Apps, Files, GitHub, Favourites, History, Processes, and Themes
- File previews, theme swatches, process previews, GitHub repo/PR previews, `tldr` docs, and local Ollama prompt previews
- Uses Omarchy shell shared colors, font settings, and state fills through `qs.Commons`
- Keyboard controls: arrows or `j`/`k` to move, `Enter` to launch, `Esc` to unwind/close, `Ctrl+S` to favourite

Useful commands:

```bash
omarchy-shell shell toggle omni '{}'
omarchy-shell shell call omni toggle ""
omarchy-shell shell call omni openCategory Quick
omarchy-shell shell hide omni
```

Optional tools:

- `fd` for file search
- `gh` for GitHub search
- `tldr` for inline command docs
- `ollama` with `qwen3.5:0.8b` for local chat and command generation

See `omni/README.md` for details.

## Validate

```bash
omarchy plugin validate omni
qmllint omni/*.qml omni/omni/*.qml
```

## License

MIT. See `LICENSE`.
