import QtQuick
import QtQuick.Controls

Menu {
    id: menu
    required property var shell
    property var app: null
    property var tile: null
    width:272;padding:4
    background:Rectangle {color:Theme.surface;border.width:1;border.color:Theme.secondary}
    component Entry: MenuItem {
        id:entry
        implicitHeight:42
        background:Rectangle {color:entry.highlighted ? Theme.accent : "transparent"}
        contentItem:Text {text:entry.text;color:Theme.foreground;font.family:Theme.font;font.pixelSize:14;verticalAlignment:Text.AlignVCenter}
    }
    Entry {text:"Открыть";enabled:!!menu.app;onTriggered:menu.shell.launchApp(menu.app)}
    Entry {text:menu.shell.isStartPinned(menu.app?.id || "") ? "Открепить от Пуска" : "Закрепить на Пуске";enabled:!!menu.app;onTriggered:menu.shell.backend("pin",["start",menu.app.id])}
    Entry {text:menu.shell.isTaskbarPinned(menu.app?.id || "") ? "Открепить от панели задач" : "Закрепить на панели задач";enabled:!!menu.app;onTriggered:menu.shell.backend("pin",["taskbar",menu.app.id])}
}
