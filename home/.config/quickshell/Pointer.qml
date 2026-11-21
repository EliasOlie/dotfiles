pragma Singleton
import QtQuick
import Quickshell

// Posição do mouse sobre o desktop (preenchida pelos widgets, lida pelo wallpaper)
// e cliques no fundo (viram uma onda nos pontos do wallpaper).
Singleton {
    property string screen: ""
    property real x: -1000
    property real y: -1000
    property bool inside: false

    signal ripple(string screen, real x, real y)
}
