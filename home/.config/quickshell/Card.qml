import QtQuick

// Cartão base dos painéis: sólido, cantos retos, borda acende em lima no hover
Rectangle {
    id: card
    property string title: ""
    property bool hovered: hover.hovered
    default property alias content: body.data

    color: Theme.void_
    border.width: 1
    border.color: hovered ? Theme.signal : Theme.line
    Behavior on border.color { ColorAnimation { duration: 120 } }

    HoverHandler { id: hover }

    Text {
        id: label
        visible: card.title !== ""
        anchors { left: parent.left; top: parent.top; leftMargin: 12; topMargin: 8 }
        text: card.title
        color: card.hovered ? Theme.signal : Theme.statik
        font.family: Theme.mono
        font.pixelSize: 9
        font.letterSpacing: 2
    }

    Item {
        id: body
        anchors {
            left: parent.left; right: parent.right; bottom: parent.bottom
            top: label.visible ? label.bottom : parent.top
            leftMargin: 12; rightMargin: 12; bottomMargin: 8; topMargin: label.visible ? 4 : 8
        }
    }
}
