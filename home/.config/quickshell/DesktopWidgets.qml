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
    // Vazio = workspace ativo sem janelas (sem dados do Hyprland ainda, não conta como vazio:
    // senão a entrada em cascata rodaria escondida no instante em que o qs inicia)
    readonly property bool empty: !!hmon && !!hmon.activeWorkspace && hmon.activeWorkspace.toplevels.values.length === 0
    readonly property int edge: 56

    // Modo compacto (Super+Alt+D, por monitor; o modo foco compacta todos): esconde atalhos e
    // painéis da direita; no lugar ficam etiquetas "+ ⌄" que abrem o bloco ao passar o mouse.
    // O alfinete (canto do bloco aberto) fixa o bloco aberto.
    readonly property string mon: modelData.name
    readonly property bool compact: DeskState.isCompact(mon) || DeskState.focus
    readonly property bool bigAgenda: DeskState.agendaOpen(mon)
    readonly property bool pinLeft: DeskState.pinned(mon, "left")
    readonly property bool pinRight: DeskState.pinned(mon, "right")
    property bool peekLeft: false
    property bool peekRight: false
    readonly property bool showLeft: !compact || peekLeft || pinLeft
    readonly property bool showRight: (!compact && !bigAgenda) || peekRight || pinRight
    onCompactChanged: { peekLeft = false; peekRight = false }
    // Fecha só se o mouse não estiver na etiqueta, no bloco nem no alfinete (evita piscar)
    Timer { id: closeLeft;  interval: 260; onTriggered: if (!leftTag.hovered && !leftHover.hovered && !leftPin.hovered) desk.peekLeft = false }
    Timer { id: closeRight; interval: 260; onTriggered: if (!rightTag.hovered && !rightHover.hovered && !rightPin.hovered) desk.peekRight = false }

    // ------------------------------------------------ voo do relógio
    // Entrando no desktop: o relógio sai do centro da waybar e cresce até o canto;
    // saindo: encolhe e volta para a barra (por cima das janelas, numa camada Overlay).
    property bool flying: false
    onEmptyChanged: {
        if (!settled) return                       // dados do Hyprland ainda chegando
        if (empty && !introDone) startIntro()
        else flight.fly(empty)
    }

    // ------------------------------------------------ entrada em cascata (login)
    // Na primeira vez que o desktop aparece: o relógio voa da barra e os blocos
    // entram um por um (atalhos, quick actions, frase, data, status, painéis).
    // Espera ~1 s ao iniciar: logo no começo o Hyprland ainda não listou as janelas
    // e todo workspace parece vazio (a cascata rodaria escondida).
    property int intro: 0
    property bool introDone: false
    property bool settled: false
    function stage(n) { return desk.intro >= n ? 1 : 0 }
    function startIntro() { desk.intro = 0; flight.fly(true); desk.intro = 1; introTick.start() }
    Timer {
        id: introTick; interval: 110; repeat: true
        onTriggered: { desk.intro++; if (desk.intro >= 6) { stop(); desk.introDone = true } }
    }
    Timer {
        interval: 1000; running: true
        onTriggered: { desk.settled = true; if (desk.empty) desk.startIntro() }
    }

    PanelWindow {
        id: flight
        screen: desk.modelData
        anchors { left: true; right: true; top: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "eliasolie-clock-flight"
        mask: Region {}                      // não pega cliques
        visible: desk.flying

        readonly property real small: 13 / 168      // relógio da waybar (Archivo 12px bold)
        function fly(toDesk) {
            const big = clock.mapToItem(content, 0, 0)
            const sx = desk.width / 2 - ft.width * small / 2, sy = 14 - ft.height * small / 2
            anim.stop()
            fromX.value = toDesk ? sx : big.x;   toX.value = toDesk ? big.x : sx
            fromY.value = toDesk ? sy : big.y;   toY.value = toDesk ? big.y : sy
            fromS.value = toDesk ? small : 1;    toS.value = toDesk ? 1 : small
            anim.easing = toDesk ? Easing.OutCubic : Easing.InOutCubic
            desk.flying = true
            anim.start()
        }

        Text {
            id: ft
            text: clock.text
            color: Theme.bone
            font: clock.font
            lineHeight: 0.8
            transformOrigin: Item.TopLeft
        }
        ParallelAnimation {
            id: anim
            property int easing: Easing.OutCubic
            onFinished: desk.flying = false
            NumberAnimation { id: fromX; property real value; target: ft; property: "x"; from: fromX.value; to: toX.value; duration: 420; easing.type: anim.easing }
            NumberAnimation { id: fromY; property real value; target: ft; property: "y"; from: fromY.value; to: toY.value; duration: 420; easing.type: anim.easing }
            NumberAnimation { id: fromS; property real value; target: ft; property: "scale"; from: fromS.value; to: toS.value; duration: 420; easing.type: anim.easing }
        }
        QtObject { id: toX; property real value }
        QtObject { id: toY; property real value }
        QtObject { id: toS; property real value }
    }

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
        // Clique no fundo do desktop: onda nos pontos do wallpaper
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: mouse => Pointer.ripple(desk.mon, mouse.x, mouse.y)
        }

        // =============================================== TOPO-CENTRO: quick actions
        CenterPiece {
            monitor: desk.mon
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: desk.edge }
            visible: content.visible
            opacity: desk.stage(2)
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            transform: Translate { y: desk.intro >= 2 ? 0 : 12; Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } } }
        }

        // =============================================== TOPO-DIREITO: frase do dia (discreta)
        Phrase {
            anchors { right: parent.right; top: parent.top; rightMargin: desk.edge; topMargin: desk.edge + 6 }
            opacity: desk.stage(3)
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            transform: Translate { y: desk.intro >= 3 ? 0 : 12; Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } } }
        }

        // =============================================== TOPO-ESQUERDO: atalhos
        Badge {
            id: leftTag
            anchors { left: parent.left; top: parent.top; leftMargin: desk.edge; topMargin: desk.edge }
            text: "atalhos"
            label.text: "+  ATALHOS  \uf078"
            opacity: (desk.compact ? 1 : 0) * desk.stage(1)    // fica por baixo do bloco aberto
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            onHoveredChanged: hovered ? (desk.peekLeft = true, closeLeft.stop()) : closeLeft.restart()
            onClicked: desk.peekLeft = true
        }
        ShortcutsPanel {
            anchors { left: parent.left; top: parent.top; leftMargin: desk.edge; topMargin: desk.edge }
            opacity: (desk.showLeft ? 1 : 0) * desk.stage(1)
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            transform: Translate { y: (desk.showLeft ? 0 : -6) + (desk.intro >= 1 ? 0 : 14); Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
            HoverHandler { id: leftHover; onHoveredChanged: if (desk.compact) hovered ? closeLeft.stop() : closeLeft.restart() }
            Pin {
                id: leftPin
                anchors { right: parent.right; top: parent.top; margins: 12 }
                visible: desk.compact
                pinned: desk.pinLeft
                onToggled: DeskState.togglePin(desk.mon, "left")
            }
        }

        // =============================================== ESQUERDA: relógio
        Column {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: desk.edge; bottomMargin: desk.edge - 20 }
            spacing: 18

            // Relógio grande (Archivo 62% / 800, igual ao manual)
            Text {
                id: clock
                opacity: desk.flying ? 0 : 1          // durante o voo quem aparece é a cópia
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
                opacity: desk.stage(4)
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                transform: Translate { y: desk.intro >= 4 ? 0 : 10; Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } } }
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
            opacity: desk.stage(5)
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            transform: Translate { y: desk.intro >= 5 ? 0 : 10; Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } } }
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

        // =============================================== CENTRO: agenda do wallpaper (Super+A, por monitor)
        AgendaWall {
            anchors.fill: parent
            opacity: desk.bigAgenda ? desk.stage(3) : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        }

        // =============================================== DIREITA: agenda, mídia, sistema
        Badge {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: desk.edge; bottomMargin: desk.edge }
            id: rightTag
            text: "painéis"
            label.text: "+  AGENDA · MÍDIA · RECURSOS  \uf077"
            opacity: (desk.compact || desk.bigAgenda ? 1 : 0) * desk.stage(6)
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            onHoveredChanged: hovered ? (desk.peekRight = true, closeRight.stop()) : closeRight.restart()
            onClicked: desk.peekRight = true
        }
        ColumnLayout {
            id: rightCol
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: desk.edge; bottomMargin: desk.edge }
            width: 380
            spacing: 10
            opacity: (desk.showRight ? 1 : 0) * desk.stage(6)
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            transform: Translate { y: (desk.showRight ? 0 : 6) + (desk.intro >= 6 ? 0 : 14); Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
            HoverHandler { id: rightHover; onHoveredChanged: if (desk.compact || desk.bigAgenda) hovered ? closeRight.stop() : closeRight.restart() }

            // ---------- AGENDA (calendário + próximos eventos; ver AgendaCard.qml)
            AgendaCard {
                visible: !desk.bigAgenda             // com a agenda grande aberta, a pequena sai
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
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
        // Alfinete da coluna da direita (canto do primeiro card)
        Pin {
            id: rightPin
            anchors { right: rightCol.right; top: rightCol.top; margins: 12 }
            visible: (desk.compact || desk.bigAgenda) && rightCol.visible
            opacity: rightCol.opacity
            pinned: desk.pinRight
            onToggled: DeskState.togglePin(desk.mon, "right")
        }
    }
}
