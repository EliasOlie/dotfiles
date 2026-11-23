import QtQuick
import Quickshell

// Agenda grande "do wallpaper" (Super+A): sem card, sem fundo. O mês é escrito
// direto sobre a grade de pontos e cada dia ocupa um quadrado da própria grade
// (células em múltiplos de 40 px, os pontos caem nos cantos). À direita, os
// próximos eventos (ou os do dia clicado) em lista, também sem caixas.
Item {
    id: wall
    readonly property int step: 40
    readonly property int cellW: width >= 1800 ? step * 3 : step * 2
    readonly property int cellH: step * 2
    function snap(v) { return Math.round(v / step) * step }

    // Área: entre o painel de atalhos (esquerda) e a borda direita
    readonly property int gridX: snap(width * 0.2)
    readonly property int gridY: snap(height * 0.26)
    readonly property int gridW: cellW * 7
    readonly property int listX: gridX + gridW + step * 2
    readonly property int listW: width - listX - 56

    property int viewYear: AgendaData.today.getFullYear()
    property int viewMonth: AgendaData.today.getMonth()
    property int selectedKey: 0
    signal newEvent(int key)          // "+ NOVO EVENTO": abre o formulário no dia escolhido
    readonly property var listed: selectedKey ? AgendaData.onDay(selectedKey, 6) : AgendaData.upcoming(6)

    readonly property var cells: {
        const first = new Date(viewYear, viewMonth, 1)
        const n = new Date(viewYear, viewMonth + 1, 0).getDate()
        const rows = Math.ceil((first.getDay() + n) / 7)
        const out = []
        for (let i = 0; i < rows * 7; i++) out.push(new Date(viewYear, viewMonth, 1 - first.getDay() + i))
        return out
    }
    function shiftMonth(n) {
        const m = viewMonth + n
        viewYear += Math.floor(m / 12)
        viewMonth = ((m % 12) + 12) % 12
        selectedKey = 0
    }

    // ------------------------------------------------ título: mês enorme + ano lima
    Text {
        id: monthTitle
        x: wall.gridX - 4
        y: wall.gridY - wall.step * 4 + 6
        text: AgendaData.months[wall.viewMonth]
        color: Theme.bone
        font.family: Theme.sans; font.pixelSize: 112; font.weight: Font.ExtraBold
        font.variableAxes: { "wdth": 62 }
        lineHeight: 0.8
    }
    Text {
        anchors { left: monthTitle.right; leftMargin: 18; baseline: monthTitle.baseline }
        text: wall.viewYear
        color: Theme.signal
        font.family: Theme.mono; font.pixelSize: 16; font.letterSpacing: 4
    }
    // navegação ‹ HOJE ›
    Row {
        x: wall.gridX + wall.gridW - width
        anchors.baseline: monthTitle.baseline
        spacing: 18
        Repeater {
            model: [{ t: "", n: -1 }, { t: "HOJE", n: 0 }, { t: "", n: 1 }]
            delegate: Text {
                required property var modelData
                text: modelData.t
                color: navMouse.containsMouse ? Theme.signal : Theme.statik
                font.family: Theme.mono; font.pixelSize: 12; font.letterSpacing: 2
                MouseArea {
                    id: navMouse
                    anchors { fill: parent; margins: -8 }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.n === 0) {
                            wall.viewYear = AgendaData.today.getFullYear()
                            wall.viewMonth = AgendaData.today.getMonth()
                            wall.selectedKey = 0
                        } else wall.shiftMonth(modelData.n)
                    }
                }
            }
        }
    }

    // ------------------------------------------------ botão "+ NOVO EVENTO" (no dia clicado, ou hoje)
    Badge {
        x: wall.listX
        anchors.verticalCenter: monthTitle.verticalCenter
        text: "novo evento"
        on: true
        label.text: wall.selectedKey
            ? "+  NOVO EVENTO EM " + String(wall.selectedKey % 100).padStart(2, "0") + "/" + String(Math.floor(wall.selectedKey / 100) % 100).padStart(2, "0")
            : "+  NOVO EVENTO"
        implicitHeight: 34
        onClicked: wall.newEvent(wall.selectedKey)
    }

    // ------------------------------------------------ dias da semana
    Repeater {
        model: ["DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SÁB"]
        delegate: Text {
            required property string modelData
            required property int index
            x: wall.gridX + index * wall.cellW + 10
            y: wall.gridY - 26
            text: modelData
            color: index === 0 ? Qt.alpha(Theme.statik, 0.55) : Theme.statik
            font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 3
        }
    }

    // ------------------------------------------------ grade do mês (sobre os pontos)
    Repeater {
        model: wall.cells
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property int key: AgendaData.keyOf(modelData)
            readonly property bool inMonth: modelData.getMonth() === wall.viewMonth
            readonly property bool isToday: key === AgendaData.todayKey
            readonly property bool isSelected: key === wall.selectedKey
            readonly property var dayMarks: AgendaData.marks[key] || []
            x: wall.gridX + (index % 7) * wall.cellW
            y: wall.gridY + Math.floor(index / 7) * wall.cellH
            width: wall.cellW; height: wall.cellH
            opacity: inMonth ? 1 : 0.22

            // hoje: traço lima no topo (como a borda da waybar); selecionado: traço osso
            Rectangle {
                visible: cell.isToday || cell.isSelected || cellMouse.containsMouse
                x: 2; width: parent.width - 4; height: 2
                color: cell.isSelected ? Theme.bone : cell.isToday ? Theme.signal : Theme.line
            }
            Text {
                x: 10; y: 10
                text: cell.modelData.getDate()
                color: cell.isToday ? Theme.signal : cellMouse.containsMouse ? Theme.bone
                     : (cell.index % 7 === 0 ? Qt.alpha(Theme.bone, 0.55) : Qt.alpha(Theme.bone, 0.85))
                font.family: Theme.sans; font.pixelSize: 34; font.weight: Font.ExtraBold
                font.variableAxes: { "wdth": 62 }
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            // marcas dos eventos: quadradinhos coloridos, como pontos acesos
            Row {
                x: 12; y: parent.height - 18
                spacing: 4
                Repeater {
                    model: cell.dayMarks.slice(0, 4)
                    delegate: Rectangle {
                        required property string modelData
                        width: 7; height: 7
                        color: AgendaData.colorOf(modelData)
                    }
                }
            }
            MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!cell.inMonth) { wall.viewYear = cell.modelData.getFullYear(); wall.viewMonth = cell.modelData.getMonth() }
                    wall.selectedKey = cell.isSelected ? 0 : cell.key
                }
            }
        }
    }

    // ------------------------------------------------ legenda (embaixo da grade)
    Row {
        x: wall.gridX + 10
        y: wall.gridY + Math.ceil(wall.cells.length / 7) * wall.cellH + 14
        spacing: 22
        Repeater {
            model: ["eliasolie", "conectame", "pessoal"]
            delegate: Row {
                required property string modelData
                spacing: 8
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; color: AgendaData.colorOf(modelData) }
                Text {
                    text: AgendaData.brandLabel[modelData]
                    color: Theme.statik; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2
                }
            }
        }
    }

    // ------------------------------------------------ lista de eventos (sem caixas)
    Text {
        x: wall.listX
        y: wall.gridY - 26
        text: wall.selectedKey
            ? (String(wall.selectedKey % 100).padStart(2, "0") + "/" + String(Math.floor(wall.selectedKey / 100) % 100).padStart(2, "0")
               + "  ·  " + wall.listed.length + (wall.listed.length === 1 ? " EVENTO" : " EVENTOS"))
            : "PRÓXIMOS"
        color: Theme.statik; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 3
    }
    Repeater {
        model: wall.listed
        delegate: Item {
            id: ev
            required property var modelData
            required property int index
            readonly property string link: (modelData.where || "").startsWith("http") ? modelData.where : ""
            readonly property color tint: AgendaData.colorOf(modelData.brand)
            x: wall.listX
            y: wall.gridY + index * wall.cellH
            width: wall.listW; height: wall.cellH

            Rectangle { x: 0; y: 2; width: parent.width; height: 1; color: Theme.line; opacity: 0.7 }
            Rectangle { x: 0; y: 16; width: 7; height: 7; color: ev.tint }
            Text {
                x: 20; y: 12
                text: AgendaData.timeLabel(ev.modelData) + (ev.link ? "   ·   MEET ↗" : "")
                color: ev.tint
                font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.5
            }
            Text {
                x: 20; y: 32
                width: parent.width - 20
                elide: Text.ElideRight
                text: ev.modelData.title
                color: evMouse.containsMouse && ev.link ? Theme.signal : Theme.bone
                font.family: Theme.sans; font.pixelSize: 22; font.weight: Font.Bold
                font.variableAxes: { "wdth": 85 }
            }
            MouseArea {
                id: evMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: ev.link !== ""
                cursorShape: ev.link ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: Qt.openUrlExternally(ev.link)
            }
        }
    }
    Text {
        visible: wall.listed.length === 0
        x: wall.listX; y: wall.gridY + 12
        text: !AgendaData.hasFile ? "sincronizando…" : wall.selectedKey ? "dia livre" : "nada pela frente"
        color: Qt.alpha(Theme.statik, 0.7); font.family: Theme.mono; font.pixelSize: 13
    }
}
