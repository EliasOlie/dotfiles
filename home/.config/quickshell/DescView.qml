import QtQuick
import Quickshell

// Descrição de evento com blocos copiáveis.
// Trechos como <legenda>texto</legenda> (qualquer nome de tag) viram um botão
// "LEGENDA" com o conteúdo oculto: clique copia o texto de dentro; ao lado,
// enviar por WhatsApp ou Telegram (abre a tela de compartilhar com o texto pronto,
// para você escolher o contato). O resto do texto aparece normal. Área com
// rolagem quando a descrição é longa.
Item {
    id: dv
    property string text: ""
    property int maxHeight: 340
    implicitHeight: Math.min(col.implicitHeight, maxHeight)
    clip: true

    // Tags de HTML comuns (o Google às vezes formata a descrição) não viram botão
    readonly property var htmlTags: ["b", "i", "u", "a", "p", "br", "span", "div", "ul", "ol", "li", "strong", "em", "html", "body", "pre", "code", "h1", "h2", "h3"]

    function clean(t) {
        return (t || "").replace(/<br\s*\/?>/gi, "\n")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
    }
    function stripHtml(t) {
        const tags = dv.htmlTags.join("|")
        return t.replace(new RegExp("</?(" + tags + ")(\\s[^>]*)?>", "gi"), "")
    }
    // [{ kind: "text", value } | { kind: "block", tag, value }]
    readonly property var segments: {
        const t = clean(dv.text)
        const out = []
        const re = /<([A-Za-z][\w-]*)>([\s\S]*?)<\/\1>/g
        let last = 0, m
        while ((m = re.exec(t)) !== null) {
            if (dv.htmlTags.indexOf(m[1].toLowerCase()) >= 0) continue
            if (m.index > last) out.push({ kind: "text", value: stripHtml(t.slice(last, m.index)) })
            out.push({ kind: "block", tag: m[1], value: stripHtml(m[2]).trim() })
            last = re.lastIndex
        }
        if (last < t.length) out.push({ kind: "text", value: stripHtml(t.slice(last)) })
        return out.filter(s => s.kind === "block" || s.value.trim() !== "")
    }

    function copy(tag, value) {
        Quickshell.execDetached(["wl-copy", "--", value])
        Quickshell.execDetached(["notify-send", "-a", "agenda", tag.charAt(0).toUpperCase() + tag.slice(1) + " copiada",
                                 value.length > 120 ? value.slice(0, 120) + "…" : value])
    }
    function share(app, value) {
        const t = encodeURIComponent(value)
        Qt.openUrlExternally(app === "wa" ? "https://wa.me/?text=" + t : "https://t.me/share/url?url=%20&text=" + t)
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: col
            width: flick.width - 10
            spacing: 10
            Repeater {
                model: dv.segments
                delegate: Loader {
                    required property var modelData
                    width: col.width
                    sourceComponent: modelData.kind === "block" ? blockC : textC
                    Component {
                        id: textC
                        Text {
                            width: col.width
                            wrapMode: Text.WordWrap
                            text: modelData.value.replace(/^\n+|\n+$/g, "")
                            color: Theme.bone; font.family: Theme.sans; font.pixelSize: 14
                            textFormat: Text.PlainText
                            lineHeight: 1.15
                        }
                    }
                    Component {
                        id: blockC
                        Row {
                            spacing: 6
                            Badge {
                                text: modelData.tag
                                on: true
                                label.text: "\u{f018f}  " + modelData.tag.toUpperCase()     // ícone de copiar
                                onClicked: dv.copy(modelData.tag, modelData.value)
                            }
                            Badge {
                                text: "whatsapp"
                                label.text: "\u{f05a3}"
                                implicitWidth: 34
                                onClicked: dv.share("wa", modelData.value)
                            }
                            Badge {
                                text: "telegram"
                                label.text: "\uf2c6"            // telegram (Font Awesome)
                                implicitWidth: 34
                                onClicked: dv.share("tg", modelData.value)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.value.length + " caracteres"
                                color: Qt.alpha(Theme.statik, 0.7); font.family: Theme.mono; font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }

    // barra de rolagem fina (lima), só quando precisa
    Rectangle {
        visible: flick.interactive
        anchors.right: parent.right
        width: 2
        y: flick.visibleArea.yPosition * parent.height
        height: flick.visibleArea.heightRatio * parent.height
        color: Theme.signal
    }
}
