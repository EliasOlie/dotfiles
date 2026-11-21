pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Estado do desktop por monitor (por enquanto: modo compacto), salvo em
// ~/.local/state/eliasolie/desktop.json para sobreviver a reinícios.
// Atalho: qs ipc call desktop toggleCompact   (monitor com foco)
Singleton {
    id: root
    property var compact: ({})          // { "eDP-1": true, ... }

    function isCompact(name) { return root.compact[name] === true }
    function toggle(name) {
        const c = Object.assign({}, root.compact)
        c[name] = !c[name]
        root.compact = c
        file.setText(JSON.stringify({ compact: c }, null, 2) + "\n")
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/eliasolie/desktop.json"
        printErrors: false
        atomicWrites: true
        onLoaded: { try { root.compact = JSON.parse(text()).compact || {} } catch (e) {} }
    }

    IpcHandler {
        target: "desktop"
        function toggleCompact(): void {
            const m = Hyprland.focusedMonitor
            if (m) root.toggle(m.name)
        }
    }
}
