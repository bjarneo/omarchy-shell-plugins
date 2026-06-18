import QtQuick

// Winamp 2-inspired spectrum analyzer: stacked LED segments per band with
// falling peak caps.
Item {
    id: root

    property var bands: []
    property color barColor: "#a9b665"
    property color accentColor: "#d8a657"
    property color warnColor: "#ea6962"
    property int segH: 3
    property int segGap: 1

    implicitWidth: 320
    implicitHeight: 56

    property var peaks: Array(10).fill(0)

    Timer {
        interval: 33
        running: root.visible
        repeat: true
        onTriggered: {
            const current = root.peaks;
            const next = current.slice();
            let dirty = false;
            for (let i = 0; i < next.length; ++i) {
                const value = root.bands[i] || 0;
                const nextValue = value > next[i] ? value : Math.max(0, next[i] - 0.018);
                if (nextValue !== current[i]) dirty = true;
                next[i] = nextValue;
            }
            if (dirty) {
                root.peaks = next;
                canvas.requestPaint();
            }
        }
    }

    onBandsChanged: canvas.requestPaint()
    onBarColorChanged: canvas.requestPaint()
    onAccentColorChanged: canvas.requestPaint()
    onWarnColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width;
            const h = height;
            const bands = root.bands || [];
            const n = bands.length || 10;
            const minGap = 2;
            const barWidth = Math.max(2, Math.floor((w - minGap * (n - 1)) / n));
            const gap = n > 1 ? (w - barWidth * n) / (n - 1) : 0;
            const rows = Math.max(4, Math.floor(h / (root.segH + root.segGap)));
            const lowRows = Math.round(rows * 0.55);
            const midRows = Math.round(rows * 0.30);
            const rowColors = new Array(rows);

            for (let r = 0; r < rows; ++r) {
                if (r < lowRows) rowColors[r] = root.barColor;
                else if (r < lowRows + midRows) rowColors[r] = root.accentColor;
                else rowColors[r] = root.warnColor;
            }

            for (let i = 0; i < n; ++i) {
                const value = Math.max(0, Math.min(1, bands[i] || 0));
                const lit = Math.round(value * rows);
                const x = i * (barWidth + gap);
                for (let r = 0; r < lit; ++r) {
                    const y = h - (r + 1) * (root.segH + root.segGap) + root.segGap;
                    if (y < 0) break;
                    ctx.fillStyle = rowColors[r];
                    ctx.fillRect(x, y, barWidth, root.segH);
                }
            }

            ctx.fillStyle = root.accentColor;
            for (let i = 0; i < n; ++i) {
                const peak = Math.max(0, Math.min(1, root.peaks[i] || 0));
                if (peak <= 0) continue;
                const peakRow = Math.max(1, Math.round(peak * rows));
                const y = h - peakRow * (root.segH + root.segGap) + root.segGap;
                if (y < 0) continue;
                const x = i * (barWidth + gap);
                ctx.fillRect(x, y, barWidth, root.segH);
            }
        }
    }
}
