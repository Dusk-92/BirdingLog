-- BirdingLog floating desktop icon
-- Left click: show/hide BirdingLog window
-- Left drag: move the icon; position is saved independently

-- Make sure localized PluginData wrappers are installed before icon-state I/O.
import "Dusk.Common"

BL_IconWindow = Turbine.UI.Window()
BL_IconWindow:SetSize(36,36)
-- Normal UI layer: native LOTRO panels such as the world map can cover the icon.
BL_IconWindow:SetZOrder(0)

local sw, sh = Turbine.UI.Display.GetWidth(), Turbine.UI.Display.GetHeight()
local defaultX = math.max(0, sw - 92)
local defaultY = math.max(0, math.floor(sh * 0.45))

local BL_IconState = Turbine.PluginData.Load(Turbine.DataScope.Server,"BL_IconState")
if type(BL_IconState) ~= "table" then BL_IconState = {} end

local savedX = tonumber(BL_IconState.x)
local savedY = tonumber(BL_IconState.y)
if (not savedX or not savedY) and BL_Options and type(BL_Options.iconPos)=="table" then
    savedX = savedX or tonumber(BL_Options.iconPos.x)
    savedY = savedY or tonumber(BL_Options.iconPos.y)
end

local px = math.max(0, math.min(savedX or defaultX, sw - 36))
local py = math.max(0, math.min(savedY or defaultY, sh - 36))
BL_IconWindow:SetPosition(px,py)

function BL_SaveIconPosition()
    if not BL_IconWindow then return end
    local x,y = BL_IconWindow:GetPosition()
    x,y = math.floor(x+0.5), math.floor(y+0.5)
    BL_IconState.x, BL_IconState.y = tostring(x), tostring(y)
    Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_IconState",BL_IconState)
    if BL_Options then
        BL_Options.iconPos = {x=x,y=y} -- backwards compatibility
    end
end

-- Create the dedicated state immediately when migrating from an older save.
if not tonumber(BL_IconState.x) or not tonumber(BL_IconState.y) then
    BL_SaveIconPosition()
end

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

local function finishDrag(sender,args)
    if args and args.Button and args.Button ~= Turbine.UI.MouseButton.Left then return end
    if not dragging then return end
    dragging = false
    if moved then
        BL_SaveIconPosition()
    else
        local visible = not BL_window:IsVisible()
        BL_window:SetVisible(visible)
        if visible then BL_window:SetZOrder(2) end
    end
end

icon.MouseUp = finishDrag
BL_IconWindow.MouseUp = finishDrag
BL_IconWindow:SetVisible(true)
