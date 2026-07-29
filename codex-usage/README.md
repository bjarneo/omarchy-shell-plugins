# Codex Usage

Track the active ChatGPT plan's Codex limits from the Omarchy bar.

## Install

```bash
mkdir -p ~/.config/omarchy/plugins
cp -a codex-usage ~/.config/omarchy/plugins/codex-usage
omarchy plugin validate ~/.config/omarchy/plugins/codex-usage
omarchy plugin rescan
omarchy bar plugin add codex-usage --section right
omarchy restart shell
```

## Usage

- The bar shows the primary limit's remaining percentage.
- Click the widget for primary and secondary limits, reset times, and your plan.
- Press `R` in the panel or middle-click the bar widget to refresh.

## Requirements

- Codex CLI must be available as `codex` on `PATH`.
- Sign in with ChatGPT using `codex login`.

The widget queries Codex's local app server. It does not read or transmit the credentials in `~/.codex/auth.json` itself.

## Validate

```bash
omarchy plugin validate codex-usage
qmllint codex-usage/*.qml
node codex-usage/Model.test.js
```
