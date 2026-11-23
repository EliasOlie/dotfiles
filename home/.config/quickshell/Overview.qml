import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Visão geral (Super+O no monitor em foco · Super+Ctrl+O em todos): cada
// workspace com janelas deste monitor vira uma miniatura do monitor, com as
// janelas na posição real e com a imagem delas (inclusive maximizadas, tela
// cheia e flutuantes). Workspaces especiais (ex.: terminal suspenso) aparecem
// em "ESCONDIDAS". Clique na janela: vai pra ela · clique no workspace: vai
// pro workspace · Esc ou clique fora: fecha.
PanelWindow {
    id: ov
    required property var modelData
    screen: modelData

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "eliasolie-overview"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    visible: shown || root.opacity > 0.01

    readonly property string mon: modelData.name
    readonly property bool shown: OverviewState.isOpen(mon)
    readonly property var hmon: Hyprland.monitorFor(modelData)
    onShownChanged: if (shown) keys.forceActiveFocus()

    function hypr(cmd) { Quickshell.execDetached(["hyprctl", "dispatch", cmd]) }
    function focusWindow(t) {
        OverviewState.closeAll()
        const a = String(t.address)
        hypr('hl.dsp.focus({ window = "address:' + (a.startsWith("0x") ? a : "0x" + a) + '" })')
    }
    function goWorkspace(ws) {
        OverviewState.closeAll()
        if (ws.id < 0) hypr('hl.dsp.workspace.toggle_special("' + ws.name.replace("special:", "") + '")')
        else hypr("hl.dsp.focus({ workspace = " + ws.id + ", on_current_monitor = true })")
    }

    // Workspaces deste monitor com janelas (+ o ativo), em ordem; e os especiais
    readonly property var normal: shown ? Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor && w.monitor.name === mon
                && (w.toplevels.values.length > 0 || (hmon && hmon.activeWorkspace === w)))
        .sort((a, b) => a.id - b.id) : []
    readonly property var special: shown ? Hyprland.workspaces.values
        .filter(w => w.id < 0 && w.toplevels.values.length > 0
                && (!w.monitor || w.monitor.name === mon || Hyprland.focusedMonitor === hmon)) : []
    readonly property var all: normal.concat(special)

    // Grade: até 3 por linha, miniaturas na proporção do monitor
    readonly property int gap: 28
    readonly property int cols: Math.max(1, Math.min(3, all.length))
    readonly property real aspect: modelData.height / modelData.width
    readonly property real boxW: Math.min(560, (width - 2 * 96 - (cols - 1) * gap) / cols)
    readonly property real boxH: boxW * aspect

    Item {
        id: root
        anchors.fill: parent
        opacity: ov.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: OverviewState.closeAll()
        }

        // fundo: void quase opaco; clique fora fecha
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Theme.void_, 0.9)
            MouseArea { anchors.fill: parent; onClicked: OverviewState.closeAll() }
        }

        Column {
            anchors.centerIn: parent
            spacing: 26
            scale: ov.shown ? 1 : 0.97
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            // título
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Text { text: "\u{f0570}"; color: Theme.signal; font.family: Theme.mono; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "VISÃO GERAL"
                    color: Theme.bone
                    font.family: Theme.sans; font.pixelSize: 24; font.weight: Font.ExtraBold
                    font.variableAxes: { "wdth": 85 }
                }
                Text {
                    anchors.baseline: parent.children[1].baseline
                    text: ov.mon + "  ·  " + ov.all.reduce((n, w) => n + w.toplevels.values.length, 0) + " JANELAS"
                    color: Theme.statik; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 2
                }
            }

            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: ov.cols
                spacing: ov.gap

                Repeater {
                    model: ov.all
                    delegate: Column {
                        id: wsBox
                        required property var modelData
                        readonly property var ws: modelData
                        readonly property bool isSpecial: ws.id < 0
                        readonly property bool active: !isSpecial && ov.hmon && ov.hmon.activeWorkspace === ws
                        readonly property var wins: ws.toplevels.values.slice().sort((a, b) =>
                            ((a.lastIpcObject || {}).floating ? 1 : 0) - ((b.lastIpcObject || {}).floating ? 1 : 0))
                        // janela maximizada/tela cheia esconde as outras ("colapsadas"): aí as
                        // janelas são espalhadas lado a lado para todas aparecerem
                        readonly property bool spread: wins.length > 1 && wins.some(t => ((t.lastIpcObject || {}).fullscreen || 0) > 0)
                        readonly property int sCols: Math.ceil(Math.sqrt(wins.length))
                        readonly property int sRows: Math.ceil(wins.length / Math.max(1, sCols))
                        spacing: 8

                        // rótulo: número como na waybar (1..0) ou ESCONDIDAS
                        Row {
                            spacing: 8
                            Rectangle { width: 7; height: 7; anchors.verticalCenter: parent.verticalCenter
                                color: wsBox.active ? Theme.signal : wsBox.isSpecial ? Theme.warn : Theme.statik }
                            Text {
                                text: wsBox.isSpecial ? "ESCONDIDAS · " + wsBox.ws.name.replace("special:", "").toUpperCase()
                                                      : "WORKSPACE " + ((wsBox.ws.id - 1) % 10 + 1 === 10 ? 0 : (wsBox.ws.id - 1) % 10 + 1)
                                color: wsBox.active ? Theme.signal : Theme.statik
                                font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 3
                            }
                        }

                        // miniatura do monitor
                        Rectangle {
                            id: mini
                            width: ov.boxW; height: ov.boxH
                            color: Theme.void_
                            border.width: 2
                            border.color: wsBox.active ? Theme.signal : wsMouse.containsMouse ? Theme.bone : Theme.line
                            clip: true
                            readonly property real k: width / ov.modelData.width

                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ov.goWorkspace(wsBox.ws)
                            }

                            // janelas na posição real (flutuantes por cima)
                            Repeater {
                                model: wsBox.wins
                                delegate: Rectangle {
                                    id: win
                                    required property var modelData
                                    required property int index
                                    readonly property var ipc: modelData.lastIpcObject || {}
                                    readonly property var at: ipc.at || [ov.modelData.x, ov.modelData.y]
                                    readonly property var sz: ipc.size || [ov.modelData.width, ov.modelData.height]
                                    // espalhado: grade dentro da miniatura · normal: posição real
                                    readonly property real cw: (mini.width - 8) / wsBox.sCols
                                    readonly property real ch: (mini.height - 8) / wsBox.sRows
                                    x: wsBox.spread ? 4 + (index % wsBox.sCols) * cw + 3 : Math.max(0, (at[0] - ov.modelData.x) * mini.k)
                                    y: wsBox.spread ? 4 + Math.floor(index / wsBox.sCols) * ch + 3 : Math.max(0, (at[1] - ov.modelData.y) * mini.k)
                                    width: wsBox.spread ? cw - 6 : Math.min(mini.width, sz[0] * mini.k)
                                    height: wsBox.spread ? ch - 6 : Math.min(mini.height, sz[1] * mini.k)
                                    color: Theme.graphite
                                    border.width: winMouse.containsMouse ? 2 : 1
                                    border.color: winMouse.containsMouse ? Theme.signal : Theme.line

                                    // imagem da janela (capturada uma vez ao abrir)
                                    ScreencopyView {
                                        anchors { fill: parent; margins: 1; bottomMargin: 20 }
                                        captureSource: ov.shown ? win.modelData.wayland : null
                                        live: false
                                    }
                                    // nome do app embaixo
                                    Rectangle {
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                        height: 20
                                        color: Qt.alpha(Theme.void_, 0.82)
                                        Text {
                                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                            text: (win.ipc.class || "") + (win.modelData.title ? "  ·  " + win.modelData.title : "")
                                            color: winMouse.containsMouse ? Theme.signal : Theme.bone
                                            font.family: Theme.mono; font.pixelSize: 10
                                        }
                                    }
                                    MouseArea {
                                        id: winMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ov.focusWindow(win.modelData)
                                    }
                                }
                            }

                            Text {
                                visible: wsBox.ws.toplevels.values.length === 0
                                anchors.centerIn: parent
                                text: "vazio"
                                color: Qt.alpha(Theme.statik, 0.6); font.family: Theme.mono; font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "clique na janela: vai pra ela  ·  clique no workspace: vai pra ele  ·  esc fecha"
                color: Qt.alpha(Theme.statik, 0.75); font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
        }
    }
}
