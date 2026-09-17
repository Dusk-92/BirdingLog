-- Drop-down menu handler

import "Turbine.UI.Lotro"

local Black = Turbine.UI.Color(0,0,0)
local Bronze = Turbine.UI.Color(229/255,209/255,136/255)
local Highlight = Turbine.UI.Color(0.85,0.65,0)
local Grey = Turbine.UI.Color(0.63,0.63,0.63)
local White = Turbine.UI.Color(1,1,1)

DropMenu = class(Turbine.UI.Control)

function DropMenu:Constructor()
	Turbine.UI.Control.Constructor(self)
    self:SetBackColor(Grey)
	--self:SetOpacity(1)
	self:SetVisible(true)

	self.Menu = Turbine.UI.Label()
	self.Menu:SetParent(self)
	self.Menu:SetPosition(2,2)
	self.Menu:SetHeight(16)
	self.Menu:SetOutlineColor(Highlight)
	self.Menu:SetForeColor(Bronze)
    self.Menu:SetBackColor(Black)
	self.Menu:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter )
	self.Menu:SetFont( Turbine.UI.Lotro.Font.TrajanPro14 )

	function self.Menu:MouseClick()
		if self.menu then
			self.menu:Close()
			self.menu = nil
			return
		end
		self.Click()
		if self.menu then
			local x,y = self:PointToScreen(0,20)
			self.menu:ShowMenuAt(x,y)
		end
	end

	-- Drop down arrow shown in the control.
	self.arrow = Turbine.UI.Control()
	self.arrow:SetParent(self.Menu)
	self.arrow:SetSize(14,14)
	self.arrow:SetBackground(0x41007e18)
	self.arrow:SetStretchMode(1)
	self.arrow.MouseClick = function()
		self.Menu.MouseClick(self.Menu)
	end
end

function DropMenu:SizeChanged()
	local x,y = self:GetSize()
	self.Menu:SetSize(x-4, y-4)
	self.arrow:SetPosition(x- 19, y-19)
end

function DropMenu:SetText(text)
	self.Menu:SetText(text)
end

function DropMenu:GetText()
	return self.Menu:GetText()
end

function DropMenu:MouseEnter()
	self.arrow:SetBackground(0x41007e1b)
	self.Menu:SetForeColor(White)
	self.Menu:SetFontStyle(8)
end

function DropMenu:MouseLeave()
	self.arrow:SetBackground(0x41007e18)
	self.Menu:SetForeColor(Bronze)
	self.Menu:SetFontStyle(0)
end

function DropMenu:addItem(menu, name, check)
	local Item = Turbine.UI.MenuItem(name)
	local print = DropMenu.print or print
	Item:SetChecked(check)
	Item.Click = function( sender,args )
		local selected = sender:GetText()
		menu:SetText( selected )
		print( "Selected "..selected )
		if menu.action then menu.action(selected) end
		menu.menu = nil
	end
	DropMenu.Items:Add( Item )
end

function DropMenu:BuildMenu(list, action, all, print)
	DropMenu.print = print
	if action then self.Menu.action = action end
	local menu = Turbine.UI.ContextMenu()
	DropMenu.Items = menu:GetItems()
	local selected = self.Menu:GetText()
	if all then DropMenu:addItem(self.Menu, all, all==selected) end
	for i,name in ipairs(list) do
        DropMenu:addItem(self.Menu, name, name==selected)
	end
	self.Menu.menu = menu
end
