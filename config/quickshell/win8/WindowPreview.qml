import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Rectangle {
    id:card
    required property var shell
    required property var window
    property bool selected:false
    readonly property bool hasPreview:capture.hasContent
    signal activated()
    color:mouse.containsMouse || selected ? Theme.secondary : Theme.surface
    clip:true
    Rectangle {width:4;height:parent.height;visible:card.selected;color:Theme.accent;z:2}
    ColumnLayout {
        anchors.fill:parent;anchors.margins:10;spacing:8
        Item {
            Layout.fillWidth:true;Layout.fillHeight:true
            ScreencopyView {
                id:capture
                anchors.centerIn:parent
                width:Math.min(parent.width,parent.height*(sourceSize.width>0 ? sourceSize.width/sourceSize.height : 1.6))
                height:width/(sourceSize.width>0 ? sourceSize.width/sourceSize.height : 1.6)
                captureSource:card.visible ? card.window?.wayland || null : null
                live:false;paintCursor:false;constraintSize:Qt.size(360,200)
                onHasContentChanged:if(hasContent)console.debug("Window preview ready")
            }
            Image {visible:!capture.hasContent;anchors.centerIn:parent;width:40;height:40;source:Quickshell.iconPath(card.shell.appForWindow(card.window)?.icon || "application-x-executable","application-x-executable")}
        }
        Text {text:card.shell.cleanTitle(card.window?.title || "");Layout.fillWidth:true;maximumLineCount:1;elide:Text.ElideRight;color:Theme.foreground;font.family:Theme.font;font.pixelSize:14}
        Text {text:I18n.tr("Desktop")+" "+(card.window?.workspace?.id || "")+" · "+(card.window?.monitor?.name || "");Layout.fillWidth:true;elide:Text.ElideRight;color:Theme.muted;font.pixelSize:11}
    }
    MouseArea {id:mouse;anchors.fill:parent;hoverEnabled:true;onClicked:card.activated()}
}
