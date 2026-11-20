pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Coleta de dados do sistema (um único coletor para todos os monitores)
Singleton {
    id: root

    property real cpu: 0        // %
    property real ram: 0        // %
    property string ramText: ""
    property real temp: 0       // °C (coretemp)
    property real gpu: -1       // % (-1 = indisponível)
    property real gpuTemp: 0
    property real disk: 0       // % usado em /
    property string diskText: ""

    // Só coleta quando algum monitor está com o desktop à mostra (workspace vazio):
    // com janelas por cima ninguém vê os medidores, então não gasta CPU à toa
    readonly property bool active: Hyprland.monitors.values.some(m => m.activeWorkspace && m.activeWorkspace.toplevels.values.length === 0)

    property var _lastCpu: null
    property string _tempPath: ""

    // CPU e RAM: lidos de /proc a cada 2 s
    FileView { id: statFile; path: "/proc/stat" }
    FileView { id: memFile;  path: "/proc/meminfo" }
    FileView { id: tempFile; path: root._tempPath }

    Timer {
        interval: 2000; running: root.active; repeat: true; triggeredOnStart: true
        onTriggered: {
            statFile.reload(); memFile.reload()
            if (root._tempPath !== "") tempFile.reload()

            const l = (statFile.text() || "").split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            if (l.length >= 4) {
                const idle = l[3] + (l[4] || 0)
                const total = l.reduce((a, b) => a + b, 0)
                if (root._lastCpu) {
                    const dt = total - root._lastCpu.total, di = idle - root._lastCpu.idle
                    if (dt > 0) root.cpu = Math.round(100 * (1 - di / dt))
                }
                root._lastCpu = { total: total, idle: idle }
            }

            const m = {}
            for (const line of (memFile.text() || "").split("\n")) {
                const p = line.split(/:\s+/)
                if (p.length === 2) m[p[0]] = parseInt(p[1])
            }
            if (m.MemTotal) {
                const used = m.MemTotal - (m.MemAvailable || 0)
                root.ram = Math.round(100 * used / m.MemTotal)
                root.ramText = (used / 1048576).toFixed(1) + " / " + (m.MemTotal / 1048576).toFixed(1) + " GiB"
            }

            const t = parseInt(tempFile.text() || "0")
            if (t > 0) root.temp = Math.round(t / 1000)
        }
    }

    // Descobre o sensor coretemp (o número do hwmon muda entre boots)
    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do [ \"$(cat $d/name)\" = coretemp ] && echo $d/temp1_input && break; done"]
        stdout: StdioCollector { onStreamFinished: root._tempPath = this.text.trim() }
    }

    // GPU NVIDIA (MX250) a cada 5 s
    Process {
        id: gpuProc
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(/,\s*/)
                if (p.length === 2) { root.gpu = Number(p[0]); root.gpuTemp = Number(p[1]) }
            }
        }
    }
    Timer { interval: 5000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: gpuProc.running = true }

    // Disco (/) a cada 60 s
    Process {
        id: diskProc
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split("\n").pop().trim().split(/\s+/).map(Number)
                if (p.length === 2 && p[1] > 0) {
                    root.disk = Math.round(100 * p[0] / p[1])
                    root.diskText = (p[0] / 1e9).toFixed(0) + " / " + (p[1] / 1e9).toFixed(0) + " GB"
                }
            }
        }
    }
    Timer { interval: 60000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: diskProc.running = true }
}
