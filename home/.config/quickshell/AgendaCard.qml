import QtQuick
import Quickshell
import Quickshell.Io

// Agenda do desktop: calendário do mês com marcação de cor por tipo de evento
// (EliasOlie, ConectaMe, Pessoal) e os próximos eventos em cards logo abaixo.
// Clique num dia para ver os eventos dele; clique de novo para voltar aos próximos.
// Contrato: ~/.local/share/eliasolie/agenda.json (gerado pelo timer agenda-sync)
//   [{ title, start, end, where, brand: "eliasolie" | "conectame" | "pessoal" | null, allDay }]
Card {
    id: agenda
    label: "AGENDA"
    title: months[viewMonth] + " " + viewYear
    glyph: "\u{f00ed}"
    implicitHeight: headerHeight + pad * 2 + col.implicitHeight

    // ---------------------------------------------------------------- dados
    readonly property var brandColor: ({ eliasolie: Theme.signal, conectame: "#6EEB62", pessoal: "#7AA7FF" })
    readonly property var brandLabel: ({ eliasolie: "ELIASOLIE", conectame: "CONECTAME", pessoal: "PESSOAL" })
    function colorOf(b) { return brandColor[b] || Theme.statik }

    readonly property var months: ["JANEIRO", "FEVEREIRO", "MARÇO", "ABRIL", "MAIO", "JUNHO",
        "JULHO", "AGOSTO", "SETEMBRO", "OUTUBRO", "NOVEMBRO", "DEZEMBRO"]
    readonly property var weekdays: ["D", "S", "T", "Q", "Q", "S", "S"]
    readonly property var weekdaysShort: ["DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SÁB"]

    property var events: []
    property bool hasFile: false
    property var today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property int selectedKey: 0          // AAAAMMDD do dia clicado; 0 = próximos eventos

    function keyOf(d) { return d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate() }
    readonly property int todayKey: keyOf(today)

    // Dias que cada evento ocupa (evento de vários dias marca todos eles)
    function daysOf(s, e) {
        const out = []
        const d = new Date(s.getFullYear(), s.getMonth(), s.getDate())
        const last = new Date(Math.max(s.getTime(), e.getTime() - 1))
        for (let i = 0; d <= last && i < 62; i++) {
            out.push(keyOf(d))
            d.setDate(d.getDate() + 1)
        }
        return out
    }

    // dia -> marcas presentes (sem repetir), na ordem eliasolie, conectame, pessoal, outros
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

    readonly property var listed: {
        if (selectedKey) return events.filter(e => e._days.indexOf(selectedKey) >= 0).slice(0, 5)
        const now = today
        return events.filter(e => e._e >= now).slice(0, 4)
    }

    // Grade do mês: começa no domingo, 5 ou 6 semanas conforme o mês
    readonly property var cells: {
        const first = new Date(viewYear, viewMonth, 1)
        const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate()
        const rows = Math.ceil((first.getDay() + daysInMonth) / 7)
        const out = []
        for (let i = 0; i < rows * 7; i++) out.push(new Date(viewYear, viewMonth, 1 - first.getDay() + i))
        return out
    }

    function shiftMonth(n) {
        const m = viewMonth + n
        viewYear = viewYear + Math.floor(m / 12)
        viewMonth = ((m % 12) + 12) % 12
    }

    function timeLabel(e) {
        const s = e._s
        const sameDay = keyOf(s) === todayKey
        const tomorrow = keyOf(s) === keyOf(new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1))
        const day = sameDay ? "HOJE" : tomorrow ? "AMANHÃ"
            : weekdaysShort[s.getDay()] + " " + Qt.formatDate(s, "dd/MM")
        if (e.allDay) return day + " · DIA TODO"
        return day + " · " + Qt.formatTime(s, "HH:mm") + "–" + Qt.formatTime(e._e, "HH:mm")
    }

    FileView {
        id: agendaFile
        path: Quickshell.env("HOME") + "/.local/share/eliasolie/agenda.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            agenda.hasFile = true
            try {
                agenda.events = JSON.parse(text())
                    .map(e => {
                        const s = new Date(e.start), en = new Date(e.end || e.start)
                        return Object.assign({}, e, { _s: s, _e: en, _days: agenda.daysOf(s, en) })
                    })
                    .sort((a, b) => a._s - b._s)
            } catch (err) { agenda.events = [] }
        }
        onLoadFailed: agenda.hasFile = false
    }
    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: { agenda.today = new Date(); agendaFile.reload() }
    }

    // "+ NOVO" na linha do mês: abre o formulário (no dia clicado, ou hoje)
    signal newEvent(int key)
    // na linha do mês, encostado à direita (mês à esquerda · NOVO à direita)
    // (parent: o card em si — filhos comuns caem na área de conteúdo, abaixo do cabeçalho)
    Badge {
        parent: agenda
        anchors { right: parent.right; rightMargin: agenda.pad; top: parent.top; topMargin: agenda.pad + 20 }
        text: "+ novo"
        implicitHeight: 24
        onClicked: agenda.newEvent(agenda.selectedKey)
    }

    // ---------------------------------------------------------------- visual
    Column {
        id: col
        width: parent.width
        spacing: 10

        // Legenda + navegação do mês
        Item {
            width: parent.width
            height: 18
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Repeater {
                    model: ["eliasolie", "conectame", "pessoal"]
                    delegate: Row {
                        required property string modelData
                        spacing: 5
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6; height: 6
                            color: agenda.colorOf(modelData)
                        }
                        Text {
                            text: agenda.brandLabel[modelData]
                            color: Theme.statik; font.family: Theme.mono; font.pixelSize: 9; font.letterSpacing: 1
                        }
                    }
                }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 4
                Repeater {
                    model: [{ t: "", n: -1 }, { t: "HOJE", n: 0 }, { t: "", n: 1 }]
                    delegate: Rectangle {
                        required property var modelData
                        width: nav.implicitWidth + 12; height: 18
                        color: navHover.hovered ? Theme.line : "transparent"
                        Text {
                            id: nav
                            anchors.centerIn: parent
                            text: modelData.t
                            color: navHover.hovered ? Theme.signal : Theme.statik
                            font.family: Theme.mono; font.pixelSize: 10
                        }
                        HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (modelData.n === 0) {
                                    agenda.viewYear = agenda.today.getFullYear()
                                    agenda.viewMonth = agenda.today.getMonth()
                                    agenda.selectedKey = 0
                                } else agenda.shiftMonth(modelData.n)
                            }
                        }
                    }
                }
            }
        }

        // Cabeçalho dos dias da semana
        Row {
            Repeater {
                model: agenda.weekdays
                delegate: Text {
                    required property string modelData
                    required property int index
                    width: col.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index === 0 ? Qt.alpha(Theme.statik, 0.6) : Theme.statik
                    font.family: Theme.mono; font.pixelSize: 10
                }
            }
        }

        // Grade do mês
        Grid {
            columns: 7
            Repeater {
                model: agenda.cells
                delegate: Item {
                    id: cell
                    required property var modelData
                    readonly property int key: agenda.keyOf(modelData)
                    readonly property bool inMonth: modelData.getMonth() === agenda.viewMonth
                    readonly property bool isToday: key === agenda.todayKey
                    readonly property bool isSelected: key === agenda.selectedKey
                    readonly property var dayMarks: agenda.marks[key] || []
                    width: col.width / 7
                    height: 36

                    Rectangle {
                        anchors { fill: parent; margins: 2 }
                        color: cell.isToday ? Qt.alpha(Theme.signal, 0.12)
                             : cellHover.hovered ? Theme.line : "transparent"
                        border.width: cell.isSelected || cell.isToday ? 1 : 0
                        border.color: cell.isSelected ? Theme.bone : Theme.signal
                    }
                    Text {
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 6 }
                        text: cell.modelData.getDate()
                        color: cell.isToday ? Theme.signal
                             : cell.inMonth ? Theme.bone : Qt.alpha(Theme.statik, 0.35)
                        font.family: Theme.mono; font.pixelSize: 12
                        font.weight: cell.isToday ? Font.Bold : Font.Normal
                    }
                    Row {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                        spacing: 3
                        opacity: cell.inMonth ? 1 : 0.4
                        Repeater {
                            model: cell.dayMarks.slice(0, 4)
                            delegate: Rectangle {
                                required property string modelData
                                width: 5; height: 5
                                color: agenda.colorOf(modelData)
                            }
                        }
                    }
                    HoverHandler { id: cellHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (!cell.inMonth) {
                                agenda.viewYear = cell.modelData.getFullYear()
                                agenda.viewMonth = cell.modelData.getMonth()
                            }
                            agenda.selectedKey = cell.isSelected ? 0 : cell.key
                        }
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.line }

        Text {
            text: agenda.selectedKey
                ? (String(agenda.selectedKey % 100).padStart(2, "0") + "/"
                   + String(Math.floor(agenda.selectedKey / 100) % 100).padStart(2, "0")
                   + " · " + agenda.listed.length + (agenda.listed.length === 1 ? " EVENTO" : " EVENTOS"))
                : "PRÓXIMOS"
            color: Theme.statik; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2
        }

        // Cards de evento
        Repeater {
            model: agenda.listed
            delegate: Rectangle {
                id: ev
                required property var modelData
                readonly property string link: (modelData.where || "").startsWith("http") ? modelData.where : ""
                width: col.width
                height: 50
                color: Theme.void_
                border.width: 1
                border.color: evHover.hovered && link ? agenda.colorOf(modelData.brand) : Theme.line

                Rectangle {
                    width: 3
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    color: agenda.colorOf(ev.modelData.brand)
                }
                Column {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: 14; rightMargin: 12 }
                    spacing: 4
                    Item {
                        width: parent.width
                        height: when.implicitHeight
                        Text {
                            id: when
                            text: agenda.timeLabel(ev.modelData)
                            color: agenda.colorOf(ev.modelData.brand)
                            font.family: Theme.mono; font.pixelSize: 10
                        }
                        Text {
                            anchors.right: parent.right
                            text: (ev.link ? "MEET  " : "") + (agenda.brandLabel[ev.modelData.brand] || "GOOGLE")
                            color: Qt.alpha(Theme.statik, 0.8)
                            font.family: Theme.mono; font.pixelSize: 9; font.letterSpacing: 1
                        }
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: ev.modelData.title
                            + (ev.modelData.where && !ev.link ? "  · " + ev.modelData.where : "")
                        color: Theme.bone
                        font.family: Theme.sans; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                }
                HoverHandler { id: evHover; cursorShape: ev.link ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler { enabled: ev.link !== ""; onTapped: Qt.openUrlExternally(ev.link) }
            }
        }

        Text {
            visible: agenda.listed.length === 0
            text: !agenda.hasFile ? "sincronizando" : agenda.selectedKey ? "dia livre" : "nada pela frente"
            color: Qt.alpha(Theme.statik, 0.6); font.family: Theme.mono; font.pixelSize: 12
        }
    }
}
