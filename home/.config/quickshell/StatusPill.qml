import QtQuick
import Quickshell

// Status do que roda fora do notebook (serviços da VPS + backup), recolhido
// numa etiqueta só, no estilo dos quick actions:
//   ■ NORMAL   (lima)   tudo ok
//   ■ CUIDADO  (âmbar)  um item com problema
//   ■ ATENÇÃO  (coral)  dois ou mais com problema
// Passou o mouse, a lista abre PARA CIMA, por cima do wallpaper, sem empurrar
// nada da tela; tirou o mouse, fecha. Clique num serviço abre o Dokploy.
Item {
    id: pill
    implicitWidth: tag.width
    implicitHeight: tag.height

    // itens: { name, ok, detail, url }
    readonly property var items: {
        const out = VpsStatus.services.map(s => ({
            name: s.name.toUpperCase(), ok: s.up,
            detail: s.up ? s.ms + " ms" : (s.code ? "fora · " + s.code : "sem resposta"),
            url: VpsStatus.panel
        }))
        out.push({ name: "BACKUP", ok: BackupStatus.fresh,
                   detail: BackupStatus.ok ? "há " + BackupStatus.age : "sem dados", url: "" })
        return out
    }
    readonly property int bad: items.filter(i => !i.ok).length
    readonly property bool checking: VpsStatus.services.length === 0
    readonly property color tint: checking ? Theme.statik : bad === 0 ? Theme.signal : bad === 1 ? Theme.warn : Theme.alert
    readonly property string word: checking ? "CHECANDO" : bad === 0 ? "NORMAL" : bad === 1 ? "CUIDADO" : "ATENÇÃO"

    property bool open: false
    Timer { id: closeT; interval: 260; onTriggered: if (!tagMouse.containsMouse && !listHover.hovered) pill.open = false }

    // ------------------------------------------------ etiqueta
    Rectangle {
        id: tag
        width: row.implicitWidth + 24; height: 26
        color: pill.open ? Theme.graphite : "transparent"
        border.width: pill.open ? 2 : 0
        border.color: pill.tint
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 10
            Rectangle { width: 7; height: 7; color: pill.tint; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: pill.word
                color: pill.bad === 0 && !pill.open ? Theme.statik : pill.tint
                font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 2
                font.weight: pill.bad > 0 ? Font.Bold : Font.Normal
            }
            Text {
                text: pill.open ? "" : ""
                color: Theme.statik; font.family: Theme.mono; font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: tagMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse ? (pill.open = true, closeT.stop()) : closeT.restart()
            onClicked: pill.open = !pill.open
        }
    }

    // ------------------------------------------------ lista (abre para cima)
    Rectangle {
        id: list
        anchors { bottom: tag.top; bottomMargin: 8; horizontalCenter: tag.horizontalCenter }
        width: Math.max(260, col.implicitWidth + 40)
        height: col.implicitHeight + 32
        color: Theme.graphite
        border.width: 2
        border.color: Theme.line
        opacity: pill.open ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 140 } }
        transform: Translate { y: pill.open ? 0 : 6; Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
        HoverHandler { id: listHover; onHoveredChanged: hovered ? closeT.stop() : closeT.restart() }

        Column {
            id: col
            x: 20; y: 16
            width: parent.width - 40
            spacing: 10
            Text { text: "STATUS"; color: Theme.statik; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 3 }
            Repeater {
                model: pill.items
                delegate: Item {
                    id: it
                    required property var modelData
                    width: col.width; height: 18
                    Rectangle { width: 7; height: 7; anchors.verticalCenter: parent.verticalCenter; color: it.modelData.ok ? Theme.signal : Theme.alert }
                    Text {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        text: it.modelData.name
                        color: itMouse.containsMouse && it.modelData.url ? Theme.signal : Theme.bone
                        font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 2
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: it.modelData.detail
                        color: it.modelData.ok ? Theme.statik : Theme.alert
                        font.family: Theme.mono; font.pixelSize: 11
                    }
                    MouseArea {
                        id: itMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: it.modelData.url !== ""
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: Quickshell.execDetached(["brave", it.modelData.url])
                    }
                }
            }
        }
    }
}
