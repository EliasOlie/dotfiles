pragma Singleton
import QtQuick
import Quickshell

// Paleta eliasolie — mesma da waybar, rofi, kitty e Hyprland
Singleton {
    readonly property color void_:    "#050505"
    readonly property color graphite: "#161614"
    readonly property color line:     "#2A2A27"
    readonly property color statik:   "#8A8A84"
    readonly property color bone:     "#EDEDE8"
    readonly property color signal:   "#C8F031"
    readonly property color alert:    "#FF5A4E"
    readonly property color warn:     "#F2C94C"    // âmbar: "cuidado" (status)

    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string sans: "Archivo"

    readonly property int gap: 7          // = gaps_out do Hyprland
    readonly property int panelHeight: 64
}
