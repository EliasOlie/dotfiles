import QtQuick
import Quickshell
import Quickshell.Io

// Topo-centro do desktop: quick actions ("+ ⌄"). A frase mora em Phrase.qml.
Column {
    id: center
    spacing: 22

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

    // Botão "+ ⌄": passou o mouse (ou clicou), abre os badges; saiu da área, fecha
    Item {
        id: qaArea
        anchors.horizontalCenter: parent.horizontalCenter
        property bool open: false
        width: Math.max(trigger.width, actions.implicitWidth)
        height: trigger.height + (open ? actions.implicitHeight + 12 : 0)
        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        HoverHandler {
            onHoveredChanged: hovered ? closeTimer.stop() : closeTimer.restart()
        }
        Timer { id: closeTimer; interval: 260; onTriggered: qaArea.open = false }

        Badge {
            id: trigger
            anchors.horizontalCenter: parent.horizontalCenter
            text: "+"
            on: qaArea.open
            implicitWidth: 64
            onHoveredChanged: if (hovered) { qaArea.open = true; closeTimer.stop() }
            onClicked: qaArea.open = !qaArea.open
            label.text: qaArea.open ? "+  \uf077" : "+  \uf078"   // chevron vira pra cima quando aberto
        }

        Row {
            id: actions
            anchors { horizontalCenter: parent.horizontalCenter; top: trigger.bottom; topMargin: 12 }
            spacing: 8
            opacity: qaArea.open ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            transform: Translate { y: qaArea.open ? 0 : -6; Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }

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
                delegate: Badge {
                    required property var modelData
                    text: modelData.label
                    on: modelData.on
                    onClicked: { Quickshell.execDetached(modelData.cmd); center.refreshSoon() }
                }
            }
        }
    }
}
