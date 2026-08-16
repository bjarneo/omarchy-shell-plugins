# Now Playing

A compact MPRIS media control for the Omarchy bar.

## Quick Start

From this repository's root directory:

```bash
ln -sT "$PWD/now-playing" "$HOME/.config/omarchy/plugins/now-playing"
omarchy plugin validate "$HOME/.config/omarchy/plugins/now-playing"
omarchy-shell shell rescanPlugins
omarchy plugin enable now-playing --section right --before omarchy.tray
```

## Features

- Shows the active player, artist, and track title.
- Hides when no player has a track.
- Uses a rounded pill with a two-pixel gap above and below it.
- Fades long titles and scrolls them once after a track change.
- Uses the active Omarchy theme for colors and fonts.

## Controls

| Input | Action |
| --- | --- |
| Left click | Play or pause |
| Right click | Next track |
| Middle click | Previous track |

## Settings

`maxWidth` controls the maximum width of the artist and title text. The
default is `220` and the supported range is `120` to `480`.

Set it in the `now-playing` entry of `bar.layout` in
`~/.config/omarchy/shell.json`:

```json
{
  "id": "now-playing",
  "maxWidth": 280
}
```

## Requirements

The media player must support MPRIS, the Linux media-control protocol. Most
desktop players and browsers expose it while media is playing.

## Validate

```bash
omarchy plugin validate now-playing
qmllint now-playing/Widget.qml
```
