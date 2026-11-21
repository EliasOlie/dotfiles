import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris

// Widgets do desktop: ficam sobre o wallpaper, abaixo das janelas,
// e só aparecem quando o workspace do monitor está vazio.
PanelWindow {
    id: desk
    required property var modelData
    screen: modelData

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "eliasolie-desktop"

    readonly property var hmon: Hyprland.monitorFor(modelData)
    readonly property bool empty: !hmon || !hmon.activeWorkspace || hmon.activeWorkspace.toplevels.values.length === 0
    readonly property int edge: 56

    Item {
        id: content
        anchors.fill: parent
        opacity: desk.empty ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // Informa a posição do mouse ao wallpaper vivo (os pontos acendem perto do cursor)
        HoverHandler {
            onPointChanged: { Pointer.screen = desk.modelData.name; Pointer.x = point.position.x; Pointer.y = point.position.y }
            onHoveredChanged: { Pointer.screen = desk.modelData.name; Pointer.inside = hovered }
        }

        // =============================================== TOPO-CENTRO: frase do dia + quick actions
        CenterPiece {
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 96 }
            visible: content.visible
        }

        // =============================================== TOPO-ESQUERDO: atalhos
        ShortcutsPanel {
            anchors { left: parent.left; top: parent.top; leftMargin: desk.edge; topMargin: desk.edge }
        }

        // =============================================== ESQUERDA: relógio
        Column {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: desk.edge; bottomMargin: desk.edge - 20 }
            spacing: 18

            // Relógio grande (Archivo 62% / 800, igual ao manual)
            Text {
                id: clock
                text: Qt.formatTime(sysClock.date, "HH:mm")
                color: Theme.bone
                font.family: Theme.sans
                font.pixelSize: 168
                font.weight: Font.ExtraBold
                font.variableAxes: { "wdth": 62 }
                lineHeight: 0.8
                SystemClock { id: sysClock; precision: SystemClock.Minutes }
            }
            Row {
                spacing: 12
                Rectangle { width: 8; height: 8; color: Theme.signal; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: Qt.locale("pt_BR").toString(sysClock.date, "dddd, d 'de' MMMM").toUpperCase()
                    color: Theme.statik; font.family: Theme.mono; font.pixelSize: 13; font.letterSpacing: 3
                }
                // Clima (Serra Talhada) na mesma linha, separado por pipe
                Text {
                    visible: Weather.ok
                    text: "|"
                    color: Theme.line; font.family: Theme.mono; font.pixelSize: 13
                }
                Text {
                    visible: Weather.ok
                    text: Weather.glyph
                    color: Theme.signal; font.family: Theme.mono; font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    visible: Weather.ok
                    text: (Weather.temp + "° " + Weather.desc + "  " + Weather.max + "°/" + Weather.min + "°").toUpperCase()
                    color: Theme.statik; font.family: Theme.mono; font.pixelSize: 13; font.letterSpacing: 3
                }
            }
        }

        // =============================================== RODAPÉ-CENTRO: status da VPS
        // Discreto: "● nome | ● nome" — lima no ar, coral fora. Clique abre o Dokploy.
        Item {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: desk.edge - 20 }
            width: vpsRow.implicitWidth; height: vpsRow.implicitHeight
        Row {
            id: vpsRow
            spacing: 12
            Repeater {
                model: VpsStatus.services
                delegate: Row {
                    required property var modelData
                    required property int index
                    spacing: 12
                    Text {
                        visible: index > 0
                        text: "|"
                        color: Theme.line; font.family: Theme.mono; font.pixelSize: 12
                    }
                    Rectangle {
                        width: 7; height: 7
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.up ? Theme.signal : Theme.alert
                    }
                    Text {
                        text: modelData.name.toUpperCase()
                        color: modelData.up ? (vpsMouse.containsMouse ? Theme.bone : Theme.statik) : Theme.alert
                        font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 2
                    }
                }
            }
            // Backup (restic): "| ■ BACKUP 22H"
            Text {
                visible: VpsStatus.services.length > 0
                text: "|"
                color: Theme.line; font.family: Theme.mono; font.pixelSize: 12
            }
            Rectangle {
                width: 7; height: 7
                anchors.verticalCenter: parent.verticalCenter
                color: BackupStatus.fresh ? Theme.signal : Theme.alert
            }
            Text {
                text: "BACKUP " + BackupStatus.age.toUpperCase()
                color: BackupStatus.fresh ? Theme.statik : Theme.alert
                font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 2
            }
        }
            MouseArea {
                id: vpsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (VpsStatus.panel) Quickshell.execDetached(["brave", VpsStatus.panel])
            }
        }

        // =============================================== DIREITA: agenda, mídia, sistema
        ColumnLayout {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: desk.edge; bottomMargin: desk.edge }
            width: 380
            spacing: 10

            // ---------- AGENDA
            // Contrato: ~/.local/share/eliasolie/agenda.json
            //   [{ "title": "...", "start": "ISO-8601", "end": "ISO-8601", "where": "..." }]
            Card {
                id: agenda
                label: "AGENDA"
                title: "PRÓXIMOS EVENTOS"
                glyph: "\u{f00ed}"
                Layout.fillWidth: true
                Layout.preferredHeight: headerHeight + pad * 2 + Math.max(1, events.length) * 24

                property var events: []
                property bool hasFile: false

                FileView {
                    id: agendaFile
                    path: Quickshell.env("HOME") + "/.local/share/eliasolie/agenda.json"
                    watchChanges: true
                    printErrors: false
                    onFileChanged: reload()
                    onLoaded: {
                        agenda.hasFile = true
                        try {
                            const now = new Date()
                            agenda.events = JSON.parse(text())
                                .map(e => Object.assign({}, e, { _s: new Date(e.start), _e: new Date(e.end || e.start) }))
                                .filter(e => e._e >= now)
                                .sort((a, b) => a._s - b._s)
                                .slice(0, 4)
                        } catch (err) { agenda.events = [] }
                    }
                    onLoadFailed: agenda.hasFile = false
                }
                Timer { interval: 60000; running: true; repeat: true; onTriggered: agendaFile.reload() }

                Column {
                    anchors.fill: parent
                    spacing: 6
                    Repeater {
                        model: agenda.events
                        delegate: Row {
                            required property var modelData
                            readonly property bool today: modelData._s.toDateString() === new Date().toDateString()
                            width: parent.width
                            spacing: 12
                            Text {
                                width: 48
                                text: today ? Qt.formatTime(modelData._s, "HH:mm") : Qt.formatDate(modelData._s, "dd/MM")
                                color: Theme.signal; font.family: Theme.mono; font.pixelSize: 12
                            }
                            Text {
                                width: parent.width - 60; elide: Text.ElideRight
                                text: modelData.title + (modelData.where ? "  · " + modelData.where : "")
                                color: Theme.bone; font.family: Theme.mono; font.pixelSize: 12
                            }
                        }
                    }
                    Text {
                        visible: agenda.events.length === 0
                        text: agenda.hasFile ? "nada pela frente" : "em breve"
                        color: Qt.alpha(Theme.statik, 0.6); font.family: Theme.mono; font.pixelSize: 12
                    }
                }
            }

            // ---------- MÍDIA (só aparece se algo estiver tocando/pausado)
            Card {
                id: media
                label: "MÍDIA"
                title: "TOCANDO AGORA"
                glyph: "\u{f075a}"
                Layout.fillWidth: true
                Layout.preferredHeight: headerHeight + pad * 2 + 70
                visible: player !== null

                readonly property var players: Mpris.players.values
                readonly property var player: players.find(p => p.isPlaying) || players[0] || null

                Row {
                    anchors.fill: parent
                    spacing: 12
                    Image {
                        id: art
                        width: 52; height: 52
                        source: media.player ? media.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(104, 104)
                        visible: status === Image.Ready
                    }
                    Column {
                        width: parent.width - (art.visible ? 64 : 0)
                        spacing: 2
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: media.player ? (media.player.trackTitle || media.player.identity) : ""
                            color: Theme.bone; font.family: Theme.sans; font.pixelSize: 13; font.weight: Font.Bold
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: media.player ? (media.player.trackArtist || media.player.identity) : ""
                            color: Theme.statik; font.family: Theme.mono; font.pixelSize: 11
                        }
                        Row {
                            spacing: 2
                            topPadding: 2
                            Repeater {
                                model: [
                                    { icon: "󰒮", run: () => media.player.previous(), ok: () => media.player && media.player.canGoPrevious },
                                    { icon: media.player && media.player.isPlaying ? "󰏤" : "󰐊", run: () => media.player.togglePlaying(), ok: () => media.player && media.player.canTogglePlaying },
                                    { icon: "󰒭", run: () => media.player.next(), ok: () => media.player && media.player.canGoNext }
                                ]
                                delegate: Text {
                                    required property var modelData
                                    width: 30; height: 22
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    text: modelData.icon
                                    color: btn.containsMouse && modelData.ok() ? Theme.signal : (modelData.ok() ? Theme.bone : Theme.line)
                                    font.family: Theme.mono; font.pixelSize: 16
                                    MouseArea { id: btn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (modelData.ok()) modelData.run() }
                                }
                            }
                        }
                    }
                }
            }

            // ---------- SISTEMA (clique abre o htop)
            Card {
                label: "SISTEMA"
                title: "RECURSOS"
                glyph: "\u{f035b}"
                Layout.fillWidth: true
                Layout.preferredHeight: headerHeight + pad * 2 + 70

                Grid {
                    anchors.fill: parent
                    columns: 3
                    columnSpacing: 22
                    rowSpacing: 8
                    Meter { width: 96; label: "cpu";   value: SysStats.cpu }
                    Meter { width: 96; label: "ram";   value: SysStats.ram }
                    Meter { width: 96; label: "temp";  value: SysStats.temp; unit: "°" }
                    Meter { width: 96; label: "gpu";   value: SysStats.gpu }
                    Meter { width: 96; label: "disco"; value: SysStats.disk; warnAt: 90 }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["kitty", "--class", "sysmon", "-e", "htop"])
                }
            }
        }
    }
}
