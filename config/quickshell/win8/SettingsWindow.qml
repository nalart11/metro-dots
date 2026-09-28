import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: settings
    required property var shell
    property string section: "system"
    property string search: ""
    property string errorText: ""
    property string wallpaperCandidate: ""
    readonly property var sections: [
        {id:"system",name:"Система",hint:"Экран, яркость и ночной свет"},
        {id:"personalization",name:"Персонализация",hint:"Обои, цвета и оформление"},
        {id:"network",name:"Сеть и Интернет",hint:"Wi-Fi и подключения"},
        {id:"bluetooth",name:"Bluetooth",hint:"Устройства и сопряжение"},
        {id:"sound",name:"Звук",hint:"Громкость и устройства вывода"},
        {id:"apps",name:"Приложения",hint:"Закрепление на Пуске и панели задач"},
        {id:"about",name:"О системе",hint:"Ресурсы, версия и восстановление"}
    ]
    title:"Параметры — Metro"
    implicitWidth:Math.min(1060,(shell.activeScreen?.width || 1200)*.85)
    implicitHeight:Math.min(760,(shell.activeScreen?.height || 900)*.85)
    minimumSize:Qt.size(640,420)
    color:Theme.background
    visible:!shell.validation && shell.settingsVisible
    onClosed:shell.settingsVisible=false
    onSectionChanged: {errorText="";if(section === "system")shell.refreshDisplays();}
    function setWallpaper(url) {
        if(wallpaperProcess.running)return;
        errorText="";wallpaperProcess.command=["python3",shell.helper,"wallpaper",String(url)];wallpaperProcess.running=true;
    }
    Dialogs.FileDialog {
        id:wallpaperDialog
        title:"Выбрать обои"
        parentWindow:settings.contentItem.Window.window
        currentFolder:"file://"+settings.shell.home+"/Pictures"
        fileMode:Dialogs.FileDialog.OpenFile
        nameFilters:["Изображения (*.png *.jpg *.jpeg *.webp *.bmp *.svg *.gif)","Все файлы (*)"]
        options:Dialogs.FileDialog.ReadOnly
        onAccepted:settings.setWallpaper(selectedFile)
    }
    Process {
        id:wallpaperProcess
        stderr:StdioCollector {onStreamFinished:settings.errorText=text.trim()}
        onExited:(code,status) => {if(code===0){settings.wallpaperCandidate="";settings.errorText="";}}
    }
    component Label: Text {color:Theme.foreground;font.family:Theme.font;font.pixelSize:16;wrapMode:Text.Wrap;textFormat:Text.PlainText}
    component Field: TextField {
        color:Theme.foreground;placeholderTextColor:Theme.muted;font.family:Theme.font;font.pixelSize:15
        background:Rectangle {color:Theme.surface;border.color:parent.activeFocus ? Theme.accent : Theme.secondary;border.width:1}
        implicitHeight:44
    }
    RowLayout {
        anchors.fill:parent;spacing:0
        Rectangle {
            color:Theme.surface
            Layout.preferredWidth:settings.width < 800 ? 190 : 250
            Layout.fillHeight:true
            ColumnLayout {
                anchors.fill:parent;anchors.margins:20;spacing:12
                Label {text:"Параметры";font.pixelSize:30;Layout.fillWidth:true}
                Field {Layout.fillWidth:true;placeholderText:"Найти параметр";text:settings.search;onTextEdited:settings.search=text}
                Repeater {
                    model:settings.sections.filter(s => (s.name+" "+s.hint).toLowerCase().includes(settings.search.toLowerCase()))
                    MetroButton {
                        required property var modelData
                        Layout.fillWidth:true;implicitHeight:52;text:modelData.name;selected:settings.section===modelData.id;fill:Theme.surface;padding:8
                        onClicked:settings.section=modelData.id
                    }
                }
                Item {Layout.fillHeight:true}
                MetroButton {Layout.fillWidth:true;text:"Быстрые настройки";onClicked:settings.shell.toggle("settings")}
                Label {text:"Metro · Arch Linux";color:Theme.muted;font.pixelSize:12}
            }
        }
        ColumnLayout {
            Layout.fillWidth:true;Layout.fillHeight:true;Layout.margins:settings.width < 800 ? 22 : 34;spacing:22
            RowLayout {
                Layout.fillWidth:true
                Label {Layout.fillWidth:true;text:settings.sections.find(s => s.id===settings.section)?.name || "Параметры";font.pixelSize:34;font.weight:Font.Light}
                MetroButton {text:"×";implicitWidth:42;onClicked:settings.shell.settingsVisible=false}
            }
            Label {visible:settings.errorText.length>0;text:settings.errorText;color:Theme.danger;Layout.fillWidth:true}
            ScrollView {
                Layout.fillWidth:true;Layout.fillHeight:true;clip:true
                contentWidth:availableWidth
                Loader {
                    width:parent.width
                    sourceComponent:settings.section === "personalization" ? personalizationPage : settings.section === "network" ? networkPage : settings.section === "bluetooth" ? bluetoothPage : settings.section === "sound" ? soundPage : settings.section === "apps" ? appsPage : settings.section === "about" ? aboutPage : systemPage
                }
            }
        }
    }
    Component {
        id:personalizationPage
        ColumnLayout {
            spacing:18
            Label {text:"Фон рабочего стола";font.pixelSize:24}
            Rectangle {
                Layout.fillWidth:true;Layout.preferredHeight:Math.min(270,width*.5625);color:Theme.surface;clip:true
                Image {anchors.fill:parent;source:settings.shell.wallpaperUrl();fillMode:Theme.data.wallpaperFit === "fit" ? Image.PreserveAspectFit : Theme.data.wallpaperFit === "stretch" ? Image.Stretch : Image.PreserveAspectCrop;sourceSize:Qt.size(900,500);asynchronous:true}
            }
            Label {text:Theme.data.wallpaper || "metro-blue.svg";color:Theme.muted;font.pixelSize:13;Layout.fillWidth:true}
            MetroButton {objectName:"wallpaperBrowse";text:"Обзор файлов…";onClicked:wallpaperDialog.open()}
            RowLayout {
                Layout.fillWidth:true
                Field {id:wallpaperPath;objectName:"wallpaperPath";Layout.fillWidth:true;placeholderText:"Путь к изображению";text:settings.wallpaperCandidate;onTextEdited:settings.wallpaperCandidate=text;onAccepted:settings.setWallpaper(text)}
                MetroButton {text:"Применить";enabled:settings.wallpaperCandidate.trim().length>0;onClicked:settings.setWallpaper(settings.wallpaperCandidate)}
            }
            Label {text:"Размещение"}
            Flow {
                Layout.fillWidth:true;spacing:8
                Repeater {model:[{id:"fill",name:"Заполнение"},{id:"fit",name:"По размеру"},{id:"stretch",name:"Растянуть"}]
                    MetroButton {required property var modelData;text:modelData.name;selected:(Theme.data.wallpaperFit || "fill")===modelData.id;onClicked:settings.shell.backend("theme-option",["wallpaperFit",modelData.id])}
                }
            }
            Label {text:"Недавние и встроенные фоны"}
            Flow {
                Layout.fillWidth:true;spacing:8
                Repeater {
                    model:["metro-blue.svg","metro-purple.svg","metro-green.svg"].concat(Theme.data.wallpaperHistory || [])
                    MetroButton {
                        required property string modelData
                        width:112;height:72;fill:Theme.surface;padding:4
                        contentItem:Image {source:settings.shell.wallpaperUrl(modelData);fillMode:Image.PreserveAspectCrop;sourceSize:Qt.size(224,144)}
                        onClicked:settings.setWallpaper(modelData.startsWith("/") ? modelData : settings.shell.home+"/.local/share/hypr-win8-dots/assets/wallpapers/"+modelData)
                    }
                }
            }
            Label {text:"Цвета";font.pixelSize:24;Layout.topMargin:14}
            RowLayout {
                MetroButton {text:"Тёмный";selected:!Theme.light;onClicked:settings.shell.backend("theme",["dark"])}
                MetroButton {text:"Светлый";selected:Theme.light;onClicked:settings.shell.backend("theme",["light"])}
            }
            Flow {Layout.fillWidth:true;spacing:10
                Repeater {model:["#0078d4","#008ba8","#7441a0","#b25417","#16865b","#c42b1c"]
                    MetroButton {required property string modelData;width:48;implicitWidth:48;height:48;fill:modelData;selected:String(Theme.accent)===modelData;onClicked:settings.shell.backend("theme",[Theme.light ? "light" : "dark",modelData])}
                }
            }
        }
    }
    Component {id:networkPage;NetworkList {shell:settings.shell;kind:"wifi"}}
    Component {id:bluetoothPage;NetworkList {shell:settings.shell;kind:"bluetooth"}}
    Component {id:soundPage;AudioPane {shell:settings.shell;outputs:true}}
    Component {
        id:systemPage
        ColumnLayout {
            spacing:18
            Label {text:"Дисплеи";font.pixelSize:24}
            Repeater {
                model:settings.shell.displays
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth:true
                    Label {text:modelData.name+" · "+modelData.width+" × "+modelData.height+" · "+Math.round(modelData.refreshRate)+" Гц";Layout.fillWidth:true}
                    Flow {Layout.fillWidth:true;spacing:8
                        property string outputName:parent.modelData.name
                        Repeater {model:["1","1.25","1.5","2"]
                            MetroButton {required property string modelData;text:modelData+"×";implicitWidth:68;onClicked:settings.shell.backend("scale",[parent.outputName,modelData])}
                        }
                    }
                }
            }
            Label {visible:settings.shell.stats.brightness!==null;text:"Яркость"}
            Slider {visible:settings.shell.stats.brightness!==null;Layout.fillWidth:true;from:1;to:100;value:settings.shell.stats.brightness || 50;onMoved:settings.shell.exec(["brightnessctl","set",Math.round(value)+"%"])}
            MetroButton {text:settings.shell.night ? "Ночной свет включён" : "Включить ночной свет";selected:settings.shell.night;onClicked:settings.shell.toggleNight()}
            MetroButton {text:settings.shell.dnd ? "Не беспокоить включено" : "Включить «Не беспокоить»";selected:settings.shell.dnd;onClicked:settings.shell.dnd=!settings.shell.dnd}
            MetroButton {text:"Питание и завершение сеанса";onClicked:settings.shell.navigate("power")}
        }
    }
    Component {
        id:appsPage
        ColumnLayout {
            spacing:12
            Label {text:"Закрепление приложений";font.pixelSize:24}
            Label {text:"Закрепляйте приложения независимо на Пуске и панели задач. Эти же команды доступны по правой кнопке мыши.";color:Theme.muted;Layout.fillWidth:true}
            Field {id:appSearch;Layout.fillWidth:true;placeholderText:"Поиск приложения"}
            Repeater {
                model:settings.shell.apps.filter(a => a.name.toLowerCase().includes(appSearch.text.toLowerCase()))
                RowLayout {
                    id:appRow
                    required property var modelData
                    Layout.fillWidth:true
                    Image {source:Quickshell.iconPath(appRow.modelData.icon,"application-x-executable");sourceSize:Qt.size(32,32);Layout.preferredWidth:32;Layout.preferredHeight:32}
                    Label {text:appRow.modelData.name;Layout.fillWidth:true;maximumLineCount:1;elide:Text.ElideRight}
                    MetroButton {text:"Пуск";implicitWidth:70;selected:settings.shell.isStartPinned(appRow.modelData.id);onClicked:settings.shell.backend("pin",["start",appRow.modelData.id])}
                    MetroButton {text:"Панель";implicitWidth:78;selected:settings.shell.isTaskbarPinned(appRow.modelData.id);onClicked:settings.shell.backend("pin",["taskbar",appRow.modelData.id])}
                }
            }
        }
    }
    Component {
        id:aboutPage
        ColumnLayout {
            spacing:18
            Label {text:"Arch Linux · Hyprland · Quickshell";font.pixelSize:24;Layout.fillWidth:true}
            Label {text:"CPU: "+settings.shell.stats.cpu+"%\nRAM: "+settings.shell.stats.ram+"%\nТемпература: "+(settings.shell.stats.temperature===null ? "Недоступна" : settings.shell.stats.temperature+"°C");Layout.fillWidth:true}
            Label {text:"Интерфейс: Metro. Конфигурация хранится в домашнем каталоге; каждое обновление создаёт проверенный резервный снимок.";color:Theme.muted;Layout.fillWidth:true}
            MetroButton {text:"Открыть руководство";onClicked:settings.shell.launch(["xdg-open",settings.shell.home+"/.local/share/hypr-win8-dots/README.md"])}
            Label {text:"Восстановление из TTY:\n~/.local/bin/hypr-win8-rollback --latest";Layout.fillWidth:true}
        }
    }
}
