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
    property string query: ""
    property string errorMessage: ""
    property string pendingPower: ""
    property bool dnd: false
    property bool night: false
    property bool zoomed: false
    property int selectedWindow: 0
    property var activeScreen: Quickshell.screens[0] || null
    property var stats: ({cpu:0, ram:0, temperature:null, brightness:null})
    property var tiles: []
    property var clipboard: []
    property var displays: []
    property var history: []
    property var popup: null
    property string layout: "EN"
    property string osdText: ""
    property date now: new Date()
    readonly property var player: Mpris.players.values[0] || null
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var wifiDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property string networkName: Networking.devices.values.filter(d => d.connected).map(d => d.type === DeviceType.Wifi ? (d.networks.values.find(n => n.connected)?.name || d.name) : d.name).join(" · ") || "Offline"
    readonly property var groups: [...new Set(tiles.filter(t => t.live !== "battery" || UPower.displayDevice.isLaptopBattery).map(t => t.group))]
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a,b) => a.name.localeCompare(b.name))
    readonly property var filteredApps: apps.filter(a => (a.name + " " + a.genericName + " " + a.categories.join(" ") + " " + a.keywords.join(" ")).toLowerCase().includes(query.toLowerCase()))
    readonly property var windows: ToplevelManager.toplevels.values
    onPageChanged: {wifiDevices.forEach(d => d.scannerEnabled = page === "settings");}
    function exec(args) { Quickshell.execDetached(args); }
    function backend(action, args) { exec(["python3", helper, action].concat(args || [])); }
    function screenForFocus() { return Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0]; }
    function toggle(name) {
        if (name === "switcher" && page === name) { selectedWindow = (selectedWindow + 1) % Math.max(1,windows.length); return; }
        activeScreen = screenForFocus(); query = ""; pendingPower = ""; errorMessage = "";
        page = page === name ? "" : name;
        if (name === "switcher") selectedWindow = windows.length > 1 ? 1 : 0;
        if (page === "clipboard") clipProcess.running = true;
        if (page === "displays") displayProcess.running = true;
    }
    function navigate(name) { page = ""; toggle(name); }
    function launchApp(a) { backend("launch", [a.id]); page = ""; }
    function launchTile(t) {
        if (t.action) { navigate(t.action); return; }
        if (t.live === "music") { if (player?.canTogglePlaying) player.togglePlaying(); return; }
        if (t.live === "network") { navigate("settings"); return; }
        if (t.desktop) { backend("launch", [t.desktop]); page = ""; }
        else if (t.command?.length) { exec(t.command); page = ""; }
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
    function activateWindow() { if (windows[selectedWindow]) windows[selectedWindow].activate(); page = ""; }
    function power(action) {
        if (action === "lock") { page = ""; backend("power",[action]); }
        else if (pendingPower === action) { page = ""; backend("power",[action]); pendingPower = ""; }
        else pendingPower = action;
    }
    IpcHandler {
        target: "metro"
        function toggle(page: string): void { root.toggle(page); }
        function status(): string { return JSON.stringify({page:root.page,apps:root.apps.length,tiles:root.tiles.length,screens:Quickshell.screens.length,notifications:root.history.length,stats:root.stats}); }
        function close(): void { root.page = ""; }
    }
    // Compatibility for preserved touchpad gestures.
    GlobalShortcut { name: "overviewWorkspacesToggle"; onPressed: root.toggle("workspaces") }
    FileView {
        path: (Quickshell.env("HYPR_WIN8_DATA") || root.home + "/.config/hypr-win8") + "/tiles.json"; watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.tiles = JSON.parse(text()); } catch(e) { console.error("Tiles JSON: " + e); } }
    }
    Timer { interval:1000; running:!root.validation; repeat:true; onTriggered:root.now = new Date() }
    Process {
        id: metricsProcess; command:["python3",root.helper,"metrics"]; running:!root.validation
        stdout: SplitParser { onRead: data => { try { root.stats=JSON.parse(data); } catch(e) { console.error(e); } } }
        onExited: (code,status) => { if(code) console.error("Metrics failed: "+code); }
    }
    Process {
        id: clipProcess; command:["python3",root.helper,"clipboard-list"]
        stdout: StdioCollector { onStreamFinished: { try {root.clipboard=JSON.parse(text);} catch(e) {root.errorMessage="Clipboard unavailable";} } }
    }
    Process {
        id: displayProcess; command:["python3",root.helper,"displays"]
        stdout: StdioCollector { onStreamFinished: { try {root.displays=JSON.parse(text);} catch(e) {root.errorMessage="Display query failed";} } }
    }
    PwObjectTracker { objects: [root.sink] }
    Connections {
        target: Hyprland
        function onRawEvent(event) { if(event.name === "activelayout") root.layout = event.data.toLowerCase().includes("russian") ? "RU" : "EN"; }
    }
    LazyLoader {
        active: !root.validation && !root.preview
        NotificationServer {
            actionsSupported:true; bodySupported:true; bodyMarkupSupported:false; persistenceSupported:true
            onNotification: n => {
                n.tracked = true;
                root.history = [{app:n.appName,summary:n.summary,body:n.body,time:Qt.formatDateTime(new Date(),"HH:mm"),notification:n}].concat(root.history).slice(0,100);
                if (!root.dnd) {root.popup=n;if(n.expireTimeout!==0){popupTimer.interval=n.expireTimeout > 0 ? n.expireTimeout : 6000;popupTimer.restart();}}
            }
        }
    }
    Connections {
        target: root.sink?.audio || null
        function onVolumesChanged() {root.osdText="Volume  "+Math.round((root.sink?.audio?.volume || 0)*100)+"%";osdTimer.restart();}
        function onMutedChanged() {root.osdText=root.sink?.audio?.muted ? "Muted" : "Sound on";osdTimer.restart();}
    }
    Timer {id:osdTimer;interval:1800;onTriggered:root.osdText=""}
    Timer {id:popupTimer; onTriggered:{let n=root.popup;root.popup=null;if(n && !n.resident)n.expire();}}
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
                source: "file://" + root.home + "/.local/share/hypr-win8-dots/assets/wallpapers/" + (Theme.data.wallpaper || "metro-blue.svg")
                fillMode:Image.PreserveAspectCrop; asynchronous:true
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
                MetroButton {
                    implicitWidth:64;implicitHeight:48;fill:Theme.accent
                    Image {anchors.centerIn:parent;width:26;height:26;source:"file://"+root.home+"/.local/share/hypr-win8-dots/assets/icons/start.svg"}
                    onClicked: {root.activeScreen=bar.screen;root.query="";root.page=root.page==="start" ? "" : "start";}
                    ToolTip.visible:hovered;ToolTip.text:"Start · Super"
                }
                Repeater {
                    model:root.tiles.filter(t => t.desktop).slice(0,4)
                    MetroButton {
                        required property var modelData
                        implicitWidth:48;implicitHeight:48
                        fill:Theme.surface
                        Image {anchors.centerIn:parent;width:24;height:24;source:Quickshell.iconPath(modelData.icon,"application-x-executable")}
                        onClicked:root.launchTile(modelData)
                        ToolTip.visible:hovered;ToolTip.text:modelData.name
                    }
                }
                Rectangle {Layout.preferredWidth:1;Layout.preferredHeight:28;color:Theme.secondary;Layout.leftMargin:8;Layout.rightMargin:8}
                Repeater {
                    model:Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor?.name === bar.screen.name)
                    MetroButton {
                        required property var modelData
                        text:String(modelData.id);implicitWidth:32;implicitHeight:32;selected:modelData.active
                        fill:Theme.surface;onClicked:modelData.activate()
                        ToolTip.visible:hovered;ToolTip.text:"Desktop " + modelData.id
                    }
                }
                ListView {
                    Layout.fillWidth:true;Layout.fillHeight:true;orientation:ListView.Horizontal;clip:true;spacing:3
                    model:root.windows
                    delegate:MetroButton {
                        required property var modelData
                        width:Math.min(170,Math.max(70,bar.width/12));height:48;text:modelData.title
                        fill:modelData.activated ? Theme.secondary : Theme.surface
                        onClicked:modelData.activate()
                        Rectangle {anchors.bottom:parent.bottom;anchors.left:parent.left;anchors.right:parent.right;height:modelData.activated ? 3 : 1;color:Theme.accent}
                        ToolTip.visible:hovered;ToolTip.text:modelData.title
                    }
                }
                Repeater {
                    model:SystemTray.items
                    MetroButton {
                        id:trayButton
                        required property var modelData
                        implicitWidth:32;implicitHeight:48;fill:Theme.surface
                        Image {anchors.centerIn:parent;width:20;height:20;source:trayButton.modelData.icon}
                        onClicked: { if(modelData.onlyMenu && modelData.hasMenu) modelData.display(bar,bar.width-200,0);else modelData.activate(); }
                        MouseArea {anchors.fill:parent;acceptedButtons:Qt.RightButton;onClicked:trayButton.modelData.display(bar,bar.width-200,0)}
                        ToolTip.visible:hovered;ToolTip.text:modelData.tooltipTitle || modelData.title
                    }
                }
                MetroButton {text:root.networkName === "Offline" ? "⊘" : "⇄";implicitWidth:38;fill:Theme.surface;onClicked:root.toggle("settings");ToolTip.visible:hovered;ToolTip.text:root.networkName}
                MetroButton {text:root.sink?.audio?.muted ? "Mute" : Math.round((root.sink?.audio?.volume || 0)*100)+"%";implicitWidth:52;fill:Theme.surface;onClicked:root.toggle("settings")}
                MetroButton {visible:UPower.displayDevice.isLaptopBattery;text:Math.round(UPower.displayDevice.percentage*100)+"%";fill:Theme.surface;onClicked:root.toggle("settings")}
                MetroButton {text:"▤ " + root.history.length;implicitWidth:48;fill:Theme.surface;onClicked:root.toggle("notifications")}
                MetroButton {text:root.layout;implicitWidth:40;fill:Theme.surface;onClicked:root.exec(["hyprctl","switchxkblayout","all","next"])}
                MetroButton {text:Qt.formatDateTime(root.now,"HH:mm\ndd.MM.yyyy");implicitWidth:102;implicitHeight:48;font.pixelSize:13;fill:Theme.surface;onClicked:root.toggle("start")}
            }
        }
    }
    PanelWindow {
        id: overlay
        screen:root.activeScreen
        visible:!root.validation && root.page !== ""
        anchors {top:true;bottom:true;left:true;right:true}
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.namespace:"hypr-win8-overlay"
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.keyboardFocus:root.page !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color:"transparent"
        property bool full:root.page === "start" || root.page === "apps" || root.page === "search" || root.page === "workspaces" || root.page === "switcher"
        MouseArea {anchors.fill:parent;onClicked:root.page=""}
        Rectangle {
            id: panel
            anchors.top:parent.top;anchors.bottom:parent.bottom;anchors.right:parent.right
            width:overlay.full ? parent.width : Math.min(440,parent.width)
            color:Theme.background
            Behavior on width {NumberAnimation {duration:160;easing.type:Easing.OutCubic}}
            MouseArea {anchors.fill:parent}
            Item {
                id: keyboard
                anchors.fill:parent;focus:true
                Keys.onPressed: event => {
                    if(event.key === Qt.Key_Escape) {root.page="";event.accepted=true;}
                    else if(root.page === "switcher" && event.key === Qt.Key_Tab) {root.selectedWindow=(root.selectedWindow+1)%Math.max(1,root.windows.length);event.accepted=true;}
                    else if(root.page === "switcher" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {root.activateWindow();event.accepted=true;}
                    else if(root.page === "start" && event.text.length && !(event.modifiers & (Qt.ControlModifier|Qt.AltModifier|Qt.MetaModifier))) {root.page="search";root.query=event.text;searchField.forceActiveFocus();event.accepted=true;}
                }
                Keys.onReleased: event => {if(root.page === "switcher" && event.key === Qt.Key_Alt) root.activateWindow();}
                ColumnLayout {
                    anchors.fill:parent
                    anchors.margins:overlay.full ? Math.max(32,Math.min(100,panel.width*.05)) : 28
                    spacing:22
                    RowLayout {
                        Layout.fillWidth:true
                        Label {text:root.page === "start" ? "Start" : root.page === "apps" ? "All apps" : root.page === "switcher" ? "Windows" : root.page.charAt(0).toUpperCase()+root.page.slice(1);font.pixelSize:overlay.full ? 52 : 36;font.weight:Font.Light;Layout.fillWidth:true}
                        MetroButton {text:"×";implicitWidth:44;fill:Theme.background;onClicked:root.page=""}
                    }
                    Label {visible:root.errorMessage.length>0;text:root.errorMessage;color:Theme.danger;Layout.fillWidth:true}
                    TextField {
                        id:searchField
                        visible:["search","apps","clipboard"].includes(root.page)
                        Layout.fillWidth:true;Layout.preferredHeight:48
                        text:root.query;onTextEdited:root.query=text
                        placeholderText:root.page === "clipboard" ? "Search clipboard" : "Search apps, settings · > command"
                        color:Theme.foreground;placeholderTextColor:Theme.muted;font.family:Theme.font;font.pixelSize:18
                        background:Rectangle {color:Theme.surface;border.color:Theme.accent;border.width:2}
                        onAccepted: {
                            if(root.query.startsWith(">")) {root.exec(["bash","-lc",root.query.slice(1).trim()]);root.page="";}
                            else if(root.filteredApps.length) root.launchApp(root.filteredApps[0]);
                        }
                        Keys.onEscapePressed:root.page=""
                    }
                    Flickable {
                        visible:root.page === "start";Layout.fillWidth:true;Layout.fillHeight:true
                        contentWidth:tileRow.width;contentHeight:Math.max(height,tileRow.height);clip:true
                        ScrollBar.horizontal:ScrollBar {policy:ScrollBar.AsNeeded}
                        Row {
                            id:tileRow;spacing:44
                            property int unit:root.zoomed ? 82 : Math.max(96,Math.min(154,(parent.height-70)/4-10))
                            Repeater {
                                model:root.groups
                                Column {
                                    id:groupColumn
                                    required property string modelData
                                    spacing:18
                                    Label {text:groupColumn.modelData;font.pixelSize:22;color:Theme.muted}
                                    Item {
                                        width:4*tileRow.unit+30;height:4*tileRow.unit+30
                                        Repeater {
                                            model:root.tiles.filter(t => t.group === groupColumn.modelData && (t.live !== "battery" || UPower.displayDevice.isLaptopBattery))
                                            Rectangle {
                                                id:tile
                                                required property var modelData
                                                x:modelData.x*(tileRow.unit+10);y:modelData.y*(tileRow.unit+10)
                                                width:modelData.w*tileRow.unit+(modelData.w-1)*10;height:modelData.h*tileRow.unit+(modelData.h-1)*10
                                                color:tileMouse.containsMouse ? Qt.lighter(modelData.color,1.15) : modelData.color
                                                border.width:tileMouse.containsMouse ? 2 : 0;border.color:"#bfffffff"
                                                scale:tileMouse.pressed ? .97 : 1
                                                Behavior on scale {NumberAnimation {duration:130}}
                                                Image {visible:!tile.modelData.live && !root.zoomed;width:Math.min(60,tile.width*.4);height:width;anchors.centerIn:parent;source:Quickshell.iconPath(tile.modelData.icon || "preferences-system","application-x-executable")}
                                                Label {
                                                    visible:!!tile.modelData.live;text:root.tileBody(tile.modelData);anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:18
                                                    color:"white";font.pixelSize:tile.modelData.live === "clock" && !root.zoomed ? 32 : root.zoomed ? 13 : 18
                                                    maximumLineCount:4;elide:Text.ElideRight
                                                }
                                                Label {text:tile.modelData.name;anchors.left:parent.left;anchors.bottom:parent.bottom;anchors.margins:14;color:"white";font.pixelSize:root.zoomed ? 13 : 16}
                                                MouseArea {id:tileMouse;anchors.fill:parent;hoverEnabled:true;onClicked:root.launchTile(tile.modelData)}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        visible:root.page === "start";Layout.fillWidth:true
                        MetroButton {text:"↓  All apps";onClicked:{root.page="apps";root.query="";searchField.forceActiveFocus();}}
                        MetroButton {text:root.zoomed ? "+  Expand" : "−  Groups";onClicked:root.zoomed=!root.zoomed}
                        Item {Layout.fillWidth:true}
                        MetroButton {text:"Settings";onClicked:root.navigate("settings")}
                        MetroButton {text:"Power";onClicked:root.navigate("power")}
                    }
                    GridView {
                        visible:root.page === "apps" || root.page === "search";Layout.fillWidth:true;Layout.fillHeight:true
                        cellWidth:Math.max(220,Math.floor(width/Math.max(1,Math.floor(width/270))));cellHeight:76;clip:true
                        model:root.filteredApps
                        ScrollBar.vertical:ScrollBar {}
                        delegate:MetroButton {
                            required property var modelData
                            width:GridView.view.cellWidth-12;height:64;fill:Theme.surface
                            contentItem:RowLayout {
                                spacing:14
                                Image {Layout.preferredWidth:32;Layout.preferredHeight:32;source:Quickshell.iconPath(modelData.icon,"application-x-executable")}
                                ColumnLayout {Layout.fillWidth:true;spacing:2
                                    Label {text:modelData.name;Layout.fillWidth:true;elide:Text.ElideRight;maximumLineCount:1}
                                    Label {text:modelData.categories.slice(0,2).join(" · ");font.pixelSize:11;color:Theme.muted;Layout.fillWidth:true;elide:Text.ElideRight;maximumLineCount:1}
                                }
                            }
                            onClicked:root.launchApp(modelData)
                        }
                    }
                    RowLayout {
                        visible:root.page === "search";Layout.fillWidth:true
                        Repeater {model:["Settings","Displays","Power","Clipboard"].filter(s => s.toLowerCase().includes(root.query.toLowerCase()))
                            MetroButton {required property string modelData;text:modelData;onClicked:root.navigate(modelData.toLowerCase())}
                        }
                        MetroButton {text:"Run command";visible:root.query.startsWith(">");onClicked:{root.exec(["bash","-lc",root.query.slice(1).trim()]);root.page="";}}
                    }
                    ListView {
                        visible:root.page === "switcher";Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:12
                        model:root.windows
                        delegate:MetroButton {
                            required property var modelData;required property int index
                            width:ListView.view.width;height:82;selected:index===root.selectedWindow;text:modelData.title
                            onClicked:{modelData.activate();root.page="";}
                        }
                    }
                    Flow {
                        visible:root.page === "workspaces";Layout.fillWidth:true;Layout.fillHeight:true;spacing:16
                        Repeater {
                            model:Hyprland.workspaces
                            MetroButton {required property var modelData;visible:modelData.id>0;text:"Desktop "+modelData.id+"\n"+(modelData.monitor?.name || "");width:200;height:128;selected:modelData.focused;onClicked:{modelData.activate();root.page="";}}
                        }
                    }
                    ColumnLayout {
                        visible:root.page === "charms";Layout.fillWidth:true;spacing:12
                        Repeater {model:["Search","Share","Start","Devices","Settings"]
                            MetroButton {required property string modelData;text:modelData;Layout.fillWidth:true;implicitHeight:72;fill:Theme.surface;onClicked:root.navigate(modelData.toLowerCase())}
                        }
                    }
                    ScrollView {
                        visible:root.page === "settings";Layout.fillWidth:true;Layout.fillHeight:true;clip:true
                        ColumnLayout {
                            width:parent.width;spacing:16
                            Label {text:"Connection · "+root.networkName;Layout.fillWidth:true;color:Theme.muted}
                            MetroButton {visible:root.wifiDevices.length>0;text:Networking.wifiEnabled ? "Wi-Fi  On" : "Wi-Fi  Off";Layout.fillWidth:true;selected:Networking.wifiEnabled;onClicked:Networking.wifiEnabled=!Networking.wifiEnabled}
                            Repeater {
                                model:root.wifiDevices
                                ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth:true
                                    Repeater {
                                        model:modelData.networks
                                        MetroButton {
                                            required property var modelData
                                            Layout.fillWidth:true;text:modelData.name+"  "+(modelData.connected ? "Connected" : Math.round(modelData.signalStrength*100)+"%")
                                            onClicked: {
                                                if(modelData.connected) modelData.disconnect();
                                                else if(modelData.known) modelData.connect();
                                                else { root.page="";root.exec(["kitty","-e","nmcli","--ask","device","wifi","connect",modelData.name]); }
                                            }
                                        }
                                    }
                                }
                            }
                            MetroButton {visible:!!root.adapter;text:root.adapter?.enabled ? "Bluetooth  On" : "Bluetooth  Off";selected:root.adapter?.enabled || false;Layout.fillWidth:true;onClicked:root.adapter.enabled=!root.adapter.enabled}
                            MetroButton {visible:!!root.adapter && root.adapter.enabled;text:root.adapter?.discovering ? "Stop discovery" : "Discover devices";Layout.fillWidth:true;onClicked:root.adapter.discovering=!root.adapter.discovering}
                            Repeater {
                                model:root.adapter?.devices || []
                                MetroButton {
                                    required property var modelData
                                    Layout.fillWidth:true;text:modelData.name+" · "+(modelData.connected ? "Connected" : modelData.paired ? "Paired" : "Available")
                                    onClicked: {if(modelData.connected) modelData.disconnect();else if(modelData.paired) modelData.connect();else root.exec(["blueman-manager"]);}
                                }
                            }
                            Label {text:"Volume · "+(root.sink?.nickname || root.sink?.description || "No output");Layout.fillWidth:true}
                            Slider {
                                Layout.fillWidth:true;from:0;to:1;value:root.sink?.audio?.volume || 0
                                onMoved:root.exec(["wpctl","set-volume","@DEFAULT_AUDIO_SINK@",value.toFixed(2),"--limit","1"])
                                background:Rectangle {x:parent.leftPadding;y:parent.topPadding+parent.availableHeight/2-2;width:parent.availableWidth;height:4;color:Theme.secondary;Rectangle{width:parent.width*parent.parent.visualPosition;height:4;color:Theme.accent}}
                                handle:Rectangle {x:parent.leftPadding+parent.visualPosition*(parent.availableWidth-width);y:parent.topPadding+parent.availableHeight/2-10;width:12;height:20;color:Theme.accent}
                            }
                            MetroButton {text:root.sink?.audio?.muted ? "Unmute" : "Mute";Layout.fillWidth:true;onClicked:root.exec(["wpctl","set-mute","@DEFAULT_AUDIO_SINK@","toggle"])}
                            Repeater {
                                model:Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
                                MetroButton {required property var modelData;Layout.fillWidth:true;text:modelData.nickname || modelData.description;selected:modelData===root.sink;onClicked:root.exec(["wpctl","set-default",String(modelData.id)])}
                            }
                            Label {visible:root.stats.brightness !== null;text:"Brightness · "+root.stats.brightness+"%"}
                            Slider {visible:root.stats.brightness !== null;Layout.fillWidth:true;from:1;to:100;value:root.stats.brightness || 50;onMoved:root.exec(["brightnessctl","set",Math.round(value)+"%"])}
                            MetroButton {text:root.night ? "Night mode  On" : "Night mode  Off";Layout.fillWidth:true;selected:root.night;onClicked:{root.night=!root.night;root.exec(["hyprctl","hyprsunset",root.night ? "temperature" : "identity"].concat(root.night ? ["4000"] : []));}}
                            MetroButton {text:root.dnd ? "Do not disturb  On" : "Do not disturb  Off";Layout.fillWidth:true;selected:root.dnd;onClicked:root.dnd=!root.dnd}
                            MetroButton {text:Theme.light ? "Dark mode" : "Light mode";Layout.fillWidth:true;onClicked:root.backend("theme",[Theme.light ? "dark" : "light"])}
                            Flow {Layout.fillWidth:true;spacing:8
                                Repeater {model:["#0078d4","#008ba8","#7441a0","#b25417","#16865b","#c42b1c"]
                                    MetroButton {required property string modelData;width:44;implicitWidth:44;fill:modelData;text:"";onClicked:root.backend("theme",[Theme.light ? "light" : "dark",modelData])}
                                }
                            }
                            MetroButton {text:"Displays";Layout.fillWidth:true;onClicked:root.navigate("displays")}
                            MetroButton {text:"Power";Layout.fillWidth:true;onClicked:root.navigate("power")}
                        }
                    }
                    ColumnLayout {
                        visible:root.page === "share" || root.page === "devices";Layout.fillWidth:true;spacing:12
                        MetroButton {visible:root.page === "share";text:"Clipboard history";Layout.fillWidth:true;onClicked:root.navigate("clipboard")}
                        MetroButton {visible:root.page === "share";text:"Capture region";Layout.fillWidth:true;onClicked:{root.page="";root.exec([root.home+"/.local/bin/hypr-win8-screenshot","region"]);}}
                        MetroButton {visible:root.page === "share";text:"Open screenshots";Layout.fillWidth:true;onClicked:root.exec(["xdg-open",root.home+"/Pictures/Screenshots"])}
                        MetroButton {visible:root.page === "devices";text:"Displays";Layout.fillWidth:true;onClicked:root.navigate("displays")}
                        MetroButton {visible:root.page === "devices" && !!root.adapter;text:"Bluetooth devices";Layout.fillWidth:true;onClicked:root.exec(["blueman-manager"])}
                        MetroButton {visible:root.page === "devices";text:"Audio outputs";Layout.fillWidth:true;onClicked:root.navigate("settings")}
                        MetroButton {visible:root.page === "devices";text:"Storage devices";Layout.fillWidth:true;onClicked:root.exec(["nautilus","other-locations:///"])}
                    }
                    ListView {
                        visible:root.page === "displays";Layout.fillWidth:true;Layout.fillHeight:true;spacing:20
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
                        visible:root.page === "clipboard";Layout.fillWidth:true;Layout.fillHeight:true;spacing:8;clip:true
                        model:root.clipboard.filter(c => c.text.toLowerCase().includes(root.query.toLowerCase()))
                        delegate:MetroButton {required property var modelData;width:ListView.view.width;height:56;text:modelData.text;onClicked:{root.backend("clipboard-copy",[modelData.id]);root.page="";}}
                    }
                    ListView {
                        visible:root.page === "notifications";Layout.fillWidth:true;Layout.fillHeight:true;spacing:12;clip:true
                        model:root.history
                        delegate:Rectangle {
                            required property var modelData
                            width:ListView.view.width;height:noticeColumn.implicitHeight+28;color:Theme.surface
                            Rectangle {width:4;height:parent.height;color:Theme.accent}
                            ColumnLayout {id:noticeColumn;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:14;spacing:8
                                Label {text:modelData.app+" · "+modelData.time;color:Theme.muted;Layout.fillWidth:true;font.pixelSize:12}
                                Label {text:modelData.summary;font.pixelSize:18;Layout.fillWidth:true}
                                Label {text:modelData.body;font.pixelSize:14;Layout.fillWidth:true}
                                RowLayout {
                                    Repeater {model:modelData.notification?.actions || []
                                        MetroButton {required property var modelData;text:modelData.text;onClicked:modelData.invoke()}
                                    }
                                }
                            }
                        }
                    }
                    MetroButton {visible:root.page === "notifications";text:"Clear history";Layout.fillWidth:true;onClicked:root.history=[]}
                    ColumnLayout {
                        visible:root.page === "power";Layout.fillWidth:true;spacing:12
                        Repeater {model:[{name:"Lock",action:"lock"},{name:"Sleep",action:"sleep"},{name:"Restart",action:"restart"},{name:"Shutdown",action:"shutdown"},{name:"Logout",action:"logout"}]
                            MetroButton {required property var modelData;Layout.fillWidth:true;implicitHeight:58;text:root.pendingPower === modelData.action ? "Confirm "+modelData.name : modelData.name;fill:root.pendingPower === modelData.action ? Theme.danger : Theme.surface;onClicked:root.power(modelData.action)}
                        }
                    }
                    Item {visible:["charms","share","devices","power"].includes(root.page);Layout.fillHeight:true}
                    Label {visible:!overlay.full;text:"Metro / Hyprland";color:Theme.muted;font.pixelSize:12}
                }
            }
        }
        onVisibleChanged: if(visible) {keyboard.forceActiveFocus();if(["search","apps","clipboard"].includes(root.page)) searchField.forceActiveFocus();}
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
        MouseArea {anchors.fill:parent;onClicked:{root.popup=null;root.navigate("notifications");}}
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
}
