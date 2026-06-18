import QtQuick
import qs.Commons

// Adapter from Omarchy shell's shared style singletons to the semantic names
// used by the original Omni quickshell config. This keeps Omni themed by the
// running shell instead of reading colors.toml itself.
Item {
    id: theme

    readonly property color paper:   Color.background
    readonly property color ink:     Color.popups.text
    readonly property color inkDeep: Qt.rgba(ink.r, ink.g, ink.b, 0.68)
    readonly property color sumi:    Qt.rgba(ink.r, ink.g, ink.b, 0.52)
    readonly property color focusColor: Style.selectedStateColor(ink, ink, Color.urgent)
    readonly property color indigo:  Style.hoverStateColor(ink, ink, Color.urgent)
    readonly property color green:   Color.foreground
    readonly property color seal:    focusColor

    readonly property string serif: "serif"
    readonly property string mono:  Style.font.family

    readonly property int  cornerRadius: Style.cornerRadius
    readonly property bool round:        cornerRadius > 0

    readonly property color bg:     Color.popups.background
    readonly property color fg:     Color.popups.text
    readonly property color muted:  sumi
    readonly property color accent: focusColor
    readonly property color warn:   Color.urgent
    readonly property color sep:    Style.normalBorderFor(ink, ink, Color.urgent)
    readonly property color rowHi:  Style.hoverFillFor(ink, ink, Color.urgent)
    readonly property color rowSel: Style.selectedFillFor(ink, ink, Color.urgent)
}
