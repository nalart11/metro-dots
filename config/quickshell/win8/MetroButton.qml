import QtQuick
import QtQuick.Controls
Button {
    id: b
    property color fill: Theme.secondary
    property bool selected: false
    implicitWidth: Math.max(90, contentItem.implicitWidth + 28)
    implicitHeight: 44
    font.family: Theme.font
    font.pixelSize: 15
    padding: 12
    background: Rectangle {
        color: b.down || b.selected ? Theme.accent : b.hovered ? Qt.lighter(b.fill, 1.25) : b.fill
        border.width: b.activeFocus ? 2 : 0
        border.color: Theme.foreground
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    contentItem: Text {
        text: b.text; color: b.selected ? "white" : Theme.foreground
        font: b.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
