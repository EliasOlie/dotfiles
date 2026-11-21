pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Nível da batida da música (0..1) para o wallpaper pulsar.
// Só escuta o áudio quando há música tocando E algum desktop está à mostra.
Singleton {
    id: root
    property real level: 0
    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying)
    readonly property bool active: playing && SysStats.active
    onActiveChanged: if (!active) level = 0

    Process {
        running: root.active
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/audio-level.py"]
        stdout: SplitParser { onRead: data => root.level = parseFloat(data) || 0 }
    }
}
