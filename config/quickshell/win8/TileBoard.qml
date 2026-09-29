import QtQuick
import QtQuick.Controls
import Quickshell

Flickable {
    id: board
    required property var shell
    property int unit:shell.zoomed ? 82 : Math.max(96,Math.min(154,(height-70)/4-10))
    readonly property int pitch:unit+10
    readonly property int stride:4*unit+74
    property bool pointerEdit:false
    signal contextMenu(var app,var tile)
    contentWidth:Math.max(width,shell.groups.length*stride-44)
    contentHeight:Math.max(height,...shell.tiles.map(t => (t.y+t.h)*pitch+header(t.group)))
    clip:true;interactive:!pointerEdit
    opacity:shell.appsTransition ? 0 : 1
    transform:Translate {y:shell.appsTransition ? -36 : 0}
    Behavior on opacity {NumberAnimation {duration:120}}
    ScrollBar.horizontal:ScrollBar {policy:ScrollBar.AsNeeded}
    ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
    WheelHandler {
        parent:board;target:null;acceptedDevices:PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel:event => {if(event.angleDelta.y !== 0 && !board.pointerEdit && !board.shell.editMode){event.accepted=true;board.shell.showAllApps();}else event.accepted=false;}
    }
    function header(group) {return group === "Daily" || group === "" ? 0 : 40;}
    function key(t) {return t.id || t.name+"|"+(t.desktop || t.live || "");}
    function sync() {
        const ids=shell.tiles.map(t => key(t));
        for(let i=tileModel.count-1;i>=0;i--)if(!ids.includes(tileModel.get(i).key))tileModel.remove(i);
        for(const info of shell.tiles) {
            const id=key(info);let index=-1;
            for(let i=0;i<tileModel.count;i++)if(tileModel.get(i).key===id){index=i;break;}
            if(index<0)tileModel.append({key:id,info:info});else tileModel.setProperty(index,"info",info);
        }
    }
    function commit(index,x,y,w,h,group) {
        const info=JSON.parse(JSON.stringify(tileModel.get(index).info));info.x=x;info.y=y;info.w=w;info.h=h;info.group=group;
        tileModel.setProperty(index,"info",info);
        shell.backend("tile-edit",[info.id,String(x),String(y),String(w),String(h),group]);
    }
    function foreground(color) {
        function linear(c){return c <= .04045 ? c/12.92 : Math.pow((c+.055)/1.055,2.4);}
        const lum=.2126*linear(color.r)+.7152*linear(color.g)+.0722*linear(color.b);
        return (1.05/(lum+.05) > (lum+.05)/.05) ? "white" : "black";
    }
    ListModel {id:tileModel;dynamicRoles:true}
    Component.onCompleted:sync()
    Connections {target:board.shell;function onTilesChanged(){board.sync();}}
    Repeater {
        model:board.shell.groups
        Text {
            required property string modelData
            required property int index
            visible:board.header(modelData)>0
            opacity:board.shell.chromeOpacity
            transform:Translate {x:board.shell.titleOffset}
            Behavior on opacity {NumberAnimation {duration:board.shell.closing || board.shell.appsTransition ? 60 : 0}}
            x:index*board.stride;y:0;text:I18n.tr(modelData);font.family:Theme.font;font.pixelSize:22;color:Theme.muted
        }
    }
    Repeater {
        model:tileModel
        Rectangle {
            id:tile
            required property string key
            required property var info
            required property int index
            readonly property int groupIndex:Math.max(0,board.shell.groups.indexOf(info.group))
            readonly property real cellX:groupIndex*board.stride+info.x*board.pitch
            readonly property real cellY:board.header(info.group)+info.y*board.pitch
            property bool dragging:false
            property bool resizing:false
            property bool pressFeedback:false
            property real dragX:0
            property real dragY:0
            property real resizeW:0
            property real resizeH:0
            property real slide:80+groupIndex*30
            property real alpha:0
            property color baseColor:info.color || Theme.accent
            x:dragging || resizing ? dragX : cellX;y:dragging || resizing ? dragY : cellY
            width:resizing ? resizeW : info.w*board.unit+(info.w-1)*10
            height:resizing ? resizeH : info.h*board.unit+(info.h-1)*10
            visible:info.live !== "battery" || board.shell.groups.includes(info.group) && board.shell.batteryAvailable
            color:tileMouse.containsMouse ? Qt.lighter(baseColor,1.12) : baseColor
            border.width:board.shell.editMode || dragging || resizing ? 2 : tileMouse.containsMouse ? 1 : 0
            border.color:board.foreground(baseColor)
            z:dragging || resizing ? 10 : 0
            opacity:alpha
            transform:Translate {x:tile.slide}
            Behavior on x {enabled:!tile.dragging && !tile.resizing;NumberAnimation {duration:180;easing.type:Easing.OutCubic}}
            Behavior on y {enabled:!tile.dragging && !tile.resizing;NumberAnimation {duration:180;easing.type:Easing.OutCubic}}
            Behavior on width {enabled:!tile.resizing;NumberAnimation {duration:180;easing.type:Easing.OutCubic}}
            Behavior on height {enabled:!tile.resizing;NumberAnimation {duration:180;easing.type:Easing.OutCubic}}
            function enter() {exitAnim.stop();alpha=0;slide=80+groupIndex*30;entrance.restart();}
            Component.onCompleted:enter()
            SequentialAnimation {
                id:entrance
                PauseAnimation {duration:80+Math.min(tile.groupIndex*2+Math.floor(tile.info.x/2),3)*15}
                ParallelAnimation {
                    NumberAnimation {target:tile;property:"slide";to:0;duration:220-Math.min(tile.groupIndex*2+Math.floor(tile.info.x/2),3)*15;easing.type:Easing.BezierSpline;easing.bezierCurve:[.1,.9,.2,1,1,1]}
                    NumberAnimation {target:tile;property:"alpha";to:1;duration:170}
                }
            }
            SequentialAnimation {
                id:exitAnim
                PauseAnimation {duration:60+Math.min(3,Math.max(0,board.shell.groups.length-1-tile.groupIndex))*15}
                ParallelAnimation {
                    NumberAnimation {target:tile;property:"slide";to:80;duration:145;easing.type:Easing.InCubic}
                    NumberAnimation {target:tile;property:"alpha";to:0;duration:145}
                }
            }
            Connections {
                target:board.shell
                function onClosingChanged(){if(board.shell.closing){entrance.stop();exitAnim.restart();}}
                function onTransitionSerialChanged(){if(board.shell.page === "start")tile.enter();}
            }
            Item {
                anchors.fill:parent
                scale:tileMouse.pressed && !tile.dragging || tile.pressFeedback ? .96 : 1
                Behavior on scale {NumberAnimation {duration:70}}
                Image {visible:!tile.info.live && !board.shell.zoomed;anchors.centerIn:parent;width:Math.min(60,parent.width*.4);height:width;source:Quickshell.iconPath(tile.info.icon || "preferences-system","application-x-executable");sourceSize:Qt.size(60,60)}
                Text {
                    visible:!!tile.info.live;text:I18n.tr(board.shell.tileBody(tile.info));color:board.foreground(tile.baseColor);font.family:Theme.font
                    font.pixelSize:tile.info.live === "clock" ? (tile.width<220 ? 21 : 32) : board.shell.zoomed ? 13 : 17
                    anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.bottom:caption.top;anchors.margins:14
                    wrapMode:Text.Wrap;maximumLineCount:6;elide:Text.ElideRight;clip:true
                }
                Text {id:caption;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:14;text:I18n.tr(tile.info.name);color:board.foreground(tile.baseColor);font.family:Theme.font;font.pixelSize:board.shell.zoomed ? 13 : 16;maximumLineCount:1;elide:Text.ElideRight}
            }
            Timer {id:launchTimer;interval:75;onTriggered:{tile.pressFeedback=false;board.shell.launchTile(tile.info);}}
            MouseArea {
                id:tileMouse;anchors.fill:parent;hoverEnabled:true;preventStealing:true;acceptedButtons:Qt.LeftButton|Qt.RightButton
                onWheel:wheel => {if(!board.pointerEdit && !board.shell.editMode && wheel.angleDelta.y !== 0){wheel.accepted=true;board.shell.showAllApps();}else wheel.accepted=false;}
                property point startPointer
                property point startTile
                onPressed:mouse => {startPointer=mapToItem(board.contentItem,mouse.x,mouse.y);startTile=Qt.point(tile.x,tile.y);}
                onPositionChanged:mouse => {
                    if(!pressed || !(pressedButtons & Qt.LeftButton))return;
                    const point=mapToItem(board.contentItem,mouse.x,mouse.y);const dx=point.x-startPointer.x,dy=point.y-startPointer.y;
                    if(Math.abs(dx)+Math.abs(dy)>9 || tile.dragging){tile.dragging=true;board.pointerEdit=true;tile.dragX=startTile.x+dx;tile.dragY=Math.max(0,startTile.y+dy);}
                }
                onReleased:mouse => {
                    if(tile.dragging) {
                        const gi=Math.max(0,Math.min(board.shell.groups.length-1,Math.floor((tile.dragX+tile.width*.5)/board.stride)));const group=board.shell.groups[gi];
                        const x=Math.max(0,Math.min(4-tile.info.w,Math.round((tile.dragX-gi*board.stride)/board.pitch)));const y=Math.max(0,Math.min(127,Math.round((tile.dragY-board.header(group))/board.pitch)));
                        board.commit(tile.index,x,y,tile.info.w,tile.info.h,group);tile.dragging=false;board.pointerEdit=false;
                    } else if(mouse.button === Qt.RightButton)board.contextMenu(board.shell.apps.find(a => a.id===board.shell.desktopKey(tile.info.desktop || "")) || null,tile.info);
                    else if(!board.shell.editMode){tile.pressFeedback=true;launchTimer.restart();}
                }
                onCanceled:{tile.dragging=false;board.pointerEdit=false;}
            }
            Rectangle {
                anchors.right:parent.right;anchors.bottom:parent.bottom;width:24;height:24
                visible:board.shell.editMode || tileMouse.containsMouse || resizeMouse.containsMouse || tile.resizing
                color:board.foreground(tile.baseColor)==="white" ? "#40ffffff" : "#40000000"
                Text {anchors.centerIn:parent;text:"↘";font.pixelSize:20;color:board.foreground(tile.baseColor)}
                MouseArea {
                    id:resizeMouse;anchors.fill:parent;hoverEnabled:true;preventStealing:true;cursorShape:Qt.SizeFDiagCursor
                    property point startPointer
                    property size startSize
                    onPressed:mouse => {startPointer=mapToItem(board.contentItem,mouse.x,mouse.y);startSize=Qt.size(tile.width,tile.height);tile.dragX=tile.x;tile.dragY=tile.y;tile.resizeW=tile.width;tile.resizeH=tile.height;tile.resizing=true;board.pointerEdit=true;}
                    onPositionChanged:mouse => {if(!pressed)return;const point=mapToItem(board.contentItem,mouse.x,mouse.y);tile.resizeW=Math.max(board.unit,Math.min(2*board.unit+10,startSize.width+point.x-startPointer.x));tile.resizeH=Math.max(board.unit,Math.min(2*board.unit+10,startSize.height+point.y-startPointer.y));}
                    onReleased:{const w=Math.max(1,Math.min(2,Math.round((tile.resizeW+10)/board.pitch))),h=Math.max(1,Math.min(2,Math.round((tile.resizeH+10)/board.pitch)));board.commit(tile.index,Math.min(tile.info.x,4-w),tile.info.y,w,h,tile.info.group);tile.resizing=false;board.pointerEdit=false;}
                    onCanceled:{tile.resizing=false;board.pointerEdit=false;}
                }
            }
        }
    }
}
