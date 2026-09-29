import QtQuick
import QtQuick.Controls

Menu {
    id: menu
    required property var shell
    property var app: null
    property var tile: null
    property var window:null
    popupType:Popup.Window
    onOpened:expiry.restart()
    onClosed:expiry.stop()
    onCurrentIndexChanged:if(opened)expiry.restart()
    Timer {id:expiry;interval:4500;onTriggered:menu.close()}
    width:272;padding:4
    background:Rectangle {color:Theme.surface;border.width:1;border.color:Theme.secondary}
    component Entry: MenuItem {
        id:entry
        implicitHeight:42
        background:Rectangle {color:entry.highlighted ? Theme.accent : "transparent"}
        contentItem:Text {text:I18n.tr(entry.text);color:entry.highlighted ? Theme.onAccent : Theme.foreground;font.family:Theme.font;font.pixelSize:14;verticalAlignment:Text.AlignVCenter}
    }
    Entry {text:I18n.tr("Открыть");enabled:!!menu.app || !!menu.window;onTriggered:{if(menu.window)menu.shell.focusWindow(menu.window);else menu.shell.launchApp(menu.app);}}
    Entry {text:I18n.tr(menu.shell.isStartPinned(menu.app?.id || "") ? "Открепить от Пуска" : "Закрепить на Пуске");enabled:!!menu.app;onTriggered:menu.shell.backend("pin",["start",menu.app.id])}
    Entry {text:I18n.tr(menu.shell.isTaskbarPinned(menu.app?.id || "") ? "Открепить от панели задач" : "Закрепить на панели задач");enabled:!!menu.app;onTriggered:menu.shell.backend("pin",["taskbar",menu.app.id])}
    Repeater {
        model:menu.tile?.id ? [[1,1],[2,1],[1,2],[2,2]] : []
        Entry {
            required property var modelData
            text:modelData[0]+" × "+modelData[1]
            onTriggered:menu.shell.backend("tile-edit",[menu.tile.id,String(Math.min(menu.tile.x,4-modelData[0])),String(menu.tile.y),String(modelData[0]),String(modelData[1]),menu.tile.group])
        }
    }
}
