import QtQuick
import Quickshell
import Quickshell.Io

// Centro do desktop: frase do dia (clique troca) + quick actions
Column {
    id: center
    spacing: 22

    // ------------------------------------------------ frases
    readonly property var phrases: [
        "funciona na minha máquina.",
        "não é bug, é feature.",
        "sexta-feira não se faz deploy.",
        "git push --force e fé.",
        "já tentou desligar e ligar de novo?",
        "sempre é o DNS.",
        "rm -rf node_modules resolve 80% da vida.",
        "TODO: refatorar (escrito em 2019).",
        "produção é o melhor ambiente de testes.",
        "café entra, código sai.",
        "commit: \"ajustes\".",
        "o código é autoexplicativo. (não é.)",
        "99 bugs no código. corrigi um. 127 bugs no código.",
        "se compilou, tá pronto.",
        "a estimativa era 2 horas.",
        "quem escreveu isso? ah. fui eu."
    ]
    // Uma por dia; clique avança
    property int idx: Math.floor((Date.now() - new Date(new Date().getFullYear(), 0, 0)) / 86400000) % phrases.length

    Text {
        id: phrase
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.StyledText
        text: "<font color='" + Theme.signal + "'>//</font> " + center.phrases[center.idx]
        color: phraseMouse.containsMouse ? Theme.bone : Qt.alpha(Theme.bone, 0.82)
        font.family: Theme.sans
        font.pixelSize: 30
        font.weight: Font.Medium
        font.variableAxes: { "wdth": 85 }
        Behavior on color { ColorAnimation { duration: 150 } }

        MouseArea {
            id: phraseMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { fade.restart() }
        }
        SequentialAnimation {
            id: fade
            NumberAnimation { target: phrase; property: "opacity"; to: 0; duration: 120 }
            ScriptAction { script: center.idx = (center.idx + 1) % center.phrases.length }
            NumberAnimation { target: phrase; property: "opacity"; to: 1; duration: 160 }
        }
    }

    // ------------------------------------------------ quick actions
    property bool nightOn: false
    property bool dndOn: false
    property bool gameOn: false
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"

    // Estado dos toggles a cada 2 s
    Process {
        id: stateProc
        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && echo 1 || echo 0; swaync-client -D 2>/dev/null || echo false; hyprctl repl 'return tostring(GAMEMODE)' 2>/dev/null || echo false"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n")
                center.nightOn = l[0] === "1"
                center.dndOn = (l[1] || "").trim() === "true"
                center.gameOn = (l[2] || "").trim() === "true"
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
                { label: "luz noturna",  on: center.nightOn, cmd: ["sh", "-c", "pkill -x hyprsunset || hyprsunset -t 4500"] },
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
