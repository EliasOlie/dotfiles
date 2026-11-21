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
    // Indicador de volume/brilho (por cima de tudo, só no monitor com foco)
    Variants {
        model: Quickshell.screens
        Osd {}
    }
    // Garante que a ponte IPC do indicador exista desde o início
    property var _osd: OsdBus
}
