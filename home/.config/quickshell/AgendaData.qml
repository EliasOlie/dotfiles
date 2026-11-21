pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Dados da agenda (um leitor só para a agenda do wallpaper e os lembretes).
// Contrato: ~/.local/share/eliasolie/agenda.json (timer agenda-sync)
//   [{ title, start, end, where, brand: "eliasolie" | "conectame" | "pessoal" | null, allDay }]
Singleton {
    id: root
    property var events: []          // ordenados, com _s, _e (Date) e _days (AAAAMMDD[])
    property bool hasFile: false
    property var today: new Date()

    readonly property var brandColor: ({ eliasolie: Theme.signal, conectame: "#6EEB62", pessoal: "#7AA7FF" })
    readonly property var brandLabel: ({ eliasolie: "ELIASOLIE", conectame: "CONECTAME", pessoal: "PESSOAL" })
    function colorOf(b) { return brandColor[b] || Theme.statik }

    readonly property var months: ["JANEIRO", "FEVEREIRO", "MARÇO", "ABRIL", "MAIO", "JUNHO",
        "JULHO", "AGOSTO", "SETEMBRO", "OUTUBRO", "NOVEMBRO", "DEZEMBRO"]
    readonly property var weekdaysShort: ["DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SÁB"]

    function keyOf(d) { return d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate() }
    readonly property int todayKey: keyOf(today)

    function daysOf(s, e) {
        const out = []
        const d = new Date(s.getFullYear(), s.getMonth(), s.getDate())
        const last = new Date(Math.max(s.getTime(), e.getTime() - 1))
        for (let i = 0; d <= last && i < 62; i++) { out.push(keyOf(d)); d.setDate(d.getDate() + 1) }
        return out
    }

    // dia -> marcas presentes, na ordem eliasolie, conectame, pessoal, outros
    readonly property var marks: {
        const m = {}
        for (const e of events)
            for (const k of e._days) {
                const b = e.brand || "google"
                if (!m[k]) m[k] = []
                if (m[k].indexOf(b) < 0) m[k].push(b)
            }
        const order = ["eliasolie", "conectame", "pessoal", "google"]
        for (const k in m) m[k].sort((a, b) => order.indexOf(a) - order.indexOf(b))
        return m
    }

    function upcoming(n) { const now = today; return events.filter(e => e._e >= now).slice(0, n) }
    function onDay(key, n) { return events.filter(e => e._days.indexOf(key) >= 0).slice(0, n) }

    function timeLabel(e) {
        const s = e._s
        const tomorrowKey = keyOf(new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1))
        const day = keyOf(s) === todayKey ? "HOJE" : keyOf(s) === tomorrowKey ? "AMANHÃ"
            : weekdaysShort[s.getDay()] + " " + Qt.formatDate(s, "dd/MM")
        if (e.allDay) return day + " · DIA TODO"
        return day + " · " + Qt.formatTime(s, "HH:mm") + "–" + Qt.formatTime(e._e, "HH:mm")
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/share/eliasolie/agenda.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.hasFile = true
            try {
                root.events = JSON.parse(text())
                    .map(e => {
                        const s = new Date(e.start), en = new Date(e.end || e.start)
                        return Object.assign({}, e, { _s: s, _e: en, _days: root.daysOf(s, en) })
                    })
                    .sort((a, b) => a._s - b._s)
            } catch (err) { root.events = [] }
        }
        onLoadFailed: root.hasFile = false
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: { root.today = new Date(); file.reload() } }
}
