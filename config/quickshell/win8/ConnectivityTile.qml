import QtQuick
import QtQuick.Controls

Rectangle {
    id: tile
    property string title
    property string subtitle
    property string icon
    property bool enabledRadio: false
    signal toggleRadio()
    signal openDetails()
    implicitWidth:180; implicitHeight:142
    color:enabledRadio ? Theme.accent : Theme.secondary
    MouseArea {anchors.fill:parent;onClicked:tile.openDetails()}
    Rectangle {
        x:12;y:12;width:42;height:42;color:radioMouse.containsMouse ? "#35ffffff" : "#20ffffff"
        Image {anchors.centerIn:parent;width:26;height:26;source:tile.icon;sourceSize:Qt.size(26,26)}
        MouseArea {id:radioMouse;anchors.fill:parent;hoverEnabled:true;onClicked:tile.toggleRadio()}
    }
    Text {x:14;y:72;width:parent.width-28;text:tile.title;color:"white";font.family:Theme.font;font.pixelSize:20}
    Text {x:14;y:103;width:parent.width-28;text:tile.subtitle;color:"white";font.family:Theme.font;font.pixelSize:13;elide:Text.ElideRight}
    Text {anchors.right:parent.right;anchors.top:parent.top;anchors.margins:20;text:"›";color:"white";font.pixelSize:24}
}
