// SDDM — tema "eliasolie": login minimalista, sólido, cantos retos, destaque lima.
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.void || "#050505"

    readonly property color cVoid:   config.void     || "#050505"
    readonly property color cLine:   config.line     || "#2A2A27"
    readonly property color cStatic: config.static   || "#8A8A84"
    readonly property color cBone:   config.bone     || "#EDEDE8"
    readonly property color cSignal: config.signal   || "#C8F031"
    readonly property color cAlert:  config.alert    || "#FF5A4E"
    readonly property string mono:   "JetBrainsMono Nerd Font"

    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string sessionName: ""
    property bool failed: false

    function doLogin() {
        if (passwordField.text.length === 0) return
        failed = false
        sddm.login(userField.text, passwordField.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.failed = true
            passwordField.text = ""
            passwordField.forceActiveFocus()
            shake.start()
        }
    }

    Image {
        anchors.fill: parent
        source: config.background || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // Nome das sessões (Hyprland, etc.) — lido do modelo sem precisar de delegate visível
    Repeater {
        id: sessions
        model: sessionModel
        delegate: Item {
            required property int index
            required property string name
            Component.onCompleted: if (index === root.sessionIndex) root.sessionName = name
        }
    }

    // Marca no canto
    Row {
        anchors { left: parent.left; top: parent.top; margins: 40 }
        spacing: 10
        Rectangle { width: 8; height: 8; color: root.cSignal; anchors.verticalCenter: parent.verticalCenter }
        Text { text: sddm.hostName; color: root.cStatic; font.family: root.mono; font.pixelSize: 13; font.letterSpacing: 2 }
    }

    // Bloco central
    Column {
        id: center
        anchors.centerIn: parent
        spacing: 0
        width: 360

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.cBone
            font.family: "Archivo"
            font.pixelSize: 150
            font.weight: Font.ExtraBold
            font.variableAxes: { "wdth": 62 }
            text: Qt.formatTime(new Date(), "HH:mm")
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm") }
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.cStatic
            font.family: root.mono
            font.pixelSize: 13
            font.letterSpacing: 2
            text: Qt.locale("pt_BR").toString(new Date(), "dddd, d 'de' MMMM").toUpperCase()
        }

        Item { width: 1; height: 70 }

        // Usuário
        TextField {
            id: userField
            width: parent.width
            text: userModel.lastUser
            color: root.cStatic
            font.family: root.mono
            font.pixelSize: 14
            horizontalAlignment: TextInput.AlignHCenter
            placeholderText: "usuário"
            placeholderTextColor: root.cLine
            background: Item {}
            selectByMouse: true
            KeyNavigation.tab: passwordField
            onAccepted: passwordField.forceActiveFocus()
        }

        Item { width: 1; height: 8 }

        // Senha: só uma linha embaixo
        Item {
            id: passBox
            width: parent.width
            height: 46

            TextField {
                id: passwordField
                anchors.fill: parent
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: root.cBone
                font.family: root.mono
                font.pixelSize: 16
                font.letterSpacing: 4
                horizontalAlignment: TextInput.AlignHCenter
                placeholderText: "senha"
                placeholderTextColor: root.cStatic
                background: Item {}
                focus: true
                KeyNavigation.backtab: userField
                onAccepted: root.doLogin()
                onTextChanged: if (text.length > 0) root.failed = false
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 2
                color: root.failed ? root.cAlert : (passwordField.activeFocus ? root.cSignal : root.cLine)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: passBox; property: "x"; to: -10; duration: 50 }
                NumberAnimation { target: passBox; property: "x"; to: 10;  duration: 50 }
                NumberAnimation { target: passBox; property: "x"; to: -6;  duration: 50 }
                NumberAnimation { target: passBox; property: "x"; to: 0;   duration: 50 }
            }
        }

        Item { width: 1; height: 14 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.cAlert
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 2
            text: root.failed ? "SENHA INCORRETA" : (keyboard.capsLock ? "CAPS LOCK LIGADO" : " ")
        }
    }

    // Rodapé esquerdo: sessão (clique para alternar)
    Text {
        id: sessionLabel
        anchors { left: parent.left; bottom: parent.bottom; margins: 40 }
        color: sessionMouse.containsMouse ? root.cBone : root.cStatic
        font.family: root.mono
        font.pixelSize: 12
        font.letterSpacing: 1
        text: "sessão  " + root.sessionName.toLowerCase()
        MouseArea {
            id: sessionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                // NameRole do SessionModel do SDDM = Qt.UserRole + 4
                root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount()
                root.sessionName = sessionModel.data(sessionModel.index(root.sessionIndex, 0), Qt.UserRole + 4) || root.sessionName
            }
        }
    }

    // Rodapé direito: energia
    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: 40 }
        spacing: 28

        Repeater {
            model: [
                { label: "suspender", ok: sddm.canSuspend,  run: function() { sddm.suspend() } },
                { label: "reiniciar", ok: sddm.canReboot,   run: function() { sddm.reboot() } },
                { label: "desligar",  ok: sddm.canPowerOff, run: function() { sddm.powerOff() } }
            ]
            delegate: Text {
                required property var modelData
                visible: modelData.ok
                color: pm.containsMouse ? root.cSignal : root.cStatic
                font.family: root.mono
                font.pixelSize: 12
                font.letterSpacing: 1
                text: modelData.label
                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.run() }
            }
        }
    }

    Component.onCompleted: passwordField.forceActiveFocus()
}
