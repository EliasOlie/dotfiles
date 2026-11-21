pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clima de Serra Talhada/PE via Open-Meteo (sem chave), a cada 30 min.
// Para outra cidade: troque lat/lon (e o nome) abaixo.
Singleton {
    id: root
    readonly property string city: "Serra Talhada"
    readonly property real lat: -7.99
    readonly property real lon: -38.30

    property bool ok: false
    property int temp: 0
    property int max: 0
    property int min: 0
    property string desc: ""
    property string glyph: ""

    // Códigos WMO -> [descrição, ícone dia, ícone noite]
    function wmo(c, day) {
        const t = c === 0 ? ["céu limpo", "\u{f0599}", "\u{f0594}"]
                : c <= 2 ? ["parcialmente nublado", "\u{f0595}", "\u{f0f31}"]
                : c === 3 ? ["nublado", "\u{f0590}", "\u{f0590}"]
                : c <= 48 ? ["neblina", "\u{f0591}", "\u{f0591}"]
                : c <= 57 ? ["garoa", "\u{f0597}", "\u{f0597}"]
                : c <= 67 ? ["chuva", "\u{f0596}", "\u{f0596}"]
                : c <= 77 ? ["neve", "\u{f0598}", "\u{f0598}"]
                : c <= 82 ? ["pancadas de chuva", "\u{f0596}", "\u{f0596}"]
                : ["trovoadas", "\u{f0593}", "\u{f0593}"]
        return { desc: t[0], glyph: day ? t[1] : t[2] }
    }

    Process {
        id: proc
        command: ["curl", "-s", "-m", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon
            + "&current=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min"
            + "&forecast_days=1&timezone=America%2FRecife"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    const w = root.wmo(d.current.weather_code, d.current.is_day === 1)
                    root.temp = Math.round(d.current.temperature_2m)
                    root.max = Math.round(d.daily.temperature_2m_max[0])
                    root.min = Math.round(d.daily.temperature_2m_min[0])
                    root.desc = w.desc
                    root.glyph = w.glyph
                    root.ok = true
                } catch (e) { root.ok = false }
            }
        }
    }

    Timer {
        interval: 30 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
