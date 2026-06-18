import QtQuick
import Quickshell
import Quickshell.Io
import "Data.js" as Data

// ps-driven process list, sorted by CPU. Selection drives a /proc-based
// cmdline + stat preview; Enter sends SIGTERM via the parent's
// activate() special-case. List refreshes on entering the mode and
// after a successful kill so the view never lies about pids that just
// exited.
Item {
    id: processes

    required property bool active
    required property var selectedItem

    property var items: []
    property string previewPid: ""
    property string previewText: ""
    readonly property bool running: psProc.running || previewProc.running

    function clear() {
        processes.items = [];
        processes.previewPid = "";
        processes.previewText = "";
    }

    function refresh() {
        // --no-headers + a fixed column layout gives a stable split on
        // whitespace. comm is last so a command with spaces would still
        // line up (kernel threads can have spaces, e.g. `kworker/...`).
        psProc.command = ["sh", "-c",
            "ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu --no-headers | head -200"];
        psProc.running = false;
        psProc.running = true;
    }

    function killPid(pid, force) {
        killProc.command = ["kill", force ? "-9" : "-15", pid];
        killProc.running = false;
        killProc.running = true;
    }

    function updatePreview() {
        if (!processes.active) return;
        const it = processes.selectedItem;
        const pid = (it && it.pid) || "";
        if (pid === processes.previewPid) return;
        processes.previewPid = pid;
        processes.previewText = "";
        if (!pid) return;
        processes.previewText = "Loading…";
        // /proc/<pid>/cmdline is NUL-separated; tr swaps to spaces.
        // Extra ps call surfaces start time + state + nice so the
        // preview tells you whether you're about to nuke a zombie or
        // your editor.
        previewProc.command = ["sh", "-c",
              "p=\"$1\"; "
            + "printf 'CMD    '; tr '\\0' ' ' < /proc/$p/cmdline 2>/dev/null; echo; "
            + "ps -p \"$p\" -o etime=,stat=,nice=,rss=,user= 2>/dev/null | "
            + "awk '{ printf \"ELAPSED %s\\nSTATE  %s\\nNICE   %s\\nRSS    %s KB\\nUSER   %s\\n\", $1,$2,$3,$4,$5 }'",
            "sh", pid];
        previewProc.running = false;
        previewProc.running = true;
    }

    function ingest(text) {
        const lines = text.split("\n");
        const out = [];
        for (let i = 0; i < lines.length; i++) {
            const ln = lines[i].trim();
            if (!ln) continue;
            // PID USER %CPU %MEM COMM
            const parts = ln.split(/\s+/);
            if (parts.length < 5) continue;
            const pid = parts[0];
            const user = parts[1];
            const cpu = parts[2];
            const mem = parts[3];
            const comm = parts.slice(4).join(" ");
            const cat = cpu + "%  " + mem + "%";
            const kw = (comm + " " + user + " " + pid).toLowerCase();
            out.push({
                title: comm,
                category: cat,
                keywords: kw,
                icon: "󰍛",
                exec: "",
                pid: pid,
                isProcess: true,
                rawCategory: true,
                _t: comm.toLowerCase(),
                _k: kw,
                _c: cat.toLowerCase()
            });
        }
        processes.items = out;
    }

    onActiveChanged: {
        if (processes.active) processes.refresh();
        else processes.clear();
    }
    onSelectedItemChanged: { if (processes.active) processes.updatePreview(); }

    Process {
        id: psProc
        running: false
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: { processes.ingest(this.text || ""); processes.updatePreview(); }
        }
    }

    Process {
        id: previewProc
        running: false
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: { processes.previewText = this.text || ""; }
        }
    }

    Process {
        id: killProc
        running: false
        command: ["true"]
        onExited: function(code) {
            // Refresh whether the kill succeeded or not — a failed kill
            // (permission denied, already-dead pid) should still pull
            // fresh stats so the user sees current state.
            if (processes.active) processes.refresh();
        }
    }
}
