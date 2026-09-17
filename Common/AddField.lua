-- Add a control item to a window
-- coding: utf-8 'ä

local labelFont = Turbine.UI.Lotro.Font.TrajanPro14
local textFont = Turbine.UI.Lotro.Font.TrajanPro16
local foreColor = Turbine.UI.Color( 0.9, 0.9, 0 )
local textColor = Turbine.UI.Color( 1, 1, 0.8 )
local backColor = Turbine.UI.Color( 0, 0, 0.1 )
local Alias = Turbine.UI.Lotro.ShortcutType.Alias
local Button = Turbine.UI.Lotro.Button
local CheckBox = Turbine.UI.Lotro.CheckBox
local DropMenu = Dusk.Common.DropMenu
local ScrollMenu = Dusk.Common.ScrollMenu
local Label = Turbine.UI.Label
local TextBox = Turbine.UI.Lotro.TextBox
local Left = Turbine.UI.ContentAlignment.MiddleLeft
local Center = Turbine.UI.ContentAlignment.MiddleCenter
local Right = Turbine.UI.ContentAlignment.MiddleRight

function AddField(window, control, text, pos, size, color)
	local field = control()
	field:SetParent( window )
	field:SetPosition( pos.x,pos.y )
	field:SetSize( size.x,size.y )
	if text then field:SetText( text ) end
	if control==Button or control==DropMenu or
		control==ScrollMenu or not text then return field end
	field:SetBackColor( backColor )
	if control==TextBox then 
		field:SetReadOnly( true )
		field:SetForeColor( color or textColor )
	else field:SetForeColor( color or foreColor ) end
	field:SetFont( control==TextBox and textFont or labelFont )
	field:SetTextAlignment( control==TextBox and Left or 
					control==Label and Right or Center )
    if text then field:SetText( text ) end
	return field
end
