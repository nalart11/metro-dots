import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire

ColumnLayout {
    id: pane
    required property var shell
    property bool outputs: false
    spacing:12
    Text {Layout.fillWidth:true;wrapMode:Text.Wrap;text:I18n.tr("Громкость · "+Math.round((pane.shell.sink?.audio?.volume || 0)*100)+"%");color:Theme.foreground;font.family:Theme.font;font.pixelSize:18}
    Text {Layout.fillWidth:true;wrapMode:Text.Wrap;text:I18n.tr(pane.shell.sink?.nickname || pane.shell.sink?.description || "Нет устройства вывода");color:Theme.muted;font.family:Theme.font;font.pixelSize:14}
    Slider {
        Layout.fillWidth:true;from:0;to:1;value:pane.shell.sink?.audio?.volume || 0
        onMoved:pane.shell.exec(["wpctl","set-volume","@DEFAULT_AUDIO_SINK@",value.toFixed(2),"--limit","1"])
        background:Rectangle {x:parent.leftPadding;y:parent.topPadding+parent.availableHeight/2-2;width:parent.availableWidth;height:4;color:Theme.secondary;Rectangle{width:parent.width*parent.parent.visualPosition;height:4;color:Theme.accent}}
        handle:Rectangle {x:parent.leftPadding+parent.visualPosition*(parent.availableWidth-width);y:parent.topPadding+parent.availableHeight/2-10;width:12;height:20;color:Theme.accent}
    }
    RowLayout {
        Layout.fillWidth:true
        MetroButton {Layout.fillWidth:true;text:I18n.tr(pane.shell.sink?.audio?.muted ? "Включить звук" : "Без звука");onClicked:pane.shell.exec(["wpctl","set-mute","@DEFAULT_AUDIO_SINK@","toggle"])}
        MetroButton {visible:!pane.outputs;text:I18n.tr("Вывод ›");onClicked:pane.shell.navigate("audio")}
    }
    Repeater {
        model:pane.outputs ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio) : []
        MetroButton {required property var modelData;Layout.fillWidth:true;text:I18n.tr(modelData.nickname || modelData.description);selected:modelData===pane.shell.sink;onClicked:pane.shell.exec(["wpctl","set-default",String(modelData.id)])}
    }
}
