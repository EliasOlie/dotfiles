// Quickshell — widgets do desktop (um conjunto por monitor, só com o workspace vazio)
import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        DesktopWidgets {}
    }
}
