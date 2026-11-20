pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Status da VPS: checa por HTTP cada serviço de vps.json (ou do arquivo local
// ~/.config/eliasolie/vps.json, que não vai pro repo) a cada 60 s.
// Só roda com o desktop à mostra, igual ao SysStats.
Singleton {
    id: root

    property string panel: ""
    property var config: []        // [{ name, url }]
    property var services: []      // [{ name, url, up, ms, code }]
    property bool checking: false
    property date checkedAt: new Date(0)
    readonly property int down: services.filter(s => !s.up).length

    readonly property string localPath: Quickshell.env("HOME") + "/.config/eliasolie/vps.json"
    property bool hasLocal: false

    function apply(txt) {
        try {
            const d = JSON.parse(txt)
            root.panel = d.panel || ""
            root.config = d.services || []
            check()
        } catch (e) { root.config = [] }
    }

    FileView {
        id: localFile
        path: root.localPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { root.hasLocal = true; root.apply(text()) }
        onLoadFailed: { root.hasLocal = false; if (repoFile.loaded) root.apply(repoFile.text()) }
    }
    FileView {
        id: repoFile
        path: Qt.resolvedUrl("vps.json").toString().replace("file://", "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: if (!root.hasLocal) root.apply(text())
    }

    function check() {
        if (root.config.length === 0 || proc.running) return
        root.checking = true
        proc.command = ["sh", "-c",
            'for u; do curl -s -o /dev/null -m 8 -w "%{http_code} %{time_total}\\n" "$u" || echo "000 0"; done',
            "sh"].concat(root.config.map(s => s.url))
        proc.running = true
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.services = root.config.map((s, i) => {
                    const p = (lines[i] || "000 0").trim().split(/\s+/)
                    const code = parseInt(p[0]) || 0
                    return { name: s.name, url: s.url, code: code,
                             up: code > 0 && code < 500,
                             ms: Math.round(parseFloat(p[1] || 0) * 1000) }
                })
                root.checkedAt = new Date()
                root.checking = false
            }
        }
    }

    Timer {
        interval: 60000; running: SysStats.active; repeat: true; triggeredOnStart: true
        onTriggered: root.check()
    }
}
