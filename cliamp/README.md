# cliamp Now Playing

Top-right Omarchy shell now-playing card for `cliamp`.

## Quick Start

Install from this checkout:

```bash
mkdir -p ~/.config/omarchy/plugins
rm -rf ~/.config/omarchy/plugins/cliamp
cp -a cliamp ~/.config/omarchy/plugins/cliamp
omarchy plugin validate ~/.config/omarchy/plugins/cliamp
omarchy plugin enable cliamp
omarchy-restart-shell
```

Start `cliamp`. The card appears at the top right when cliamp starts or changes songs, then hides itself after a few seconds.

## Controls

- Previous, play/pause, next buttons use cliamp's MPRIS controls.
- Click the progress line to seek.
- Press `Esc` or `Q` while the card has focus to hide it.
- Show it again briefly with `omarchy-shell shell call cliamp refresh ""`.

## IPC

```bash
omarchy-shell shell call cliamp refresh ""
omarchy-shell shell call cliamp toggle ""
omarchy-shell shell call cliamp close ""
```

## Requirements

- `cliamp` on `PATH`
- cliamp running on Linux with its default MPRIS service enabled

The card uses Omarchy shell colors and fonts through `qs.Commons`. It does not read `colors.toml` directly.
