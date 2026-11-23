import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Eventos da agenda pelo desktop, em três modos:
//   novo   — mesmo formulário do painel do app (EliasOlie / ConectaMe / Pessoal,
//            título, data, início, fim, local, descrição, Meet)
//   ver    — detalhes do evento clicado: editar, excluir, abrir no Google, Meet
//   editar — o formulário preenchido com o evento
// Fala com a API do app por `agenda-api` (mesmas regras do painel) e atualiza a
// agenda local na hora. Abre por cima de tudo (sem prender o foco); Esc fecha,
// Ctrl+Enter salva.
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
    property string mode: "new"            // new | view | edit
    property var ev: null                  // evento aberto (view/edit), do agenda.json
    property bool confirmDelete: false
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
        form.mode = "new"; form.ev = null; form.brand = "eliasolie"
        form.shown = true
        titleIn.forceActiveFocus()
    }
    function close() { form.shown = false; form.confirmDelete = false }

    // Detalhes de um evento (clique na agenda)
    function openEvent(e) {
        form.ev = e; form.mode = "view"; form.error = ""; form.busy = false; form.confirmDelete = false
        form.shown = true
        viewFocus.forceActiveFocus()
    }
    readonly property bool canEdit: !!ev && !!ev.id && !ev.booking && !ev.allDay
    function startEdit() {
        const e = form.ev, s = e._s, en = e._e
        form.brand = e.brand || "pessoal"
        titleIn.text = e.title
        dateIn.text = pad(s.getDate()) + "/" + pad(s.getMonth() + 1) + "/" + s.getFullYear()
        startIn.text = pad(s.getHours()) + ":" + pad(s.getMinutes())
        endIn.text = pad(en.getHours()) + ":" + pad(en.getMinutes())
        whereIn.text = e.location || ""
        descIn.text = e.description || ""
        form.meet = !!e.meetUrl
        form.error = ""; form.mode = "edit"
        titleIn.forceActiveFocus()
    }
    function remove() {
        if (!form.confirmDelete) { form.confirmDelete = true; return }   // 2º clique confirma
        form.busy = true; form.error = ""; form.action = "delete"
        send.command = [Quickshell.env("HOME") + "/.local/bin/agenda-api", "DELETE", "/api/widget/events/" + encodeURIComponent(form.ev.id)]
        send.running = true
    }
    property string action: "create"      // create | update | delete (para a mensagem final)

    function submit() {
        if (form.busy) return
        const m = dateIn.text.trim().match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/)
        if (!titleIn.text.trim()) { form.error = "Dê um título ao evento."; return }
        if (!m) { form.error = "Data no formato DD/MM/AAAA."; return }
        if (!/^\d{2}:\d{2}$/.test(startIn.text) || !/^\d{2}:\d{2}$/.test(endIn.text)) { form.error = "Horários no formato HH:MM."; return }
        if (endIn.text <= startIn.text) { form.error = "O fim precisa ser depois do início."; return }
        form.error = ""; form.busy = true
        form.action = form.mode === "edit" ? "update" : "create"
        const body = {
            brand: form.brand, title: titleIn.text.trim(),
            date: m[3] + "-" + pad(m[2]) + "-" + pad(m[1]),
            start: startIn.text, end: endIn.text,
            location: whereIn.text.trim(), description: descIn.text.trim(), meet: form.meet
        }
        send.command = form.mode === "edit"
            ? [Quickshell.env("HOME") + "/.local/bin/agenda-api", "PATCH", "/api/widget/events/" + encodeURIComponent(form.ev.id), JSON.stringify(body)]
            : [Quickshell.env("HOME") + "/.local/bin/agenda-api", "POST", "/api/widget/events", JSON.stringify(body)]
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
                const label = (form.brands.find(b => b.id === form.brand) || {}).label || ""
                const what = form.action === "delete" ? (r.booking ? "Reserva cancelada" : "Evento excluído")
                           : form.action === "update" ? "Evento atualizado · " + label : "Evento criado · " + label
                const name = form.action === "delete" ? form.ev.title : titleIn.text.trim()
                Quickshell.execDetached(["notify-send", "-a", "agenda", "-i", "x-office-calendar",
                    what, name + (r.meetUrl ? "  ·  Meet: " + r.meetUrl : "")])
                form.close()
            } else {
                form.confirmDelete = false
                form.error = r.error || "Não deu certo. Tente de novo."
            }
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
        height: (form.mode === "view" ? viewBody.implicitHeight : body.implicitHeight) + 56
        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        clip: true
        color: Theme.graphite
        border.width: 2
        border.color: Theme.signal
        opacity: form.shown ? 1 : 0
        scale: form.shown ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }        // clique dentro não fecha

        // ---------------------------------------------- modo VER (detalhes do evento)
        Column {
            id: viewBody
            visible: form.mode === "view"
            x: 28; y: 28
            width: parent.width - 56
            spacing: 18
            readonly property color tint: form.ev ? AgendaData.colorOf(form.ev.brand) : Theme.signal

            // Esc fecha / E edita / Delete exclui, quando o foco está nos detalhes
            Item {
                id: viewFocus
                width: 0; height: 0
                Keys.onEscapePressed: form.close()
                Keys.onPressed: (k) => {
                    if (k.key === Qt.Key_E && form.canEdit) { form.startEdit(); k.accepted = true }
                    else if (k.key === Qt.Key_Delete && form.ev && form.ev.id) { form.remove(); k.accepted = true }
                }
            }
            Column {
                spacing: 6
                width: parent.width
                Row {
                    spacing: 8
                    Rectangle { width: 7; height: 7; color: viewBody.tint; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: form.ev ? (AgendaData.brandLabel[form.ev.brand] || "GOOGLE") + (form.ev.booking ? "  ·  RESERVA" : "") : ""
                        color: Theme.statik; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 3
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: form.ev ? form.ev.title : ""
                    color: Theme.bone
                    font.family: Theme.sans; font.pixelSize: 26; font.weight: Font.ExtraBold
                    font.variableAxes: { "wdth": 85 }
                }
                Text {
                    text: form.ev ? AgendaData.timeLabel(form.ev) : ""
                    color: viewBody.tint
                    font.family: Theme.mono; font.pixelSize: 12; font.letterSpacing: 1.5
                }
            }
            Column {
                width: parent.width
                spacing: 6
                visible: !!form.ev && !!form.ev.location
                Text { text: "LOCAL"; color: Theme.statik; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 3 }
                Text { width: parent.width; wrapMode: Text.WordWrap; text: form.ev ? form.ev.location || "" : ""; color: Theme.bone; font.family: Theme.sans; font.pixelSize: 15 }
            }
            Column {
                width: parent.width
                spacing: 6
                visible: !!form.ev && !!form.ev.description
                Text { text: "DESCRIÇÃO"; color: Theme.statik; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 3 }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    maximumLineCount: 8; elide: Text.ElideRight
                    text: form.ev ? form.ev.description || "" : ""
                    color: Theme.bone; font.family: Theme.sans; font.pixelSize: 14
                    textFormat: Text.PlainText
                }
            }
            Text {
                visible: !!form.ev && (form.ev.booking || form.ev.allDay)
                width: parent.width; wrapMode: Text.WordWrap
                text: !form.ev ? "" : form.ev.booking
                    ? "Reserva da página pública: remarcar é pelo link da reserva; excluir aqui cancela e avisa o visitante."
                    : "Evento de dia inteiro: dá pra excluir aqui; para editar, abra no Google."
                color: Qt.alpha(Theme.statik, 0.85); font.family: Theme.mono; font.pixelSize: 10
            }
            // ações
            Item {
                width: parent.width; height: 34
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Badge {
                        visible: !!form.ev && !!form.ev.meetUrl
                        text: "entrar no meet ↗"; on: true
                        onClicked: Qt.openUrlExternally(form.ev.meetUrl)
                    }
                    Badge {
                        visible: !!form.ev && !!form.ev.htmlLink
                        text: "abrir no google ↗"
                        onClicked: Qt.openUrlExternally(form.ev.htmlLink)
                    }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Badge {
                        visible: !!form.ev && !!form.ev.id
                        text: form.busy && form.action === "delete" ? "excluindo…" : form.confirmDelete ? "confirmar exclusão" : "excluir"
                        // coral: excluir é a ação perigosa
                        color: form.confirmDelete ? Theme.alert : (hovered ? Theme.graphite : Theme.void_)
                        border.color: form.confirmDelete || hovered ? Theme.alert : Theme.line
                        label.color: form.confirmDelete ? Theme.void_ : (hovered ? Theme.alert : Theme.statik)
                        onClicked: form.remove()
                    }
                    Badge { visible: form.canEdit; text: "editar"; on: true; onClicked: form.startEdit() }
                }
            }
            Text {
                width: parent.width
                text: form.error || (form.ev && !form.ev.id ? "Atualizando a agenda… feche e abra de novo em instantes para editar." : "e edita  ·  delete exclui  ·  esc fecha")
                color: form.error ? Theme.alert : Qt.alpha(Theme.statik, 0.7)
                font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1
                wrapMode: Text.WordWrap
            }
        }

        // ---------------------------------------------- modos NOVO / EDITAR (formulário)
        Column {
            id: body
            visible: form.mode !== "view"
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
                        text: form.mode === "edit" ? "EDITAR EVENTO" : "NOVO EVENTO"; color: Theme.bone
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
                    Badge { text: form.mode === "edit" ? "voltar" : "cancelar"; onClicked: form.mode === "edit" ? (form.mode = "view") : form.close() }
                    Badge {
                        text: form.busy ? "salvando…" : form.mode === "edit" ? "salvar ↗" : "criar evento ↗"
                        on: true; onClicked: form.submit()
                    }
                }
            }

            Text {
                width: parent.width
                text: form.error || "ctrl+enter salva  ·  esc fecha  ·  enter vai pro próximo campo"
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
