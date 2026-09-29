import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
GridView {
    id:view
    required property var shell
    model:visible ? shell.workspaceOrder : []
    cellWidth:Math.max(320,Math.floor(width/Math.max(1,Math.floor(width/420))))
    cellHeight:330;clip:true
    ScrollBar.vertical:ScrollBar {}
    Shortcut {sequences:["Tab","Meta+Tab"];enabled:view.visible;onActivated:view.shell.stepSwitch(1)}
    Shortcut {sequences:["Shift+Tab","Meta+Shift+Tab"];enabled:view.visible;onActivated:view.shell.stepSwitch(-1)}
    Connections {target:view.shell;function onSelectedWorkspaceChanged(){view.positionViewAtIndex(view.shell.selectedWorkspace,GridView.Contain);}}
    delegate:Rectangle {
        id:workspace
        required property var modelData
        required property int index
        width:GridView.view.cellWidth-14;height:316;color:Theme.surface
        readonly property var windows:view.shell.windows.filter(w => w.workspace?.id===modelData.id)
        ColumnLayout {
            anchors.fill:parent;anchors.margins:12;spacing:10
            MetroButton {Layout.fillWidth:true;showFocus:false;focusPolicy:Qt.NoFocus;selected:workspace.index===view.shell.selectedWorkspace;text:I18n.tr("Desktop")+" "+workspace.modelData.id+" · "+(workspace.modelData.monitor?.name || "");onClicked:view.shell.focusWorkspace(workspace.modelData)}
            GridView {
                Layout.fillWidth:true;Layout.fillHeight:true;cellWidth:width/2;cellHeight:115;clip:true
                model:workspace.windows;ScrollBar.vertical:ScrollBar {}
                delegate:WindowPreview {required property var modelData;width:GridView.view.cellWidth-6;height:109;shell:view.shell;window:modelData;onActivated:view.shell.focusWindow(modelData)}
                Text {visible:workspace.windows.length===0;anchors.centerIn:parent;text:I18n.tr("Empty workspace");color:Theme.muted}
            }
            Text {visible:workspace.windows.length>4;text:"+ "+(workspace.windows.length-4);color:Theme.muted}
        }
    }
}
