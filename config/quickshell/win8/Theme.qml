pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id: t
    property var data: ({})
    readonly property bool light: data.mode === "light"
    readonly property color background: light ? "#edf0f4" : (data.background || "#171b26")
    readonly property color surface: light ? "#ffffff" : (data.surface || "#222735")
    readonly property color secondary: light ? "#dce2eb" : (data.surfaceSecondary || "#303849")
    readonly property color accent: data.accent || "#0078d4"
    readonly property color foreground: light ? "#172235" : (data.foreground || "#f5f6fa")
    readonly property color muted: light ? "#526078" : (data.muted || "#aeb6c6")
    readonly property color danger: data.danger || "#c42b1c"
    readonly property color success: data.success || "#16865b"
    readonly property string font: data.font || "Adwaita Sans"
    FileView {
        path: (Quickshell.env("HYPR_WIN8_DATA") || Quickshell.env("HOME") + "/.config/hypr-win8") + "/theme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { t.data = JSON.parse(text()); } catch(e) { console.error("Theme JSON: " + e); } }
    }
}
