# QuickApps HUD

Iron Man-style quick-app launcher for Quickshell and Omarchy.

## Quick Start

Install from this checkout:

```bash
mkdir -p ~/.config/quickshell
rm -rf ~/.config/quickshell/quickapps-hud
cp -a quickapps-hud ~/.config/quickshell/quickapps-hud
```

Launch it:

```bash
qs -n -c quickapps-hud
```

Suggested Hyprland binding for `~/.config/hypr/bindings.lua`:

```lua
hl.bind("SUPER + A", hl.dsp.exec_cmd("qs -n -c quickapps-hud"), { description = "QuickApps HUD" })
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

## Files

```text
quickapps-hud/
  shell.qml
  quickapps.example.json
  README.md
```
