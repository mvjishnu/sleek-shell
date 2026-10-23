import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// IPC for monitor-scoped workspace keys: SUPER+N / SUPER+SHIFT+N / SUPER+X / SUPER+Z.
// "N" is the Nth workspace of the monitor that currently has focus, so the key never jumps monitors.
Scope {
    IpcHandler {
        target: "ws"
        function goto(n: int): void { Wm.gotoNth(n) }
        function move(n: int): void { Wm.moveActiveNth(n) }
        function next(): void { Wm.stepWs("", 1) }
        function prev(): void { Wm.stepWs("", -1) }
    }
}
