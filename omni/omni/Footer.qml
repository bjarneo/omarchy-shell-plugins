import QtQuick

// Footer line: surfaces the exec command of the current selection so
// the user can verify what's about to fire before pressing Enter.
Item {
    id: footer
    required property var omni

    width: parent ? parent.width : 0
    height: 22

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 4
        elide: Text.ElideRight
        text: {
            const it = footer.omni.filteredItems[footer.omni.selectedIndex];
            if (!it) return "";
            if (it.isCategory)  return "→ open " + it.target.toLowerCase();
            if (it.isProcess)   return "↵ kill " + (it.pid || "");
            if (it.isTheme)     return "↵ omarchy-theme-set " + (it.themeName || "");
            return "$ " + it.exec;
        }
        color: footer.omni.inkDeep
        font.family: footer.omni.mono
        font.pixelSize: 10 * footer.omni.fontScale
        font.letterSpacing: 1
        opacity: 0.65
    }
}
