//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QS_NO_RELOAD_POPUP=1
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Services.Polkit
import Quickshell.Services.Notifications
import Quickshell.Networking
import Quickshell.Bluetooth

ShellRoot {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string helper: Quickshell.env("HYPR_WIN8_HELPER") || home + "/.local/bin/hypr-win8-backend"
    readonly property bool validation: Quickshell.env("HYPR_WIN8_VALIDATE") === "1"
    readonly property bool preview: Quickshell.env("HYPR_WIN8_PREVIEW") === "1"
    property string page: ""
    property string displayPage: ""
    property bool closing: false
    property bool settingsVisible: false
    property int transitionSerial: 0
    property real backgroundOpacity: 0
    property real sideOffset: 44
    property real titleOffset: 25
    property real titleOpacity: 0
    property var pinIds: []
    property var pendingLaunch: []
    property string query: ""
    property string errorMessage: ""
    property string pendingPower: ""
    property bool dnd: false
    property bool night: false
    property bool showNetworks: false
    property bool zoomed: false
    property int selectedWindow: 0
    property var activeScreen: Quickshell.screens[0] || null
    property var stats: ({cpu:0, ram:0, temperature:null, brightness:null})
    property var tiles: []
    property var appCatalog: []
    property var clipboard: []
    property var displays: []
    property var history: []
    property int popupId: -1
    readonly property var liveNotifications: notificationLoader.item?.trackedNotifications.values || []
    readonly property var popup: liveNotifications.find(n => n.id === popupId) || null
    property string mainKeyboard: ""
    property string layout: "EN"
    readonly property var authFlow: polkitLoader.item?.flow || null
    property string osdText: ""
    property date now: new Date()
    readonly property var player: Mpris.players.values[0] || null
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var wifiDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property string networkName: Networking.devices.values.filter(d => d.connected).map(d => d.type === DeviceType.Wifi ? (d.networks.values.find(n => n.connected)?.name || d.name) : d.name).join(" · ") || "Offline"
    readonly property var groups: [...new Set(tiles.filter(t => t.live !== "battery" || UPower.displayDevice.isLaptopBattery).map(t => t.group))]
    readonly property var apps: appCatalog
    readonly property var filteredApps: apps.filter(a => (a.name + " " + a.genericName + " " + a.categories.join(" ") + " " + a.keywords.join(" ")).toLowerCase().includes(query.toLowerCase()))
    readonly property var windows: ToplevelManager.toplevels.values
    onSettingsVisibleChanged: {updateScan();if(settingsVisible)refreshDisplays();}
    onPageChanged: {
        updateScan();
        if(page === "") {
            if(displayPage !== "") {closing=true;openBackground.stop();headerEntrance.stop();sideEntrance.stop();backgroundExit.restart();sideExit.restart();finishClose.restart();}
            return;
        }
        const wasClosed=displayPage === "";
        finishClose.stop();backgroundExit.stop();sideExit.stop();closing=false;displayPage=page;
        if(wasClosed) {backgroundOpacity=0;sideOffset=44;openBackground.restart();sideEntrance.restart();}
        else {backgroundOpacity=1;sideOffset=0;}
        if(page === "start") {titleOffset=25;titleOpacity=0;headerEntrance.restart();}
        else {titleOffset=0;titleOpacity=1;}
        transitionSerial++;
    }
    function updateScan() {wifiDevices.forEach(d => d.scannerEnabled=page === "wifi" || (settingsVisible && settingsWindow.section === "network"));}
    function refreshDisplays() {if(!validation && !displayProcess.running)displayProcess.running=true;}
    function wallpaperUrl(value) {const path=value || Theme.data.wallpaper || "metro-blue.svg";return "file://"+(path.startsWith("/") ? path : home+"/.local/share/hypr-win8-dots/assets/wallpapers/"+path).split("/").map(encodeURIComponent).join("/");}
    function iconUrl(name) {return "file://"+home+"/.local/share/hypr-win8-dots/assets/icons/"+name+".svg";}
    function desktopKey(id) {return apps.find(a => a.id===id || a.id===id+".desktop")?.id || id;}
    function isStartPinned(id) {return !!id && tiles.some(t => t.desktop && desktopKey(t.desktop)===desktopKey(id));}
    function isTaskbarPinned(id) {return !!id && pinIds.some(i => desktopKey(i)===desktopKey(id));}
    readonly property var pinnedApps:pinIds.map(id => apps.find(a => a.id===desktopKey(id))).filter(a => !!a)
    function appForWindow(window) {return apps.find(a => a.id.toLowerCase()===window.appId.toLowerCase()+".desktop" || a.id.toLowerCase()===window.appId.toLowerCase()) || apps.find(a => a.id===DesktopEntries.heuristicLookup(window.appId)?.id) || null;}
    function openSettings(section) {activeScreen=screenForFocus();page="";settingsWindow.section=section || "system";settingsVisible=true;settingsWindow.minimized=false;}
    function toggleNight() {night=!night;exec(["hyprctl","hyprsunset",night ? "temperature" : "identity"].concat(night ? ["4000"] : []));}
    function launchAndClose(args) {pendingLaunch=args;page="";appLaunchTimer.restart();}
    NumberAnimation {id:openBackground;target:root;property:"backgroundOpacity";to:1;duration:100}
    NumberAnimation {id:sideEntrance;target:root;property:"sideOffset";to:0;duration:220;easing.type:Easing.OutCubic}
    NumberAnimation {id:sideExit;target:root;property:"sideOffset";to:44;duration:160;easing.type:Easing.InCubic}
    SequentialAnimation {id:headerEntrance;PauseAnimation{duration:70} ParallelAnimation {
        NumberAnimation{target:root;property:"titleOffset";to:0;duration:150;easing.type:Easing.BezierSpline;easing.bezierCurve:[.1,.9,.2,1,1,1]}
        NumberAnimation{target:root;property:"titleOpacity";to:1;duration:150}
    }}
    SequentialAnimation {id:backgroundExit;PauseAnimation{duration:170} NumberAnimation{target:root;property:"backgroundOpacity";to:0;duration:60}}
    Timer {id:finishClose;interval:230;onTriggered:{if(root.page === "")root.displayPage="";}}
    Timer {id:appLaunchTimer;interval:150;onTriggered:{const command=root.pendingLaunch;root.pendingLaunch=[];if(command.length)root.launch(command);}}
    SettingsWindow {id:settingsWindow;shell:root}
    Connections {target:settingsWindow;function onSectionChanged(){root.updateScan();}}
    function cleanTitle(title) {return title.replace(/^[\u2800-\u28ff]\s/, "");}
    function exec(args) { Quickshell.execDetached(args); }
    function launch(args) {Quickshell.execDetached(["systemd-run","--user","--scope","--quiet","--collect"].concat(args));}
    function backend(action, args) {
        const command=["python3",helper,action].concat(args || []);
        if(["launch","power"].includes(action)) launch(command);else exec(command);
    }
    function screenForFocus() { return Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0]; }
    function toggle(name) {
        if(name === "control-panel") {openSettings();return;}
        if (name === "switcher" && page === name) { selectedWindow = (selectedWindow + 1) % Math.max(1,windows.length); return; }
        activeScreen = screenForFocus(); query = ""; pendingPower = ""; errorMessage = "";
        page = page === name ? "" : name;
        if (name === "switcher") selectedWindow = windows.length > 1 ? 1 : 0;
        if (page === "clipboard") clipProcess.running = true;
        if (page === "displays") displayProcess.running = true;
    }
    function navigate(name) { page = ""; toggle(name); }
    function launchApp(a) { launchAndClose(["python3",helper,"launch",a.id]); }
    function launchTile(t) {
        if (t.action) {if(t.action === "settings" || t.action === "control-panel")openSettings("personalization");else navigate(t.action);return;}
        if (t.live === "music") { if (player?.canTogglePlaying) player.togglePlaying(); return; }
        if (t.live === "network") { navigate("settings"); return; }
        if (t.desktop) { launchAndClose(["python3",helper,"launch",t.desktop]); }
        else if (t.command?.length) { launchAndClose(t.command); }
    }
    function tileBody(t) {
        if (t.live === "clock") return Qt.formatDateTime(now,"HH:mm") + "\n" + Qt.formatDateTime(now,"dddd, d MMMM");
        if (t.live === "system") return "CPU " + stats.cpu + "%   RAM " + stats.ram + "%" + (stats.temperature !== null ? "\n" + stats.temperature + "°C" : "");
        if (t.live === "network") return networkName;
        if (t.live === "music") return player ? player.trackTitle + "\n" + player.trackArtist + "\n" + (player.isPlaying ? "Ⅱ  Pause" : "▷  Play") : "No active player";
        if (t.live === "calendar") return Qt.formatDateTime(now,"d MMMM\nyyyy");
        if (t.live === "battery") return Math.round(UPower.displayDevice.percentage * 100) + "%";
        return "";
    }
    function notificationFor(id) {return liveNotifications.find(n => n.id === id) || null;}
    function invokeAction(id,identifier) {
        const n=notificationFor(id);
        if(n) {const action=Array.from(n.actions).find(a => a.identifier===identifier);if(action)action.invoke();}
    }
    function clearHistory() {
        history=[];popupId=-1;
        Array.from(liveNotifications).forEach(n => n.dismiss());
    }
    function activateWindow() { if (windows[selectedWindow]) windows[selectedWindow].activate(); page = ""; }
    function power(action) {
        if (action === "lock") { page = ""; backend("power",[action]); }
        else if (pendingPower === action) { page = ""; backend("power",[action]); pendingPower = ""; }
        else pendingPower = action;
    }
    IpcHandler {
        target: "metro"
        function toggle(page: string): void { root.toggle(page); }
        function status(): string { return JSON.stringify({page:root.page,apps:root.apps.length,tiles:root.tiles.length,screens:Quickshell.screens.length,notifications:root.history.length,query:root.query,results:root.filteredApps.length,tray:SystemTray.items.values.length,monitor:root.activeScreen?.name,polkitRegistered:polkitLoader.item?.isRegistered || false,liveNotifications:root.liveNotifications.length,stats:root.stats,displayPage:root.displayPage,closing:root.closing,backgroundOpacity:root.backgroundOpacity,pins:root.pinIds,settingsVisible:root.settingsVisible,settingsSection:settingsWindow.section}); }
        function close(): void { root.page = ""; }
        function settings(section: string): void {root.openSettings(section);}
        function hideSettings(): void {root.settingsVisible=false;}
        function pin(target: string, id: string): void {root.backend("pin",[target,id]);}
    }
    // Compatibility for preserved touchpad gestures.
    GlobalShortcut { name: "overviewWorkspacesToggle"; onPressed: root.toggle("workspaces") }
    FileView {
        path: (Quickshell.env("HYPR_WIN8_DATA") || root.home + "/.config/hypr-win8") + "/tiles.json"; watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.tiles = JSON.parse(text()); } catch(e) { console.error("Tiles JSON: " + e); } }
    }
    FileView {
        path:(Quickshell.env("HYPR_WIN8_DATA") || root.home+"/.config/hypr-win8")+"/pins.json";watchChanges:true
        onFileChanged:reload()
        onLoaded:{try{root.pinIds=JSON.parse(text()).taskbar || [];}catch(e){console.error("Pinned apps JSON: "+e);}}
    }
    Timer { interval:1000; running:!root.validation; repeat:true; onTriggered:root.now = new Date() }
    Process {
        id: metricsProcess; command:["python3",root.helper,"metrics"]; running:!root.validation
        stdout: SplitParser { onRead: data => { try { const next=JSON.parse(data);if(root.stats.brightness!==null && next.brightness!==null && root.stats.brightness!==next.brightness){root.osdText="Brightness  "+next.brightness+"%";osdTimer.restart();}root.stats=next; } catch(e) { console.error(e); } } }
        onExited: (code,status) => { if(code) console.error("Metrics failed: "+code); }
    }
    Process {
        command:["python3",root.helper,"apps-watch"];running:!root.validation
        stdout:SplitParser {onRead:data => {try{root.appCatalog=JSON.parse(data);}catch(e){console.error("Application catalog failed: "+e);}}}
        onExited:(code,status) => {if(code)console.error("Application catalog process failed: "+code);}
    }
    Process {
        id: clipProcess; command:["python3",root.helper,"clipboard-list"]
        stdout: StdioCollector { onStreamFinished: { try {root.clipboard=JSON.parse(text);} catch(e) {root.errorMessage="Clipboard unavailable";} } }
    }
    Process {
        id: displayProcess; command:["python3",root.helper,"displays"]
        stdout: StdioCollector { onStreamFinished: { try {root.displays=JSON.parse(text);} catch(e) {root.errorMessage="Display query failed";} } }
    }
    Process {
        command:["hyprctl","devices","-j"];running:!root.validation
        stdout:StdioCollector {onStreamFinished: {
            try {const keyboard=JSON.parse(text).keyboards.find(k => k.main);if(keyboard){root.mainKeyboard=keyboard.name;root.layout=keyboard.active_keymap.toLowerCase().includes("russian") ? "RU" : "EN";}}catch(e){console.error("Keyboard query failed: "+e);}
        }}
    }
    PwObjectTracker { objects: [root.sink] }
    Connections {
        target: Hyprland
        function onRawEvent(event) { if(event.name === "activelayout" && (!root.mainKeyboard || event.data.startsWith(root.mainKeyboard+","))) root.layout = event.data.toLowerCase().includes("russian") ? "RU" : "EN"; }
    }
    LazyLoader {
        id:polkitLoader
        active:!root.validation && !root.preview
        PolkitAgent {
            onAuthenticationRequestStarted: {root.activeScreen=root.screenForFocus();root.page="";}
        }
    }
    LazyLoader {
        id:notificationLoader
        active: !root.validation && !root.preview
        NotificationServer {
            actionsSupported:true; bodySupported:true; bodyMarkupSupported:false; persistenceSupported:true
            onNotification: n => {
                const old=root.popup;
                if(old && old.id!==n.id && !old.resident && old.expireTimeout!==0) old.expire();
                n.tracked = true;
                root.history = [{id:n.id,app:n.appName,summary:n.summary,body:n.body,time:Qt.formatDateTime(new Date(),"HH:mm"),actions:Array.from(n.actions).map(a => ({identifier:a.identifier,text:a.text}))}].concat(root.history.filter(h => h.id!==n.id)).slice(0,100);
                Array.from(root.liveNotifications).filter(item => !root.history.some(h => h.id===item.id)).forEach(item => item.dismiss());
                if (!root.dnd) {root.popupId=n.id;if(n.expireTimeout!==0){popupTimer.interval=n.expireTimeout > 0 ? n.expireTimeout : 6000;popupTimer.restart();}}
            }
        }
    }
    Connections {
        target: root.sink?.audio || null
        function onVolumesChanged() {root.osdText="Volume  "+Math.round((root.sink?.audio?.volume || 0)*100)+"%";osdTimer.restart();}
        function onMutedChanged() {root.osdText=root.sink?.audio?.muted ? "Muted" : "Sound on";osdTimer.restart();}
    }
    Timer {id:osdTimer;interval:1800;onTriggered:root.osdText=""}
    Timer {id:popupTimer; onTriggered:{let n=root.popup;root.popupId=-1;if(n && !n.resident)n.expire();}}
    component BarButton: MetroButton {
        id:b
        property bool truncate:false
        padding:4
        Layout.minimumWidth:implicitWidth;Layout.preferredWidth:implicitWidth;Layout.maximumWidth:implicitWidth
        contentItem:Text {text:b.text;color:Theme.foreground;font:b.font;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;elide:b.truncate ? Text.ElideRight : Text.ElideNone}
    }
    component Label: Text { color:Theme.foreground; font.family:Theme.font; font.pixelSize:16; wrapMode:Text.Wrap; textFormat:Text.PlainText }

    Variants {
        model: root.validation ? [] : Quickshell.screens
        PanelWindow {
            id: wallpaperWindow
            required property var modelData
            screen:modelData
            anchors {top:true;bottom:true;left:true;right:true}
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "hypr-win8-wallpaper"
            color:Theme.background
            visible: !root.preview
            Image {
                anchors.fill:parent
                sourceSize:Qt.size(width * wallpaperWindow.screen.devicePixelRatio,height * wallpaperWindow.screen.devicePixelRatio)
                source:root.wallpaperUrl()
                fillMode:Theme.data.wallpaperFit === "fit" ? Image.PreserveAspectFit : Theme.data.wallpaperFit === "stretch" ? Image.Stretch : Image.PreserveAspectCrop; asynchronous:true
            }
        }
    }
    Variants {
        model:root.validation ? [] : Quickshell.screens
        PanelWindow {
            id: bar
            required property var modelData
            screen:modelData;visible:!root.preview
            anchors {bottom:true;left:true;right:true}
            implicitHeight:48;exclusiveZone:48;color:Theme.surface
            WlrLayershell.namespace:"hypr-win8-taskbar"
            RowLayout {
                anchors.fill:parent;spacing:0
                BarButton {
                    implicitWidth:64;implicitHeight:48;fill:Theme.accent
                    Image { sourceSize:Qt.size(width,height);anchors.centerIn:parent;width:26;height:26;source:"file://"+root.home+"/.local/share/hypr-win8-dots/assets/icons/start.svg"}
                    onClicked: {root.activeScreen=bar.screen;root.query="";root.page=root.page==="start" ? "" : "start";}
                }
                ListView {
                    Layout.minimumWidth:Math.min(root.pinnedApps.length*48,bar.width*.22)
                    Layout.preferredWidth:Math.min(root.pinnedApps.length*48,bar.width*.22)
                    Layout.maximumWidth:Math.min(root.pinnedApps.length*48,bar.width*.22)
                    Layout.fillHeight:true;orientation:ListView.Horizontal;clip:true
                    model:root.pinnedApps
                    delegate:BarButton {
                        required property var modelData
                        width:48;height:48;implicitWidth:48;fill:Theme.surface
                        Image {sourceSize:Qt.size(24,24);anchors.centerIn:parent;width:24;height:24;source:Quickshell.iconPath(modelData.icon,"application-x-executable")}
                        onClicked:root.launchApp(modelData)
                        MouseArea {anchors.fill:parent;acceptedButtons:Qt.RightButton;onClicked:{barMenu.app=parent.modelData;barMenu.popup();}}
                    }
                }
                Rectangle {Layout.preferredWidth:1;Layout.preferredHeight:28;color:Theme.secondary;Layout.leftMargin:8;Layout.rightMargin:8}
                Repeater {
                    model:Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor?.name === bar.screen.name)
                    BarButton {
                        required property var modelData
                        text:String(modelData.id);implicitWidth:32;implicitHeight:32;selected:modelData.active
                        fill:Theme.surface;onClicked:modelData.activate()
                    }
                }
                ListView {
                    Layout.fillWidth:true;Layout.fillHeight:true;orientation:ListView.Horizontal;clip:true;spacing:3
                    model:ToplevelManager.toplevels
                    delegate:BarButton {
                        required property var modelData
                        truncate:true;width:Math.min(170,Math.max(70,bar.width/12));height:48;text:root.cleanTitle(modelData.title)
                        fill:modelData.activated ? Theme.secondary : Theme.surface
                        onClicked:modelData.activate()
                        MouseArea {anchors.fill:parent;acceptedButtons:Qt.RightButton;onClicked:{barMenu.app=root.appForWindow(parent.modelData);barMenu.popup();}}
                        Rectangle {anchors.bottom:parent.bottom;anchors.left:parent.left;anchors.right:parent.right;height:modelData.activated ? 3 : 1;color:Theme.accent}
                    }
                }
                Repeater {
                    model:SystemTray.items
                    BarButton {
                        id:trayButton
                        required property var modelData
                        implicitWidth:32;implicitHeight:48;fill:Theme.surface
                        Image { sourceSize:Qt.size(width,height);anchors.centerIn:parent;width:20;height:20;source:trayButton.modelData.icon}
                        onClicked: { if(modelData.onlyMenu && modelData.hasMenu) modelData.display(bar,bar.width-200,0);else modelData.activate(); }
                        MouseArea {anchors.fill:parent;acceptedButtons:Qt.RightButton;onClicked:trayButton.modelData.display(bar,bar.width-200,0)}
                    }
                }
                BarButton {implicitWidth:42;fill:Theme.surface;Image{anchors.centerIn:parent;width:24;height:24;source:root.iconUrl("network");sourceSize:Qt.size(24,24)} onClicked:root.toggle("wifi")}
                BarButton {text:root.sink?.audio?.muted ? "Mute" : Math.round((root.sink?.audio?.volume || 0)*100)+"%";implicitWidth:76;fill:Theme.surface;onClicked:root.toggle("audio")}
                BarButton {visible:UPower.displayDevice.isLaptopBattery;text:Math.round(UPower.displayDevice.percentage*100)+"%";implicitWidth:70;fill:Theme.surface;onClicked:root.toggle("settings")}
                BarButton {implicitWidth:42;fill:Theme.surface;Image{anchors.centerIn:parent;width:24;height:24;source:root.iconUrl("notifications");sourceSize:Qt.size(24,24)} onClicked:root.toggle("notifications")}
                BarButton {implicitWidth:42;fill:Theme.surface;Image{anchors.centerIn:parent;width:24;height:24;source:root.iconUrl("settings");sourceSize:Qt.size(24,24)} onClicked:root.toggle("settings")}
                BarButton {text:root.layout;implicitWidth:44;fill:Theme.surface;onClicked:root.exec(["hyprctl","switchxkblayout","all","next"])}
                BarButton {id:clockButton;text:Qt.formatDateTime(root.now,"HH:mm\ndd.MM.yyyy");implicitWidth:120;implicitHeight:48;font.pixelSize:13;fill:Theme.surface;onClicked:root.toggle("start")}
            }
            AppMenu {id:barMenu;shell:root}
        }
    }
    LazyLoader {
        active:!root.validation && root.displayPage !== ""
        component:PanelWindow {
        id: overlay
        screen:root.activeScreen
        visible:!root.validation && root.displayPage !== ""
        anchors {top:true;bottom:true;left:true;right:true}
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.namespace:"hypr-win8-overlay"
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.keyboardFocus:root.page !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color:"transparent"
        property bool full:root.displayPage === "start" || root.displayPage === "apps" || root.displayPage === "search" || root.displayPage === "workspaces" || root.displayPage === "switcher"
        MouseArea {anchors.fill:parent;onClicked:root.page=""}
        Rectangle {
            id: panel
            anchors.top:parent.top;anchors.bottom:parent.bottom;anchors.right:parent.right
            width:overlay.full ? parent.width : Math.min(440,parent.width)
            color:"transparent"
            transform:Translate {x:overlay.full ? 0 : root.sideOffset}
            Rectangle {anchors.fill:parent;color:Theme.background;opacity:root.backgroundOpacity}
            enabled:!root.closing
            MouseArea {anchors.fill:parent}
            Item {
                id: keyboard
                anchors.fill:parent;focus:true
                Keys.onPressed: event => {
                    if(event.key === Qt.Key_Escape) {root.page="";event.accepted=true;}
                    else if(root.displayPage === "switcher" && event.key === Qt.Key_Tab) {root.selectedWindow=(root.selectedWindow+1)%Math.max(1,root.windows.length);event.accepted=true;}
                    else if(root.displayPage === "switcher" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {root.activateWindow();event.accepted=true;}
                    else if(root.displayPage === "start" && event.text.length && !(event.modifiers & (Qt.ControlModifier|Qt.AltModifier|Qt.MetaModifier))) {root.page="search";root.query=event.text;searchField.forceActiveFocus();event.accepted=true;}
                }
                Keys.onReleased: event => {if(root.displayPage === "switcher" && event.key === Qt.Key_Alt) root.activateWindow();}
                ColumnLayout {
                    anchors.fill:parent
                    anchors.margins:overlay.full ? Math.max(32,Math.min(100,panel.width*.05)) : 28
                    spacing:22
                    RowLayout {
                        Layout.fillWidth:true
                        opacity:root.closing ? 0 : root.titleOpacity
                        transform:Translate {x:root.titleOffset}
                        Behavior on opacity {NumberAnimation {duration:root.closing ? 120 : 0}}
                        Label {text:root.displayPage === "start" ? "Start" : root.displayPage === "apps" ? "All apps" : root.displayPage === "switcher" ? "Windows" : root.displayPage.charAt(0).toUpperCase()+root.displayPage.slice(1);font.pixelSize:overlay.full ? 52 : 36;font.weight:Font.Light;Layout.fillWidth:true}
                        MetroButton {text:"×";implicitWidth:44;fill:Theme.background;onClicked:root.page=""}
                    }
                    Label {visible:root.errorMessage.length>0;text:root.errorMessage;color:Theme.danger;Layout.fillWidth:true}
                    TextField {
                        id:searchField
                        visible:["search","apps","clipboard"].includes(root.displayPage)
                        Layout.fillWidth:true;Layout.preferredHeight:48
                        text:root.query;onTextEdited:root.query=text
                        placeholderText:root.displayPage === "clipboard" ? "Search clipboard" : "Search apps, settings · > command"
                        color:Theme.foreground;placeholderTextColor:Theme.muted;font.family:Theme.font;font.pixelSize:18
                        background:Rectangle {color:Theme.surface;border.color:Theme.accent;border.width:2}
                        onAccepted: {
                            if(root.query.startsWith(">")) {root.launch(["bash","-lc",root.query.slice(1).trim()]);root.page="";}
                            else if(root.filteredApps.length) root.launchApp(root.filteredApps[0]);
                        }
                        Keys.onEscapePressed:root.page=""
                    }
                    Flickable {
                        visible:root.displayPage === "start";Layout.fillWidth:true;Layout.fillHeight:true
                        contentWidth:tileRow.width;contentHeight:Math.max(height,tileRow.height);clip:true
                        ScrollBar.horizontal:ScrollBar {policy:ScrollBar.AsNeeded}
                        ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
                        Row {
                            id:tileRow;spacing:44
                            property int unit:root.zoomed ? 82 : Math.max(96,Math.min(154,(parent.height-70)/4-10))
                            Repeater {
                                model:root.groups
                                Column {
                                    id:groupColumn
                                    required property string modelData
                                    required property int index
                                    property real slideOffset:80+Math.min(index,3)*30
                                    property real tileOpacity:0
                                    transform:Translate {x:slideOffset}
                                    opacity:tileOpacity
                                    spacing:18
                                    function enter() {exitAnimation.stop();tileOpacity=0;slideOffset=80+Math.min(index,3)*30;entrance.restart();}
                                    Component.onCompleted:enter()
                                    SequentialAnimation {
                                        id:entrance
                                        PauseAnimation {duration:80+Math.min(groupColumn.index,3)*15}
                                        ParallelAnimation {
                                            NumberAnimation {target:groupColumn;property:"slideOffset";to:0;duration:220-Math.min(groupColumn.index,3)*15;easing.type:Easing.BezierSpline;easing.bezierCurve:[.1,.9,.2,1,1,1]}
                                            NumberAnimation {target:groupColumn;property:"tileOpacity";to:1;duration:190-Math.min(groupColumn.index,3)*15}
                                        }
                                    }
                                    SequentialAnimation {
                                        id:exitAnimation
                                        PauseAnimation {duration:Math.min(3,Math.max(0,root.groups.length-1-groupColumn.index))*15}
                                        ParallelAnimation {
                                            NumberAnimation {target:groupColumn;property:"slideOffset";to:80;duration:145;easing.type:Easing.InCubic}
                                            NumberAnimation {target:groupColumn;property:"tileOpacity";to:0;duration:145}
                                        }
                                    }
                                    Connections {
                                        target:root
                                        function onClosingChanged(){if(root.closing){entrance.stop();exitAnimation.restart();}}
                                        function onTransitionSerialChanged(){if(root.page === "start")groupColumn.enter();}
                                    }
                                    Label {text:groupColumn.modelData;font.pixelSize:22;color:Theme.muted}
                                    Item {
                                        width:4*tileRow.unit+30;height:Math.max(4,...root.tiles.filter(t => t.group===groupColumn.modelData).map(t => t.y+t.h))*(tileRow.unit+10)-10
                                        Repeater {
                                            model:root.tiles.filter(t => t.group === groupColumn.modelData && (t.live !== "battery" || UPower.displayDevice.isLaptopBattery))
                                            Rectangle {
                                                id:tile
                                                required property var modelData
                                                x:modelData.x*(tileRow.unit+10);y:modelData.y*(tileRow.unit+10)
                                                width:modelData.w*tileRow.unit+(modelData.w-1)*10;height:modelData.h*tileRow.unit+(modelData.h-1)*10
                                                color:tileMouse.containsMouse ? Qt.lighter(modelData.color,1.15) : modelData.color
                                                border.width:tileMouse.containsMouse ? 2 : 0;border.color:"#bfffffff"
                                                property bool pressFeedback:false
                                                Item {
                                                anchors.fill:parent;scale:tileMouse.pressed || tile.pressFeedback ? .96 : 1
                                                Behavior on scale {NumberAnimation {duration:70}}

                                                Image { sourceSize:Qt.size(width,height);visible:!tile.modelData.live && !root.zoomed;width:Math.min(60,tile.width*.4);height:width;anchors.centerIn:parent;source:Quickshell.iconPath(tile.modelData.icon || "preferences-system","application-x-executable")}
                                                Label {
                                                    visible:!!tile.modelData.live;text:root.tileBody(tile.modelData);anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:18
                                                    color:"white";font.pixelSize:tile.modelData.live === "clock" && !root.zoomed ? 32 : root.zoomed ? 13 : 18
                                                    maximumLineCount:4;elide:Text.ElideRight
                                                }
                                                Label {text:tile.modelData.name;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;maximumLineCount:1;elide:Text.ElideRight;anchors.margins:14;color:"white";font.pixelSize:root.zoomed ? 13 : 16}
                                                }
                                                Timer {id:tileLaunch;interval:75;onTriggered:{tile.pressFeedback=false;root.launchTile(tile.modelData);}}
                                                MouseArea {id:tileMouse;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton;onClicked:mouse => {
                                                    if(mouse.button===Qt.RightButton){overlayMenu.app=root.apps.find(a => a.id===root.desktopKey(tile.modelData.desktop || "")) || null;overlayMenu.tile=tile.modelData;overlayMenu.popup();}
                                                    else {tile.pressFeedback=true;tileLaunch.restart();}
                                                }}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        visible:root.displayPage === "start";Layout.fillWidth:true
                        MetroButton {text:"↓  All apps";onClicked:{root.page="apps";root.query="";searchField.forceActiveFocus();}}
                        MetroButton {text:root.zoomed ? "+  Expand" : "−  Groups";onClicked:root.zoomed=!root.zoomed}
                        Item {Layout.fillWidth:true}
                        MetroButton {text:"Параметры";onClicked:root.openSettings("personalization")}
                        MetroButton {text:"Power";onClicked:root.navigate("power")}
                    }
                    GridView {
                        visible:root.displayPage === "apps" || root.displayPage === "search";Layout.fillWidth:true;Layout.fillHeight:true
                        cellWidth:Math.max(220,Math.floor(width/Math.max(1,Math.floor(width/270))));cellHeight:76;clip:true
                        model:root.filteredApps
                        ScrollBar.vertical:ScrollBar {}
                        delegate:MetroButton {
                            required property var modelData
                            width:GridView.view.cellWidth-12;height:64;fill:Theme.surface
                            contentItem:RowLayout {
                                spacing:14
                                Image { sourceSize:Qt.size(32*overlay.screen.devicePixelRatio,32*overlay.screen.devicePixelRatio);Layout.preferredWidth:32;Layout.preferredHeight:32;source:Quickshell.iconPath(modelData.icon,"application-x-executable")}
                                ColumnLayout {Layout.fillWidth:true;spacing:2
                                    Label {text:modelData.name;Layout.fillWidth:true;elide:Text.ElideRight;maximumLineCount:1}
                                    Label {text:modelData.categories.slice(0,2).join(" · ");font.pixelSize:11;color:Theme.muted;Layout.fillWidth:true;elide:Text.ElideRight;maximumLineCount:1}
                                }
                            }
                            onClicked:root.launchApp(modelData)
                            MouseArea {anchors.fill:parent;acceptedButtons:Qt.RightButton;onClicked:{overlayMenu.app=parent.modelData;overlayMenu.popup();}}
                        }
                    }
                    RowLayout {
                        visible:root.displayPage === "search";Layout.fillWidth:true
                        Repeater {model:["Settings","Displays","Power","Clipboard"].filter(s => s.toLowerCase().includes(root.query.toLowerCase()))
                            MetroButton {required property string modelData;text:modelData;onClicked:root.navigate(modelData.toLowerCase())}
                        }
                        MetroButton {text:"Run command";visible:root.query.startsWith(">");onClicked:{root.launch(["bash","-lc",root.query.slice(1).trim()]);root.page="";}}
                    }
                    ListView {
                        visible:root.displayPage === "switcher";Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:12
                        model:ToplevelManager.toplevels
                        delegate:MetroButton {
                            required property var modelData;required property int index
                            width:ListView.view.width;height:82;selected:index===root.selectedWindow;text:root.cleanTitle(modelData.title)
                            contentItem:RowLayout {
                                spacing:16
                                Image { sourceSize:Qt.size(40*overlay.screen.devicePixelRatio,40*overlay.screen.devicePixelRatio);Layout.preferredWidth:40;Layout.preferredHeight:40;source:Quickshell.iconPath(DesktopEntries.heuristicLookup(modelData.appId)?.icon || "application-x-executable","application-x-executable")}
                                Label {text:root.cleanTitle(modelData.title);Layout.fillWidth:true;maximumLineCount:1;elide:Text.ElideRight}
                            }
                            onClicked:{modelData.activate();root.page="";}
                        }
                    }
                    Flow {
                        visible:root.displayPage === "workspaces";Layout.fillWidth:true;Layout.fillHeight:true;spacing:16
                        Repeater {
                            model:Hyprland.workspaces
                            MetroButton {required property var modelData;visible:modelData.id>0;text:"Desktop "+modelData.id+"\n"+(modelData.monitor?.name || "");width:200;height:128;selected:modelData.focused;onClicked:{modelData.activate();root.page="";}}
                        }
                    }
                    ColumnLayout {
                        visible:root.displayPage === "charms";Layout.fillWidth:true;spacing:12
                        Repeater {model:["Search","Share","Start","Devices","Settings"]
                            MetroButton {required property string modelData;text:modelData;Layout.fillWidth:true;implicitHeight:72;fill:Theme.surface;onClicked:root.navigate(modelData.toLowerCase())}
                        }
                    }
                    ScrollView {
                        visible:root.displayPage === "settings";Layout.fillWidth:true;Layout.fillHeight:true;clip:true;contentWidth:availableWidth
                        ColumnLayout {
                            width:parent.width;spacing:18
                            RowLayout {
                                Layout.fillWidth:true;spacing:12
                                ConnectivityTile {visible:root.wifiDevices.length>0;Layout.fillWidth:true;title:"Wi-Fi";subtitle:Networking.wifiEnabled ? root.networkName : "Выключен";icon:root.iconUrl("wifi");enabledRadio:Networking.wifiEnabled;onToggleRadio:Networking.wifiEnabled=!Networking.wifiEnabled;onOpenDetails:root.navigate("wifi")}
                                ConnectivityTile {visible:!!root.adapter;Layout.fillWidth:true;title:"Bluetooth";subtitle:root.adapter?.enabled ? "Включён" : "Выключен";icon:root.iconUrl("bluetooth");enabledRadio:root.adapter?.enabled || false;onToggleRadio:root.adapter.enabled=!root.adapter.enabled;onOpenDetails:root.navigate("bluetooth")}
                            }
                            AudioPane {shell:root;Layout.fillWidth:true}
                            Label {visible:root.stats.brightness!==null;text:"Яркость · "+root.stats.brightness+"%"}
                            Slider {visible:root.stats.brightness!==null;Layout.fillWidth:true;from:1;to:100;value:root.stats.brightness || 50;onMoved:root.exec(["brightnessctl","set",Math.round(value)+"%"])}
                            RowLayout {Layout.fillWidth:true
                                MetroButton {Layout.fillWidth:true;text:"Ночной свет";selected:root.night;onClicked:root.toggleNight()}
                                MetroButton {Layout.fillWidth:true;text:"Не беспокоить";selected:root.dnd;onClicked:root.dnd=!root.dnd}
                            }
                            RowLayout {Layout.fillWidth:true
                                MetroButton {Layout.fillWidth:true;text:"Экран";onClicked:root.navigate("displays")}
                                MetroButton {Layout.fillWidth:true;text:"Питание";onClicked:root.navigate("power")}
                            }
                            MetroButton {text:"Все параметры ›";Layout.fillWidth:true;onClicked:root.openSettings()}
                        }
                    }
                    ScrollView {
                        visible:["wifi","bluetooth","audio"].includes(root.displayPage);Layout.fillWidth:true;Layout.fillHeight:true;clip:true;contentWidth:availableWidth
                        ColumnLayout {
                            width:parent.width;spacing:18
                            MetroButton {text:"‹ Быстрые настройки";Layout.fillWidth:true;onClicked:root.navigate("settings")}
                            Loader {Layout.fillWidth:true;active:root.displayPage === "wifi" || root.displayPage === "bluetooth";sourceComponent:NetworkList {shell:root;kind:root.displayPage}}
                            Loader {Layout.fillWidth:true;active:root.displayPage === "audio";sourceComponent:AudioPane {shell:root;outputs:true}}
                        }
                    }
                    ColumnLayout {
                        visible:root.displayPage === "share" || root.displayPage === "devices";Layout.fillWidth:true;spacing:12
                        MetroButton {visible:root.displayPage === "share";text:"Clipboard history";Layout.fillWidth:true;onClicked:root.navigate("clipboard")}
                        MetroButton {visible:root.displayPage === "share";text:"Capture region";Layout.fillWidth:true;onClicked:{root.page="";root.launch([root.home+"/.local/bin/hypr-win8-screenshot","region"]);}}
                        MetroButton {visible:root.displayPage === "share";text:"Open screenshots";Layout.fillWidth:true;onClicked:root.launch(["xdg-open",root.home+"/Pictures/Screenshots"])}
                        MetroButton {visible:root.displayPage === "devices";text:"Displays";Layout.fillWidth:true;onClicked:root.navigate("displays")}
                        MetroButton {visible:root.displayPage === "devices" && !!root.adapter;text:"Bluetooth devices";Layout.fillWidth:true;onClicked:root.navigate("bluetooth")}
                        MetroButton {visible:root.displayPage === "devices";text:"Audio outputs";Layout.fillWidth:true;onClicked:root.navigate("audio")}
                        MetroButton {visible:root.displayPage === "devices";text:"Storage devices";Layout.fillWidth:true;onClicked:root.launch(["nautilus","other-locations:///"])}
                    }
                    ListView {
                        visible:root.displayPage === "displays";Layout.fillWidth:true;Layout.fillHeight:true;spacing:20
                        model:root.displays
                        delegate:ColumnLayout {
                            required property var modelData
                            width:ListView.view.width
                            Label {text:modelData.name+"\n"+modelData.width+"×"+modelData.height+" · "+Math.round(modelData.refreshRate)+" Hz";Layout.fillWidth:true}
                            Label {text:"Scale · live session";color:Theme.muted}
                            Flow {Layout.fillWidth:true;spacing:6
                                Repeater {model:["1","1.25","1.5","2"]
                                    MetroButton {required property string modelData;text:modelData;implicitWidth:68;onClicked:root.backend("scale",[parent.parent.modelData.name,modelData])}
                                }
                            }
                        }
                    }
                    ListView {
                        visible:root.displayPage === "clipboard";Layout.fillWidth:true;Layout.fillHeight:true;spacing:8;clip:true
                        model:root.clipboard.filter(c => c.text.toLowerCase().includes(root.query.toLowerCase()))
                        delegate:MetroButton {required property var modelData;width:ListView.view.width;height:56;text:modelData.text;onClicked:{root.backend("clipboard-copy",[modelData.id]);root.page="";}}
                    }
                    ListView {
                        visible:root.displayPage === "notifications";Layout.fillWidth:true;Layout.fillHeight:true;spacing:12;clip:true
                        model:root.history
                        delegate:Rectangle {
                            id:noticeCard
                            required property var modelData
                            width:ListView.view.width;height:noticeColumn.implicitHeight+28;color:Theme.surface
                            Rectangle {width:4;height:parent.height;color:Theme.accent}
                            ColumnLayout {id:noticeColumn;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:14;spacing:8
                                Label {text:modelData.app+" · "+modelData.time;color:Theme.muted;Layout.fillWidth:true;font.pixelSize:12}
                                Label {text:modelData.summary;font.pixelSize:18;Layout.fillWidth:true}
                                Label {text:modelData.body;font.pixelSize:14;Layout.fillWidth:true}
                                RowLayout {
                                    Repeater {model:noticeCard.modelData.actions || []
                                        MetroButton {required property var modelData;text:modelData.text;enabled:root.notificationFor(noticeCard.modelData.id)!==null;onClicked:root.invokeAction(noticeCard.modelData.id,modelData.identifier)}
                                    }
                                }
                            }
                        }
                    }
                    MetroButton {visible:root.displayPage === "notifications";text:"Clear history";Layout.fillWidth:true;onClicked:root.clearHistory()}
                    ColumnLayout {
                        visible:root.displayPage === "power";Layout.fillWidth:true;spacing:12
                        Repeater {model:[{name:"Lock",action:"lock"},{name:"Sleep",action:"sleep"},{name:"Restart",action:"restart"},{name:"Shutdown",action:"shutdown"},{name:"Logout",action:"logout"}]
                            MetroButton {required property var modelData;Layout.fillWidth:true;implicitHeight:58;text:root.pendingPower === modelData.action ? "Confirm "+modelData.name : modelData.name;fill:root.pendingPower === modelData.action ? Theme.danger : Theme.surface;onClicked:root.power(modelData.action)}
                        }
                    }
                    Item {visible:["charms","share","devices","power"].includes(root.displayPage);Layout.fillHeight:true}
                    Label {visible:!overlay.full;text:"Metro / Hyprland";color:Theme.muted;font.pixelSize:12}
                }
            }
        }
        AppMenu {id:overlayMenu;shell:root}
        function focusPage() {
            if(["search","apps","clipboard"].includes(root.displayPage)) searchField.forceActiveFocus();else keyboard.forceActiveFocus();
        }
        Component.onCompleted:Qt.callLater(focusPage)
        Connections {target:root;function onPageChanged(){Qt.callLater(overlay.focusPage);}}
        onVisibleChanged: if(visible) Qt.callLater(focusPage)
    }
    }
    PanelWindow {
        screen:root.screenForFocus();visible:!root.validation && root.popup !== null && !root.dnd
        anchors {top:true;right:true}
        margins {top:24;right:24}
        implicitWidth:360;implicitHeight:toastColumn.implicitHeight+40;exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"hypr-win8-toast"
        color:Theme.surface
        Rectangle {width:5;height:parent.height;color:Theme.accent}
        ColumnLayout {id:toastColumn;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:20;spacing:8
            Label {text:root.popup?.appName || "";color:Theme.muted;font.pixelSize:12;Layout.fillWidth:true}
            Label {text:root.popup?.summary || "";font.pixelSize:19;Layout.fillWidth:true}
            Label {text:root.popup?.body || "";font.pixelSize:14;maximumLineCount:4;elide:Text.ElideRight;Layout.fillWidth:true}
        }
        MouseArea {anchors.fill:parent;onClicked:{root.popupId=-1;root.navigate("notifications");}}
    }
    PanelWindow {
        screen:root.screenForFocus();visible:!root.validation && !root.preview && root.osdText.length>0
        anchors {bottom:true;left:true}
        margins {bottom:72;left:24}
        implicitWidth:260;implicitHeight:58;exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"hypr-win8-osd"
        color:Theme.surface
        Rectangle {width:5;height:parent.height;color:Theme.accent}
        Label {anchors.centerIn:parent;text:root.osdText;font.pixelSize:20}
    }
    PanelWindow {
        id:authentication
        screen:root.activeScreen
        visible:!root.validation && !!root.authFlow && !root.authFlow.isCompleted
        anchors {top:true;bottom:true;left:true;right:true}
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"hypr-win8-authentication"
        WlrLayershell.keyboardFocus:visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color:"#dd171b26"
        Rectangle {
            anchors.centerIn:parent;width:Math.min(480,parent.width-48);height:authColumn.implicitHeight+56;color:Theme.surface
            Rectangle {width:5;height:parent.height;color:Theme.accent}
            ColumnLayout {
                id:authColumn;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:28;spacing:16
                Label {text:"Authentication";font.pixelSize:30;Layout.fillWidth:true}
                Label {text:root.authFlow?.message || "";Layout.fillWidth:true}
                Label {text:root.authFlow?.supplementaryMessage || "";color:root.authFlow?.supplementaryIsError ? Theme.danger : Theme.muted;Layout.fillWidth:true;visible:text.length>0}
                TextField {
                    id:authInput;Layout.fillWidth:true;enabled:root.authFlow?.isResponseRequired || false
                    echoMode:root.authFlow?.responseVisible ? TextInput.Normal : TextInput.Password
                    placeholderText:root.authFlow?.inputPrompt || "Password"
                    color:Theme.foreground;placeholderTextColor:Theme.muted;font.family:Theme.font
                    background:Rectangle {color:Theme.background;border.color:Theme.accent;border.width:2}
                    onAccepted: {root.authFlow.submit(text);text="";}
                    Keys.onEscapePressed: {root.authFlow.cancelAuthenticationRequest();text="";}
                }
                RowLayout {
                    MetroButton {text:"Cancel";onClicked:{root.authFlow.cancelAuthenticationRequest();authInput.text="";}}
                    MetroButton {text:"Authenticate";enabled:root.authFlow?.isResponseRequired || false;onClicked:{root.authFlow.submit(authInput.text);authInput.text="";}}
                }
            }
        }
        onVisibleChanged: {authInput.text="";if(visible)Qt.callLater(()=>authInput.forceActiveFocus());}
    }
}
