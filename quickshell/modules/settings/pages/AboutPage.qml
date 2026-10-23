import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components
import qs.modules.settings

SettingsPage {
    id: ab
    title: "About Sleek Shell"
    subtitle: "Your Hyprland + Quickshell desktop, unified."
    property string info: ""
    Process {
        running: true
        command: ["sh", "-c", "printf 'Kernel  %s\\nHyprland  %s\\nQuickshell  %s\\nGPU  %s\\n' \"$(uname -r)\" \"$(hyprctl version -j 2>/dev/null | sed -n 's/.*\"tag\": *\"\\([^\"]*\\)\".*/\\1/p' | head -n1)\" \"$(quickshell --version 2>/dev/null | head -n1 | sed 's/^quickshell //')\" \"$(lspci 2>/dev/null | grep -Ei 'vga|3d' | sed 's/.*: //' | paste -sd ';' -)\""]
        stdout: StdioCollector { onStreamFinished: ab.info = text.trim() }
    }

    SettingsSection {
        title: "System"
        Text { Layout.fillWidth: true; text: ab.info || "…"; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; wrapMode: Text.WordWrap; lineHeight: 1.3 }
    }
    SettingsSection {
        title: "Where things live"
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap; lineHeight: 1.3
            color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontMd
            text: "Settings  ~/.config/sleek-shell/  (appearance.json, settings.json, themes.json, keybinds.json)\n" +
                  "Shell  ~/.config/quickshell/  (services, components, modules)\n" +
                  "Compositor  ~/.config/hypr/  (sleekshell/ layers on top of your modules)\n" +
                  "Docs, greeter, uninstaller  ~/.local/share/sleek-shell/"
        }
    }
    SettingsSection {
        title: "Maintenance"
        RowLayout {
            spacing: 8
            UiBtn { label: "Reload shell"; code: Theme.ic.refresh; onClicked: Quickshell.reload(true) }
            UiBtn { label: "Reload Hyprland"; code: Theme.ic.refresh; onClicked: Sys.run(["hyprctl", "reload"]) }
            UiBtn { label: "Open Sleek Shell folder"; code: Theme.ic.folder; onClicked: { Ui.closeSettings(); Sys.run(["xdg-open", Quickshell.env("HOME") + "/.local/share/sleek-shell"]) } }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm
            text: "Uninstall: ~/.local/share/sleek-shell/uninstall.sh restores the files the installer backed up (see docs/UNINSTALL.md)."
        }
    }
}
