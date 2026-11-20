import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

// Painéis do rodapé: apps · mídia · agenda · sistema
PanelWindow {
    id: panel
    required property var modelData
    screen: modelData

    anchors { left: true; right: true; bottom: true }
    margins { left: Theme.gap; right: Theme.gap; bottom: Theme.gap }
    implicitHeight: Theme.panelHeight
    exclusiveZone: Theme.panelHeight
    color: "transparent"
    WlrLayershell.namespace: "eliasolie-panels"
    WlrLayershell.layer: WlrLayer.Top

    RowLayout {
        anchors.fill: parent
        spacing: Theme.gap

        // ---------------------------------------------------- APPS
        Card {
            title: "APPS"
            Layout.fillHeight: true
            Layout.preferredWidth: appsRow.implicitWidth + 24

            Row {
                id: appsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Fixados primeiro, depois os abertos que não estão fixados
                readonly property var pinned: ["kitty", "brave-browser", "org.kde.dolphin"]
                readonly property var running: ToplevelManager.toplevels.values
                readonly property var ids: {
                    const out = pinned.slice()
                    for (const t of running) if (t.appId && !out.includes(t.appId)) out.push(t.appId)
                    return out
                }

                Repeater {
                    model: appsRow.ids
                    delegate: Item {
                        id: app
                        required property string modelData
                        readonly property var entry: DesktopEntries.heuristicLookup(modelData)
                        readonly property var wins: appsRow.running.filter(t => t.appId === modelData)
                        readonly property bool active: wins.some(t => t.activated)
                        width: 30; height: 30

                        Rectangle {
                            anchors.fill: parent
                            color: appMouse.containsMouse ? Theme.graphite : "transparent"
                        }
                        Image {
                            anchors.centerIn: parent
                            width: 20; height: 20
                            sourceSize: Qt.size(40, 40)
                            source: Quickshell.iconPath(app.entry ? app.entry.icon : app.modelData, "application-x-executable")
                            opacity: app.wins.length > 0 || appMouse.containsMouse ? 1 : 0.55
                        }
                        // Indicador: aberto = traço curto, ativo = traço longo lima
                        Rectangle {
                            visible: app.wins.length > 0
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            height: 2
                            width: app.active ? 18 : 6
                            color: app.active ? Theme.signal : Theme.statik
                            Behavior on width { NumberAnimation { duration: 150 } }
                        }
                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                // Esquerdo: foca (ou abre). Meio: sempre abre uma nova janela.
                                if (mouse.button === Qt.LeftButton && app.wins.length > 0) {
                                    const i = app.wins.findIndex(t => t.activated)
                                    app.wins[(i + 1) % app.wins.length].activate()
                                } else if (app.entry) {
                                    app.entry.execute()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------- MÍDIA
        Card {
            id: media
            title: "MÍDIA"
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: 260

            readonly property var players: Mpris.players.values
            readonly property var player: players.find(p => p.isPlaying) || players[0] || null

            Row {
                anchors.fill: parent
                spacing: 10
                visible: media.player !== null

                Image {
                    width: 30; height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    source: media.player ? media.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    sourceSize: Qt.size(60, 60)
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30 - 110 - 20
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: media.player ? (media.player.trackTitle || media.player.identity) : ""
                        color: Theme.bone; font.family: Theme.sans; font.pixelSize: 12; font.weight: Font.Bold
                    }
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: media.player ? (media.player.trackArtist || media.player.identity) : ""
                        color: Theme.statik; font.family: Theme.mono; font.pixelSize: 10
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: [
                            { icon: "󰒮", run: () => media.player.previous(), ok: () => media.player && media.player.canGoPrevious },
                            { icon: media.player && media.player.isPlaying ? "󰏤" : "󰐊", run: () => media.player.togglePlaying(), ok: () => media.player && media.player.canTogglePlaying },
                            { icon: "󰒭", run: () => media.player.next(), ok: () => media.player && media.player.canGoNext }
                        ]
                        delegate: Text {
                            required property var modelData
                            width: 34; height: 30
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: modelData.icon
                            color: btn.containsMouse ? Theme.signal : (modelData.ok() ? Theme.bone : Theme.line)
                            font.family: Theme.mono; font.pixelSize: 16
                            MouseArea { id: btn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (modelData.ok()) modelData.run() }
                        }
                    }
                }
            }

            Text {
                visible: media.player === null
                anchors.verticalCenter: parent.verticalCenter
                text: "nada tocando"
                color: Theme.line; font.family: Theme.mono; font.pixelSize: 11
            }
        }

        // ---------------------------------------------------- AGENDA
        // Contrato: ~/.local/share/eliasolie/agenda.json
        //   [{ "title": "Reunião", "start": "2026-11-21T14:00:00-03:00", "end": "...", "where": "..." }]
        // Qualquer sistema que escrever esse arquivo aparece aqui (atualiza sozinho).
        Card {
            id: agenda
            title: "AGENDA"
            Layout.fillHeight: true
            Layout.preferredWidth: 340

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
                            .slice(0, 2)
                    } catch (err) { agenda.events = [] }
                }
                onLoadFailed: agenda.hasFile = false
            }
            Timer { interval: 60000; running: true; repeat: true; onTriggered: agendaFile.reload() }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 2
                Repeater {
                    model: agenda.events
                    delegate: Row {
                        required property var modelData
                        spacing: 10
                        width: parent.width
                        readonly property bool today: modelData._s.toDateString() === new Date().toDateString()
                        Text {
                            width: 44
                            text: today ? Qt.formatTime(modelData._s, "HH:mm") : Qt.formatDate(modelData._s, "dd/MM")
                            color: Theme.signal; font.family: Theme.mono; font.pixelSize: 11
                        }
                        Text {
                            width: parent.width - 54; elide: Text.ElideRight
                            text: modelData.title + (modelData.where ? "  · " + modelData.where : "")
                            color: Theme.bone; font.family: Theme.mono; font.pixelSize: 11
                        }
                    }
                }
                Text {
                    visible: agenda.events.length === 0
                    text: agenda.hasFile ? "nada pela frente" : "em breve"
                    color: Theme.line; font.family: Theme.mono; font.pixelSize: 11
                }
            }
        }

        // ---------------------------------------------------- SISTEMA
        Card {
            title: "SISTEMA"
            Layout.fillHeight: true
            Layout.preferredWidth: sysRow.implicitWidth + 24

            Row {
                id: sysRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
                Meter { label: "cpu";  value: SysStats.cpu }
                Meter { label: "ram";  value: SysStats.ram }
                Meter { label: "temp"; value: SysStats.temp; unit: "°" }
                Meter { label: "gpu";  value: SysStats.gpu }
                Meter { label: "disco"; value: SysStats.disk; warnAt: 90 }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["kitty", "--class", "sysmon", "-e", "htop"])
            }
        }
    }
}
