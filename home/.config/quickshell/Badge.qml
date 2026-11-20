import QtQuick

// Badge no estilo do eliasolie-site: borda 2px, mono maiúsculo, cantos retos.
//   normal: borda line + texto static · hover: lima · ligado (on): lima cheio
Rectangle {
    id: badge
    property string text: ""
    property bool on: false
    property alias hovered: mouse.containsMouse
    property alias label: label
    signal clicked()

    implicitWidth: label.implicitWidth + 22
    implicitHeight: label.implicitHeight + 12

    color: on ? Theme.signal : (hovered ? Theme.graphite : Theme.void_)
    border.width: 2
    border.color: on || hovered ? Theme.signal : Theme.line
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
        id: label
        anchors.centerIn: parent
        text: badge.text.toUpperCase()
        color: badge.on ? Theme.void_ : (badge.hovered ? Theme.signal : Theme.statik)
        font.family: Theme.mono
        font.pixelSize: 11
        font.weight: badge.on ? Font.Bold : Font.Medium
        font.letterSpacing: 1.4
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: badge.clicked()
    }
}
