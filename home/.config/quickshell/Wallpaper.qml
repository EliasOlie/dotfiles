import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Wallpaper vivo, desenhado pela GPU (shaders/wallpaper.frag): fundo void +
// grade de pontos. Os pontos acendem em lima perto do mouse, numa onda a partir
// do clique, no ritmo da música e, de vez em quando, sozinhos (como estrelas).
// Em descanso (Idle.qml: 2 min sem mexer em nada) eles formam a hora e acendem
// sozinhos, como estrelas.
// Custo: zero com janelas na frente; em uso, só redesenha quando algo muda
// (mouse, clique, música). A animação contínua (estrelas, 15 quadros/s) roda
// só em descanso: cada quadro custa CPU no Qt, e em uso isso dava ~6-9%.
PanelWindow {
    id: wall
    required property var modelData
    screen: modelData

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.void_
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "eliasolie-wallpaper"

    readonly property int step: 40          // distância entre pontos (igual ao PNG antigo)
    readonly property real radius: 170      // alcance do brilho em volta do mouse
    readonly property bool here: Pointer.inside && Pointer.screen === modelData.name

    // Desktop deste monitor à mostra? (sem janelas no workspace ativo)
    readonly property var hmon: Hyprland.monitorFor(modelData)
    readonly property bool shown: !!hmon && !!hmon.activeWorkspace && hmon.activeWorkspace.toplevels.values.length === 0

    // Intensidade do brilho: acende ao entrar, apaga suave ao sair
    property real amount: here ? 1 : 0
    Behavior on amount { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    property point glowAt: Qt.point(-1000, -1000)

    // Onda do clique
    readonly property real rippleMax: 560
    property point rippleAt: Qt.point(0, 0)
    property real rr: -1                 // raio atual (-1 = sem onda)
    NumberAnimation { id: rippleAnim; target: wall; property: "rr"; from: 0; to: wall.rippleMax; duration: 950; easing.type: Easing.OutQuad
        onFinished: wall.rr = -1 }

    Connections {
        target: Pointer
        function onRipple(screen, x, y) {
            if (screen !== wall.modelData.name) return
            wall.rippleAt = Qt.point(x, y); rippleAnim.restart()
        }
        function onXChanged() { if (wall.here) wall.glowAt = Qt.point(Pointer.x, Pointer.y) }
        function onYChanged() { if (wall.here) wall.glowAt = Qt.point(Pointer.x, Pointer.y) }
    }

    // Relógio das estrelas: só em descanso, com o desktop deste monitor à mostra
    property real time: 0
    Timer { interval: 66; repeat: true; running: wall.shown && Idle.resting; onTriggered: wall.time += 0.066 }

    // Modo descanso: sobe devagar, some rápido ao mexer
    property real rest: Idle.resting && wall.shown ? 1 : 0
    Behavior on rest { NumberAnimation { duration: wall.rest > 0.5 ? 400 : 2200; easing.type: Easing.InOutCubic } }

    // Hora em matriz de pontos: textura com 1 pixel por ponto da grade
    readonly property int cols: Math.ceil(width / step) + 1
    readonly property int rows: Math.ceil(height / step) + 1
    readonly property var font5x7: ({
        "0": ["01110","10001","10011","10101","11001","10001","01110"],
        "1": ["00100","01100","00100","00100","00100","00100","01110"],
        "2": ["01110","10001","00001","00010","00100","01000","11111"],
        "3": ["11111","00010","00100","00010","00001","10001","01110"],
        "4": ["00010","00110","01010","10010","11111","00010","00010"],
        "5": ["11111","10000","11110","00001","00001","10001","01110"],
        "6": ["00110","01000","10000","11110","10001","10001","01110"],
        "7": ["11111","00001","00010","00100","01000","01000","01000"],
        "8": ["01110","10001","10001","01110","10001","10001","01110"],
        "9": ["01110","10001","10001","01111","00001","00010","01100"],
        ":": ["0","0","1","0","1","0","0"]
    })
    Canvas {
        id: dotClock
        width: wall.cols; height: wall.rows
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d")
            ctx.fillStyle = "#000000"; ctx.fillRect(0, 0, width, height)
            ctx.fillStyle = "#ffffff"
            const txt = Qt.formatTime(new Date(), "HH:mm")
            const glyphs = txt.split("").map(ch => wall.font5x7[ch])
            const w = glyphs.reduce((a, g) => a + g[0].length, 0) + glyphs.length - 1
            let x = Math.floor((wall.cols - w) / 2)
            const y = Math.floor((wall.rows - 7) / 2) - 1
            for (const g of glyphs) {
                for (let r = 0; r < 7; r++)
                    for (let k = 0; k < g[r].length; k++)
                        if (g[r][k] === "1") ctx.fillRect(x + k, y + r, 1, 1)
                x += g[0].length + 1
            }
        }
        Component.onCompleted: requestPaint()
    }
    SystemClock { id: clock; precision: SystemClock.Minutes; onDateChanged: dotClock.requestPaint() }
    onRestChanged: if (rest > 0 && rest < 0.05) dotClock.requestPaint()

    ShaderEffect {
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/wallpaper.frag.qsb")
        property real cellStep: wall.step
        property real glowAmount: wall.amount
        property real glowRadius: wall.radius
        property point res: Qt.point(width, height)
        property point mouse: wall.glowAt
        property point ripple: wall.rippleAt
        property real rippleR: wall.rr
        property real rippleMax: wall.rippleMax
        property real pulse: wall.shown ? AudioLevel.level : 0     // só no monitor com o desktop à mostra
        property real time: wall.time
        property real twinkle: Idle.resting ? 1 : 0
        property real rest: wall.rest
        property point grid: Qt.point(wall.cols, wall.rows)
        // hideSource: a textura vai pro shader e o canvas some da tela
        property var matrix: ShaderEffectSource { sourceItem: dotClock; hideSource: true; smooth: false }
    }
}
