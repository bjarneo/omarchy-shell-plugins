# Taildrop

Send and receive Taildrop files from the Omarchy bar.

## Quick Start

Enable **Send Files** in Tailscale Admin Console > Settings > General, then install:

```bash
mkdir -p ~/.config/omarchy/plugins
cp -a taildrop ~/.config/omarchy/plugins/taildrop
omarchy plugin validate ~/.config/omarchy/plugins/taildrop
omarchy plugin rescan
omarchy bar plugin add taildrop --section right
omarchy restart shell
```

## Use

- Choose files, use **Add files** to combine selections, click a device, then confirm **Yes, send**.
- Click **Clear file list** or press `x` to remove pending files.
- Click **Receive incoming files** or press `i` to save pending files to `~/Downloads`.
- Click **Cancel transfer** to stop an active send. Taildrop can resume interrupted sends.
- Click **Authorize Taildrop** once if Tailscale requests access. Later transfers do not need `sudo`.

## Requirements

- Tailscale CLI connected to your tailnet.
- A personal device eligible for Taildrop.
- Zenity, included with Omarchy, for file selection.

## Configure

```bash
omarchy bar plugin set taildrop refreshIntervalSec 60 --json
omarchy bar plugin set taildrop notifyOnComplete false --json
```

## Verify

```bash
omarchy plugin validate taildrop
qmllint taildrop/*.qml
node taildrop/Model.test.js
```
