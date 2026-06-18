import QtQuick

// Crisp, font-independent media transport icons drawn with Canvas2D.
Item {
    id: root

    property string shape: "play"
    property color color: "#d4be98"
    property real size: 14

    implicitWidth: size
    implicitHeight: size

    onShapeChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width;
            const h = height;
            const s = Math.min(w, h);
            const pad = Math.max(1, Math.round(s * 0.12));
            const x0 = (w - s) / 2 + pad;
            const y0 = (h - s) / 2 + pad;
            const sz = s - pad * 2;

            ctx.fillStyle = root.color;
            ctx.strokeStyle = root.color;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";

            switch (root.shape) {
            case "prev": drawPrev(ctx, x0, y0, sz); break;
            case "next": drawNext(ctx, x0, y0, sz); break;
            case "pause": drawPause(ctx, x0, y0, sz); break;
            case "stop": drawStop(ctx, x0, y0, sz); break;
            case "play":
            default: drawPlay(ctx, x0, y0, sz); break;
            }
        }

        function triangleRight(ctx, x, y, w, h) {
            ctx.beginPath();
            ctx.moveTo(x, y);
            ctx.lineTo(x + w, y + h / 2);
            ctx.lineTo(x, y + h);
            ctx.closePath();
            ctx.fill();
        }

        function drawPlay(ctx, x0, y0, sz) {
            const w = sz * 0.92;
            triangleRight(ctx, x0 + (sz - w) / 2, y0, w, sz);
        }

        function drawPause(ctx, x0, y0, sz) {
            const barW = Math.max(2, Math.round(sz * 0.28));
            const gap = Math.max(2, Math.round(sz * 0.18));
            const totalW = barW * 2 + gap;
            const left = x0 + (sz - totalW) / 2;
            ctx.fillRect(left, y0, barW, sz);
            ctx.fillRect(left + barW + gap, y0, barW, sz);
        }

        function drawStop(ctx, x0, y0, sz) {
            const side = sz * 0.86;
            const inset = (sz - side) / 2;
            ctx.fillRect(x0 + inset, y0 + inset, side, side);
        }

        function drawPrev(ctx, x0, y0, sz) {
            const barW = Math.max(1.5, sz * 0.14);
            ctx.fillRect(x0, y0, barW, sz);
            const tStart = x0 + barW + Math.max(1, sz * 0.06);
            const tSpan = (x0 + sz) - tStart;
            const tHalf = tSpan / 2;
            ctx.beginPath();
            ctx.moveTo(tStart, y0 + sz / 2);
            ctx.lineTo(tStart + tHalf, y0);
            ctx.lineTo(tStart + tHalf, y0 + sz);
            ctx.closePath();
            ctx.fill();
            ctx.beginPath();
            ctx.moveTo(tStart + tHalf, y0 + sz / 2);
            ctx.lineTo(tStart + tSpan, y0);
            ctx.lineTo(tStart + tSpan, y0 + sz);
            ctx.closePath();
            ctx.fill();
        }

        function drawNext(ctx, x0, y0, sz) {
            const barW = Math.max(1.5, sz * 0.14);
            const barX = x0 + sz - barW;
            ctx.fillRect(barX, y0, barW, sz);
            const tEnd = barX - Math.max(1, sz * 0.06);
            const tSpan = tEnd - x0;
            const tHalf = tSpan / 2;
            ctx.beginPath();
            ctx.moveTo(x0, y0);
            ctx.lineTo(x0 + tHalf, y0 + sz / 2);
            ctx.lineTo(x0, y0 + sz);
            ctx.closePath();
            ctx.fill();
            ctx.beginPath();
            ctx.moveTo(x0 + tHalf, y0);
            ctx.lineTo(tEnd, y0 + sz / 2);
            ctx.lineTo(x0 + tHalf, y0 + sz);
            ctx.closePath();
            ctx.fill();
        }
    }
}
