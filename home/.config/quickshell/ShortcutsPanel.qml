import QtQuick
import Quickshell
import Quickshell.Io

// Painel de atalhos (lado esquerdo do desktop), no estilo dos cards do
// eliasolie-site ("Performance verificável"): fundo graphite, borda 2px que
// acende em lima, ícone lima, rótulo mono e link "ABRIR … ↗" no rodapé.
// Os atalhos vêm de shortcuts.json (recarrega ao salvar).
Rectangle {
    id: panel
    readonly property int tile: 64
    readonly property int gapT: 8
    readonly property int pad: 22
    readonly property int maxRows: 4     // linhas visíveis antes de rolar
    property var items: []
    property var hoveredItem: null

    width: pad * 2 + tile * 3 + gapT * 2
    height: body.implicitHeight + pad * 2
    color: Theme.graphite
    border.width: 2
    border.color: cardHover.hovered ? Theme.signal : Theme.line
    Behavior on border.color { ColorAnimation { duration: 150 } }
    HoverHandler { id: cardHover }

    FileView {
        id: file
        path: Qt.resolvedUrl("shortcuts.json").toString().replace("file://", "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { panel.items = JSON.parse(text()).items || [] } catch (e) { panel.items = [] }
        }
    }

    function run(it) {
        if (it.url) Quickshell.execDetached(["brave", it.url])
        else if (it.cmd) Quickshell.execDetached(["sh", "-c", it.cmd])
    }

    Column {
        id: body
        x: panel.pad; y: panel.pad
        width: panel.width - panel.pad * 2
        spacing: 0

        // Rótulo + raio lima e título na mesma linha (como o card do site)
        Text {
            text: "ATALHOS"
            color: Theme.statik
            font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 3
        }
        Item { width: 1; height: 6 }
        Row {
            spacing: 10
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""          // raio
                color: Theme.signal
                font.family: Theme.mono
                font.pixelSize: 20
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "ACESSO RÁPIDO"
                color: Theme.bone
                font.family: Theme.sans; font.pixelSize: 22; font.weight: Font.ExtraBold
                font.variableAxes: { "wdth": 85 }
            }
        }
        Item { width: 1; height: 16 }

        // Grade com rolagem: mostra até `maxRows` linhas; passou disso, rola
        // com a roda do mouse e aparece uma barrinha lima de posição
        Item {
            width: parent.width
            height: Math.min(grid.implicitHeight, panel.maxRows * panel.tile + (panel.maxRows - 1) * panel.gapT)

        Flickable {
            id: flick
            anchors.fill: parent
            contentHeight: grid.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

        Grid {
            id: grid
            columns: 3
            spacing: panel.gapT
            Repeater {
                model: panel.items
                delegate: Rectangle {
                    id: t
                    required property var modelData
                    width: panel.tile; height: panel.tile
                    color: tMouse.containsMouse ? Theme.graphite : Theme.void_
                    border.width: 2
                    border.color: tMouse.containsMouse ? Theme.signal : Theme.line
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Image {
                        visible: !!t.modelData.icon
                        anchors.centerIn: parent
                        width: 34; height: 34
                        source: t.modelData.icon ? Qt.resolvedUrl(t.modelData.icon) : ""
                        sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectFit
                        smooth: true; mipmap: true
                    }
                    Text {
                        visible: !t.modelData.icon && !!t.modelData.glyph
                        anchors.centerIn: parent
                        text: t.modelData.glyph || ""
                        color: tMouse.containsMouse ? Theme.signal : Theme.bone
                        font.family: Theme.mono; font.pixelSize: 26
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    // Badge do canto (ex.: envelope do webmail)
                    Rectangle {
                        visible: !!t.modelData.badge
                        anchors { right: parent.right; bottom: parent.bottom; margins: 5 }
                        width: 18; height: 18
                        color: Theme.signal
                        Text {
                            anchors.centerIn: parent
                            text: t.modelData.badge || ""
                            color: Theme.void_
                            font.family: Theme.mono; font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: tMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: panel.hoveredItem = containsMouse ? t.modelData : (panel.hoveredItem === t.modelData ? null : panel.hoveredItem)
                        onClicked: panel.run(t.modelData)
                    }
                }
            }
        }

        }   // Flickable

            // Barra de rolagem fina (só quando há mais que maxRows linhas)
            Rectangle {
                visible: flick.interactive
                anchors.right: parent.right
                anchors.rightMargin: -12
                width: 2
                y: flick.visibleArea.yPosition * parent.height
                height: flick.visibleArea.heightRatio * parent.height
                color: Theme.signal
            }
        }   // Item

        Item { width: 1; height: 16 }

        // Rodapé: "ABRIR … ↗" do atalho sob o mouse (como o link do card do site)
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: panel.hoveredItem ? "ABRIR " + panel.hoveredItem.name.toUpperCase() + "  ↗" : "PASSE O MOUSE"
            color: panel.hoveredItem ? Theme.signal : Qt.alpha(Theme.statik, 0.6)
            font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.2
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }
}
