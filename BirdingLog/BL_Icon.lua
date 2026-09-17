-- BirdingLog floating desktop icon
-- Left click: show/hide BirdingLog window
-- Left drag: move the icon; position is saved in BL_Options

BL_IconWindow = Turbine.UI.Window()
BL_IconWindow:SetSize(36,36)
BL_IconWindow:SetZOrder(1000)

local sw, sh = Turbine.UI.Display.GetWidth(), Turbine.UI.Display.GetHeight()
local defaultPos = { x = math.max(0, sw - 92), y = math.max(0, math.floor(sh * 0.45)) }
local p = BL_Options.iconPos or defaultPos
local px = math.max(0, math.min(tonumber(p.x) or defaultPos.x, sw - 36))
local py = math.max(0, math.min(tonumber(p.y) or defaultPos.y, sh - 36))
BL_IconWindow:SetPosition(px,py)

local icon = Turbine.UI.Control()
icon:SetParent(BL_IconWindow)
icon:SetPosition(2,2)
icon:SetSize(32,32)
icon:SetBackground("Dusk/BirdingLog/Bird.tga")

local dragging = false
local moved = false
local startMouseX, startMouseY = 0,0
local startX, startY = 0,0

icon.MouseDown = function(sender,args)
    if args.Button ~= Turbine.UI.MouseButton.Left then return end
    dragging = true
    moved = false
    startMouseX, startMouseY = Turbine.UI.Display.GetMouseX(), Turbine.UI.Display.GetMouseY()
    startX, startY = BL_IconWindow:GetPosition()
end

icon.MouseMove = function(sender,args)
    if not dragging then return end
    local mx,my = Turbine.UI.Display.GetMouseX(), Turbine.UI.Display.GetMouseY()
    local dx,dy = mx-startMouseX, my-startMouseY
    if math.abs(dx)>2 or math.abs(dy)>2 then moved = true end
    if moved then
        local x = math.max(0, math.min(startX+dx, Turbine.UI.Display.GetWidth()-36))
        local y = math.max(0, math.min(startY+dy, Turbine.UI.Display.GetHeight()-36))
        BL_IconWindow:SetPosition(x,y)
    end
end

icon.MouseUp = function(sender,args)
    if args.Button ~= Turbine.UI.MouseButton.Left then return end
    if not dragging then return end
    dragging = false
    if moved then
        local x,y = BL_IconWindow:GetPosition()
        BL_Options.iconPos = { x=x, y=y }
        Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_Options",BL_Options)
    else
        local visible = not BL_window:IsVisible()
        BL_window:SetVisible(visible)
        if visible then BL_window:SetZOrder(2) end
    end
end

BL_IconWindow:SetVisible(true)
