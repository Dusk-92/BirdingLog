-- Birding Log window handler
-- coding: utf-8 '�

import "Turbine.UI.Lotro"
import "Dusk.Common.DropMenu"
import "Dusk.Common.ToolTip"

local labelFont = Turbine.UI.Lotro.Font.Verdana14
local foreColor = Turbine.UI.Color( 0.9, 0.9, 0 )
local whiteColor = Turbine.UI.Color( 1.0, 1.0, 1.0 )
local backColor = Turbine.UI.Color( 0.0, 0.0, 0.0 )
local greyColor = Turbine.UI.Color( 0.1, 0.1, 0.1 )
local Button = Turbine.UI.Lotro.Button
local Label = Turbine.UI.Label
local TextBox = Turbine.UI.TextBox
local CheckBox = Turbine.UI.Lotro.CheckBox
local DropMenu = Dusk.Common.DropMenu
local Item = Turbine.UI.Lotro.ShortcutType.Item
local Hobby = Turbine.UI.Lotro.ShortcutType.Hobby
local Alias = Turbine.UI.Lotro.ShortcutType.Alias
local Shortcut = Turbine.UI.Lotro.Shortcut
local Quickslot = Turbine.UI.Lotro.Quickslot
local Qsize = 34
local Blank

local UI = {
    title="Birding Log", kit="Birding kit:", spot="Spot bird:", weapon="Weapon:", second="2nd slot:",
    setzone="Set Zone", zonebirds="Zone Birds", listzones="List Zones", seen="Birds Seen", totals="Personal Totals", add="Add Bird:"
}
if BL_Lang=="FR" then
    UI = {
        title="Carnet d'ornithologie", kit="Kit :", spot="Observer :", weapon="Arme :", second="2e slot :",
        setzone="Détecter zone", zonebirds="Oiseaux zone", listzones="Liste zones", seen="Vus ici", totals="Totaux perso", add="Ajouter :"
    }
end

BL_Window = class( Turbine.UI.Lotro.Window )

function BL_Window:AddField(control, text, pos, size)
	local field = control()
	field:SetParent( self )
	if text then field:SetText( text ) end
	field:SetPosition( pos.x,pos.y )
	field:SetSize( size.x,size.y )
	if control==Button or control==DropMenu or not text then return field end
	field:SetFont( labelFont )
	field:SetForeColor( text=="" and whiteColor or foreColor )
	local grey = control==TextBox or control==Quickslot
	field:SetBackColor( grey and greyColor or backColor )
	field:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft )
	return field
end

