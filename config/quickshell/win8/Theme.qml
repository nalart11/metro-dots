pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id: t
    property var data: ({})
    readonly property bool light: data.mode === "light"
    readonly property var colors:data.palettes?.[light ? "light" : "dark"] || data
    readonly property color onAccent:colors.onAccent || "white"
    readonly property color background: colors.background || (light ? "#edf0f4" : "#171b26")
    readonly property color surface: colors.surface || (light ? "#ffffff" : "#222735")
    readonly property color secondary: colors.surfaceSecondary || (light ? "#dce2eb" : "#303849")
    readonly property color accent: colors.accent || "#0078d4"
    readonly property color foreground: colors.foreground || (light ? "#172235" : "#f5f6fa")
    readonly property color muted: colors.muted || (light ? "#526078" : "#aeb6c6")
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
