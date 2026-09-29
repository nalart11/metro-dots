import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
ColumnLayout {
    id:pane
    required property var shell
    property string error:""
    property int remaining:Math.max(0,Math.ceil((shell.displayTrial.deadline || 0)-Date.now()/1000))
    spacing:14
    Timer {interval:500;repeat:true;running:pane.visible && pane.shell.displayTrial.status === "pending";onTriggered:pane.remaining=Math.max(0,Math.ceil(pane.shell.displayTrial.deadline-Date.now()/1000))}
    Label {visible:!!pane.error;text:pane.error;color:Theme.danger;Layout.fillWidth:true;wrapMode:Text.Wrap}
    Label {visible:pane.shell.displayTrial.status === "pending";text:I18n.tr("Сохранить настройки экрана?")+" "+pane.remaining+" s";font.pixelSize:22;Layout.fillWidth:true;wrapMode:Text.Wrap}
    RowLayout {
        visible:pane.shell.displayTrial.status === "pending"
        MetroButton {text:I18n.tr("Сохранить");onClicked:pane.action("display-confirm",[pane.shell.displayTrial.token])}
        MetroButton {text:I18n.tr("Вернуть");onClicked:pane.action("display-revert",[pane.shell.displayTrial.token])}
    }
    function action(name,args){if(command.running)return;error="";command.command=["python3",shell.helper,name].concat(args);command.running=true;}
    Process {id:command;stderr:StdioCollector {onStreamFinished:pane.error=text.trim()} onExited:pane.shell.refreshDisplays()}
    Repeater {
        model:pane.shell.displays
        ColumnLayout {
            id:output
            required property var modelData
            readonly property var resolutions:[...new Set((modelData.modes || []).map(m => m.width+" × "+m.height))]
            readonly property var rates:(modelData.modes || []).filter(m => m.width+" × "+m.height === resolution.currentText)
            Layout.fillWidth:true;spacing:8
            Label {text:output.modelData.name+" · "+output.modelData.width+" × "+output.modelData.height+" · "+output.modelData.refreshRate.toFixed(2)+" Hz";font.pixelSize:20;Layout.fillWidth:true;wrapMode:Text.Wrap}
            Label {text:I18n.tr("Разрешение");color:Theme.muted}
            ComboBox {id:resolution;Layout.fillWidth:true;model:output.resolutions;currentIndex:Math.max(0,output.resolutions.indexOf(output.modelData.width+" × "+output.modelData.height))}
            Label {text:I18n.tr("Частота обновления");color:Theme.muted}
            ComboBox {id:refresh;Layout.fillWidth:true;model:output.rates.map(m => m.rate.toFixed(2)+" Hz");currentIndex:Math.max(0,output.rates.findIndex(m => Math.abs(m.rate-output.modelData.refreshRate)<.1))}
            Label {text:I18n.tr("Масштаб");color:Theme.muted}
            ComboBox {id:scale;Layout.fillWidth:true;model:["1","1.25","1.5","1.75","2","2.5","3"];currentIndex:Math.max(0,model.indexOf(String(output.modelData.scale)))}
            CheckBox {id:custom;text:I18n.tr("Собственный режим (CVT)")}
            RowLayout {
                visible:custom.checked
                TextField {id:customWidth;text:String(output.modelData.width);placeholderText:I18n.tr("Ширина");Layout.fillWidth:true;validator:IntValidator {bottom:320;top:16384}}
                Label {text:"×"}
                TextField {id:customHeight;text:String(output.modelData.height);placeholderText:I18n.tr("Высота");Layout.fillWidth:true;validator:IntValidator {bottom:200;top:16384}}
                TextField {id:customRate;text:String(Math.round(output.modelData.refreshRate));placeholderText:"Hz";Layout.fillWidth:true;validator:DoubleValidator {bottom:20;top:1000;locale:"C"}}
            }
            MetroButton {
                Layout.fillWidth:true;text:I18n.tr("Проверить режим на 20 секунд")
                enabled:!command.running && pane.shell.displayTrial.status !== "pending" && (!custom.checked || (customWidth.acceptableInput && customHeight.acceptableInput && customRate.acceptableInput))
                onClicked:{const mode=output.rates[refresh.currentIndex];pane.action("display-test",[output.modelData.name,custom.checked ? customWidth.text : String(mode.width),custom.checked ? customHeight.text : String(mode.height),custom.checked ? customRate.text : String(mode.rate),scale.currentText,String(custom.checked)]);}
            }
            Rectangle {Layout.fillWidth:true;implicitHeight:1;color:Theme.secondary}
        }
    }
    Label {text:I18n.tr("Если изображение пропадёт, прежний режим вернётся автоматически. Подтверждённые настройки сохраняются после входа.");color:Theme.muted;Layout.fillWidth:true;wrapMode:Text.Wrap}
    Label {text:I18n.tr("Растяжение всего рабочего стола: текущий NVIDIA Wayland backend и управление этих мониторов не предоставляют эту функцию. Соотношение сторон можно выбрать в меню самого монитора, если оно поддерживается.");color:Theme.muted;Layout.fillWidth:true;wrapMode:Text.Wrap}
}
