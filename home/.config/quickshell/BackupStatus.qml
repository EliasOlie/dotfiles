pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Idade do último snapshot do restic (script backup-status.sh, que cacheia 30 min).
// Coral quando passa de `maxHours` sem backup (o backup roda todo dia de madrugada).
Singleton {
    id: root
    readonly property int maxHours: 26
    property bool ok: false
    property real last: 0          // epoch do último snapshot
    property real now: Date.now() / 1000
    readonly property real hours: (now - last) / 3600
    readonly property bool fresh: ok && hours < maxHours
    readonly property string age: !ok ? "?" : hours < 1 ? Math.max(1, Math.round(hours * 60)) + "min"
                                       : hours < 48 ? Math.round(hours) + "h" : Math.round(hours / 24) + "d"

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/backup-status.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ")
                root.ok = p[0] === "ok"
                if (root.ok) root.last = parseFloat(p[1])
            }
        }
    }
    Timer {
        interval: 10 * 60 * 1000; running: SysStats.active; repeat: true; triggeredOnStart: true
        onTriggered: { root.now = Date.now() / 1000; proc.running = true }
    }
}
