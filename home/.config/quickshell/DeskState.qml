pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Estado do desktop por monitor, salvo em ~/.local/state/eliasolie/desktop.json:
//   compact  { "eDP-1": true }                         modo compacto (Super+Alt+D)
//   pins     { "eDP-1": { left, right, qa } }          blocos fixados abertos (alfinete)
//   focus    (não salvo) modo foco ligado -> compacta todos os monitores
// IPC: qs ipc call desktop toggleCompact | setFocus true/false
Singleton {
    id: root
    property var compact: ({})
    property var pins: ({})
    property bool focus: false

    function isCompact(name) { return root.compact[name] === true }
    function pinned(name, key) { return !!(root.pins[name] && root.pins[name][key]) }

    function save() { file.setText(JSON.stringify({ compact: root.compact, pins: root.pins }, null, 2) + "\n") }
    function toggle(name) {
        const c = Object.assign({}, root.compact); c[name] = !c[name]; root.compact = c; save()
    }
    function togglePin(name, key) {
        const p = Object.assign({}, root.pins)
        p[name] = Object.assign({}, p[name] || {}); p[name][key] = !p[name][key]
        root.pins = p; save()
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/eliasolie/desktop.json"
        printErrors: false
        atomicWrites: true
        onLoaded: { try { const d = JSON.parse(text()); root.compact = d.compact || {}; root.pins = d.pins || {} } catch (e) {} }
    }
    // Foco já ligado quando o Quickshell (re)inicia
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/focus"
        printErrors: false
        onLoaded: root.focus = true
    }

    IpcHandler {
        target: "desktop"
        function toggleCompact(): void {
            const m = Hyprland.focusedMonitor
            if (m) root.toggle(m.name)
        }
        function setFocus(on: bool): void { root.focus = on }
    }
}
