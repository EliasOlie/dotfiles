pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Não lidas das 3 contas de WhatsApp (whatsapp.sh status), a cada 5 s
// enquanto algum desktop está à mostra. -1 = conta fechada.
Singleton {
    id: root
    readonly property var accounts: [
        { id: "pessoal", label: "PESSOAL" },
        { id: "profissional", label: "PROF" },
        { id: "jac", label: "JAC" }
    ]
    property var counts: ({})
    readonly property bool anyOpen: accounts.some(a => (counts[a.id] ?? -1) >= 0)
    function toggle(id) { Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/whatsapp.sh", "toggle", id]) }

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/whatsapp.sh", "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.counts = JSON.parse(text) } catch (e) {} } }
    }
    Timer { interval: 5000; running: SysStats.active; repeat: true; triggeredOnStart: true; onTriggered: proc.running = true }
}
