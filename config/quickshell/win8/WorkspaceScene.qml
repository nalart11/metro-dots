import QtQuick
import Quickshell
import Quickshell.Wayland
import "WorkspaceGeometry.js" as Geometry
Rectangle {
    id:preview
    required property var shell
    required property var workspace
    required property var controller
    property int previewIndex:0
    readonly property var monitor:workspace.monitor || null
    readonly property var screen:shell.screenForMonitor(monitor?.name)
    readonly property var viewport:Geometry.viewport(monitor?.lastIpcObject || {},screen ? {width:screen.width,height:screen.height} : null)
    readonly property var windows:shell.windows.filter(w => w.workspace?.id===workspace.id)
    readonly property real sceneScale:Geometry.fit(width,height,viewport)
    color:Theme.background;clip:true
    objectName:"workspace-scene-"+workspace.id
    function geometryReport(){
        const origin=mapToItem(null,0,0);
        return {workspace:workspace.id,x:origin.x,y:origin.y,width:width,height:height,windows:windows.map(w => {
            const g=Geometry.rectangle(w.lastIpcObject,viewport);
            return {address:w.address,x:origin.x+scene.x+g.x*sceneScale,y:origin.y+scene.y+g.y*sceneScale,width:g.width*sceneScale,height:g.height*sceneScale};
        })};
    }
    Item {
        id:scene
        x:(preview.width-width*scale)/2;y:(preview.height-height*scale)/2
        width:preview.viewport.width;height:preview.viewport.height
        scale:preview.sceneScale;transformOrigin:Item.TopLeft;clip:true
        Image {anchors.fill:parent;source:preview.shell.wallpaperUrl();sourceSize:Qt.size(640,400);fillMode:Theme.data.wallpaperFit === "stretch" ? Image.Stretch : Theme.data.wallpaperFit === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop}
        MouseArea {anchors.fill:parent;onClicked:preview.shell.focusWorkspace(preview.workspace)}
        Repeater {
            model:preview.windows
            Rectangle {
                id:windowProxy
                required property var modelData
                readonly property var geometry:Geometry.rectangle(modelData.lastIpcObject,preview.viewport)
                x:geometry.x;y:geometry.y;width:geometry.width;height:geometry.height
                z:10000-(modelData.lastIpcObject.focusHistoryID ?? 999)
                color:Theme.surface;clip:true
                objectName:"overview-window-"+modelData.address
                ScreencopyView {
                    id:capture;anchors.fill:parent;captureSource:preview.visible ? windowProxy.modelData.wayland || null : null
                    live:false;paintCursor:false;constraintSize:Qt.size(640,400)
                }
                Image {visible:!capture.hasContent;anchors.centerIn:parent;width:Math.min(70,parent.width*.2);height:width;source:Quickshell.iconPath(preview.shell.appForWindow(windowProxy.modelData)?.icon || "application-x-executable","application-x-executable")}
                Rectangle {visible:windowMouse.containsMouse;anchors.fill:parent;color:"transparent";border.width:Math.max(1,1/preview.sceneScale);border.color:Theme.accent}
                Rectangle {
                    visible:windowMouse.containsMouse;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
                    height:Math.min(parent.height,28/preview.sceneScale);color:Theme.surface
                    Text {anchors.fill:parent;anchors.margins:5/preview.sceneScale;text:preview.shell.cleanTitle(windowProxy.modelData.title);color:Theme.foreground;font.pixelSize:12/preview.sceneScale;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter}
                }
                MouseArea {
                    id:windowMouse;anchors.fill:parent;hoverEnabled:true;preventStealing:true;acceptedButtons:Qt.LeftButton|Qt.RightButton
                    property point start
                    onPressed:mouse => {start=mapToItem(preview.controller,mouse.x,mouse.y);preview.controller.beginWindowDrag(windowProxy.modelData,start);}
                    onPositionChanged:mouse => {if(pressed && (pressedButtons & Qt.LeftButton))preview.controller.updateWindowDrag(mapToItem(preview.controller,mouse.x,mouse.y));}
                    onReleased:mouse => {
                        if(mouse.button === Qt.RightButton){preview.controller.cancelWindowDrag();preview.controller.showMoveMenu(windowProxy.modelData,mapToItem(preview.controller,mouse.x,mouse.y));}
                        else if(!preview.controller.finishWindowDrag())preview.shell.focusWindow(windowProxy.modelData);
                    }
                    onCanceled:preview.controller.cancelWindowDrag()
                }
            }
        }
        Rectangle {anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:48;color:Theme.surface;z:20000
            Rectangle {width:64;height:parent.height;color:Theme.accent
                Image {anchors.centerIn:parent;width:26;height:26;source:preview.shell.iconUrl("linux")}
            }
        }
    }
    DropArea {
        id:target;anchors.fill:parent;keys:["metro-window"]
        onDropped:drop => {if(drop.source.window && drop.source.window.workspace?.id!==preview.workspace.id){preview.shell.moveWindow(drop.source.window,preview.workspace.id);drop.acceptProposedAction();}}
    }
    Rectangle {anchors.fill:parent;visible:target.containsDrag;color:Theme.accent;opacity:.22}
    Text {visible:preview.windows.length===0;anchors.centerIn:parent;text:I18n.tr("Empty workspace");color:Theme.foreground;font.pixelSize:16}
}
