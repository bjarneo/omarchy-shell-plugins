.pragma library

// Sentinel values for the search/state drills.
const fileCategory = "Files";
const githubCategory = "GitHub";
const favCategory = "Favourites";
const histCategory = "History";
const themeCategory = "Themes";

// fd already respects .gitignore, the global ignore file, and skips
// hidden files by default. These excludes catch build dirs that
// aren't always gitignored.
const fdExcludes = [
    "node_modules", "target", "dist", "build", ".cache",
    ".venv", "__pycache__", ".tox", ".next", ".nuxt"
];

const imageExts = [
    "png", "jpg", "jpeg", "webp", "gif", "bmp", "ico", "avif", "svg"
];

const textExts = [
    "md", "txt", "qml", "lua", "toml", "sh", "bash", "zsh", "fish",
    "py", "js", "mjs", "cjs", "ts", "tsx", "jsx", "json", "jsonc",
    "yaml", "yml", "rs", "go", "c", "h", "cpp", "hpp", "cc", "hh",
    "html", "css", "scss", "conf", "ini", "cfg", "log", "csv", "xml",
    "rb", "java", "kt", "swift", "php", "sql", "vim", "el", "tex",
    "gitignore", "gitconfig", "dockerfile", "makefile", "env"
];

const fileIcons = {
    "png": "󰋩", "jpg": "󰋩", "jpeg": "󰋩", "webp": "󰋩", "gif": "󰋩",
    "bmp": "󰋩", "ico": "󰋩", "avif": "󰋩", "svg": "󰜡", "tiff": "󰋩",
    "mp4": "󰕧", "mkv": "󰕧", "webm": "󰕧", "mov": "󰕧", "avi": "󰕧",
    "m4v": "󰕧", "flv": "󰕧",
    "mp3": "󰝚", "flac": "󰝚", "ogg": "󰝚", "wav": "󰝚", "m4a": "󰝚",
    "opus": "󰝚", "aac": "󰝚",
    "pdf": "󰈦", "epub": "󰂺", "djvu": "󰈦",
    "doc": "󰈬", "docx": "󰈬", "odt": "󰈬", "rtf": "󰈬",
    "xls": "󰈛", "xlsx": "󰈛", "ods": "󰈛",
    "ppt": "󰈧", "pptx": "󰈧", "odp": "󰈧",
    "zip": "󰗄", "tar": "󰗄", "gz": "󰗄", "xz": "󰗄", "bz2": "󰗄",
    "7z": "󰗄", "rar": "󰗄", "zst": "󰗄",
    "md": "󰍔", "txt": "󰈙", "log": "󰦪", "csv": "󰈛",
    "json": "󰘦", "jsonc": "󰘦", "yaml": "󰈙", "yml": "󰈙",
    "toml": "󰈙", "xml": "󰗀", "ini": "󰒓", "cfg": "󰒓",
    "conf": "󰒓", "env": "󰒓",
    "sh": "󱆃", "bash": "󱆃", "zsh": "󱆃", "fish": "󰈺",
    "lua": "󰢱", "vim": "",
    "html": "󰌝", "css": "󰌜", "scss": "󰌜", "sass": "󰌜",
    "py": "󰌠", "js": "󰌞", "mjs": "󰌞", "cjs": "󰌞",
    "ts": "󰛦", "tsx": "󰜈", "jsx": "󰜈",
    "rs": "󱘗", "go": "󰟓", "java": "󰬷", "kt": "󱈙",
    "swift": "󰛥", "rb": "󰴭", "php": "󰌟",
    "c": "󰙱", "h": "󰙱", "cpp": "󰙲", "hpp": "󰙲", "cc": "󰙲", "hh": "󰙲",
    "qml": "󰢫", "sql": "󰆼", "el": "", "tex": "",
    // Dotless filenames: fileExt() returns the whole lowercased name.
    "gitignore": "", "gitconfig": "",
    "dockerfile": "󰡨", "makefile": "󰣪"
};

