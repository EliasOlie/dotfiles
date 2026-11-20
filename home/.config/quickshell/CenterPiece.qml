import QtQuick
import Quickshell
import Quickshell.Io

// Topo-centro do desktop: frase (troca sozinha e no clique) + quick actions
Column {
    id: center
    spacing: 22

    // ------------------------------------------------ frases
    // Lista em phrases.txt (uma por linha). Troca a cada `rotateMinutes`,
    // em ordem embaralhada sem repetir; clique troca na hora.
    property int rotateMinutes: 10
    property var phrases: ["Funciona na minha máquina."]
    property var bag: []
    property string current: phrases[0]
    property int clicks: 0

    FileView {
        id: phrasesFile
        path: Qt.resolvedUrl("phrases.txt").toString().replace("file://", "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const list = text().split("\n").map(l => l.trim()).filter(l => l && !l.startsWith("#"))
            if (list.length) { center.phrases = list; center.bag = []; center.next() }
        }
    }

    // Easter eggs por data/hora: devolve uma frase ou "" (nada especial agora)
    function egg() {
        const d = new Date(), h = d.getHours(), m = d.getMinutes(), dow = d.getDay()
        const md = (d.getMonth() + 1) + "-" + d.getDate()
        const pick = arr => arr[Math.floor(Math.random() * arr.length)]
        if (h === 13 && m === 37) return "13:37. Elite."
        if (md === "12-25") return "Feliz Natal! Que o build venha verde."
        if (md === "12-31") return "Último dia do ano. Último deploy do ano? Melhor não."
        if (md === "1-1")   return "Ano novo, bugs novos."
        if (md === "4-1")   return "Todos os testes passaram. (Primeiro de abril.)"
        if (md === "3-14")  return "Feliz dia do π: 3,14159265…"
        if (md === "5-4")   return "Que a força esteja com o seu código."
        if (md === "10-31") return "Doces ou bugs?"
        const doy = Math.floor((d - new Date(d.getFullYear(), 0, 0)) / 86400000)
        if (doy === 256) return "Dia do Programador: 256º dia do ano. Parabéns!"
        if (h >= 0 && h < 5) return pick([
            "Já passou da meia-noite. O bug espera até amanhã.",
            "Código escrito às 3h é problema das 9h.",
            "Vai dormir. O servidor não vai fugir."])
        if (dow === 5 && h >= 15) return pick(["Sexta à tarde. Nem pense em deploy.", "Sexta-feira: commita e corre."])
        if (dow === 1 && h < 10) return pick(["Segunda-feira. Café primeiro, código depois.", "Segunda de manhã: git pull e coragem."])
        if (h >= 12 && h < 13 && Math.random() < 0.5) return "Hora do almoço. O código não foge."
        return ""
    }

    function next() {
        const e = egg()
        if (e && Math.random() < 0.5) { center.current = e; return }   // easter egg metade das vezes, quando cabe
        if (center.bag.length === 0) {
            const b = center.phrases.slice()
            for (let i = b.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [b[i], b[j]] = [b[j], b[i]] }
            if (b.length > 1 && b[b.length - 1] === center.current) b.unshift(b.pop())   // não repete a atual
            center.bag = b
        }
        const b = center.bag.slice(); center.current = b.pop(); center.bag = b
    }


    Timer {
        interval: center.rotateMinutes * 60000; running: true; repeat: true
        onTriggered: fade.restart()
    }
    // Zera o contador de cliques se ficar parado
    Timer { id: clickReset; interval: 3000; onTriggered: center.clicks = 0 }

    function esc(t) { return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }

    Text {
        id: phrase
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.StyledText
        text: "<font color='" + Theme.signal + "'>//</font> " + center.esc(center.current)
        color: phraseMouse.containsMouse ? Theme.bone : Qt.alpha(Theme.bone, 0.82)
        font.family: Theme.sans
        font.pixelSize: 30
        font.weight: Font.Medium
        font.variableAxes: { "wdth": 85 }
        Behavior on color { ColorAnimation { duration: 150 } }

        MouseArea {
            id: phraseMouse
            // Área de clique larga e fixa: a frase muda de largura a cada troca,
            // então clicando rápido o mouse não "cai fora" da frase nova
            anchors { fill: parent; leftMargin: -260; rightMargin: -260; topMargin: -14; bottomMargin: -14 }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function hit() {
                if (eggHold.running) return            // segura o easter egg na tela por uns segundos
                center.clicks++; clickReset.restart()
                // Easter egg escondido: 6 cliques seguidos
                if (center.clicks >= 6) { center.clicks = 0; fade.target_text = "Para de clicar e vai codar. :)"; eggHold.start() }
                fade.restart()
            }
            onClicked: hit()
            onDoubleClicked: hit()   // cliques rápidos viram duplo clique no Qt: contam também
        }
        Timer { id: eggHold; interval: 4000 }
        SequentialAnimation {
            id: fade
            property string target_text: ""
            NumberAnimation { target: phrase; property: "opacity"; to: 0; duration: 140 }
            ScriptAction { script: { if (fade.target_text) { center.current = fade.target_text; fade.target_text = "" } else center.next() } }
            NumberAnimation { target: phrase; property: "opacity"; to: 1; duration: 180 }
        }
    }

    // ------------------------------------------------ quick actions
    property bool nightOn: false
    property int nightTemp: 6000
    property bool dndOn: false
    property bool gameOn: false
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"

    // Estado dos toggles a cada 2 s
    Process {
        id: stateProc
        // Cada valor sai rotulado (chave=valor) para não depender da ordem das linhas
        command: ["sh", "-c",
            "echo night=$($HOME/.config/hypr/scripts/nightlight.sh status);" +
            "echo dnd=$(swaync-client -D 2>/dev/null);" +
            "echo game=$(hyprctl repl 'return tostring(GAMEMODE)' 2>/dev/null | tr -d '[:space:]');" +
            "echo temp=$(hyprctl hyprsunset temperature 2>/dev/null | grep -oE '[0-9]+' | head -1)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {}
                for (const line of this.text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) v[line.slice(0, i)] = line.slice(i + 1).trim()
                }
                center.nightOn = v.night === "1"
                center.dndOn = v.dnd === "true"
                center.gameOn = v.game === "true"
                center.nightTemp = parseInt(v.temp) || 6000
            }
        }
    }
    Timer { interval: 2000; running: center.visible; repeat: true; triggeredOnStart: true; onTriggered: stateProc.running = true }
    function refreshSoon() { refresh.restart() }
    Timer { id: refresh; interval: 400; onTriggered: stateProc.running = true }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        Repeater {
            model: [
                { label: "projetos",     on: false,          cmd: [center.scripts + "/projects.sh"] },
                { label: "senhas",       on: false,          cmd: [center.scripts + "/bitwarden.sh"] },
                { label: "print",        on: false,          cmd: [center.scripts + "/screenshot.sh", "area"] },
                { label: center.nightOn ? "luz noturna " + center.nightTemp + "K" : "luz noturna", on: center.nightOn, cmd: [center.scripts + "/nightlight.sh", "toggle"] },
                { label: "não perturbe", on: center.dndOn,   cmd: ["swaync-client", "-d", "-sw"] },
                { label: "game mode",    on: center.gameOn,  cmd: ["hyprctl", "repl", "GameModeToggle()"] },
                { label: "bloquear",     on: false,          cmd: ["sh", "-c", "pidof hyprlock || hyprlock"] }
            ]
            delegate: Row {
                required property var modelData
                required property int index

                Text {
                    visible: index > 0
                    text: "  ·  "
                    color: Theme.line; font.family: Theme.mono; font.pixelSize: 12
                }
                Text {
                    text: modelData.label
                    color: modelData.on ? Theme.signal : (qa.containsMouse ? Theme.bone : Theme.statik)
                    font.family: Theme.mono
                    font.pixelSize: 12
                    font.letterSpacing: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    // Sublinhado lima no hover
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.bottom; topMargin: 3 }
                        height: 1
                        color: Theme.signal
                        opacity: qa.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: qa
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Quickshell.execDetached(modelData.cmd); center.refreshSoon() }
                    }
                }
            }
        }
    }
}
