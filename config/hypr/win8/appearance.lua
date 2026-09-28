hl.config({
    general = {border_size=1, gaps_in=3, gaps_out=5, col={active_border="rgba(0078d4ff)",inactive_border="rgba(303849ff)"}},
    decoration = {rounding=1, blur={enabled=false}, shadow={enabled=false}, dim_inactive=false},
    animations = {enabled=true},
    misc = {disable_hyprland_logo=true,disable_splash_rendering=true},
    cursor = {no_hardware_cursors=false}
})
hl.curve("metro",{type="bezier",points={{0.16,0.65},{0.25,1}}})
for _, leaf in ipairs({"windowsIn","windowsOut","windowsMove","fadeIn","fadeOut","layersIn","layersOut","fadeLayersIn","fadeLayersOut","workspaces","specialWorkspaceIn","specialWorkspaceOut"}) do
    hl.animation({leaf=leaf,enabled=true,speed=1.8,bezier="metro",style=leaf=="workspaces" and "slide" or nil})
end
hl.layer_rule({match={namespace="hypr-win8-overlay"},animation="fade"})
