import QtQuick
import Quickshell
import Quickshell.Io

// Frase do dia, discreta no canto superior direito do desktop.
// Troca sozinha e no clique; 6 cliques rápidos = easter egg.
Item {
    id: center
    implicitWidth: phrase.implicitWidth
    implicitHeight: phrase.implicitHeight

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
        anchors.right: parent.right
        textFormat: Text.StyledText
        text: "<font color='" + Theme.signal + "'>//</font> " + center.esc(center.current)
        color: phraseMouse.containsMouse ? Theme.bone : Qt.alpha(Theme.statik, 0.75)
        font.family: Theme.sans
        font.pixelSize: 15
        font.weight: Font.Medium
        font.variableAxes: { "wdth": 85 }
        Behavior on color { ColorAnimation { duration: 150 } }

        MouseArea {
            id: phraseMouse
            // Área de clique larga e fixa: a frase muda de largura a cada troca,
            // então clicando rápido o mouse não "cai fora" da frase nova
            // (alinhada à direita: a frase cresce para a esquerda, então a área vai bem para a esquerda)
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: -10; bottomMargin: -10 }
            width: 620
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
}
