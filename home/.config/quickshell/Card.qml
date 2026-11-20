import QtQuick

// Card base no estilo do eliasolie-site (igual ao painel de atalhos):
// fundo graphite, borda 2px que acende em lima, rótulo mono e, na mesma
// linha, ícone lima + título em Archivo ExtraBold.
Rectangle {
    id: card
    property string label: ""      // rótulo mono pequeno (ex.: AGENDA)
    property string title: ""      // título forte (ex.: PRÓXIMOS EVENTOS)
    property string glyph: ""      // ícone Nerd Font em lima
    property bool hovered: hover.hovered
    readonly property int pad: 20
    readonly property int headerHeight: header.height + 14
    default property alias content: body.data

    color: Theme.graphite
    border.width: 2
    border.color: hovered ? Theme.signal : Theme.line
    Behavior on border.color { ColorAnimation { duration: 150 } }

    HoverHandler { id: hover }

    Column {
        id: header
        x: card.pad; y: card.pad
        spacing: 6
        Text {
            visible: card.label !== ""
            text: card.label
            color: Theme.statik
            font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 3
        }
        Row {
            spacing: 10
            visible: card.title !== ""
            Text {
                visible: card.glyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: card.glyph
                color: Theme.signal
                font.family: Theme.mono; font.pixelSize: 18
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: card.title
                color: Theme.bone
                font.family: Theme.sans; font.pixelSize: 20; font.weight: Font.ExtraBold
                font.variableAxes: { "wdth": 85 }
            }
        }
    }

    Item {
        id: body
        anchors {
            left: parent.left; right: parent.right; bottom: parent.bottom; top: header.bottom
            leftMargin: card.pad; rightMargin: card.pad; bottomMargin: card.pad; topMargin: 14
        }
    }
}
