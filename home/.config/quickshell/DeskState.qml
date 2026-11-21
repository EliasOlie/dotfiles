pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Estado do desktop por monitor, salvo em ~/.local/state/eliasolie/desktop.json:
//   compact  { "eDP-1": true }                         modo compacto (Super+Alt+D)
//   pins     { "eDP-1": { left, right, qa } }          blocos fixados abertos (alfinete)
//   agenda   { "eDP-1": true }                         agenda grande no centro (Super+A)
//   focus    (não salvo) modo foco ligado -> compacta todos os monitores
// IPC: qs ipc call desktop toggleCompact | toggleAgenda | setFocus true/false
Singleton {
    id: root
    property var compact: ({})
    property var pins: ({})
    property var agenda: ({})
    property bool focus: false

    function isCompact(name) { return root.compact[name] === true }
    function agendaOpen(name) { return root.agenda[name] === true }
    function pinned(name, key) { return !!(root.pins[name] && root.pins[name][key]) }

    function save() { file.setText(JSON.stringify({ compact: root.compact, pins: root.pins, agenda: root.agenda }, null, 2) + "\n") }
    function toggleAgendaOn(name) {
        const a = Object.assign({}, root.agenda); a[name] = !a[name]; root.agenda = a; save()
        return a[name]
    }
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
        onLoaded: { try { const d = JSON.parse(text()); root.compact = d.compact || {}; root.pins = d.pins || {}; root.agenda = d.agenda || {} } catch (e) {} }
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
        // Abre/fecha a agenda grande no monitor com foco; abrindo com janelas
        // na frente, vai para o desktop (Super+D) para ela aparecer
        function toggleAgenda(): void {
            const m = Hyprland.focusedMonitor
            if (!m) return
            const on = root.toggleAgendaOn(m.name)
            const ws = m.activeWorkspace
            if (on && ws && ws.toplevels.values.length > 0) Quickshell.execDetached(["hyprctl", "eval", "ShowDesktop()"])
        }
    }
}