function BL_Shortcut(sender,name,iname)
	local shortcut = sender:GetShortcut()
	local itemType = shortcut:GetType()
	if itemType==0 then return end
	local itemData = shortcut:GetData()
	if sender:IsAltKeyDown() then BL_Print((BL_Lang=="FR" and "Type=" or "Type=")..itemType..(BL_Lang=="FR" and ", Données=" or ", Data=")..itemData) end
	if itemType~=Item then 
		sender:SetShortcut(Blank) 
		BL_Print(BL_Lang=="FR" and (name.." réinitialisé.") or (name.." reset."))
		return 
	end
	local Item = shortcut:GetItem()
	if not Item then BL_PrintE(BL_Lang=="FR" and "Objet introuvable." or "Item is null.") return end
	if iname and Item:GetName():sub(-#iname)~=iname then
		BL_PrintE(BL_Lang=="FR" and (Item:GetName().." n’est pas un objet valide pour cet emplacement.") or (Item:GetName().." is not a "..iname))
		sender:SetShortcut(Blank)
		return
	end
	BL_Print(BL_Lang=="FR" and (name.." défini sur "..Item:GetName()) or (name.." set to "..Item:GetName()))
	return itemData
end

function BL_Window:Constructor()
	Turbine.UI.Lotro.Window.Constructor( self )

	-- Position the window near the top center of the screen.
	self:SetSize( 340,275 )
--	self:SetBackColor( Turbine.UI.Color() )
	local pos = BL_Options.pos1 or 
		{ x=(Turbine.UI.Display.GetWidth() - self:GetWidth())/3, 
		y=(Turbine.UI.Display:GetHeight() - self:GetHeight())*.7 }
	self:SetPosition( pos.x, pos.y )
	self:SetText( UI.title )
	self:SetVisible( false )

-- Hobby:Birding action is Type=Hobby(9), Data=0x7000EE1E

	-- Create a Name field
	self.name = self:AddField(Label, UI.kit, {x=37,y=47}, {x=80,y=16} )
	self.name:SetFont(Turbine.UI.Lotro.Font.TrajanPro18)

	-- Create an kit field
	self.kit = self:AddField(Quickslot, nil, {x=115,y=40}, {x=Qsize,y=Qsize} )
	Blank = self.kit:GetShortcut()
	if BL_Totals.kit then self.kit:SetShortcut( Shortcut(Item,BL_Totals.kit) ) 
	else self.kit:SetBackground("Dusk/BirdingLog/Kit.tga") end
	self.kit.ShortcutChanged = function( sender, args )
		BL_Totals.kit = BL_Shortcut(sender,BL_Lang=="FR" and "Kit d’ornithologie" or "Birding Kit")
	end

	-- Create a birding label
	self:AddField(Label, UI.spot, {x=185,y=45}, {x=70,y=16} )

	-- Create an birding field
	self.fish = self:AddField(Quickslot, nil, {x=255,y=40}, {x=Qsize,y=Qsize} )
	self.fish:SetShortcut( Shortcut(Hobby,"0x7006B1F4") )
    self.fish:SetAllowDrop( false )
	self.fish.MouseEnter = function( sender, args ) BL_TrackHover = true end
	self.fish.MouseLeave = function( sender, args ) BL_TrackHover = false end

	-- Create a weapon label
	self:AddField(Label, UI.weapon, {x=45,y=95}, {x=70,y=16} )

	-- Create an weapon field, weapon slot=16, cat=104
	self.weapon = self:AddField(Quickslot, nil, {x=115,y=90}, {x=Qsize,y=Qsize} )
	if BL_Totals.wpn then self.weapon:SetShortcut( Shortcut(Item,BL_Totals.wpn) ) 
	else self.weapon:SetBackground("Dusk/BirdingLog/Sword.tga") end
	self.weapon.ShortcutChanged = function( sender, args )
		BL_Totals.wpn = BL_Shortcut(sender,BL_Lang=="FR" and "Arme" or "Weapon")
	end

	-- Create a Shield label
	self:AddField(Label, UI.second, {x=190,y=95}, {x=60,y=16} )

	-- Create an shield field, shield slot=17
	self.shield = self:AddField(Quickslot, nil, {x=255,y=90}, {x=Qsize,y=Qsize} )
	if BL_Totals.shl then self.shield:SetShortcut( Shortcut(Item,BL_Totals.shl) ) 
	else self.shield:SetBackground("Dusk/BirdingLog/Shield.tga") end
	self.shield.ShortcutChanged = function( sender, args )
		BL_Totals.shl = BL_Shortcut(sender,BL_Lang=="FR" and "2e emplacement" or "2nd")
	end

	-- Keep the Alias Quickslot and the visual LOTRO button as siblings.
	-- The slot is inset so its own Alias rendering cannot leak around the skin.
	local slot = Turbine.UI.Lotro.Quickslot()
	slot:SetParent( self )
    slot:SetPosition( 32,142 )
    slot:SetSize( 121,16 )
    slot:SetOpacity( 0 )
    slot:SetZOrder( 1 )
    slot:SetShortcut(Turbine.UI.Lotro.Shortcut( Alias,"/bll "..BL_Loc ))
    slot:SetAllowDrop( false )

	self.locButton = self:AddField(Button, UI.setzone, {x=30,y=140}, {x=125,y=20} )
    self.locButton:SetMouseVisible( false )
    self.locButton:SetZOrder( 2 )

	-- Create a Zone menu button
	self.zoneMenu = self:AddField(DropMenu, "", {x=175,y=140}, {x=135,y=20} )
	local action = function(args)
		BL_LocStr = BL_Zname[args]
		if not BL_Locs[BL_LocStr] then BL_Locs[BL_LocStr] = {} end
		BL_Print(BL_Lang=="FR" and ("Zone sélectionnée : "..args) or ("Selected zone: "..args))
	end
	self.zoneMenu.Menu.Click = function()
		self.zoneMenu:BuildMenu(BL_Zlist,action,nil,function() end)
	end

	-- Create a sighting listing button
	self.birdsButton = self:AddField(Button, UI.zonebirds, {x=30,y=170}, {x=125,y=20} )
	self.birdsButton.Click = function( sender,args )
        BL_Command:Execute("bll","zone")
	end

	-- Create a zones button
	self.zonesButton = self:AddField(Button, UI.listzones, {x=175,y=170}, {x=135,y=20} )
	self.zonesButton.Click = function( sender,args )
        BL_Command:Execute("bl","zones")
	end

	-- Create a sighting listing button
	self.seenButton = self:AddField(Button, UI.seen, {x=30,y=200}, {x=125,y=20} )
	self.seenButton.Click = function( sender,args )
        BL_Command:Execute("bll","list")
	end

	-- Create a totals button
	self.totalsButton = self:AddField(Button, UI.totals, {x=175,y=200}, {x=135,y=20} )
	self.totalsButton.Click = function( sender,args )
        BL_Command:Execute("bl","sight")
	end

	-- Create an Add Bird label
	self:AddField(Label, UI.add, {x=35,y=230}, {x=75,y=16} )

	-- Create an Add Bird menu button. Use an explicit label->ID map so
	-- duplicate localized names can never increment the wrong bird.
	self.birdMenu = self:AddField(DropMenu, "", {x=100,y=230}, {x=210,y=20} )
	local birdMenuIds = {}
	local action = function(args)
		local id = birdMenuIds[args]
		if not id or not BL_ID[id] or not BL_LocStr then
			BL_PrintE(BL_Lang=="FR" and "Impossible d’ajouter cette observation." or "Unable to add this sighting.")
			return
		end
		BL_Totals[id] = (BL_Totals[id] or 0)+1
		local locTbl = BL_Locs[BL_LocStr]
		if not locTbl then
			locTbl = {}
			BL_Locs[BL_LocStr] = locTbl
		end
		locTbl[id] = (locTbl[id] or 0)+1
		BL_Print(BL_Lang=="FR" and ("Observation ajoutée : "..(BL_ID[id].ln or BL_ID[id].n)) or ("Added "..(BL_ID[id].ln or BL_ID[id].n).." sighting"))
	end
	self.birdMenu.Menu.Click = function()
		if BL_LocStr then
			local zt = BL_Zone[BL_LocStr]
			local Blist,counts = {},{}
			for id in pairs(zt.id) do
				local name = BL_ID[id].ln or BL_ID[id].n
				counts[name] = (counts[name] or 0)+1
			end
			birdMenuIds = {}
			for id in Sort(zt.id,function(a,b)
				local an,bn = BL_ID[a].ln or BL_ID[a].n, BL_ID[b].ln or BL_ID[b].n
				if an==bn then return BL_ID[a].n < BL_ID[b].n end
				return an<bn
			end) do
				local name = BL_ID[id].ln or BL_ID[id].n
				local label = counts[name]>1 and (name.." ("..BL_ID[id].n..")") or name
				if birdMenuIds[label] then label = label.." ["..id.."]" end
				birdMenuIds[label] = id
				table.insert(Blist,label)
			end
			self.birdMenu:BuildMenu(Blist,action,nil,function() end)
		else BL_PrintE(BL_Lang=="FR" and "Aucune zone sélectionnée" or "No zone selected") end
	end

end


BL_window = BL_Window()

-- Set Escape action
BL_window:SetWantsKeyEvents( true )
BL_window.KeyDown = function(sender, args)
	if( args.Action == Turbine.UI.Lotro.Action.Escape and not BL_Options.esc ) then
		BL_window:SetVisible( false )
	-- elseif Track and args.Control then 
	-- 	BL_window.fish:MouseDown(sender, args)
	end
end
