// Quickshell — painéis do rodapé (um por monitor)
import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        BottomPanel {}
    }
}
