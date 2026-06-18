import QtQuick
import qs.Commons

// Adapter from Omarchy shell's shared style singletons. Omni should use the
// running shell palette, not old theme-specific colour aliases.
Item {
    id: theme

    readonly property color background: Color.popups.background
    readonly property color foreground: Color.popups.text
    readonly property color mutedForeground: Color.muted
    readonly property color accent: Color.accent
    readonly property color urgent: Color.urgent
    readonly property color border: Color.popups.border

    readonly property color hoverForeground: Style.hoverStateColor(foreground, accent, urgent)
    readonly property color selectedForeground: Style.selectedStateColor(foreground, accent, urgent)
    readonly property color selectionForeground: background
    readonly property color hoverFill: Style.hoverFillFor(foreground, accent, urgent)
    readonly property color selectedFill: Style.selectedFillFor(foreground, accent, urgent)

    readonly property string serif: "serif"
    readonly property string mono:  Style.font.family

    readonly property int  cornerRadius: Style.cornerRadius
    readonly property bool round:        cornerRadius > 0
}
