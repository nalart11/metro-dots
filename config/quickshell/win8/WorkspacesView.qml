import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
GridView {
    id:view
    required property var shell
    property bool dragging:false
    property var dragWindow:null
    property point dragStart:Qt.point(0,0)
    property var contextWindow:null
    readonly property var cards:shell.workspaceCards
    function geometryReport(){return visible ? Array.from(contentItem.children).filter(c => c.previewScene).map(c => c.previewScene.geometryReport()) : [];}
    model:visible ? cards : []
    cellWidth:Math.max(320,Math.floor(width/Math.max(1,Math.floor(width/500))))
    cellHeight:cellWidth*.62+66;clip:true
    ScrollBar.vertical:ScrollBar {}
    function beginWindowDrag(window,point){dragWindow=window;dragStart=point;ghost.x=point.x-ghost.width/2;ghost.y=point.y-ghost.height/2;}
    function updateWindowDrag(point){if(!dragWindow)return;if(Math.abs(point.x-dragStart.x)+Math.abs(point.y-dragStart.y)>8)dragging=true;if(dragging){ghost.x=point.x-ghost.width/2;ghost.y=point.y-ghost.height/2;}}
    function finishWindowDrag(){const moved=dragging;if(moved)ghost.Drag.drop();cancelWindowDrag();return moved;}
    function cancelWindowDrag(){dragging=false;dragWindow=null;}
    function showMoveMenu(window,point){contextWindow=window;moveMenu.popup(view,point.x,point.y);}
    onVisibleChanged:if(!visible){cancelWindowDrag();moveMenu.close();}
    Connections {target:view.shell;function onSelectedWorkspaceChanged(){view.positionViewAtIndex(view.shell.selectedWorkspace,GridView.Contain);}}
    Rectangle {
        id:ghost;parent:view;z:100000;width:180;height:66;visible:view.dragging;color:Theme.accent
        property var window:view.dragWindow
        Drag.active:view.dragging;Drag.keys:["metro-window"];Drag.source:ghost
        Drag.supportedActions:Qt.MoveAction;Drag.proposedAction:Qt.MoveAction
        Drag.hotSpot.x:width/2;Drag.hotSpot.y:height/2
        Text {anchors.fill:parent;anchors.margins:12;text:view.shell.cleanTitle(ghost.window?.title || "");color:Theme.onAccent;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;font.pixelSize:13}
    }
    Menu {
        id:moveMenu;width:280;popupType:Popup.Item
        onOpened:menuExpiry.restart();onClosed:menuExpiry.stop()
        Timer {id:menuExpiry;interval:4500;onTriggered:moveMenu.close()}
        background:Rectangle {color:Theme.surface}
        MenuItem {text:view.shell.cleanTitle(view.contextWindow?.title || "");enabled:false}
        Instantiator {
            model:view.cards
            delegate:MenuItem {
                required property var modelData
                text:I18n.tr("Move to")+" "+I18n.tr("Desktop")+" "+modelData.id
                enabled:view.contextWindow?.workspace?.id!==modelData.id
                onTriggered:view.shell.moveWindow(view.contextWindow,modelData.id)
            }
            onObjectAdded:(index,object) => moveMenu.insertItem(index+1,object)
            onObjectRemoved:(index,object) => moveMenu.removeItem(object)
        }
    }
    delegate:Rectangle {
        id:card
        required property var modelData
        required property int index
        property alias previewScene:scenePreview
        width:GridView.view.cellWidth-18;height:GridView.view.cellHeight-18;color:Theme.surface
        Rectangle {width:4;height:parent.height;color:Theme.accent;visible:card.index===view.shell.selectedWorkspace;z:1}
        ColumnLayout {
            anchors.fill:parent;anchors.margins:10;spacing:8
            MetroButton {Layout.fillWidth:true;showFocus:false;focusPolicy:Qt.NoFocus;selected:card.index===view.shell.selectedWorkspace;text:I18n.tr("Desktop")+" "+card.modelData.id+(card.modelData.empty ? " +" : " · "+(card.modelData.monitor?.name || ""));onClicked:view.shell.focusWorkspace(card.modelData)}
            WorkspaceScene {id:scenePreview;Layout.fillWidth:true;Layout.fillHeight:true;shell:view.shell;workspace:card.modelData;controller:view;previewIndex:card.index}
        }
    }
    footer:Label {width:view.width;height:44;text:I18n.tr("Click a window to open it. Drag windows to another desktop; right-click to move.");color:Theme.muted;wrapMode:Text.Wrap;font.pixelSize:14}
}
