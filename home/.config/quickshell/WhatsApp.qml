pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Não lidas das contas de WhatsApp (whatsapp.sh status), a cada 5 s
// enquanto algum desktop está à mostra. -1 = conta fechada.
Singleton {
    id: root
    // [{ id, name, short, n }] — contas de ~/.config/eliasolie/whatsapp.json
    property var list: []
    readonly property var open: list.filter(a => a.n >= 0)
    readonly property bool anyOpen: open.length > 0
    function toggle(id) { Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/whatsapp.sh", "toggle", id]) }

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/whatsapp.sh", "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.list = JSON.parse(text) } catch (e) {} } }
    }
    Timer { interval: 5000; running: SysStats.active; repeat: true; triggeredOnStart: true; onTriggered: proc.running = true }
}
