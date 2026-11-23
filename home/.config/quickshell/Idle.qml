pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

// Modo descanso: depois de `minutes` sem mexer em nada (teclado/mouse, todo o
// sistema), o wallpaper forma a hora com os pontos e os widgets se apagam.
// Respeita quem pede para não ficar ocioso (vídeo em tela cheia etc.).
Singleton {
    id: root
    readonly property int minutes: 2
    readonly property bool resting: idle.isIdle
    IdleMonitor {
        id: idle
        timeout: 60 * root.minutes
        respectInhibitors: true
    }
}
