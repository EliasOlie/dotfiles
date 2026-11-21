pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Ponte IPC do indicador: qs ipc call osd popup volume 45 false
Singleton {
    id: root
    signal show(string kind, int value, bool muted)
    IpcHandler {
        target: "osd"
        function popup(kind: string, value: int, muted: bool): void { root.show(kind, value, muted) }
    }
}
