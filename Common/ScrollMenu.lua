-- Scrollable drop-down menu handler

import "Turbine.UI.Lotro"

local Black = Turbine.UI.Color(0,0,0)
local Bronze = Turbine.UI.Color(229/255,209/255,136/255)
local Highlight = Turbine.UI.Color(0.85,0.65,0)
local Grey = Turbine.UI.Color(0.63,0.63,0.63)
local Grey2 = Turbine.UI.Color(0.6,0.6,0.6)
local White = Turbine.UI.Color(1,1,1)
local Vertical = Turbine.UI.Orientation.Vertical
local TP14 = Turbine.UI.Lotro.Font.TrajanPro14
local TPB16 = Turbine.UI.Lotro.Font.TrajanProBold16

ScrollMenu = class(Turbine.UI.Control)

function ScrollMenu:AddScroll(field, orientation)
	local scroll = Turbine.UI.Lotro.ScrollBar()
	local left, top = field:GetPosition()
	local width, height = field:GetSize()
	scroll:SetParent( field )
	scroll:SetOrientation( orientation )
	scroll:SetValue( 0 )
	if orientation==Vertical then
		scroll:SetPosition( left+width-28, top )
		scroll:SetSize( 10, height )
		field:SetVerticalScrollBar( scroll )
	else
		scroll:SetPosition( left, top+height-10 )
		scroll:SetSize( width, 10 )
		field:SetHorizontalScrollBar( scroll )
	end
	return scroll
end

-- checkMark box for menu.
-- function ScrollMenu:addCheck(field,pos)
-- 	local checkMark = Turbine.UI.Control()
-- 	checkMark:SetParent(field)
-- 	checkMark:SetSize(12,12)
-- 	checkMark:SetPosition(pos,1)
-- 	checkMark:SetBackground("Dusk/Common/Check.tga")
-- 	checkMark:SetStretchMode(2)
-- --	checkMark:SetVisible(false)
-- end

function ScrollMenu:Constructor()
	Turbine.UI.Control.Constructor(self)
    self:SetBackColor(Grey2)
	self:SetVisible(true)

	self.MenuBox = Turbine.UI.Label()
	self.MenuBox:SetParent(self)
	self.MenuBox:SetPosition(2,2)
	self.MenuBox:SetHeight(16)
	self.MenuBox:SetOutlineColor(Highlight)
	self.MenuBox:SetForeColor(Bronze)
    self.MenuBox:SetBackColor(Black)
	self.MenuBox:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter )
	self.MenuBox:SetFont( TP14 )

	function self.MenuBox:MouseClick()
		if ScrollMenu.Items then
			ScrollMenu.box:Close()
			ScrollMenu.Items = nil
			return
		end
		if isOpen then isOpen:Close() end
		ScrollMenu.Menu = self
		self.Click()
		if ScrollMenu.Items then
			local ctl = self:GetParent()
			local x0,y0 = ctl:GetParent():GetPosition()
			local x,y = ctl:GetPosition()
			x,y = x0+x,y0+y+3+ctl:GetHeight()
			local dy = Turbine.UI.Display.GetHeight()-y-ScrollMenu.box:GetHeight()
			if dy<0 then y = y+dy end
			ScrollMenu.box:SetPosition(x, y)
			ScrollMenu.box:SetVisible(true)
			isOpen = ScrollMenu.box
		end
	end

	-- Drop down arrow shown in the control.
	self.arrow = Turbine.UI.Control()
	self.arrow:SetParent(self.MenuBox)
	self.arrow:SetSize(14,14)
	self.arrow:SetBackground(0x41007e18)
	self.arrow:SetStretchMode(1)
	self.arrow.MouseClick = function()
		self.MenuBox.MouseClick(self.MenuBox)
	end
end

function ScrollMenu:SetText(text)
	self.MenuBox:SetText(text)
end

function ScrollMenu:GetText()
	return self.MenuBox:GetText()
