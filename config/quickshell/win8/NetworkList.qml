import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking

ColumnLayout {
    id: list
    required property var shell
    property string kind: "wifi"
    spacing:12
    MetroButton {
        Layout.fillWidth:true
        text:I18n.tr(list.kind === "wifi" ? (Networking.wifiEnabled ? "Wi-Fi включён" : "Включить Wi-Fi") : (list.shell.adapter?.enabled ? "Bluetooth включён" : "Включить Bluetooth"))
        selected:list.kind === "wifi" ? Networking.wifiEnabled : (list.shell.adapter?.enabled || false)
        enabled:list.kind === "wifi" ? list.shell.wifiDevices.length>0 : !!list.shell.adapter
        onClicked: {if(list.kind === "wifi")Networking.wifiEnabled=!Networking.wifiEnabled;else list.shell.adapter.enabled=!list.shell.adapter.enabled;}
    }
    Text {Layout.fillWidth:true;wrapMode:Text.Wrap;color:Theme.muted;font.family:Theme.font;font.pixelSize:14;text:I18n.tr(list.kind === "wifi" ? "Сохранённые сети подключаются через NetworkManager. Для новой сети пароль запрашивает nmcli." : "Сопряжение новых устройств открывает Bluetooth Manager; пароли не сохраняются оболочкой.")}
    MetroButton {
        visible:list.kind === "bluetooth" && !!list.shell.adapter && list.shell.adapter.enabled
        Layout.fillWidth:true;text:I18n.tr(list.shell.adapter?.discovering ? "Остановить поиск" : "Искать устройства")
        onClicked:list.shell.adapter.discovering=!list.shell.adapter.discovering
    }
    Repeater {
        model:list.kind === "wifi" && Networking.wifiEnabled ? list.shell.wifiDevices : []
        ColumnLayout {
            required property var modelData
            Layout.fillWidth:true
            Repeater {
                model:modelData.networks
                MetroButton {
                    required property var modelData
                    Layout.fillWidth:true;text:I18n.tr(modelData.name+"  ·  "+(modelData.connected ? "Подключено" : Math.round(modelData.signalStrength*100)+"%"))
                    selected:modelData.connected
                    onClicked: {
                        if(modelData.connected)modelData.disconnect();
                        else if(modelData.known)modelData.connect();
                        else list.shell.launch(["kitty","-e","nmcli","--ask","device","wifi","connect",modelData.name]);
                    }
                }
            }
        }
    }
    Repeater {
        model:list.kind === "bluetooth" && list.shell.adapter?.enabled ? list.shell.adapter.devices : []
        MetroButton {
            required property var modelData
            Layout.fillWidth:true
            text:I18n.tr(modelData.name+" · "+(modelData.connected ? "Подключено" : modelData.paired ? "Сопряжено" : "Доступно"))
            selected:modelData.connected
            onClicked: {if(modelData.connected)modelData.disconnect();else if(modelData.paired)modelData.connect();else list.shell.launch(["blueman-manager"]);}
        }
    }
    MetroButton {visible:list.kind === "bluetooth";Layout.fillWidth:true;text:I18n.tr("Управление сопряжением");onClicked:list.shell.launch(["blueman-manager"])}
}
