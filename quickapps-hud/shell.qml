import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets

// Iron Man-style quick-app launcher. Hex tiles orbit an animated arc-reactor
// readout with scanlines, targeting beam, tactical frame, and launch charge.
ShellRoot {
    id: root

    // ---------- Apps ----------
    property var apps: []
    property int selectedIndex: 0
    readonly property var selectedApp: apps.length ? apps[selectedIndex] : null
    property real hudSweep: 0
    property real reactorPulse: 0.45
    property real launchCharge: 0

    NumberAnimation on hudSweep {
        from: 0
        to: 1
        duration: 9000
        loops: Animation.Infinite
    }
    SequentialAnimation on reactorPulse {
        loops: Animation.Infinite
        NumberAnimation { from: 0.32; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.0; to: 0.32; duration: 1200; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        id: chargeAnimation
        NumberAnimation { target: root; property: "launchCharge"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "launchCharge"; from: 1; to: 0; duration: 260; easing.type: Easing.OutCubic }
    }

    // ---------- Omarchy palette roles ----------
    property color background: "#0c1014"
    property color foreground: "#cdd6f4"
    property color mutedForeground: "#7f849c"
    property color accent: "#89b4fa"
    property color selectedForeground: "#f38ba8"

    readonly property color wash: Qt.lighter(background, 1.15)
    readonly property color overlayBackground: Qt.rgba(background.r, background.g, background.b, 0.97)
    readonly property color glassPanel: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.055)
    readonly property color gridLine: Qt.rgba(accent.r, accent.g, accent.b, 0.72)
    readonly property color hotLine: Qt.rgba(selectedForeground.r, selectedForeground.g, selectedForeground.b, 0.9)

    // ---------- Hex geometry ----------
    readonly property real tileRadius: 46
    readonly property real tileWidth: Math.sqrt(3) * tileRadius
    readonly property real tileHeight: 2 * tileRadius

    // Hex-ring radius. Scales with app count so the perimeter has enough
    // arclength to keep tiles from crowding each other. 90 is the minimum
    // centre-to-centre spacing we want; hex perimeter = 6 * R, so solve for R.
    readonly property real ringRadius: Math.max(230, apps.length * 90 / 6)

    // Place tile `index` of `total` evenly along the perimeter of a regular
    // pointy-top hexagon of radius `ringRadius`. First tile lands on the top
    // vertex, and subsequent tiles walk clockwise side by side.
    function tileOffset(index, total) {
        if (total <= 0) return { x: 0, y: 0 };
        const t = (index / total) * 6;
        const side = Math.floor(t) % 6;
        const frac = t - Math.floor(t);
        const a1 = (-90 + 60 * side) * Math.PI / 180;
        const a2 = (-90 + 60 * (side + 1)) * Math.PI / 180;
        const radius = ringRadius;
        const x1 = radius * Math.cos(a1), y1 = radius * Math.sin(a1);
        const x2 = radius * Math.cos(a2), y2 = radius * Math.sin(a2);
        return { x: x1 + (x2 - x1) * frac, y: y1 + (y2 - y1) * frac };
    }

    // ---------- Navigation ----------
    function rotate(delta) {
        if (apps.length) selectedIndex = (selectedIndex + delta + apps.length) % apps.length;
    }
    function jumpTo(index) {
        if (apps.length) selectedIndex = Math.max(0, Math.min(apps.length - 1, index));
    }

    function pad2(value) {
        const number = Number(value) || 0;
        return number < 10 ? "0" + number : String(number);
    }

    function drawHex(ctx, cx, cy, radius) {
        ctx.beginPath();
        for (let i = 0; i < 6; i++) {
            const angle = (Math.PI / 3) * i - Math.PI / 2;
            const px = cx + radius * Math.cos(angle);
            const py = cy + radius * Math.sin(angle);
            if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        }
        ctx.closePath();
    }

    // ---------- App list source ----------
    Process {
        running: true
        command: ["bash", "-c",
            "cat \"$HOME/.config/omarchy-quickapps-hud/apps.json\" 2>/dev/null"
            + " || cat \"$HOME/.config/omarchy-quickapps2/apps.json\" 2>/dev/null"
            + " || cat \"$HOME/.config/omarchy-quickapps/apps.json\" 2>/dev/null"
            + " || cat \"" + Quickshell.shellDir + "/quickapps.example.json\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.apps = (JSON.parse(this.text).apps) || []; }
                catch (e) { console.warn(e); }
            }
        }
    }

    // ---------- Launcher ----------
    Process { id: launchProc; running: false }
    Timer { id: launchExitTimer; interval: 320; onTriggered: Qt.quit() }
    function launchSelected() {
        const app = selectedApp;
        if (!app) return;
        chargeAnimation.restart();
        launchProc.command = ["sh", "-c", "setsid -f " + app.exec + " >/dev/null 2>&1"];
        launchProc.running = true;
        launchExitTimer.restart();
    }

    // ---------- Palette watcher ----------
    function parseColors(text) {
        const wanted = { background: null, foreground: null, accent: null, color1: null, color8: null };
        const line = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]+)"/;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const match = lines[i].match(line);
            if (match && (match[1] in wanted)) wanted[match[1]] = match[2];
        }
        if (wanted.background) root.background = wanted.background;
        if (wanted.foreground) root.foreground = wanted.foreground;
        if (wanted.color8) root.mutedForeground = wanted.color8;
        if (wanted.accent) root.accent = wanted.accent;
        if (wanted.color1) root.selectedForeground = wanted.color1;
    }

    function paletteCommand() {
        return "name=$(omarchy theme current 2>/dev/null | tr '[:upper:]' '[:lower:]'); "
             + "key=$(printf '%s' \"$name\" | tr -cs '[:alnum:]' '-'); "
             + "key=${key#-}; key=${key%-}; "
             + "for root in \"$HOME/.config/omarchy/themes\" \"$HOME/.local/share/omarchy/themes\" \"${OMARCHY_PATH:-/usr/share/omarchy}/themes\"; do "
             + "  file=\"$root/$key/colors.toml\"; "
             + "  [ -f \"$file\" ] && cat \"$file\" && exit 0; "
             + "done"
    }

    Process {
        id: paletteProc
        running: true
        command: ["bash", "-lc", root.paletteCommand()]
        stdout: StdioCollector {
            onStreamFinished: root.parseColors(this.text)
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            paletteProc.running = false;
            paletteProc.running = true;
        }
    }

    PanelWindow {
        id: panel
        anchors { top: true; bottom: true; left: true; right: true }
        color: root.overlayBackground
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickapps-hud"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: Qt.quit()
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) root.rotate(-1);
                else if (wheel.angleDelta.y < 0) root.rotate(1);
                wheel.accepted = true;
            }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
                    Qt.quit(); event.accepted = true;
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Up || event.key === Qt.Key_K
                    || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    root.rotate(-1); event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Down || event.key === Qt.Key_J
                    || event.key === Qt.Key_Tab) {
                    root.rotate(1); event.accepted = true;
                } else if (event.key === Qt.Key_Home) {
                    root.jumpTo(0); event.accepted = true;
                } else if (event.key === Qt.Key_End) {
                    root.jumpTo(root.apps.length - 1); event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.launchSelected(); event.accepted = true;
                } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    const index = event.key - Qt.Key_1;
                    if (index < root.apps.length) { root.selectedIndex = index; root.launchSelected(); }
                    event.accepted = true;
                }
            }
        }

        // ---------- Animated HUD wash ----------
        Rectangle {
            z: -8
            anchors.left: parent.left
            anchors.right: parent.right
            y: -height + (parent.height + height * 2) * root.hudSweep
            height: 190
            opacity: 0.22
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.0) }
                GradientStop { position: 0.48; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) }
                GradientStop { position: 0.52; color: Qt.rgba(root.selectedForeground.r, root.selectedForeground.g, root.selectedForeground.b, 0.28) }
                GradientStop { position: 1.00; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.0) }
            }
        }

        Canvas {
            id: hudFrame
            z: 20
            anchors.fill: parent
            property color stroke: root.gridLine
            property color hot: root.hotLine
            property real charge: root.launchCharge
            onStrokeChanged: requestPaint()
            onHotChanged: requestPaint()
            onChargeChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const margin = 42;
                const len = 132;
                const notch = 18;
                ctx.lineWidth = 1.4;
                ctx.strokeStyle = stroke;
                ctx.globalAlpha = 0.82;

                function corner(x, y, sx, sy) {
                    ctx.beginPath();
                    ctx.moveTo(x, y + sy * len);
                    ctx.lineTo(x, y);
                    ctx.lineTo(x + sx * len, y);
                    ctx.moveTo(x + sx * notch, y + sy * notch);
                    ctx.lineTo(x + sx * (len * 0.48), y + sy * notch);
                    ctx.moveTo(x + sx * notch, y + sy * notch);
                    ctx.lineTo(x + sx * notch, y + sy * (len * 0.48));
                    ctx.stroke();
                }

                corner(margin, margin, 1, 1);
                corner(width - margin, margin, -1, 1);
                corner(margin, height - margin, 1, -1);
                corner(width - margin, height - margin, -1, -1);

                ctx.globalAlpha = 0.28;
                ctx.beginPath();
                ctx.moveTo(width * 0.22, margin + 10);
                ctx.lineTo(width * 0.78, margin + 10);
                ctx.moveTo(width * 0.22, height - margin - 10);
                ctx.lineTo(width * 0.78, height - margin - 10);
                ctx.stroke();

                if (charge > 0) {
                    ctx.strokeStyle = hot;
                    ctx.globalAlpha = charge;
                    ctx.lineWidth = 2.4;
                    const cx = width / 2;
                    const cy = height / 2;
                    const r = 260 + charge * 260;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    ctx.stroke();
                }
            }
        }

        Text {
            z: 21
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 58
            anchors.topMargin: 44
            text: "MARK HUD // QUICK LAUNCH"
            color: root.foreground
            opacity: 0.88
            font.family: "monospace"
            font.pixelSize: 12
            font.letterSpacing: 4
        }

        Text {
            z: 21
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 58
            anchors.topMargin: 44
            text: "SLOT " + root.pad2(root.selectedIndex + 1) + " / " + root.pad2(root.apps.length)
            color: root.selectedForeground
            opacity: 0.88
            font.family: "monospace"
            font.pixelSize: 12
            font.letterSpacing: 3
        }

        Text {
            z: 21
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 58
            anchors.bottomMargin: 44
            text: "ARC REACTOR ONLINE   TARGET LOCK " + (root.selectedApp ? root.selectedApp.name.toUpperCase() : "NONE")
            color: root.mutedForeground
            opacity: 0.78
            font.family: "monospace"
            font.pixelSize: 10
            font.letterSpacing: 2
        }

        Column {
            z: 21
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 58
            anchors.topMargin: 98
            spacing: 9
            Repeater {
                model: ["REACTOR  STABLE", "ROUTE    ARMED", "SHELL    ONLINE"]
                delegate: Text {
                    required property string modelData
                    text: modelData
                    color: root.mutedForeground
                    opacity: 0.58
                    font.family: "monospace"
                    font.pixelSize: 9
                    font.letterSpacing: 2
                }
            }
        }

        Column {
            z: 21
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 58
            anchors.topMargin: 98
            spacing: 7
            Repeater {
                model: 5
                delegate: Rectangle {
                    required property int index
                    width: 84 - index * 9
                    height: 2
                    color: index === 0 ? root.selectedForeground : root.accent
                    opacity: 0.24 + (4 - index) * 0.08 + root.reactorPulse * 0.12
                }
            }
        }

        // ---------- Faint hex grid background ----------
        Canvas {
            id: gridWash
            z: -10
            anchors.fill: parent
            opacity: 0.06
            property color stroke: root.accent
            property real sweep: root.hudSweep
            onStrokeChanged: requestPaint()
            onSweepChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = stroke;
                ctx.lineWidth = 1;
                ctx.translate((sweep - 0.5) * 26, 0);
                const radius = 38;
                const width_ = Math.sqrt(3) * radius;
                const height_ = 2 * radius;
                const verticalStep = height_ * 0.75;
                for (let row = -1; row * verticalStep < height + height_; row++) {
                    const y = row * verticalStep;
                    const xOffset = (row % 2 === 0) ? 0 : width_ / 2;
                    for (let col = -1; col * width_ + xOffset < width + width_; col++) {
                        const cx = col * width_ + xOffset;
                        const cy = y;
                        ctx.beginPath();
                        for (let i = 0; i < 6; i++) {
                            const angle = (Math.PI / 3) * i - Math.PI / 2;
                            const px = cx + radius * Math.cos(angle);
                            const py = cy + radius * Math.sin(angle);
                            if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
                        }
                        ctx.closePath();
                        ctx.stroke();
                    }
                }
            }
        }

        // ---------- Stage ----------
        Item {
            id: stage
            anchors.centerIn: parent
            width: 760
            height: 760

            // Hex ring outline: a circle drawn from six line segments.
            // Tiles sit on the corners and edges of this outline.
            Canvas {
                id: hexRing
                anchors.fill: parent
                z: 0
                property color stroke: root.accent
                property real radius: root.ringRadius
                property real sweep: root.hudSweep
                onStrokeChanged: requestPaint()
                onRadiusChanged: requestPaint()
                onSweepChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = stroke;
                    ctx.globalAlpha = 0.4;
                    ctx.lineWidth = 1;
                    const cx = width / 2, cy = height / 2;
                    root.drawHex(ctx, cx, cy, radius);
                    ctx.stroke();

                    ctx.globalAlpha = 0.75;
                    ctx.strokeStyle = root.hotLine;
                    ctx.lineWidth = 1.6;
                    const side = Math.floor(sweep * 6) % 6;
                    const a1 = (-90 + 60 * side) * Math.PI / 180;
                    const a2 = (-90 + 60 * (side + 0.62)) * Math.PI / 180;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, a1, a2);
                    ctx.stroke();
                }
            }

            Canvas {
                id: selectionBeam
                anchors.fill: parent
                z: 1
                property int selected: root.selectedIndex
                property int total: root.apps.length
                property real pulse: root.reactorPulse
                property color stroke: root.hotLine
                onSelectedChanged: requestPaint()
                onTotalChanged: requestPaint()
                onPulseChanged: requestPaint()
                onStrokeChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    if (total <= 0) return;
                    const centerX = width / 2;
                    const centerY = height / 2;
                    const offset = root.tileOffset(selected, total);
                    const targetX = centerX + offset.x;
                    const targetY = centerY + offset.y;
                    ctx.strokeStyle = stroke;
                    ctx.lineWidth = 1;
                    ctx.globalAlpha = 0.28 + pulse * 0.26;
                    ctx.beginPath();
                    ctx.moveTo(centerX, centerY);
                    ctx.lineTo(targetX, targetY);
                    ctx.stroke();

                    ctx.globalAlpha = 0.5 + pulse * 0.4;
                    ctx.beginPath();
                    ctx.arc(targetX, targetY, root.tileRadius + 14 + pulse * 5, 0, Math.PI * 2);
                    ctx.stroke();
                }
            }

            Item {
                id: reactor
                z: 5
                anchors.centerIn: parent
                width: 286
                height: 286

                Canvas {
                    id: reactorCanvas
                    anchors.fill: parent
                    property real sweep: root.hudSweep
                    property real pulse: root.reactorPulse
                    property real charge: root.launchCharge
                    property color stroke: root.gridLine
                    property color hot: root.hotLine
                    onSweepChanged: requestPaint()
                    onPulseChanged: requestPaint()
                    onChargeChanged: requestPaint()
                    onStrokeChanged: requestPaint()
                    onHotChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const cx = width / 2;
                        const cy = height / 2;
                        const start = -Math.PI / 2 + sweep * Math.PI * 2;

                        ctx.strokeStyle = stroke;
                        ctx.lineWidth = 1;
                        ctx.globalAlpha = 0.24 + pulse * 0.18;
                        root.drawHex(ctx, cx, cy, 124);
                        ctx.stroke();

                        ctx.globalAlpha = 0.38 + pulse * 0.24;
                        ctx.beginPath();
                        ctx.arc(cx, cy, 102, 0, Math.PI * 2);
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.arc(cx, cy, 74, 0, Math.PI * 2);
                        ctx.stroke();

                        ctx.strokeStyle = hot;
                        ctx.lineWidth = 2.2;
                        ctx.globalAlpha = 0.62 + pulse * 0.32;
                        for (let i = 0; i < 3; i++) {
                            const offset = start + i * Math.PI * 2 / 3;
                            ctx.beginPath();
                            ctx.arc(cx, cy, 92 + i * 8, offset, offset + Math.PI * 0.56);
                            ctx.stroke();
                        }

                        ctx.lineWidth = 1.2;
                        ctx.globalAlpha = 0.32 + pulse * 0.2;
                        for (let i = 0; i < 12; i++) {
                            const angle = i * Math.PI / 6 + sweep * Math.PI * 2;
                            ctx.beginPath();
                            ctx.moveTo(cx + Math.cos(angle) * 50, cy + Math.sin(angle) * 50);
                            ctx.lineTo(cx + Math.cos(angle) * 64, cy + Math.sin(angle) * 64);
                            ctx.stroke();
                        }

                        ctx.fillStyle = hot;
                        ctx.globalAlpha = 0.18 + pulse * 0.18 + charge * 0.34;
                        ctx.beginPath();
                        ctx.arc(cx, cy, 34 + pulse * 4 + charge * 18, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
            }

            Text {
                z: 8
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -78
                text: "ARC"
                color: root.selectedForeground
                opacity: 0.82 + root.reactorPulse * 0.18
                font.family: "monospace"
                font.pixelSize: 11
                font.letterSpacing: 5
            }

            Rectangle {
                z: 8
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 36
                width: 150
                height: 1
                color: root.selectedForeground
                opacity: 0.55 + root.reactorPulse * 0.25
            }

            // ---------- Hex tiles ----------
            Repeater {
                model: root.apps
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool focused: index === root.selectedIndex
                    width: root.tileWidth + 6
                    height: root.tileHeight + 6
                    z: focused ? 10 : 1

                    readonly property var offset: root.tileOffset(index, root.apps.length)
                    x: stage.width / 2 - width / 2 + offset.x
                    y: stage.height / 2 - height / 2 + offset.y
                    Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuart } }
                    Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutQuart } }

                    scale: focused ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutQuart } }

                    Canvas {
                        id: hexBody
                        anchors.fill: parent
                        property color fillColor: tile.focused ? root.foreground : root.wash
                        property color strokeColor: tile.focused ? root.hotLine : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.65)
                        property real strokeWidth: tile.focused ? 1.6 : 1.0
                        property real pulse: root.reactorPulse
                        onFillColorChanged: requestPaint()
                        onStrokeColorChanged: requestPaint()
                        onStrokeWidthChanged: requestPaint()
                        onPulseChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const cx = width / 2, cy = height / 2;
                            const radius = root.tileRadius;
                            ctx.globalAlpha = tile.focused ? 0.96 : 0.42;
                            root.drawHex(ctx, cx, cy, radius);
                            ctx.fillStyle = fillColor;
                            ctx.fill();
                            ctx.strokeStyle = strokeColor;
                            ctx.lineWidth = strokeWidth;
                            ctx.stroke();
                            if (tile.focused) {
                                ctx.globalAlpha = 0.45 + pulse * 0.35;
                                ctx.lineWidth = 2.6;
                                root.drawHex(ctx, cx, cy, radius + 2);
                                ctx.stroke();
                            }
                        }
                    }

                    IconImage {
                        id: iconImage
                        anchors.centerIn: parent
                        implicitSize: 38
                        width: 38
                        height: 38
                        source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                        smooth: true
                        asynchronous: true
                        mipmap: true
                        opacity: tile.focused ? 0.95 : 0.6
                        layer.enabled: iconImage.status === Image.Ready
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: tile.focused ? root.background : root.foreground
                        }
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: iconImage.status !== Image.Ready
                        text: (modelData.name || "?").charAt(0).toUpperCase()
                        color: tile.focused ? root.background : root.foreground
                        font.family: "monospace"
                        font.pixelSize: 22
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 6
                        width: 128
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: (modelData.name || "").toUpperCase()
                        color: tile.focused ? root.selectedForeground : root.mutedForeground
                        opacity: tile.focused ? 0.95 : 0.44
                        font.family: "monospace"
                        font.pixelSize: tile.focused ? 10 : 9
                        font.letterSpacing: 1.5
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = tile.index
                        onClicked: { root.selectedIndex = tile.index; root.launchSelected(); }
                    }
                }
            }

            // Centre readout sits in the empty middle of the hex ring.
            Column {
                z: 9
                anchors.centerIn: parent
                width: 360
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.selectedApp ? root.selectedApp.name.toUpperCase() : "----"
                    color: root.foreground
                    font.family: "monospace"
                    font.pixelSize: 18
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.selectedApp ? (root.selectedApp.comment || root.selectedApp.exec || "") : ""
                    color: root.mutedForeground
                    font.family: "monospace"
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
            }
        }

        // ---------- Footer hint ----------
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50
            text: "TAB  CYCLE     ENT  EXECUTE     ESC  DISMISS"
            color: root.mutedForeground
            font.family: "monospace"
            font.pixelSize: 10
            font.letterSpacing: 3
        }
    }
}