end

function ScrollMenu:SizeChanged()
	local x,y = self:GetSize()
	self.MenuBox:SetSize(x-4, y-4)
	self.arrow:SetPosition(x- 19, y-19)
end

function ScrollMenu:MouseEnter()
	self.arrow:SetBackground(0x41007e1b)
	self.MenuBox:SetForeColor(White)
	self.MenuBox:SetFontStyle(8)
end

function ScrollMenu:MouseLeave()
	self.arrow:SetBackground(0x41007e18)
	self.MenuBox:SetForeColor(Bronze)
	self.MenuBox:SetFontStyle(0)
end

function ScrollMenu:addItem(menu, name, check, color)
	local print = ScrollMenu.print or print
	local Item = Turbine.UI.Label(name)
	Item:SetText(name)
	Item:SetFont( check and TPB16 or TP14 )
	Item:SetTextAlignment( Turbine.UI.ContentAlignment.BottomLeft )
	Item.color = color or Bronze
	Item:SetForeColor(Item.color)
	Item:SetBackColor(Black)
	Item:SetOutlineColor(Highlight)
	Item:SetSize(250, 16)
	Item:SetParent(menu)
	Item.MouseClick = function( sender,args )
		local selected = sender:GetText()
		local menu = ScrollMenu.Menu
		menu:SetText( selected )
		print( (BL_Lang=="FR" or FL_Lang=="FR") and ("Sélection : "..selected) or ("Selected "..selected) )
		if menu.action then menu.action(selected) end
		ScrollMenu.box:Close()
		ScrollMenu.Items = nil
	end
	ScrollMenu.Items:AddItem( Item )

	function Item:MouseEnter()
		Item:SetForeColor(White)
		Item:SetFontStyle(8)
	end
	
	function Item:MouseLeave()
		Item:SetForeColor(Item.color)
		Item:SetFontStyle(0)
	end
end

function ScrollMenu:BuildMenu(list, size, print, action, all, colors)
	colors = colors or {}
	ScrollMenu.print = print
	local msize = #list + (all and 1 or 0)
	if size>msize then size = msize end
	local vs = size*16+2
	if action then self.MenuBox.action = action end
	local box = Turbine.UI.Window()
    box:SetBackColor(Grey2)
	box:SetVisible(true)
	box:SetZOrder(100)
	ScrollMenu.box = box

	-- Set parent window Close action
	self:GetParent().Closing =  function()
		box:Close()
		ScrollMenu.Items = nil
	end

	-- Set Escape action
	box:SetWantsKeyEvents( true )
	box.KeyDown = function(sender, args)
		if( args.Action == Turbine.UI.Lotro.Action.Escape ) then
			box:Close()
			ScrollMenu.Items = nil
		end
	end

	local ibox = Turbine.UI.Control()
	ibox:SetParent(box)
	ibox:SetPosition(2,2)
    ibox:SetBackColor(Black)
	ibox:SetVisible(true)

	local menu = Turbine.UI.ListBox()
	menu:SetParent(box)
	menu:SetPosition(20,2)
	menu:SetVisible(true)
	ScrollMenu.Items = menu
	local selected = self.MenuBox:GetText()
	if all then ScrollMenu:addItem(self.Menu, all, all==selected) end
	local len = 0
	for i,name in ipairs(list) do
		if #name>len then len = #name end
        ScrollMenu:addItem(self.Menu, name, name==selected, colors[name])
	end
	local boxw = self:GetWidth()
	if boxw<30+len*7.5 then boxw = 30+len*7.5 end
	box:SetSize(boxw, vs+4)
	ibox:SetSize(boxw-4, vs)
	menu:SetSize(boxw-24, vs)
	-- Add a scrollbar on the right side
	local sbox = ScrollMenu:AddScroll(menu, Vertical)
	sbox:SetVisible(true)
	self.MenuBox.sbox = sbox
end
