import QtQuick

// Standalone Omni does not depend on the personal desktop navbar. This shim
// keeps the search model contract intact without surfacing desktop-only IPC
// targets.
Item {
    id: navbarApps

    readonly property var items: []

    // Kept for callers that still nudge a refresh — now a no-op.
    function probe() {}
}
