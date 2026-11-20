// Quickshell — wallpaper vivo + widgets do desktop (um conjunto por monitor)
import QtQuick
import Quickshell

ShellRoot {
    // Wallpaper vivo (camada de fundo)
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }
    // Widgets (acima do wallpaper, abaixo das janelas)
    Variants {
        model: Quickshell.screens
        DesktopWidgets {}
    }
}
