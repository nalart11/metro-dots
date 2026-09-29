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
    property string wallpaperTarget:"desktop"
    property string colorRole:"accent"
    readonly property var sections: [
        {id:"system",name:I18n.tr("Система"),hint:I18n.tr("Экран, яркость и ночной свет")},
        {id:"personalization",name:I18n.tr("Персонализация"),hint:I18n.tr("Обои, цвета и оформление")},
        {id:"lockscreen",name:I18n.tr("Экран блокировки"),hint:I18n.tr("Фон экрана блокировки")},
        {id:"language",name:I18n.tr("Язык"),hint:I18n.tr("Язык интерфейса и приложений")},
        {id:"network",name:I18n.tr("Сеть и Интернет"),hint:I18n.tr("Wi-Fi и подключения")},
        {id:"bluetooth",name:I18n.tr("Bluetooth"),hint:I18n.tr("Устройства и сопряжение")},
        {id:"sound",name:I18n.tr("Звук"),hint:I18n.tr("Громкость и устройства вывода")},
        {id:"apps",name:I18n.tr("Приложения"),hint:I18n.tr("Закрепление на Пуске и панели задач")},
        {id:"about",name:I18n.tr("О системе"),hint:I18n.tr("Ресурсы, версия и восстановление")}
    ]
    title:I18n.tr("Параметры — Metro")
    implicitWidth:Math.min(1060,(shell.activeScreen?.width || 1200)*.85)
    implicitHeight:Math.min(760,(shell.activeScreen?.height || 900)*.85)
    minimumSize:Qt.size(640,420)
    color:Theme.background
    visible:!shell.validation && shell.settingsVisible
    onClosed:shell.settingsVisible=false
    onSectionChanged: {errorText="";if(section === "system")shell.refreshDisplays();}
    function setWallpaper(url,target) {
        if(wallpaperProcess.running)return;
        errorText="";wallpaperProcess.command=["python3",shell.helper,"wallpaper",String(url),target || "desktop"];wallpaperProcess.running=true;
    }
    Dialogs.FileDialog {
        id:wallpaperDialog
        title:settings.wallpaperTarget === "lock" ? I18n.tr("Фон экрана блокировки") : I18n.tr("Выбрать обои")
        parentWindow:settings.contentItem.Window.window
        currentFolder:"file://"+settings.shell.home+"/Pictures"
        fileMode:Dialogs.FileDialog.OpenFile
        nameFilters:["Изображения (*.png *.jpg *.jpeg *.webp *.bmp *.svg *.gif)","Все файлы (*)"]
        options:Dialogs.FileDialog.ReadOnly
        onAccepted:settings.setWallpaper(selectedFile,settings.wallpaperTarget)
    }
    function setColor(role,color) {
        if(wallpaperProcess.running)return;
        settings.errorText="";wallpaperProcess.command=["python3",shell.helper,"custom-color",role,String(color)];wallpaperProcess.running=true;
    }
    Dialogs.ColorDialog {
        id:colorDialog
        title:I18n.tr("Выбрать цвет…")
        parentWindow:settings.contentItem.Window.window
        onAccepted:settings.setColor(settings.colorRole,selectedColor)
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
                Label {text:I18n.tr("Параметры");font.pixelSize:30;Layout.fillWidth:true}
                Field {Layout.fillWidth:true;placeholderText:I18n.tr("Найти параметр");text:settings.search;onTextEdited:settings.search=text}
                ListView {
                    Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:8
                    model:settings.sections.filter(s => (s.name+" "+s.hint).toLowerCase().includes(settings.search.toLowerCase()))
                    ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
                    delegate:MetroButton {
                        required property var modelData
                        width:ListView.view.width;height:52;text:modelData.name;selected:settings.section===modelData.id;fill:Theme.surface;padding:8
                        onClicked:settings.section=modelData.id
                    }
                }
                MetroButton {Layout.fillWidth:true;text:I18n.tr("Быстрые настройки");onClicked:settings.shell.toggle("settings")}
                Label {text:I18n.tr("Metro · Arch Linux");color:Theme.muted;font.pixelSize:12}
            }
        }
        ColumnLayout {
            Layout.fillWidth:true;Layout.fillHeight:true;Layout.margins:settings.width < 800 ? 22 : 34;spacing:22
            RowLayout {
                Layout.fillWidth:true
                Label {Layout.fillWidth:true;text:I18n.tr(settings.sections.find(s => s.id===settings.section)?.name || "Параметры");font.pixelSize:34;font.weight:Font.Light}
                MetroButton {text:I18n.tr("×");implicitWidth:42;onClicked:settings.shell.settingsVisible=false}
            }
            Label {visible:settings.errorText.length>0;text:I18n.tr(settings.errorText);color:Theme.danger;Layout.fillWidth:true}
            ScrollView {
                Layout.fillWidth:true;Layout.fillHeight:true;clip:true
                contentWidth:availableWidth
                Loader {
                    width:parent.width
                    sourceComponent:settings.section === "personalization" ? personalizationPage : settings.section === "lockscreen" ? lockPage : settings.section === "language" ? languagePage : settings.section === "network" ? networkPage : settings.section === "bluetooth" ? bluetoothPage : settings.section === "sound" ? soundPage : settings.section === "apps" ? appsPage : settings.section === "about" ? aboutPage : systemPage
                }
            }
        }
    }
    Component {
        id:personalizationPage
        ColumnLayout {
            spacing:18
            Label {text:I18n.tr("Фон рабочего стола");font.pixelSize:24}
            Rectangle {
                Layout.fillWidth:true;Layout.preferredHeight:Math.min(270,width*.5625);color:Theme.surface;clip:true
                Image {anchors.fill:parent;source:settings.shell.wallpaperUrl();fillMode:Theme.data.wallpaperFit === "fit" ? Image.PreserveAspectFit : Theme.data.wallpaperFit === "stretch" ? Image.Stretch : Image.PreserveAspectCrop;sourceSize:Qt.size(900,500);asynchronous:true}
            }
            Label {text:I18n.tr(Theme.data.wallpaper || "metro-blue.svg");color:Theme.muted;font.pixelSize:13;Layout.fillWidth:true}
            MetroButton {objectName:"wallpaperBrowse";text:I18n.tr("Обзор файлов…");onClicked:{settings.wallpaperTarget="desktop";wallpaperDialog.open();}}
            RowLayout {
                Layout.fillWidth:true
                Field {id:wallpaperPath;objectName:"wallpaperPath";Layout.fillWidth:true;placeholderText:I18n.tr("Путь к изображению");text:settings.wallpaperCandidate;onTextEdited:settings.wallpaperCandidate=text;onAccepted:settings.setWallpaper(text)}
                MetroButton {text:I18n.tr("Применить");enabled:settings.wallpaperCandidate.trim().length>0;onClicked:settings.setWallpaper(settings.wallpaperCandidate)}
            }
            Label {text:I18n.tr("Размещение")}
            Flow {
                Layout.fillWidth:true;spacing:8
                Repeater {model:[{id:"fill",name:I18n.tr("Заполнение")},{id:"fit",name:I18n.tr("По размеру")},{id:"stretch",name:I18n.tr("Растянуть")}]
                    MetroButton {required property var modelData;text:I18n.tr(modelData.name);selected:(Theme.data.wallpaperFit || "fill")===modelData.id;onClicked:settings.shell.backend("theme-option",["wallpaperFit",modelData.id])}
                }
            }
            Label {text:I18n.tr("Недавние и встроенные фоны")}
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
            MetroButton {Layout.fillWidth:true;text:I18n.tr("Автоматические цвета из обоев");selected:Theme.data.autoPalette !== false;onClicked:settings.shell.backend("theme-option",["autoPalette",Theme.data.autoPalette === false ? "true" : "false"])}
            Label {text:I18n.tr("Цвета");font.pixelSize:24;Layout.topMargin:14}
            RowLayout {
                MetroButton {text:I18n.tr("Тёмный");selected:!Theme.light;onClicked:settings.shell.backend("theme",["dark"])}
                MetroButton {text:I18n.tr("Светлый");selected:Theme.light;onClicked:settings.shell.backend("theme",["light"])}
            }
            Flow {Layout.fillWidth:true;spacing:10
                Repeater {model:["#0078d4","#008ba8","#7441a0","#b25417","#16865b","#c42b1c"]
                    MetroButton {required property string modelData;width:48;implicitWidth:48;height:48;fill:modelData;selected:String(Theme.accent)===modelData;onClicked:settings.shell.backend("theme",[Theme.light ? "light" : "dark",modelData])}
                }
            }
            Repeater {
                model:[{id:"accent",name:"Акцент"},{id:"background",name:"Фон"},{id:"surface",name:"Поверхность"},{id:"surfaceSecondary",name:"Вторая поверхность"},{id:"foreground",name:"Текст"},{id:"muted",name:"Второстепенный текст"}]
                MetroButton {
                    required property var modelData
                    Layout.fillWidth:true;text:I18n.tr(modelData.name)+" · "+(Theme.colors[modelData.id] || Theme.data[modelData.id] || "")
                    onClicked:{settings.colorRole=modelData.id;colorDialog.selectedColor=Theme.colors[modelData.id] || Theme.accent;colorDialog.open();}
                }
            }
            RowLayout {
                Layout.fillWidth:true
                Field {id:hexColor;Layout.fillWidth:true;placeholderText:"#RRGGBB";onAccepted:settings.setColor(settings.colorRole,text)}
                MetroButton {text:I18n.tr("Применить")+" · "+I18n.tr(({accent:"Акцент",background:"Фон",surface:"Поверхность",surfaceSecondary:"Вторая поверхность",foreground:"Текст",muted:"Второстепенный текст"})[settings.colorRole]);onClicked:settings.setColor(settings.colorRole,hexColor.text)}
            }
        }
    }
    Component {
        id:lockPage
        ColumnLayout {
            spacing:18
            Label {text:I18n.tr("Фон экрана блокировки");font.pixelSize:24}
            Rectangle {Layout.fillWidth:true;Layout.preferredHeight:270;color:Theme.surface;clip:true
                Image {anchors.fill:parent;source:settings.shell.wallpaperUrl(Theme.data.lockWallpaper || Theme.data.wallpaper);fillMode:Image.PreserveAspectCrop;sourceSize:Qt.size(900,500)}
            }
            Label {text:Theme.data.lockWallpaper || Theme.data.wallpaper || "metro-blue.svg";color:Theme.muted;Layout.fillWidth:true}
            MetroButton {text:I18n.tr("Обзор файлов…");onClicked:{settings.wallpaperTarget="lock";wallpaperDialog.open();}}
            RowLayout {
                Layout.fillWidth:true
                Field {id:lockPath;Layout.fillWidth:true;placeholderText:I18n.tr("Путь к изображению");onAccepted:settings.setWallpaper(text,"lock")}
                MetroButton {text:I18n.tr("Применить");enabled:lockPath.text.trim().length>0;onClicked:settings.setWallpaper(lockPath.text,"lock")}
            }
            MetroButton {text:I18n.tr("Использовать фон рабочего стола");onClicked:settings.setWallpaper(decodeURIComponent(settings.shell.wallpaperUrl()).replace("file://",""),"lock")}
        }
    }
    Component {
        id:languagePage
        ColumnLayout {
            spacing:18
            Label {text:I18n.tr("Язык интерфейса и приложений");font.pixelSize:24}
            MetroButton {Layout.fillWidth:true;text:"Русский";selected:I18n.language === "ru";onClicked:settings.shell.backend("language",["ru"])}
            MetroButton {Layout.fillWidth:true;text:"English";selected:I18n.language === "en";onClicked:settings.shell.backend("language",["en"])}
            Label {text:I18n.tr("Приложения используют новый язык после повторного запуска.");color:Theme.muted;Layout.fillWidth:true}
        }
    }
    Component {id:networkPage;NetworkList {shell:settings.shell;kind:"wifi"}}
    Component {id:bluetoothPage;NetworkList {shell:settings.shell;kind:"bluetooth"}}
    Component {id:soundPage;AudioPane {shell:settings.shell;outputs:true}}
    Component {
        id:systemPage
        ColumnLayout {
            spacing:18
            Label {text:I18n.tr("Дисплеи");font.pixelSize:24}
            DisplaySettings {Layout.fillWidth:true;shell:settings.shell}
            Label {visible:settings.shell.stats.brightness!==null;text:I18n.tr("Яркость")}
            Slider {visible:settings.shell.stats.brightness!==null;Layout.fillWidth:true;from:1;to:100;value:settings.shell.stats.brightness || 50;onMoved:settings.shell.exec(["brightnessctl","set",Math.round(value)+"%"])}
            MetroButton {text:I18n.tr(settings.shell.night ? "Ночной свет включён" : "Включить ночной свет");selected:settings.shell.night;onClicked:settings.shell.toggleNight()}
            MetroButton {text:I18n.tr(settings.shell.dnd ? "Не беспокоить включено" : "Включить «Не беспокоить»");selected:settings.shell.dnd;onClicked:settings.shell.dnd=!settings.shell.dnd}
            MetroButton {text:I18n.tr("Питание и завершение сеанса");onClicked:settings.shell.navigate("power")}
        }
    }
    Component {
        id:appsPage
        ColumnLayout {
            spacing:12
            Label {text:I18n.tr("Закрепление приложений");font.pixelSize:24}
            Label {text:I18n.tr("Закрепляйте приложения независимо на Пуске и панели задач. Эти же команды доступны по правой кнопке мыши.");color:Theme.muted;Layout.fillWidth:true}
            Field {id:appSearch;Layout.fillWidth:true;placeholderText:I18n.tr("Поиск приложения")}
            Repeater {
                model:settings.shell.apps.filter(a => a.name.toLowerCase().includes(appSearch.text.toLowerCase()))
                RowLayout {
                    id:appRow
                    required property var modelData
                    Layout.fillWidth:true
                    Image {source:Quickshell.iconPath(appRow.modelData.icon,"application-x-executable");sourceSize:Qt.size(32,32);Layout.preferredWidth:32;Layout.preferredHeight:32}
                    Label {text:I18n.tr(appRow.modelData.name);Layout.fillWidth:true;maximumLineCount:1;elide:Text.ElideRight}
                    MetroButton {text:I18n.tr("Пуск");implicitWidth:70;selected:settings.shell.isStartPinned(appRow.modelData.id);onClicked:settings.shell.backend("pin",["start",appRow.modelData.id])}
                    MetroButton {text:I18n.tr("Панель");implicitWidth:78;selected:settings.shell.isTaskbarPinned(appRow.modelData.id);onClicked:settings.shell.backend("pin",["taskbar",appRow.modelData.id])}
                }
            }
        }
    }
    Component {
        id:aboutPage
        ColumnLayout {
            spacing:18
            Label {text:I18n.tr("Arch Linux · Hyprland · Quickshell");font.pixelSize:24;Layout.fillWidth:true}
            Label {text:I18n.tr("CPU: "+settings.shell.stats.cpu+"%\nRAM: "+settings.shell.stats.ram+"%\nТемпература: "+(settings.shell.stats.temperature===null ? "Недоступна" : settings.shell.stats.temperature+"°C"));Layout.fillWidth:true}
            Label {text:I18n.tr("Интерфейс: Metro. Конфигурация хранится в домашнем каталоге; каждое обновление создаёт проверенный резервный снимок.");color:Theme.muted;Layout.fillWidth:true}
            MetroButton {text:I18n.tr("Открыть руководство");onClicked:settings.shell.launch(["xdg-open",settings.shell.home+"/.local/share/hypr-win8-dots/README.md"])}
            Label {text:I18n.tr("Восстановление из TTY:\n~/.local/bin/hypr-win8-rollback --latest");Layout.fillWidth:true}
        }
    }
}
