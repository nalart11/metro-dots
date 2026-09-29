import QtQuick
import QtQuick.Controls
GridView {
    id:view
    required property var shell
    model:visible ? shell.switchOrder : []
    cellWidth:Math.max(240,Math.floor(width/Math.max(1,Math.floor(width/320))))
    cellHeight:230;clip:true
    ScrollBar.vertical:ScrollBar {}
    onVisibleChanged:if(visible)positionViewAtIndex(shell.selectedWindow,GridView.Contain)
    Connections {target:view.shell;function onSelectedWindowChanged(){view.positionViewAtIndex(view.shell.selectedWindow,GridView.Contain);}}
    Shortcut {sequences:["Tab","Alt+Tab"];enabled:view.visible;onActivated:view.shell.stepSwitch(1)}
    Shortcut {sequences:["Shift+Tab","Alt+Shift+Tab"];enabled:view.visible;onActivated:view.shell.stepSwitch(-1)}
    delegate:WindowPreview {
        required property var modelData
        required property int index
        width:GridView.view.cellWidth-14;height:216;shell:view.shell;window:modelData
        selected:index===view.shell.selectedWindow
        onActivated:view.shell.focusWindow(modelData)
    }
}
