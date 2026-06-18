# QuickApps HUD

Fast Iron Man-style quick-app launcher overlay for `omarchy-shell`.

## Quick Start

Install from this checkout:

```bash
mkdir -p ~/.config/omarchy/plugins
rm -rf ~/.config/omarchy/plugins/quickapps-hud
cp -a quickapps-hud ~/.config/omarchy/plugins/quickapps-hud
omarchy plugin validate ~/.config/omarchy/plugins/quickapps-hud
omarchy plugin enable quickapps-hud
omarchy-restart-shell
```

Launch it:

```bash
omarchy-shell shell toggle quickapps-hud '{}'
```

Suggested Hyprland binding for `~/.config/hypr/bindings.lua`:

```lua
hl.bind("SUPER + A", hl.dsp.exec_cmd([[omarchy-shell shell toggle quickapps-hud '{}']]), { description = "QuickApps HUD" })
```

## Configure Apps

Create `~/.config/omarchy-quickapps-hud/apps.json`:

```json
{
  "apps": [
    { "name": "TERMINAL", "icon": "ghostty", "exec": "ghostty" },
    { "name": "BROWSER", "icon": "chromium", "exec": "chromium" },
    { "name": "EDITOR", "icon": "nvim", "exec": "omarchy-launch-or-focus-tui nvim" }
  ]
}
```

Fallback order:

- `~/.config/omarchy-quickapps-hud/apps.json`
- `~/.config/omarchy-quickapps2/apps.json`
- `~/.config/omarchy-quickapps/apps.json`
- `quickapps.example.json`

## Keys

| Key | Action |
| --- | --- |
| Left / Right / H / L / Up / Down / J / K | Rotate selection |
| Tab / Shift+Tab | Rotate selection |
| Scroll wheel | Rotate selection |
| 1 to 9 | Jump to and launch the nth app |
| Home / End | Jump to first / last |
| Enter / Space | Launch selected app |
| Esc / Q | Dismiss |

## Performance

- Runs as an on-demand Omarchy overlay plugin, not a separate Quickshell process.
- Unloads when hidden because `keepLoaded` is `false`.
- Uses `qs.Commons` colors directly, so it does not poll the theme or spawn theme commands.
- Full-screen Canvas layers are static and repaint only on resize or theme change.
- Motion uses transform/opacity animations while the overlay is open.

## Files

```text
quickapps-hud/
  manifest.json
  QuickAppsHud.qml
  quickapps.example.json
  README.md
```
