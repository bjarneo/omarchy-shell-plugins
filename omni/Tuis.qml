import QtQuick
import Quickshell.Io
import "Data.js" as Data

// Probes a curated list of terminal-UI apps at startup and surfaces
// only the ones actually on $PATH. Items launch via omarchy-launch-tui
// so they get a real terminal (most don't ship .desktop entries; the
// ones that do are picked up by AppScan with Terminal=true respected
// — the duplicate is fine, users star the one they prefer).
Item {
    id: tuis

    readonly property var candidates: [
        { cmd: "lazygit",    title: "lazygit",    icon: "󰊢", keywords: "lazygit git tui repo branch commit diff log" },
        { cmd: "lazydocker", title: "lazydocker", icon: "󰡨", keywords: "lazydocker docker containers compose images volumes tui" },
        { cmd: "btop",       title: "btop",       icon: "󰍛", keywords: "btop system monitor cpu memory disk processes" },
        { cmd: "htop",       title: "htop",       icon: "󰍛", keywords: "htop system monitor cpu memory processes" },
        { cmd: "yazi",       title: "yazi",       icon: "󰉋", keywords: "yazi file manager browser tui" },
        { cmd: "ranger",     title: "ranger",     icon: "󰉋", keywords: "ranger file manager browser tui" },
        { cmd: "nnn",        title: "nnn",        icon: "󰉋", keywords: "nnn file manager browser tui" },
        { cmd: "lf",         title: "lf",         icon: "󰉋", keywords: "lf file manager browser tui" },
        { cmd: "mc",         title: "Midnight Commander", icon: "󰉋", keywords: "mc midnight commander file manager tui" },
        { cmd: "ncdu",       title: "ncdu",       icon: "󰋊", keywords: "ncdu disk usage du tui size" },
        { cmd: "tig",        title: "tig",        icon: "󰊢", keywords: "tig git log diff browser tui" },
        { cmd: "k9s",        title: "k9s",        icon: "󱃾", keywords: "k9s kubernetes kubectl pods tui" },
        { cmd: "nvtop",      title: "nvtop",      icon: "󰢮", keywords: "nvtop gpu nvidia amd monitor tui" },
        { cmd: "glances",    title: "glances",    icon: "󰍛", keywords: "glances system monitor tui" },
        { cmd: "broot",      title: "broot",      icon: "󰉋", keywords: "broot file tree browser tui" },
        { cmd: "atuin",      title: "atuin",      icon: "󱆃", keywords: "atuin shell history fuzzy tui" }
    ]

    property var items: []

    function probe() {
        const cs = tuis.candidates;
        const names = cs.map(c => c.cmd).join(" ");
        probeProc.command = ["sh", "-c",
            "for c in " + names + "; do command -v \"$c\" >/dev/null 2>&1 && echo \"$c\"; done"];
        probeProc.running = false;
        probeProc.running = true;
    }

    Process {
        id: probeProc
        running: false
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                const lines = (this.text || "").split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const c = lines[i].trim();
                    if (c) found[c] = true;
                }
                const out = [];
                const cs = tuis.candidates;
                for (let i = 0; i < cs.length; i++) {
                    if (!found[cs[i].cmd]) continue;
                    out.push({
                        title: cs[i].title,
                        icon: cs[i].icon,
                        category: "TUI",
                        keywords: cs[i].keywords,
                        exec: cs[i].cmd,
                        tui: "omarchy-launch-tui"
                    });
                }
                tuis.items = Data.annotate(out);
            }
        }
    }

    Component.onCompleted: tuis.probe()
}
