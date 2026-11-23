pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Visão geral das janelas (Overview.qml), aberta por monitor.
//   qs ipc call overview toggle      monitor em foco   (Super+O)
//   qs ipc call overview toggleAll   todos os monitores (Super+Ctrl+O)
Singleton {
    id: root
    property var open: ({})            // { "eDP-1": true }

    function isOpen(name) { return root.open[name] === true }
    function set(map) {
        if (Object.keys(map).some(k => map[k])) { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces() }
        root.open = map
    }
    function close(name) { const m = Object.assign({}, root.open); delete m[name]; set(m) }
    function closeAll() { set({}) }

    IpcHandler {
        target: "overview"
        function toggle(): void {
            const f = Hyprland.focusedMonitor
            if (!f) return
            if (root.isOpen(f.name)) root.close(f.name)
            else { const m = Object.assign({}, root.open); m[f.name] = true; root.set(m) }
        }
        function toggleAll(): void {
            const any = Object.keys(root.open).some(k => root.open[k])
            if (any) { root.closeAll(); return }
            const m = {}
            for (const mon of Hyprland.monitors.values) m[mon.name] = true
            root.set(m)
        }
    }
}