// Synthetic rows at root level. Activating one sets the categoryFilter
// instead of executing a command. `target` matches against item.category;
// "App" is the bucket all .desktop entries land in. fileCategory and
// githubCategory routes to its search drill.
const categoryNav = [
    { title: "Quick",   icon: "󱎫", category: "Browse", isCategory: true, target: "Quick",       keywords: "quick settings panel tray toggle popup display weather calendar aether screenshots videos brightness volume mute" },
    { title: "Apps",    icon: "󰀻", category: "Browse", isCategory: true, target: "App",         keywords: "apps applications launcher programs software desktop" },
    { title: "Files",   icon: "󰉋", category: "Browse", isCategory: true, target: fileCategory,  keywords: "files file search find folder browse path open image picture document text fd" },
    { title: "GitHub",  icon: "󰊤", category: "Browse", isCategory: true, target: githubCategory, keywords: "github gh repo repository search code clone star issue pull request pr open source git" },
    { title: "Favourites", icon: "󰓎", category: "Browse", isCategory: true, target: favCategory,  keywords: "favourites favorites favs starred pinned bookmarks marked" },
    { title: "History", icon: "󰋚", category: "Browse", isCategory: true, target: histCategory,    keywords: "history recent recents log past activity used opened" },
    { title: "Style",   icon: "󰏘", category: "Browse", isCategory: true, target: "Style",       keywords: "style theme appearance look font background corners waybar screensaver" },
    { title: "Setup",   icon: "󰒓", category: "Browse", isCategory: true, target: "Setup",       keywords: "setup config audio wifi bluetooth power monitors keybindings defaults dns security" },
    { title: "Install", icon: "󰏗", category: "Browse", isCategory: true, target: "Install",     keywords: "install add package aur webapp tui service style dev editor terminal browser ai gaming" },
    { title: "Remove",  icon: "󰆴", category: "Browse", isCategory: true, target: "Remove",      keywords: "remove uninstall delete package webapp tui theme browser gaming dev preinstalls" },
    { title: "Update",  icon: "󰚰", category: "Browse", isCategory: true, target: "Update",      keywords: "update upgrade omarchy channel themes process hardware firmware password timezone time" },
    { title: "System",  icon: "󰐥", category: "Browse", isCategory: true, target: "System",      keywords: "system lock suspend hibernate logout restart reboot shutdown power" },
    { title: "Toggle",  icon: "󰨚", category: "Browse", isCategory: true, target: "Toggle",      keywords: "toggle screensaver nightlight idle notifications bar layout gaps scaling sudo touchpad" },
    { title: "Trigger", icon: "󰚥", category: "Browse", isCategory: true, target: "Trigger",     keywords: "trigger reminder transcode capture share toggle hardware" },
    { title: "Capture", icon: "󰄀", category: "Browse", isCategory: true, target: "Capture",     keywords: "capture screenshot screenrecord ocr text extraction color picker" },
    { title: "Share",   icon: "󰒖", category: "Browse", isCategory: true, target: "Share",       keywords: "share clipboard file folder receive localsend send transfer" },
    { title: "Learn",   icon: "󰂺", category: "Browse", isCategory: true, target: "Learn",       keywords: "learn docs manual help keybindings wiki cheatsheet" },
    { title: "Themes",    icon: "󰸌", category: "Browse", isCategory: true, target: themeCategory, keywords: "themes theme palette color swatch switcher dark light apply" }
];

