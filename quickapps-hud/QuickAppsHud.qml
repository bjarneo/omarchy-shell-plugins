import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import qs.Commons

// Iron Man-style quick-app launcher as a native Omarchy shell overlay.
// Performance notes: animations run only while open, Canvas items are static
// except on theme/selection changes, and the plugin is unloaded when hidden.
Item {
    id: root

    property var shell: null
    property var manifest: null
    readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "quickapps-hud"
    readonly property string pluginDir: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : Quickshell.shellDir

    property bool opened: false
    property var apps: []
    property int selectedIndex: 0
    readonly property var selectedApp: apps.length ? apps[Math.max(0, Math.min(apps.length - 1, selectedIndex))] : null

    property real scanPosition: 0
    property real spinnerRotation: 0
    property real pulse: 0.35
    property real launchCharge: 0

    readonly property color background: Color.popups.background
    readonly property color foreground: Color.popups.text
    readonly property color mutedForeground: Color.muted
    readonly property color accent: Color.accent
    readonly property color selectedForeground: Style.selectedStateColor(foreground, accent, Color.urgent)
    readonly property color overlayBackground: Qt.rgba(background.r, background.g, background.b, 0.96)
    readonly property color glassPanel: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.055)
    readonly property color gridLine: Qt.rgba(accent.r, accent.g, accent.b, 0.58)
    readonly property color hotLine: Qt.rgba(selectedForeground.r, selectedForeground.g, selectedForeground.b, 0.88)
    readonly property color tileFill: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.055)

    readonly property real tileRadius: 44
    readonly property real tileWidth: Math.sqrt(3) * tileRadius
    readonly property real tileHeight: 2 * tileRadius
    readonly property real ringRadius: Math.max(218, apps.length * 84 / 6)

    NumberAnimation on scanPosition {
        running: root.opened
        from: 0
        to: 1
        duration: 5200
        loops: Animation.Infinite
    }

    NumberAnimation on spinnerRotation {
        running: root.opened
        from: 0
        to: 360
        duration: 7800
        loops: Animation.Infinite
    }

    SequentialAnimation on pulse {
        running: root.opened
        loops: Animation.Infinite
        NumberAnimation { from: 0.25; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.0; to: 0.25; duration: 950; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: chargeAnimation
        NumberAnimation { target: root; property: "launchCharge"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "launchCharge"; from: 1; to: 0; duration: 220; easing.type: Easing.OutCubic }
    }

    function open(payloadJson) {
        let payload = ({});
        try { payload = JSON.parse(payloadJson || "{}"); } catch (_) { payload = ({}); }
        root.selectedIndex = payload.index !== undefined ? Number(payload.index) || 0 : 0;
        root.opened = true;
        root.scanPosition = 0;
        root.spinnerRotation = 0;
        root.loadApps();
        Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
    }

    function close() {
        root.opened = false;
        launchCloseTimer.stop();
        appsProc.running = false;
    }

    function dismiss() {
        root.close();
        if (shell && typeof shell.hide === "function") shell.hide(pluginId);
    }

    function toggle(payloadJson) {
        if (root.opened) dismiss(); else open(payloadJson || "{}");
    }

    function refresh() {
        root.loadApps();
        return "ok";
    }

    function appsCommand() {
        return "cat \"$HOME/.config/omarchy-quickapps-hud/apps.json\" 2>/dev/null"
             + " || cat \"$HOME/.config/omarchy-quickapps2/apps.json\" 2>/dev/null"
             + " || cat \"$HOME/.config/omarchy-quickapps/apps.json\" 2>/dev/null"
             + " || cat \"" + root.pluginDir + "/quickapps.example.json\"";
    }

    function loadApps() {
        appsProc.command = ["bash", "-lc", root.appsCommand()];
        appsProc.running = false;
        appsProc.running = true;
    }

    function rotate(delta) {
        if (!apps.length) return;
        selectedIndex = (selectedIndex + delta + apps.length) % apps.length;
    }

    function jumpTo(index) {
        if (!apps.length) return;
        selectedIndex = Math.max(0, Math.min(apps.length - 1, index));
    }

    function pad2(value) {
        const number = Number(value) || 0;
        return number < 10 ? "0" + number : String(number);
    }

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

    function launchSelected() {
        const app = selectedApp;
        if (!app || !app.exec) return;
        chargeAnimation.restart();
        launchProc.command = ["sh", "-c", "setsid -f " + app.exec + " >/dev/null 2>&1"];
        launchProc.running = false;
        launchProc.running = true;
        launchCloseTimer.restart();
    }

    Process {
        id: appsProc
        running: false
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text || "{}");
                    const list = Array.isArray(parsed.apps) ? parsed.apps : [];
                    root.apps = list.filter(app => app && app.name && app.exec);
                    if (root.selectedIndex >= root.apps.length) root.selectedIndex = 0;
                } catch (e) {
                    console.warn("quickapps-hud: failed to parse apps.json", e);
                    root.apps = [];
                }
            }
        }
    }

    Process { id: launchProc; running: false }
    Timer { id: launchCloseTimer; interval: 260; onTriggered: root.dismiss() }

    PanelWindow {
        id: panel
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: root.overlayBackground
        WlrLayershell.namespace: "quickapps-hud"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: root.dismiss()
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) root.rotate(-1);
                else if (wheel.angleDelta.y < 0) root.rotate(1);
                wheel.accepted = true;
            }
        }

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: root.opened
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
                    root.dismiss(); event.accepted = true;
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

        // Static grid: expensive full-screen Canvas paints only on resize/theme.
        Canvas {
            id: grid
            anchors.fill: parent
            opacity: 0.045
            property color stroke: root.accent
            onStrokeChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = stroke;
                ctx.lineWidth = 1;
                const radius = 42;
                const hexWidth = Math.sqrt(3) * radius;
                const hexHeight = 2 * radius;
                const verticalStep = hexHeight * 0.75;
                for (let row = -1; row * verticalStep < height + hexHeight; row++) {
                    const y = row * verticalStep;
                    const xOffset = (row % 2 === 0) ? 0 : hexWidth / 2;
                    for (let col = -1; col * hexWidth + xOffset < width + hexWidth; col++) {
                        root.drawHex(ctx, col * hexWidth + xOffset, y, radius);
                        ctx.stroke();
                    }
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            y: -height + (panel.height + height * 2) * root.scanPosition
            height: 170
            opacity: 0.16
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.0) }
                GradientStop { position: 0.48; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) }
                GradientStop { position: 0.52; color: Qt.rgba(root.selectedForeground.r, root.selectedForeground.g, root.selectedForeground.b, 0.26) }
                GradientStop { position: 1.00; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.0) }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.selectedForeground.r, root.selectedForeground.g, root.selectedForeground.b, 0.20)
            opacity: root.launchCharge
        }

        Canvas {
            id: hudFrame
            anchors.fill: parent
            property color stroke: root.gridLine
            property color hot: root.hotLine
            onStrokeChanged: requestPaint()
            onHotChanged: requestPaint()
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
            }
        }

        Text {
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

        Column {
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

        Item {
            id: stage
            anchors.centerIn: parent
            width: Math.max(560, Math.min(panel.width - 150, panel.height - 120, 820))
            height: width

            Canvas {
                id: ring
                anchors.fill: parent
                property color stroke: root.gridLine
                property real radius: root.ringRadius
                onStrokeChanged: requestPaint()
                onRadiusChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = width / 2, cy = height / 2;
                    ctx.strokeStyle = stroke;
                    ctx.globalAlpha = 0.42;
                    ctx.lineWidth = 1;
                    root.drawHex(ctx, cx, cy, radius);
                    ctx.stroke();
                    ctx.globalAlpha = 0.16;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius * 0.72, 0, Math.PI * 2);
                    ctx.stroke();
                }
            }

            Canvas {
                id: ringSweep
                anchors.fill: parent
                rotation: root.spinnerRotation
                property color stroke: root.hotLine
                property real radius: root.ringRadius
                onStrokeChanged: requestPaint()
                onRadiusChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = stroke;
                    ctx.globalAlpha = 0.72;
                    ctx.lineWidth = 1.8;
                    const cx = width / 2, cy = height / 2;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 0.38);
                    ctx.stroke();
                }
            }

            Canvas {
                id: selectionBeam
                anchors.fill: parent
                property int selected: root.selectedIndex
                property int total: root.apps.length
                property color stroke: root.hotLine
                onSelectedChanged: requestPaint()
                onTotalChanged: requestPaint()
                onStrokeChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    if (total <= 0) return;
                    const centerX = width / 2, centerY = height / 2;
                    const offset = root.tileOffset(selected, total);
                    const targetX = centerX + offset.x;
                    const targetY = centerY + offset.y;
                    ctx.strokeStyle = stroke;
                    ctx.lineWidth = 1;
                    ctx.globalAlpha = 0.42;
                    ctx.beginPath();
                    ctx.moveTo(centerX, centerY);
                    ctx.lineTo(targetX, targetY);
                    ctx.stroke();
                    ctx.globalAlpha = 0.58;
                    ctx.beginPath();
                    ctx.arc(targetX, targetY, root.tileRadius + 16, 0, Math.PI * 2);
                    ctx.stroke();
                }
            }

            Item {
                id: reactor
                anchors.centerIn: parent
                width: 280
                height: 280

                Canvas {
                    anchors.fill: parent
                    property color stroke: root.gridLine
                    property color hot: root.hotLine
                    onStrokeChanged: requestPaint()
                    onHotChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const cx = width / 2, cy = height / 2;
                        ctx.strokeStyle = stroke;
                        ctx.lineWidth = 1;
                        ctx.globalAlpha = 0.38;
                        root.drawHex(ctx, cx, cy, 122);
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.arc(cx, cy, 102, 0, Math.PI * 2);
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.arc(cx, cy, 72, 0, Math.PI * 2);
                        ctx.stroke();
                        ctx.strokeStyle = hot;
                        ctx.globalAlpha = 0.68;
                        ctx.lineWidth = 1.5;
                        for (let i = 0; i < 12; i++) {
                            const angle = i * Math.PI / 6;
                            ctx.beginPath();
                            ctx.moveTo(cx + Math.cos(angle) * 50, cy + Math.sin(angle) * 50);
                            ctx.lineTo(cx + Math.cos(angle) * 64, cy + Math.sin(angle) * 64);
                            ctx.stroke();
                        }
                    }
                }

                Canvas {
                    anchors.fill: parent
                    rotation: root.spinnerRotation * -1.35
                    property color stroke: root.hotLine
                    onStrokeChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const cx = width / 2, cy = height / 2;
                        ctx.strokeStyle = stroke;
                        ctx.lineWidth = 2.2;
                        ctx.globalAlpha = 0.78;
                        for (let i = 0; i < 3; i++) {
                            const offset = -Math.PI / 2 + i * Math.PI * 2 / 3;
                            ctx.beginPath();
                            ctx.arc(cx, cy, 92 + i * 8, offset, offset + Math.PI * 0.56);
                            ctx.stroke();
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 68 + root.pulse * 8
                    height: width
                    radius: width / 2
                    color: Qt.rgba(root.selectedForeground.r, root.selectedForeground.g, root.selectedForeground.b, 0.16 + root.pulse * 0.10)
                }
            }

            Column {
                anchors.centerIn: parent
                width: 360
                spacing: 7

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
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 150
                    height: 1
                    color: root.selectedForeground
                    opacity: 0.62
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

            Repeater {
                model: root.apps
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool focused: index === root.selectedIndex
                    readonly property var offset: root.tileOffset(index, root.apps.length)
                    width: root.tileWidth + 6
                    height: root.tileHeight + 6
                    x: stage.width / 2 - width / 2 + offset.x
                    y: stage.height / 2 - height / 2 + offset.y
                    z: focused ? 10 : 1
                    scale: focused ? 1.08 : 1.0

                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuart } }
                    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuart } }
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuart } }

                    Canvas {
                        id: tileBody
                        anchors.fill: parent
                        property bool focused_: tile.focused
                        property color fillColor: tile.focused ? root.foreground : root.tileFill
                        property color strokeColor: tile.focused ? root.hotLine : root.gridLine
                        onFocused_Changed: requestPaint()
                        onFillColorChanged: requestPaint()
                        onStrokeColorChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const cx = width / 2, cy = height / 2;
                            ctx.globalAlpha = focused_ ? 0.96 : 0.56;
                            root.drawHex(ctx, cx, cy, root.tileRadius);
                            ctx.fillStyle = fillColor;
                            ctx.fill();
                            ctx.strokeStyle = strokeColor;
                            ctx.lineWidth = focused_ ? 2.2 : 1.0;
                            ctx.stroke();
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
                        opacity: tile.focused ? 0.96 : 0.62
                        layer.enabled: iconImage.status === Image.Ready
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: tile.focused ? root.background : root.foreground
                        }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
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
                        opacity: tile.focused ? 0.95 : 0.42
                        font.family: "monospace"
                        font.pixelSize: tile.focused ? 10 : 9
                        font.letterSpacing: 1.5
                        Behavior on opacity { NumberAnimation { duration: 140 } }
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
        }

        Text {
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

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50
            text: "TAB  CYCLE     ENT  EXECUTE     ESC  DISMISS"
            color: root.mutedForeground
            opacity: 0.84
            font.family: "monospace"
            font.pixelSize: 10
            font.letterSpacing: 3
        }
    }
}
