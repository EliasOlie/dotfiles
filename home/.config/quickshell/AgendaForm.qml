import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// "Novo evento" pelo desktop: mesmo formulário do painel do app de agenda
// (agenda EliasOlie / ConectaMe / Pessoal, título, data, início, fim, local,
// descrição, Meet). Envia com `agenda-new` (POST /api/widget/events, mesmas
// regras do painel) e atualiza a agenda local na hora.
// Abre por cima de tudo (sem prender o foco); Esc fecha, Ctrl+Enter cria.
PanelWindow {
    id: form
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "eliasolie-agenda-form"
    // OnDemand (não Exclusive): o teclado vem pro formulário, mas dá pra clicar em
    // outra janela/monitor e voltar (Exclusive prendia o foco e travava os monitores)
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    visible: shown || card.opacity > 0.01

    property bool shown: false
    property string brand: "eliasolie"
    property bool meet: false
    property bool busy: false
    property string error: ""

    readonly property var brands: [
        { id: "eliasolie", label: "EliasOlie" },
        { id: "conectame", label: "ConectaMe" },
        { id: "pessoal",   label: "Pessoal" }
    ]

    function pad(n) { return String(n).padStart(2, "0") }
    // Abre já com o dia escolhido (AAAAMMDD) ou hoje; horário: próxima hora cheia
    function openFor(key) {
        const now = new Date()
        const d = key ? new Date(Math.floor(key / 10000), Math.floor(key / 100) % 100 - 1, key % 100) : now
        dateIn.text = pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear()
        const sameDay = d.toDateString() === now.toDateString()
        const h = sameDay ? Math.min(22, now.getHours() + 1) : 9
        startIn.text = pad(h) + ":00"; endIn.text = pad(h + 1) + ":00"
        titleIn.text = ""; whereIn.text = ""; descIn.text = ""
        form.meet = false; form.error = ""; form.busy = false
        form.shown = true
        titleIn.forceActiveFocus()
    }
    function close() { form.shown = false }

    function submit() {
        if (form.busy) return
        const m = dateIn.text.trim().match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/)
        if (!titleIn.text.trim()) { form.error = "Dê um título ao evento."; return }
        if (!m) { form.error = "Data no formato DD/MM/AAAA."; return }
        if (!/^\d{2}:\d{2}$/.test(startIn.text) || !/^\d{2}:\d{2}$/.test(endIn.text)) { form.error = "Horários no formato HH:MM."; return }
        if (endIn.text <= startIn.text) { form.error = "O fim precisa ser depois do início."; return }
        form.error = ""; form.busy = true
        const body = {
            brand: form.brand, title: titleIn.text.trim(),
            date: m[3] + "-" + pad(m[2]) + "-" + pad(m[1]),
            start: startIn.text, end: endIn.text,
            location: whereIn.text.trim(), description: descIn.text.trim(), meet: form.meet
        }
        send.command = [Quickshell.env("HOME") + "/.local/bin/agenda-new", JSON.stringify(body)]
        send.running = true
    }

    Process {
        id: send
        stdout: StdioCollector { id: out }
        onExited: (code) => {
            form.busy = false
            let r = {}
            try { r = JSON.parse(out.text) } catch (e) {}
            if (code === 0) {
                const label = form.brands.find(b => b.id === form.brand).label
                Quickshell.execDetached(["notify-send", "-a", "agenda", "-i", "x-office-calendar",
                    "Evento criado · " + label, titleIn.text.trim() + (r.meetUrl ? "  ·  Meet: " + r.meetUrl : "")])
                form.close()
            } else form.error = r.error || "Não deu para criar o evento."
        }
    }

    // Fundo escurecido: clique fora fecha
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.void_, 0.72)
        opacity: card.opacity
        MouseArea { anchors.fill: parent; onClicked: form.close() }
    }

    // ------------------------------------------------ campo reutilizável
    component Field: Column {
        id: field
        property string label: ""
        property alias input: ti
        property alias text: ti.text
        property string hint: ""
        property int maxLen: 300
        spacing: 7
        Text { text: field.label; color: Theme.statik; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 3 }
        Item {
            width: field.width; height: 30
            TextInput {
                id: ti
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                color: Theme.bone
                selectionColor: Theme.signal; selectedTextColor: Theme.void_
                font.family: Theme.sans; font.pixelSize: 17; font.weight: Font.DemiBold
                maximumLength: field.maxLen
                clip: true
                Keys.onEscapePressed: form.close()
                Keys.onReturnPressed: (ev) => { if (ev.modifiers & Qt.ControlModifier) form.submit(); else nextItemInFocusChain().forceActiveFocus() }
                Keys.onEnterPressed: (ev) => { if (ev.modifiers & Qt.ControlModifier) form.submit(); else nextItemInFocusChain().forceActiveFocus() }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !ti.text && !ti.activeFocus
                text: field.hint
                color: Qt.alpha(Theme.statik, 0.5); font: ti.font
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: ti.activeFocus ? 2 : 1
                color: ti.activeFocus ? Theme.signal : Theme.line
            }
        }
    }

    // ------------------------------------------------ cartão do formulário
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 620
        height: body.implicitHeight + 56
        color: Theme.graphite
        border.width: 2
        border.color: Theme.signal
        opacity: form.shown ? 1 : 0
        scale: form.shown ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }        // clique dentro não fecha

        Column {
            id: body
            x: 28; y: 28
            width: parent.width - 56
            spacing: 22

            Column {
                spacing: 6
                Text { text: "AGENDA"; color: Theme.statik; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 3 }
                Row {
                    spacing: 10
                    Text { text: "\u{f00ed}"; color: Theme.signal; font.family: Theme.mono; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "NOVO EVENTO"; color: Theme.bone
                        font.family: Theme.sans; font.pixelSize: 24; font.weight: Font.ExtraBold
                        font.variableAxes: { "wdth": 85 }
                    }
                }
            }

            // Qual agenda
            Row {
                spacing: 8
                Repeater {
                    model: form.brands
                    delegate: Badge {
                        required property var modelData
                        text: modelData.label
                        on: form.brand === modelData.id
                        onClicked: form.brand = modelData.id
                        Rectangle {
                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            width: 6; height: 6
                            color: parent.on ? Theme.void_ : AgendaData.colorOf(modelData.id)
                        }
                        implicitWidth: label.implicitWidth + 38
                        label.anchors.horizontalCenterOffset: 6
                    }
                }
            }

            Field { id: title; width: parent.width; label: "TÍTULO"; hint: "Reunião com…"; maxLen: 200 }
            Row {
                width: parent.width
                spacing: 24
                Field { id: date;  width: 170; label: "DATA";   hint: "DD/MM/AAAA"; maxLen: 10 }
                Field { id: start; width: 100; label: "INÍCIO"; hint: "09:00"; maxLen: 5 }
                Field { id: end;   width: 100; label: "FIM";    hint: "10:00"; maxLen: 5 }
            }
            Field { id: where; width: parent.width; label: "LOCAL"; hint: "opcional"; maxLen: 300 }
            Field { id: desc;  width: parent.width; label: "DESCRIÇÃO"; hint: "opcional"; maxLen: 4000 }

            // Meet + ações
            Item {
                width: parent.width; height: 34
                Badge {
                    anchors.verticalCenter: parent.verticalCenter
                    text: form.meet ? "\u{f00c}  google meet" : "google meet"
                    on: form.meet
                    onClicked: form.meet = !form.meet
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Badge { text: "cancelar"; onClicked: form.close() }
                    Badge { text: form.busy ? "criando…" : "criar evento ↗"; on: true; onClicked: form.submit() }
                }
            }

            Text {
                width: parent.width
                text: form.error || "ctrl+enter cria  ·  esc fecha  ·  enter vai pro próximo campo"
                color: form.error ? Theme.alert : Qt.alpha(Theme.statik, 0.7)
                font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1
                wrapMode: Text.WordWrap
            }
        }
    }

    // atalhos para os TextInput (id dos campos acima)
    property alias titleIn: title.input
    property alias dateIn: date.input
    property alias startIn: start.input
    property alias endIn: end.input
    property alias whereIn: where.input
    property alias descIn: desc.input
}
