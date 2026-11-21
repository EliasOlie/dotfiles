import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Indicador de volume/brilho/microfone no estilo do site: card graphite com
// borda 2px, rótulo mono e barra lima, que sobe do rodapé e some sozinho.
// Aparece só no monitor com foco. Chamado pelo osd.sh:
//   qs ipc call osd popup <volume|brilho|mic> <0-100> <mudo:true|false>
PanelWindow {
    id: osd
    required property var modelData
    screen: modelData

    anchors.bottom: true
    margins.bottom: 72
    implicitWidth: 380
    implicitHeight: 86
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "eliasolie-osd"
    mask: Region {}
    visible: shown || box.opacity > 0.01

    property bool shown: false
    property string kind: "volume"
    property int value: 0
    property bool muted: false

    Connections {
        target: OsdBus
        function onShow(kind, value, muted) {
            const f = Hyprland.focusedMonitor
            if (f && f.name !== osd.modelData.name) return
            osd.kind = kind; osd.value = value; osd.muted = muted
            osd.shown = true; hide.restart()
        }
    }
    Timer { id: hide; interval: 1300; onTriggered: osd.shown = false }

    readonly property var meta: ({
        volume: { label: "VOLUME", icon: muted ? "\u{f075f}" : value > 60 ? "\u{f057e}" : value > 25 ? "\u{f0580}" : "\u{f057f}" },
        brilho: { label: "BRILHO", icon: value > 60 ? "\u{f00e0}" : value > 25 ? "\u{f00df}" : "\u{f00de}" },
        mic:    { label: "MICROFONE", icon: muted ? "\u{f036d}" : "\u{f036c}" }
    })

    Rectangle {
        id: box
        width: parent.width; height: 62
        y: osd.shown ? parent.height - height : parent.height
        opacity: osd.shown ? 1 : 0
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: Theme.graphite
        border.width: 2
        border.color: Theme.line

        Row {
            anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
            spacing: 16
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (osd.meta[osd.kind] || osd.meta.volume).icon
                color: osd.muted ? Theme.alert : Theme.signal
                font.family: Theme.mono; font.pixelSize: 22
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 54
                spacing: 9
                Item {
                    width: parent.width; height: 14
                    Text {
                        text: (osd.meta[osd.kind] || osd.meta.volume).label
                        color: Theme.statik
                        font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 3
                    }
                    Text {
                        anchors.right: parent.right
                        text: osd.muted ? "MUDO" : osd.kind === "mic" ? "LIGADO" : osd.value + "%"
                        color: osd.muted ? Theme.alert : Theme.bone
                        font.family: Theme.mono; font.pixelSize: 12; font.weight: Font.Bold
                    }
                }
                Rectangle {
                    width: parent.width; height: 3
                    color: Theme.line
                    Rectangle {
                        height: parent.height
                        width: parent.width * (osd.muted ? 0 : Math.max(0, Math.min(100, osd.value)) / 100)
                        color: Theme.signal
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