// Every leaf action omarchy-menu can dispatch is flattened here with a
// synonym list so search hits non-obvious terms. `exec` is the bash run
// verbatim; `tui` (when set) is the wrapper command name that prefixes
// exec so the launch lands in a real terminal.
const omarchyItems = [
    // ----- Quick -----
    // Mirrors the standalone QuickSettings sheet's targets: popup togglers
    // and one-shot device toggles. Reached as a drill-down (Quick) or by
    // typing the action name; Alt+Space binds straight into this category.
    { title: "Theme",            icon: "󰸌", category: "Quick", keywords: "theme color palette dark light mode appearance look style scheme switcher",              exec: "omarchy-menu summon theme" },
    { title: "Background",       icon: "󰸉", category: "Quick", keywords: "background wallpaper image desktop picture backdrop bg",                               exec: "omarchy-menu summon background" },
    { title: "Screenshot",       icon: "󰄀", category: "Quick", keywords: "screenshot screenshots capture image shot region screen",                              exec: "omarchy-capture-screenshot" },
    { title: "Screen Record",    icon: "󰑊", category: "Quick", keywords: "screen record recording video capture mp4 gif",                                       exec: "omarchy-capture-screenrecording" },
    { title: "Mute Audio",       icon: "󰝟", category: "Quick", keywords: "mute audio unmute silence toggle volume sound speaker pamixer quick",                  exec: "pamixer -t" },
    { title: "Audio Mixer",      icon: "󰕾", category: "Quick", keywords: "audio mixer pavucontrol pipewire pulse volume sink source device level",                exec: "omarchy-launch-audio" },
    { title: "Wi-Fi Picker",     icon: "󰖩", category: "Quick", keywords: "wifi wireless network connect picker chooser ssid signal nmcli",                       exec: "omarchy-launch-wifi" },
    { title: "Bluetooth Picker", icon: "󰂯", category: "Quick", keywords: "bluetooth bt pair connect device picker headset speaker keyboard mouse",                exec: "omarchy-launch-bluetooth" },
    { title: "System Monitor",   icon: "󰍛", category: "Quick", keywords: "cpu memory process monitor btop top htop performance load activity",                   exec: "omarchy-launch-or-focus-tui btop" },
    { title: "Keybindings",      icon: "󰌌", category: "Quick", keywords: "keybindings shortcuts hotkeys cheatsheet reference help",                              exec: "omarchy-menu-keybindings" },
    { title: "Lock Screen",      icon: "󰌾", category: "Quick", keywords: "lock screen security hyprlock password",                                               exec: "omarchy-system-lock" },
    { title: "Power Menu",       icon: "󰐥", category: "Quick", keywords: "power menu battery suspend hibernate logout restart reboot shutdown lock",              exec: "omarchy-menu summon system" },

    // ----- Style -----
    { title: "Theme",            icon: "󰸌", category: "Style",   keywords: "theme color palette dark light mode appearance look style scheme switcher", exec: "omarchy-menu theme" },
    { title: "Background",       icon: "󰸉", category: "Style",   keywords: "background wallpaper image desktop picture backdrop bg",                                                 exec: "omarchy-menu background" },
    { title: "Font",             icon: "󰛖", category: "Style",   keywords: "font typeface monospace typography family character glyph nerd",                                        exec: "omarchy-menu style" },
    { title: "Waybar Position",  icon: "󰍜", category: "Style",   keywords: "bar panel top bottom left right position dock waybar status",                                          exec: "omarchy-menu style" },
    { title: "Hyprland Look",    icon: "󰕮", category: "Style",   keywords: "hyprland looknfeel border gaps animation effects compositor window",                                   exec: "omarchy-launch-editor ~/.config/hypr/looknfeel.lua" },
    { title: "Screensaver",      icon: "󱄄", category: "Style",   keywords: "screensaver branding lock idle screen saver text image logo",                                        exec: "omarchy-menu style" },
    { title: "About",            icon: "󰋽", category: "Style",   keywords: "about branding logo profile text image owner identity",                                                exec: "omarchy-menu about" },
    { title: "Unlock Theme",     icon: "󰟵", category: "Style",   keywords: "unlock premium paid theme purchase license",                                                          exec: "omarchy-launch-walker -m menus:omarchyunlocks --width 800 --minheight 400" },

    // ----- Setup -----
    { title: "Audio",            icon: "󰕾", category: "Setup",   keywords: "audio sound speaker mixer pulse pipewire volume output input device",                                  exec: "omarchy-launch-audio" },
    { title: "Wi-Fi",            icon: "󰖩", category: "Setup",   keywords: "wifi wireless network internet nmcli connection",                                                      exec: "omarchy-launch-wifi" },
    { title: "Bluetooth",        icon: "󰂯", category: "Setup",   keywords: "bluetooth bt pair device headset speaker keyboard mouse",                                              exec: "omarchy-launch-bluetooth" },
    { title: "Power Profile",    icon: "󱐋", category: "Setup",   keywords: "power profile performance battery saver balanced cpu governor",                                       exec: "omarchy-menu power" },
    { title: "System Sleep",     icon: "󰤄", category: "Setup",   keywords: "sleep suspend hibernate power management lid",                                                         exec: "omarchy-menu setup" },
    { title: "Monitors",         icon: "󰍹", category: "Setup",   keywords: "monitor display screen resolution scaling refresh hz external hdmi displayport",                       exec: "omarchy-launch-editor ~/.config/hypr/monitors.lua" },
    { title: "Keybindings",      icon: "󰌌", category: "Setup",   keywords: "keybindings shortcuts hotkeys keymap bindings input hypr",                                              exec: "omarchy-launch-editor ~/.config/hypr/bindings.lua" },
    { title: "Input",            icon: "󰍽", category: "Setup",   keywords: "input keyboard mouse touchpad layout language repeat",                                                 exec: "omarchy-launch-editor ~/.config/hypr/input.lua" },
    { title: "Default Browser",  icon: "󰖟", category: "Setup",   keywords: "default browser web chrome firefox brave edge zen chromium",                                           exec: "omarchy-menu setup" },
    { title: "Default Terminal", icon: "󰆍", category: "Setup",   keywords: "default terminal alacritty foot ghostty kitty emulator shell",                                          exec: "omarchy-menu setup" },
    { title: "Default Editor",   icon: "󱩼", category: "Setup",   keywords: "default editor neovim vscode cursor zed sublime helix vim emacs ide",                                  exec: "omarchy-menu setup" },
    { title: "DNS",              icon: "󰱔", category: "Setup",   keywords: "dns resolver network domain server nameserver",                                                       exec: "omarchy-setup-dns",                  tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Fingerprint",      icon: "󰈷", category: "Setup",   keywords: "fingerprint biometric security login auth fingerprint reader",                                         exec: "omarchy-setup-security-fingerprint", tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Fido2 Key",        icon: "󰌆", category: "Setup",   keywords: "fido2 yubikey hardware key security 2fa auth",                                                          exec: "omarchy-setup-security-fido2",       tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Hyprland Config",  icon: "󰢨", category: "Setup",   keywords: "hyprland config compositor window manager edit settings",                                              exec: "omarchy-launch-editor ~/.config/hypr/hyprland.lua" },
    { title: "Hypridle Config",  icon: "󱎫", category: "Setup",   keywords: "hypridle idle timeout lock screen blank afk",                                                          exec: "omarchy-launch-editor ~/.config/hypr/hypridle.conf" },
    { title: "Hyprlock Config",  icon: "󰌾", category: "Setup",   keywords: "hyprlock lock screen password security",                                                                exec: "omarchy-launch-editor ~/.config/hypr/hyprlock.conf" },
    { title: "Hyprsunset Config",icon: "󰖕", category: "Setup",   keywords: "hyprsunset nightlight blue light filter warm temperature",                                              exec: "omarchy-launch-editor ~/.config/hypr/hyprsunset.conf" },
    { title: "Plymouth",         icon: "󱣴", category: "Setup",   keywords: "plymouth boot splash screen logo",                                                                     exec: "omarchy-refresh-plymouth" },
    { title: "Swayosd Config",   icon: "󰧴", category: "Setup",   keywords: "swayosd osd volume brightness indicator overlay",                                                       exec: "omarchy-launch-editor ~/.config/swayosd/config.toml" },
    { title: "Walker Config",    icon: "󰌧", category: "Setup",   keywords: "walker launcher runner dmenu picker rofi",                                                              exec: "omarchy-launch-editor ~/.config/walker/config.toml" },
    { title: "Waybar Config",    icon: "󰍜", category: "Setup",   keywords: "waybar status bar config modules",                                                                      exec: "omarchy-launch-editor ~/.config/waybar/config.jsonc" },
    { title: "XCompose",         icon: "󰞅", category: "Setup",   keywords: "xcompose compose key special characters accents typing emoji input",                                  exec: "omarchy-launch-editor ~/.XCompose" },

    // ----- Install -----
    { title: "Install Package",       icon: "󰣇", category: "Install", keywords: "install package pacman pkg arch repo add",                                  exec: "omarchy-pkg-install",          tui: "omarchy-launch-tui" },
    { title: "Install from AUR",      icon: "󰣇", category: "Install", keywords: "aur install package yay paru arch user repository",                          exec: "omarchy-pkg-aur-install",      tui: "omarchy-launch-tui" },
    { title: "Install Web App",       icon: "󱂛", category: "Install", keywords: "web app pwa browser shortcut install chromium edge",                          exec: "omarchy-webapp-install",       tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Install TUI",           icon: "󰆍", category: "Install", keywords: "tui terminal app cli tool install",                                            exec: "omarchy-tui-install",          tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Install Service",       icon: "󰒋", category: "Install", keywords: "service install dropbox tailscale nordvpn vpn sunshine bitwarden",            exec: "omarchy-menu install service" },
    { title: "Install Style",         icon: "󰏘", category: "Install", keywords: "install style theme background font palette appearance",                       exec: "omarchy-menu install style" },
    { title: "Install Theme",         icon: "󰸌", category: "Install", keywords: "install theme color palette appearance download",                              exec: "omarchy-theme-install",        tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Install Background",    icon: "󰸉", category: "Install", keywords: "install background wallpaper image download add",                              exec: "omarchy-theme-bg-install" },
    { title: "Install Dev Env",       icon: "󰵮", category: "Install", keywords: "development install ruby rails javascript node go php python elixir zig rust java dotnet ocaml clojure scala", exec: "omarchy-menu install development" },
    { title: "Install Editor",        icon: "󱩼", category: "Install", keywords: "editor install vscode cursor zed sublime helix vim emacs neovim ide",          exec: "omarchy-menu install editor" },
    { title: "Install Terminal",      icon: "󰆍", category: "Install", keywords: "terminal install alacritty foot ghostty kitty",                                exec: "omarchy-menu install terminal" },
    { title: "Install Browser",       icon: "󰖟", category: "Install", keywords: "browser install chrome edge brave firefox zen chromium web",                   exec: "omarchy-menu install browser" },
    { title: "Install AI",            icon: "󱚤", category: "Install", keywords: "ai install ollama lmstudio crush dictation voice llm gpt local",              exec: "omarchy-menu install ai" },
    { title: "Install Gaming",        icon: "󰊴", category: "Install", keywords: "gaming install steam retroarch minecraft geforce xbox moonlight lutris heroic", exec: "omarchy-menu install gaming" },
    { title: "Install Docker DB",     icon: "󰡨", category: "Install", keywords: "docker database postgres mysql redis container",                                exec: "omarchy-install-docker-dbs",   tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Install Windows VM",    icon: "󰍲", category: "Install", keywords: "windows vm virtual machine qemu kvm install",                                  exec: "omarchy-windows-vm install",   tui: "omarchy-launch-floating-terminal-with-presentation" },

    // ----- Remove -----
    { title: "Remove Package",        icon: "󰣇", category: "Remove",  keywords: "remove uninstall package pacman arch delete pkg",            exec: "omarchy-pkg-remove",          tui: "omarchy-launch-tui" },
    { title: "Remove Web App",        icon: "󱂛", category: "Remove",  keywords: "remove web app pwa uninstall",                                exec: "omarchy-webapp-remove",       tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Remove TUI",            icon: "󰆍", category: "Remove",  keywords: "tui remove uninstall cli tool",                               exec: "omarchy-tui-remove",          tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Remove Theme",          icon: "󰸌", category: "Remove",  keywords: "theme remove uninstall delete palette",                       exec: "omarchy-theme-remove",        tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Remove Dictation",      icon: "󰍬", category: "Remove",  keywords: "dictation voxtype voice remove uninstall speech",             exec: "omarchy-voxtype-remove",      tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Remove Browser",        icon: "󰖟", category: "Remove",  keywords: "browser remove uninstall chrome firefox brave edge",          exec: "omarchy-menu remove browser" },
    { title: "Remove Gaming",         icon: "󰊴", category: "Remove",  keywords: "gaming remove uninstall steam retroarch minecraft",           exec: "omarchy-menu remove gaming" },
    { title: "Remove Dev Env",        icon: "󰵮", category: "Remove",  keywords: "development remove uninstall ruby node go python rust",       exec: "omarchy-menu remove development" },
    { title: "Remove Preinstalls",    icon: "󰏓", category: "Remove",  keywords: "preinstalls remove cleanup bloat default apps",               exec: "omarchy-remove-preinstalls",  tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Remove Windows VM",     icon: "󰍲", category: "Remove",  keywords: "windows vm virtual machine remove uninstall",                 exec: "omarchy-windows-vm remove",   tui: "omarchy-launch-floating-terminal-with-presentation" },

    // ----- Update -----
    { title: "Update Omarchy",        icon: "󰦗", category: "Update",  keywords: "update upgrade omarchy system latest sync pull",                        exec: "omarchy-update",              tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Update Channel",        icon: "󰔫", category: "Update",  keywords: "channel branch stable rc edge dev release track",                        exec: "omarchy-menu update" },
    { title: "Update Themes",         icon: "󰸌", category: "Update",  keywords: "themes update refresh extra catalogue",                                  exec: "omarchy-theme-update",        tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Update Firmware",       icon: "󰍛", category: "Update",  keywords: "firmware bios uefi fwupd update flash",                                  exec: "omarchy-update-firmware",     tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Update Time",           icon: "󰥔", category: "Update",  keywords: "time ntp sync clock update",                                              exec: "omarchy-update-time",         tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Update Timezone",       icon: "󰃭", category: "Update",  keywords: "timezone tz region locale time zone change",                              exec: "omarchy-tz-select",           tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Update Drive Password", icon: "󰋊", category: "Update",  keywords: "drive password luks encryption disk security",                            exec: "omarchy-drive-password",      tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Update User Password",  icon: "󰷛", category: "Update",  keywords: "user password passwd security login change",                              exec: "passwd",                      tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Reset Hyprland Config", icon: "󰑐", category: "Update",  keywords: "reset default config hyprland restore factory refresh",                  exec: "omarchy-refresh-hyprland" },
    { title: "Reset Hypridle Config", icon: "󰑐", category: "Update",  keywords: "reset default config hypridle idle restore",                              exec: "omarchy-refresh-hypridle" },
    { title: "Reset Hyprlock Config", icon: "󰑐", category: "Update",  keywords: "reset default config hyprlock lock restore",                              exec: "omarchy-refresh-hyprlock" },
    { title: "Reset Hyprsunset Cfg",  icon: "󰑐", category: "Update",  keywords: "reset default config hyprsunset nightlight restore",                      exec: "omarchy-refresh-hyprsunset" },
    { title: "Reset Swayosd Config",  icon: "󰑐", category: "Update",  keywords: "reset default config swayosd osd restore",                                exec: "omarchy-refresh-swayosd" },
    { title: "Reset Tmux Config",     icon: "󰑐", category: "Update",  keywords: "reset default config tmux restore",                                       exec: "omarchy-refresh-tmux" },
    { title: "Reset Walker Config",   icon: "󰌧", category: "Update",  keywords: "reset default config walker launcher restore",                            exec: "omarchy-refresh-walker" },
    { title: "Reset Waybar Config",   icon: "󰍜", category: "Update",  keywords: "reset default config waybar bar restore",                                 exec: "omarchy-refresh-waybar" },
    { title: "Restart Hypridle",      icon: "󰜉", category: "Update",  keywords: "restart hypridle idle service process reload",                            exec: "omarchy-restart-hypridle" },
    { title: "Restart Hyprsunset",    icon: "󰜉", category: "Update",  keywords: "restart hyprsunset nightlight service process reload",                    exec: "omarchy-restart-hyprsunset" },
    { title: "Restart Mako",          icon: "󰎟", category: "Update",  keywords: "restart mako notifications dunst service reload",                         exec: "omarchy-restart-mako" },
    { title: "Restart Swayosd",       icon: "󰜉", category: "Update",  keywords: "restart swayosd osd service reload",                                      exec: "omarchy-restart-swayosd" },
    { title: "Restart Walker",        icon: "󰌧", category: "Update",  keywords: "restart walker launcher service reload",                                  exec: "omarchy-restart-walker" },
    { title: "Restart Waybar",        icon: "󰍜", category: "Update",  keywords: "restart waybar bar service reload",                                       exec: "omarchy-restart-waybar" },
    { title: "Restart Audio",         icon: "󰜉", category: "Update",  keywords: "restart audio pipewire pulse sound reload service",                       exec: "omarchy-restart-pipewire" },
    { title: "Restart Wi-Fi",         icon: "󱚾", category: "Update",  keywords: "restart wifi wireless network reload service",                            exec: "omarchy-restart-wifi" },
    { title: "Restart Bluetooth",     icon: "󰂯", category: "Update",  keywords: "restart bluetooth bt reload service",                                     exec: "omarchy-restart-bluetooth" },
    { title: "Restart Trackpad",      icon: "󰟸", category: "Update",  keywords: "restart trackpad touchpad pointer reload service",                        exec: "omarchy-restart-trackpad" },

    // ----- System -----
    { title: "Lock Screen",         icon: "󰌾", category: "System", keywords: "lock screen security hyprlock password",                                            exec: "omarchy-system-lock" },
    { title: "Force Screensaver",   icon: "󱄄", category: "System", keywords: "screensaver force start show idle",                                              exec: "omarchy-launch-screensaver force" },
    { title: "Suspend",             icon: "󰒲", category: "System", keywords: "suspend sleep power down ram s3",                                                 exec: "systemctl suspend" },
    { title: "Hibernate",           icon: "󰤁", category: "System", keywords: "hibernate disk power down s4 swap",                                               exec: "systemctl hibernate" },
    { title: "Logout",              icon: "󰍃", category: "System", keywords: "logout signout exit session end",                                                  exec: "omarchy-system-logout" },
    { title: "Restart Computer",    icon: "󰜉", category: "System", keywords: "restart reboot reset power cycle",                                                exec: "omarchy-system-reboot" },
    { title: "Shutdown",            icon: "󰐥", category: "System", keywords: "shutdown poweroff off halt turn off",                                              exec: "omarchy-system-shutdown" },

    // ----- Toggle -----
    { title: "Toggle Screensaver",  icon: "󱄄", category: "Toggle", keywords: "toggle screensaver enable disable on off",                                        exec: "omarchy-toggle-screensaver" },
    { title: "Toggle Nightlight",   icon: "󰔎", category: "Toggle", keywords: "toggle nightlight blue light filter warm color temperature hyprsunset",            exec: "omarchy-toggle-nightlight" },
    { title: "Toggle Idle Lock",    icon: "󱫖", category: "Toggle", keywords: "toggle idle lock auto away timeout",                                                exec: "omarchy-toggle-idle" },
    { title: "Toggle Notifications",icon: "󰂛", category: "Toggle", keywords: "toggle notifications silence mute mako dnd",                                       exec: "omarchy-toggle-notification-silencing" },
    { title: "Toggle Top Bar",      icon: "󰍜", category: "Toggle", keywords: "toggle waybar top bar show hide visibility",                                       exec: "omarchy-toggle-waybar" },
    { title: "Toggle Workspace Layout", icon: "󱂬", category: "Toggle", keywords: "toggle workspace layout dwindle master tile hyprland",                          exec: "omarchy-hyprland-workspace-layout-toggle" },
    { title: "Toggle Window Gaps",  icon: "󱂩", category: "Toggle", keywords: "toggle gaps window spacing hyprland margin",                                       exec: "omarchy-hyprland-window-gaps-toggle" },
    { title: "Toggle 1-Window Ratio",icon: "󰋃", category: "Toggle", keywords: "toggle aspect ratio single window square",                                          exec: "omarchy-hyprland-window-single-square-aspect-toggle" },
    { title: "Toggle Monitor Scaling", icon: "󰍹", category: "Toggle", keywords: "toggle monitor scaling cycle resolution hidpi",                                  exec: "omarchy-hyprland-monitor-scaling-cycle" },
    { title: "Toggle Direct Boot",  icon: "󰓅", category: "Toggle", keywords: "toggle direct boot autologin no password",                                          exec: "omarchy-config-direct-boot", tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Toggle Passwordless Sudo", icon: "󰟵", category: "Toggle", keywords: "passwordless sudo nopasswd root admin security",                               exec: "omarchy-sudo-passwordless",  tui: "omarchy-launch-floating-terminal-with-presentation" },
    { title: "Toggle Suspend",      icon: "󰒲", category: "Toggle", keywords: "toggle suspend disable enable sleep power",                                        exec: "omarchy-toggle-suspend" },
    { title: "Toggle Touchpad",     icon: "󰟸", category: "Toggle", keywords: "toggle touchpad trackpad enable disable",                                          exec: "omarchy-toggle-touchpad" },
    { title: "Toggle Touchscreen",  icon: "󰆽", category: "Toggle", keywords: "toggle touchscreen enable disable",                                                exec: "omarchy-toggle-touchscreen" },

    // ----- Capture -----
    { title: "Screenshot",          icon: "󰄀", category: "Capture", keywords: "screenshot screen capture image png shot snip print",                              exec: "omarchy-capture-screenshot" },
    { title: "Screen Record",       icon: "󰑊", category: "Capture", keywords: "screen record video capture mp4 gif",                                              exec: "omarchy-capture-screenrecording" },
    { title: "Text Extraction (OCR)",icon: "󰴑", category: "Capture", keywords: "ocr text extract recognize image scan copy",                                       exec: "omarchy-capture-text-extraction" },
    { title: "Color Picker",        icon: "󰃉", category: "Capture", keywords: "color picker hex rgb hyprpicker dropper sample eyedropper",                        exec: "bash -c 'pkill hyprpicker || hyprpicker -a'" },
    { title: "Notes",               icon: "󰍔", category: "Capture", keywords: "notes note markdown scratchpad journal nvim neovim editor write text omni-notes",  exec: "bash -c 'mkdir -p \"$HOME/Documents/omni-notes\" && cd \"$HOME/Documents/omni-notes\" && nvim .'", tui: "omarchy-launch-tui" },

    // ----- Share -----
    { title: "Share Clipboard",     icon: "󰅎", category: "Share",   keywords: "share clipboard localsend send transfer",                                          exec: "omarchy-menu-share clipboard" },
    { title: "Share File",          icon: "󰈤", category: "Share",   keywords: "share file send transfer localsend",                                                exec: "omarchy-menu-share file",   tui: "omarchy-launch-tui" },
    { title: "Share Folder",        icon: "󰉒", category: "Share",   keywords: "share folder directory send transfer localsend",                                    exec: "omarchy-menu-share folder", tui: "omarchy-launch-tui" },
    { title: "Receive (LocalSend)", icon: "󰥦", category: "Share",   keywords: "receive localsend share airdrop transfer",                                          exec: "uwsm-app -- localsend" },

    // ----- Trigger -----
    { title: "Set Reminder",        icon: "󰔛", category: "Trigger", keywords: "reminder alarm timer notify wake notification",                                    exec: "omarchy-menu reminder-set" },
    { title: "Show Reminders",      icon: "󰔛", category: "Trigger", keywords: "reminders show list pending",                                                       exec: "omarchy-reminder show" },
    { title: "Clear Reminders",     icon: "󰔛", category: "Trigger", keywords: "reminders clear delete remove all",                                                 exec: "omarchy-reminder clear" },
    { title: "Transcode Media",     icon: "󰧸", category: "Trigger", keywords: "transcode media video audio convert compress mp4 mp3",                              exec: "omarchy-transcode" },

    // ----- Learn -----
    { title: "Keybindings",         icon: "󰌌", category: "Learn", keywords: "keybindings shortcuts hotkeys cheatsheet reference help",                              exec: "omarchy-menu-keybindings" },
    { title: "Tmux Keybindings",    icon: "󱂬", category: "Learn", keywords: "tmux keybindings shortcuts reference",                                                 exec: "omarchy-menu-tmux-keybindings" },
    { title: "Omarchy Manual",      icon: "󰂺", category: "Learn", keywords: "omarchy manual docs documentation help learn",                                         exec: "omarchy-launch-webapp 'https://learn.omacom.io/2/the-omarchy-manual'" },
    { title: "Hyprland Wiki",       icon: "󱁉", category: "Learn", keywords: "hyprland wiki docs documentation help",                                                exec: "omarchy-launch-webapp 'https://wiki.hypr.land/'" },
    { title: "Arch Wiki",           icon: "󰣇", category: "Learn", keywords: "arch wiki docs documentation help linux",                                              exec: "omarchy-launch-webapp 'https://wiki.archlinux.org/title/Main_page'" },
    { title: "Neovim Keymaps",      icon: "󰕷", category: "Learn", keywords: "neovim nvim keymaps shortcuts lazyvim reference",                                      exec: "omarchy-launch-webapp 'https://www.lazyvim.org/keymaps'" },
    { title: "Bash Cheatsheet",     icon: "󱆃", category: "Learn", keywords: "bash shell cheatsheet reference scripting",                                            exec: "omarchy-launch-webapp 'https://devhints.io/bash'" }
];

// Pre-lowercases `title`/`keywords`/`category` onto `_t`/`_k`/`_c` so the
// per-keystroke scoring loop doesn't re-lowercase the same strings on
// every character.
function annotate(items) {
    const out = new Array(items.length);
    for (let i = 0; i < items.length; i++) {
        const it = items[i];
        out[i] = Object.assign({}, it, {
            _t: (it.title || "").toLowerCase(),
            _k: (it.keywords || "").toLowerCase(),
            _c: (it.category || "").toLowerCase()
        });
    }
    return out;
}

function basename(p) {
    const s = p.lastIndexOf("/");
    return s >= 0 ? p.substring(s + 1) : p;
}
function dirname(p) {
    const s = p.lastIndexOf("/");
    return s >= 0 ? p.substring(0, s) : "";
}
function tildify(p, homeDir) {
    return (homeDir && p.indexOf(homeDir) === 0)
        ? "~" + p.substring(homeDir.length)
        : p;
}
function fileExt(path) {
    const name = basename(path);
    const dot = name.lastIndexOf(".");
    if (dot <= 0) return name.toLowerCase(); // dotless name (Makefile)
    return name.substring(dot + 1).toLowerCase();
}
function fileIcon(path) {
    return fileIcons[fileExt(path)] || "";
}
function openUrl(url) {
    return "xdg-open " + JSON.stringify(url);
}

function stripJsonc(raw) {
    const src = String(raw || "");
    let out = "";
    let inString = false;
    let escaped = false;
    let lineComment = false;
    let blockComment = false;

    for (let i = 0; i < src.length; i++) {
        const c = src.charAt(i);
        const n = i + 1 < src.length ? src.charAt(i + 1) : "";

        if (lineComment) {
            if (c === "\n") {
                lineComment = false;
                out += c;
            }
            continue;
        }
        if (blockComment) {
            if (c === "*" && n === "/") {
                blockComment = false;
                i += 1;
            } else if (c === "\n") {
                out += c;
            }
            continue;
        }
        if (inString) {
            out += c;
            if (escaped) escaped = false;
            else if (c === "\\") escaped = true;
            else if (c === "\"") inString = false;
            continue;
        }

        if (c === "\"") {
            inString = true;
            out += c;
            continue;
        }
        if (c === "/" && n === "/") {
            lineComment = true;
            i += 1;
            continue;
        }
        if (c === "/" && n === "*") {
            blockComment = true;
            i += 1;
            continue;
        }
        out += c;
    }

    return removeTrailingCommas(out);
}

function removeTrailingCommas(raw) {
    const src = String(raw || "");
    let out = "";
    let inString = false;
    let escaped = false;

    for (let i = 0; i < src.length; i++) {
        const c = src.charAt(i);
        if (inString) {
            out += c;
            if (escaped) escaped = false;
            else if (c === "\\") escaped = true;
            else if (c === "\"") inString = false;
            continue;
        }
        if (c === "\"") {
            inString = true;
            out += c;
            continue;
        }
        if (c === ",") {
            let j = i + 1;
            while (j < src.length && /\s/.test(src.charAt(j))) j += 1;
            if (j < src.length && (src.charAt(j) === "}" || src.charAt(j) === "]")) continue;
        }
        out += c;
    }

    return out;
}

function isPlainObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function parseMenuJsonc(raw) {
    const stripped = stripJsonc(raw);
    if (!stripped.trim()) return [];

    let parsed;
    try {
        parsed = JSON.parse(stripped);
    } catch (_) {
        return [];
    }
    if (!isPlainObject(parsed)) return [];

    const source = isPlainObject(parsed.items) ? parsed.items : parsed;
    const out = [];
    for (let id in source) {
        const entry = source[id];
        if (!isPlainObject(entry)) continue;
        const copy = { id: id };
        for (let key in entry) copy[key] = entry[key];
        out.push(copy);
    }
    return out;
}

function normalizeMenuAliases(value) {
    if (Array.isArray(value)) return value.filter(function(v) { return !!v; });
    if (typeof value === "string" && value) return [value];
    return [];
}

function normalizeMenuItem(raw) {
    const id = String(raw.id || "");
    const aliases = normalizeMenuAliases(raw.aliases);
    let parent = raw.parent;
    if (parent === undefined)
        parent = id.indexOf(".") >= 0 ? id.split(".").slice(0, -1).join(".") : "root";
    if (id === "root") parent = "";

    const action = raw.action === undefined ? "" : String(raw.action || "");
    const target = raw.target === undefined ? "" : String(raw.target || "");
    const kind = action ? "action" : (target ? "link" : "menu");

    return {
        id: id,
        parent: String(parent || ""),
        kind: kind,
        icon: String(raw.icon || ""),
        label: String(raw.label || id),
        target: target,
        keywords: String(raw.keywords || ""),
        description: String(raw.description || ""),
        action: action,
        provider: String(raw.provider || ""),
        aliases: aliases,
        when: String(raw.when || ""),
        checked: String(raw.checked || "")
    };
}

function mergeMenuSources(defaultItems, userItems) {
    const rawById = ({});
    const order = [];
    const sources = [defaultItems || [], userItems || []];

    for (let s = 0; s < sources.length; s++) {
        const source = sources[s];
        for (let i = 0; i < source.length; i++) {
            const entry = source[i];
            const id = entry && entry.id ? String(entry.id) : "";
            if (!id) continue;
            if (!rawById[id]) {
                rawById[id] = { id: id };
                order.push(id);
            }
            const merged = rawById[id];
            for (let key in entry) {
                if (key === "id") continue;
                merged[key] = entry[key];
            }
        }
    }

    if (!rawById.root) {
        rawById.root = { id: "root", label: "Go" };
        order.unshift("root");
    }

    const items = ({});
    for (let j = 0; j < order.length; j++) {
        const item = normalizeMenuItem(rawById[order[j]]);
        item.order = j;
        items[item.id] = item;
    }
    return { items: items, itemOrder: order };
}

function shellQuote(value) {
    return "'" + String(value || "").replace(/'/g, "'\\''") + "'";
}

function searchableToken(value) {
    return String(value || "").replace(/[._-]+/g, " ");
}

function menuItem(items, id) {
    return items && items[id] ? items[id] : null;
}

function menuTopEntry(items, entry) {
    let current = entry;
    let guard = 0;
    while (current && current.parent && current.parent !== "root" && guard < 32) {
        current = menuItem(items, current.parent);
        guard += 1;
    }
    return current && current.id !== "root" ? current : null;
}

function menuPath(items, id) {
    const labels = [];
    let current = menuItem(items, id);
    let guard = 0;
    while (current && current.id !== "root" && guard < 32) {
        labels.unshift(current.label);
        current = menuItem(items, current.parent);
        guard += 1;
    }
    return labels.join(" > ");
}

function menuParentPath(items, entry) {
    if (!entry || !entry.parent || entry.parent === "root") return "";
    return menuPath(items, entry.parent);
}

function menuLabel(entry, checkedResults) {
    if (entry && entry.checked && checkedResults && checkedResults[entry.id])
        return entry.label + " ✓";
    return entry ? entry.label : "";
}

function menuEntryVisible(entry, whenResults) {
    if (!entry) return false;
    if (!entry.when) return true;
    const result = whenResults ? whenResults[entry.id] : undefined;
    return result === undefined ? true : result;
}

function menuCategory(items, entry) {
    const id = entry ? entry.id : "";
    if (id.indexOf("trigger.capture.") === 0) return "Capture";
    if (id.indexOf("trigger.share.") === 0) return "Share";
    if (id.indexOf("trigger.toggle.") === 0) return "Toggle";

    const top = menuTopEntry(items, entry);
    return top ? top.label : "Omarchy";
}

function menuExec(entry) {
    if (!entry) return "";
    if (entry.action) return entry.action;
    const target = entry.kind === "link" && entry.target ? entry.target : entry.id;
    return "omarchy-menu summon " + shellQuote(target);
}

function omarchyMenuRows(items, itemOrder, whenResults, checkedResults) {
    const rows = [];
    const order = Array.isArray(itemOrder) ? itemOrder : [];
    for (let i = 0; i < order.length; i++) {
        const entry = menuItem(items, order[i]);
        if (!entry || entry.id === "root") continue;
        if (entry.id === "apps") continue;
        if (entry.parent === "root" && entry.kind === "menu") continue;
        if (!menuEntryVisible(entry, whenResults)) continue;

        const path = menuPath(items, entry.id);
        const parentPath = menuParentPath(items, entry);
        const aliases = Array.isArray(entry.aliases) ? entry.aliases.join(" ") : "";
        const keywords = [
            searchableToken(entry.id),
            path,
            parentPath,
            aliases,
            entry.keywords,
            entry.description,
            entry.target,
            entry.provider,
            entry.action,
            entry.kind !== "action" ? "submenu menu open" : ""
        ].join(" ");

        rows.push({
            title: menuLabel(entry, checkedResults),
            icon: entry.icon,
            category: menuCategory(items, entry),
            keywords: keywords,
            exec: menuExec(entry),
            action: entry.action,
            target: entry.target,
            provider: entry.provider,
            menuId: entry.id,
            menuKind: entry.kind,
            menuTarget: entry.kind === "link" && entry.target ? entry.target : entry.id,
            menuPath: path,
            description: entry.description,
            aliases: entry.aliases,
            when: entry.when,
            checked: entry.checked
        });
    }
    return rows;
}

function omniExtraItems() {
    const out = [];
    for (let i = 0; i < omarchyItems.length; i++) {
        const item = omarchyItems[i];
        if (item.category === "Quick"
            || (item.category === "Capture" && item.title === "Notes")) {
            out.push(Object.assign({}, item));
        }
    }
    return out;
}

function formatStars(n) {
    if (n >= 1000000) return (n / 1000000).toFixed(1) + "m";
    if (n >= 1000)    return (n / 1000).toFixed(1) + "k";
    return "" + n;
}

// Stable identity per item — path wins (files, repos, PRs), exec next
// (apps, omarchy actions), title+category last (synthetic rows).
function itemKey(item) {
    if (!item) return "";
    return item.path || item.exec || (item.title + "|" + item.category);
}
