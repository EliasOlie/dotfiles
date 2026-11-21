import QtQuick
import Quickshell
import Quickshell.Wayland

// Wallpaper vivo: fundo void + grade de pontos sutil. Perto do mouse,
// os pontos acendem em lima (substitui o hyprpaper).
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

    // Intensidade do brilho: acende ao entrar, apaga suave ao sair
    property real amount: here ? 1 : 0
    Behavior on amount { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    onAmountChanged: glow.requestPaint()

    // Último ponto conhecido (mantém o brilho no lugar enquanto apaga)
    property real gx: -1000
    property real gy: -1000
    // Onda do clique: um anel de pontos acesos que cresce e some
    readonly property real rippleMax: 560
    property real rx: 0
    property real ry: 0
    property real rr: -1                 // raio atual (-1 = sem onda)
    onRrChanged: glow.requestPaint()
    NumberAnimation { id: rippleAnim; target: wall; property: "rr"; from: 0; to: wall.rippleMax; duration: 950; easing.type: Easing.OutQuad
        onFinished: wall.rr = -1 }

    Connections {
        target: Pointer
        function onRipple(screen, x, y) {
            if (screen !== wall.modelData.name) return
            wall.rx = x; wall.ry = y; rippleAnim.restart()
        }
        function onXChanged() { if (wall.here) { wall.gx = Pointer.x; glow.requestPaint() } }
        function onYChanged() { if (wall.here) { wall.gy = Pointer.y; glow.requestPaint() } }
    }

    // Grade base: desenhada uma vez (e ao redimensionar)
    Canvas {
        id: grid
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#22221F"
            for (let y = 0; y < height; y += wall.step)
                for (let x = 0; x < width; x += wall.step)
                    ctx.fillRect(x, y, 1, 1)
        }
    }

    // Pulso da música: pontos lima mais fortes no centro, desenhados UMA vez;
    // o que muda a cada batida é só a opacidade (barato, feito pela GPU)
    Canvas {
        id: pulse
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        opacity: AudioLevel.level * 0.6
        visible: opacity > 0.01
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const cx = width / 2, cy = height / 2, R = Math.hypot(cx, cy)
            for (let y = 0; y < height; y += wall.step)
                for (let x = 0; x < width; x += wall.step) {
                    const t = Math.pow(1 - Math.hypot(x - cx, y - cy) / R, 1.8)
                    ctx.fillStyle = Qt.rgba(200 / 255, 240 / 255, 49 / 255, 0.08 + 0.9 * t)
                    const size = 1 + Math.round(t)
                    ctx.fillRect(x - (size - 1) / 2, y - (size - 1) / 2, size, size)
                }
        }
    }

    // Camada do brilho: só os pontos dentro do raio são redesenhados
    Canvas {
        id: glow
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const s0 = wall.step
            // Onda do clique (anel com ~44 px de espessura, apaga conforme cresce)
            if (wall.rr >= 0) {
                const W = 44, R = wall.rr, fade = 1 - R / wall.rippleMax
                const x0 = Math.max(0, Math.floor((wall.rx - R - W) / s0) * s0), x1 = Math.min(width, wall.rx + R + W)
                const y0 = Math.max(0, Math.floor((wall.ry - R - W) / s0) * s0), y1 = Math.min(height, wall.ry + R + W)
                for (let y = y0; y <= y1; y += s0)
                    for (let x = x0; x <= x1; x += s0) {
                        const k = 1 - Math.abs(Math.hypot(x - wall.rx, y - wall.ry) - R) / W
                        if (k <= 0) continue
                        const t = k * fade
                        const size = 1 + 2 * t
                        ctx.fillStyle = Qt.rgba(200 / 255, 240 / 255, 49 / 255, 0.2 + 0.8 * t)
                        ctx.fillRect(x - (size - 1) / 2, y - (size - 1) / 2, size, size)
                    }
            }
            if (wall.amount <= 0.01) return
            const s = wall.step, R = wall.radius
            const x0 = Math.max(0, Math.floor((wall.gx - R) / s) * s), x1 = Math.min(width,  wall.gx + R)
            const y0 = Math.max(0, Math.floor((wall.gy - R) / s) * s), y1 = Math.min(height, wall.gy + R)
            for (let y = y0; y <= y1; y += s) {
                for (let x = x0; x <= x1; x += s) {
                    const d = Math.hypot(x - wall.gx, y - wall.gy)
                    if (d > R) continue
                    const t = Math.pow(1 - d / R, 1.6) * wall.amount
                    const size = 1 + 2 * t
                    ctx.fillStyle = Qt.rgba(200 / 255, 240 / 255, 49 / 255, 0.15 + 0.85 * t)
                    ctx.fillRect(x - (size - 1) / 2, y - (size - 1) / 2, size, size)
                }
            }
        }
    }
}
