pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lembretes da agenda (lê o mesmo agenda.json do desktop):
//   eventos com hora: 1 h antes e 10 min antes
//   dia inteiro:      às 8h do dia (ou assim que o computador ligar depois disso)
// Cada aviso sai uma vez só; o que já foi avisado fica em
// ~/.local/state/eliasolie/agenda-notified.json (sobrevive a reinícios do qs).
Singleton {
    id: root
    property var events: []
    property var sent: ({})          // chave "início|título|tipo" -> epoch do envio
    property bool sentLoaded: false

    FileView {
        id: agendaFile
        path: Quickshell.env("HOME") + "/.local/share/eliasolie/agenda.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.events = JSON.parse(text()) } catch (e) { root.events = [] } }
    }
    FileView {
        id: sentFile
        path: Quickshell.env("HOME") + "/.local/state/eliasolie/agenda-notified.json"
        printErrors: false
        atomicWrites: true
        onLoaded: { try { root.sent = JSON.parse(text()) } catch (e) {} root.sentLoaded = true; root.check() }
        onLoadFailed: { root.sentLoaded = true; root.check() }
    }

    function hhmm(d) { return Qt.formatTime(d, "HH:mm") }
    function notify(key, summary, body) {
        const s = Object.assign({}, root.sent); s[key] = Date.now(); root.sent = s
        // poda avisos com mais de 3 dias
        for (const k in s) if (Date.now() - s[k] > 3 * 86400000) delete s[k]
        sentFile.setText(JSON.stringify(s) + "\n")
        Quickshell.execDetached(["notify-send", "-a", "agenda", "-i", "x-office-calendar", summary, body])
    }

    function check() {
        if (!root.sentLoaded) return
        const now = new Date()
        for (const e of root.events) {
            const s = new Date(e.start), en = new Date(e.end || e.start)
            if (isNaN(s) || en < now) continue
            const where = e.where ? (e.where.startsWith("http") ? "  ·  link da reunião na agenda" : "  ·  " + e.where) : ""
            const base = e.start + "|" + e.title
            if (e.allDay) {
                // dia inteiro: a partir das 8h do dia, uma vez
                const eight = new Date(s.getFullYear(), s.getMonth(), s.getDate(), 8, 0)
                if (now >= eight && now < en && !root.sent[base + "|dia"])
                    notify(base + "|dia", "Hoje: " + e.title, "Dia inteiro" + where)
                continue
            }
            const min = (s - now) / 60000
            // 10 min antes (janela: de 10 min antes até o início)
            if (min <= 10 && min > -1) {
                if (!root.sent[base + "|10"]) notify(base + "|10", "Em " + Math.max(1, Math.round(min)) + " min · " + e.title, hhmm(s) + "–" + hhmm(en) + where)
            // 1 h antes (janela: de 60 até 10 min antes; perdeu a janela, não avisa atrasado)
            } else if (min <= 60 && min > 10) {
                if (!root.sent[base + "|60"]) notify(base + "|60", "Em " + Math.round(min) + " min · " + e.title, hhmm(s) + "–" + hhmm(en) + where)
            }
        }
    }

    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.check() }
    onEventsChanged: check()
}
