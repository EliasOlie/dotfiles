import QtQuick

// Alfinete dos blocos recolhíveis: fixado = fica aberto mesmo sem o mouse.
Item {
    id: pin
    property bool pinned: false
    property alias hovered: m.containsMouse
    signal toggled()
    width: 24; height: 24

    Text {
        anchors.centerIn: parent
        text: pin.pinned ? "\u{f0403}" : "\u{f0931}"      // pin cheio / contorno
        rotation: pin.pinned ? 0 : 45
        color: pin.pinned ? Theme.signal : (m.containsMouse ? Theme.bone : Theme.statik)
        font.family: Theme.mono; font.pixelSize: 15
        Behavior on rotation { NumberAnimation { duration: 140 } }
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    MouseArea {
        id: m
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pin.toggled()
    }
}
