import QtQuick

// Medidor compacto: rótulo, valor e uma barra fina
Item {
    id: m
    property string label: ""
    property real value: 0          // 0..100 (negativo = indisponível)
    property string unit: "%"
    property string tip: ""
    property real warnAt: 85

    implicitWidth: 74
    implicitHeight: 30

    readonly property bool hot: value >= warnAt

    Row {
        spacing: 6
        Text { text: m.label; color: Theme.statik; font.family: Theme.mono; font.pixelSize: 10 }
        Text {
            text: m.value < 0 ? "—" : Math.round(m.value) + m.unit
            color: m.hot ? Theme.alert : Theme.bone
            font.family: Theme.mono; font.pixelSize: 11; font.weight: Font.Medium
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 2
        color: Theme.line
        Rectangle {
            height: parent.height
            width: parent.width * Math.max(0, Math.min(1, m.value / 100))
            color: m.hot ? Theme.alert : Theme.signal
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }
}
