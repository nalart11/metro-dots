-- Preserve original window/workspace/media binds; explicitly migrate shell actions.
local shell_keys={"SUPER + SUPER_L","SUPER + SUPER_R","SUPER_L","SUPER_R","SUPER + Tab","SUPER + V","SUPER + Period","SUPER + A","SUPER + ALT + A","SUPER + B","SUPER + O","SUPER + N","SUPER + Slash","SUPER + K","SUPER + M","SUPER + G","CTRL + ALT + Delete","SUPER + J","SHIFT + SUPER + ALT + Slash","CTRL + SUPER + T","CTRL + SUPER + ALT + T","CTRL + SUPER + SHIFT + D","CTRL + SUPER + R","CTRL + SUPER + P","SUPER + SHIFT + S","SUPER + SHIFT + A","SUPER + SHIFT + X","SUPER + SHIFT + T","SUPER + SHIFT + R","SUPER + ALT + R","CTRL + ALT + R","SUPER + SHIFT + ALT + R","SUPER + Q","SUPER + C","SUPER + I","SUPER + L","ALT + F4","ALT + Tab","Print","XF86MonBrightnessUp","XF86MonBrightnessDown"}
for _, key in ipairs(shell_keys) do hl.unbind(key) end
local command="$HOME/.local/bin/hypr-win8 "
local function ui(key,page) hl.bind(key,hl.dsp.exec_cmd(command..page),{description="Metro: "..page}) end
for _, key in ipairs({"SUPER + SUPER_L","SUPER + SUPER_R"}) do
    hl.bind(key,hl.dsp.exec_cmd(command.."start"),{release=true,description="Metro: Start"})
end
ui("SUPER + C","charms");ui("SUPER + Q","search");ui("SUPER + I","settings")
ui("SUPER + Tab","workspaces");ui("ALT + Tab","switcher");ui("SUPER + V","clipboard")
ui("SUPER + N","notifications");ui("SUPER + M","settings");ui("CTRL + ALT + Delete","power")
ui("CTRL + SUPER + T","settings");ui("SUPER + A","apps");ui("SUPER + O","workspaces");ui("SUPER + B","charms")
ui("SUPER + G","start");ui("SUPER + J","start");ui("SUPER + Slash","search")
ui("SUPER + Period","clipboard")
hl.bind("ALT + F4",hl.dsp.window.close(),{description="Window: Close"})
hl.bind("SUPER + ALT + C",hl.dsp.exec_cmd(codeEditor),{description="App: Code editor"})
hl.bind("SUPER + L",hl.dsp.exec_cmd("hyprlock -c $HOME/.config/hypr/win8/hyprlock.conf"),{description="Session: Lock"})
hl.bind("Print",hl.dsp.exec_cmd("$HOME/.local/bin/hypr-win8-screenshot monitor"))
hl.bind("SUPER + SHIFT + S",hl.dsp.exec_cmd("$HOME/.local/bin/hypr-win8-screenshot region"))
hl.bind("CTRL + SUPER + R",hl.dsp.exec_cmd("systemctl --user restart hypr-win8-shell.service"))
hl.bind("CTRL + SUPER + SHIFT + D",hl.dsp.exec_cmd("python3 $HOME/.local/bin/hypr-win8-backend theme toggle"))
for _, item in ipairs({{"XF86MonBrightnessUp","5%+"},{"XF86MonBrightnessDown","5%-"}}) do
    hl.bind(item[1],hl.dsp.exec_cmd("brightnessctl set "..item[2]),{repeating=true,locked=true})
end
