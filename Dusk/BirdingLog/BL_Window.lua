-- Birding Log window handler
-- coding: utf-8 '�

import "Turbine.UI.Lotro"
import "Dusk.Common.DropMenu"

local labelFont = Turbine.UI.Lotro.Font.Verdana14
local foreColor = Turbine.UI.Color( 0.9, 0.9, 0 )
local whiteColor = Turbine.UI.Color( 1.0, 1.0, 1.0 )
local backColor = Turbine.UI.Color( 0.0, 0.0, 0.0 )
local greyColor = Turbine.UI.Color( 0.1, 0.1, 0.1 )
local Button = Turbine.UI.Lotro.Button
local Label = Turbine.UI.Label
local TextBox = Turbine.UI.TextBox
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

local function BL_ProficiencyText()
	local fp = tonumber(BL_Totals and BL_Totals.fp)
	if not fp then
		return BL_Lang=="FR" and "Ornithologie : niveau inconnu" or "Birding: unknown level"
	end

	local bestLevel = -1
	local bestTitle = nil
	for level,title in pairs(BL_Title or {}) do
		local n = tonumber(level)
		if n and fp>=n and n>bestLevel then
			bestLevel = n
			bestTitle = (BL_Lang=="FR" and BL_TitleFR and BL_TitleFR[n]) or title
		end
	end

	local text = (BL_Lang=="FR" and "Ornithologie : niveau " or "Birding: level ")..tostring(math.floor(fp))
	if type(bestTitle)=="string" and bestTitle~="" then
		text = text.." — "..bestTitle
	end
	return text
end

function BL_Window:RefreshProficiency()
	if not self.proficiency then return end
	self.proficiency:SetText(BL_ProficiencyText())
	self._lastProficiency = tonumber(BL_Totals and BL_Totals.fp)
end

function BL_Shortcut(sender,name,iname,icat)
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
    if sender:IsShiftKeyDown() then iname=nil; icat=nil end
    if icat then
        local info = Item:GetItemInfo()
        local category = info and info:GetCategory()
        if category ~= icat then
            BL_PrintE(BL_Lang=="FR" and (Item:GetName().." n’est pas un kit d’ornithologie valide.") or (Item:GetName().." is not a valid Birding Kit."))
            sender:SetShortcut(Blank)
            return
        end
    end
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

	-- Slightly roomier than the original layout so the proficiency line and
	-- equipment rows have breathing space without changing the overall style.
	self:SetSize( 360,295 )
--	self:SetBackColor( Turbine.UI.Color() )
	local pos = BL_Options.pos1 or 
		{ x=(Turbine.UI.Display.GetWidth() - self:GetWidth())/3, 
		y=(Turbine.UI.Display:GetHeight() - self:GetHeight())*.7 }
	self:SetPosition( pos.x, pos.y )
	self:SetText( UI.title )
	self:SetVisible( false )

	-- Current Birding proficiency and highest title reached.
	self.proficiency = self:AddField(Label, "", {x=30,y=27}, {x=300,y=16} )
	self.proficiency:SetForeColor( whiteColor )
	self.proficiency:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter )
	self:RefreshProficiency()

-- Hobby:Birding action is Type=Hobby(9), Data=0x7000EE1E

	-- Create a Name field
	self.name = self:AddField(Label, UI.kit, {x=42,y=57}, {x=80,y=16} )
	self.name:SetFont(Turbine.UI.Lotro.Font.TrajanPro18)

	-- Create an kit field
	self.kit = self:AddField(Quickslot, nil, {x=125,y=50}, {x=Qsize,y=Qsize} )
	Blank = self.kit:GetShortcut()
	if BL_Totals.kit then self.kit:SetShortcut( Shortcut(Item,BL_Totals.kit) ) 
	else self.kit:SetBackground("Dusk/BirdingLog/Kit.tga") end
	self.kit.ShortcutChanged = function( sender, args )
		BL_Totals.kit = BL_Shortcut(sender,BL_Lang=="FR" and "Kit d’ornithologie" or "Birding Kit")
	end

	-- Create a birding label
	self:AddField(Label, UI.spot, {x=205,y=55}, {x=75,y=16} )

	-- Create an birding field
	self.fish = self:AddField(Quickslot, nil, {x=285,y=50}, {x=Qsize,y=Qsize} )
	self.fish:SetShortcut( Shortcut(Hobby,"0x7006B1F4") )
    self.fish:SetAllowDrop( false )
	self.fish.MouseEnter = function( sender, args ) BL_TrackHover = true end
	self.fish.MouseLeave = function( sender, args ) BL_TrackHover = false end

	-- Create a weapon label
	self:AddField(Label, UI.weapon, {x=50,y=107}, {x=70,y=16} )

	-- Create an weapon field, weapon slot=16, cat=104
	self.weapon = self:AddField(Quickslot, nil, {x=125,y=100}, {x=Qsize,y=Qsize} )
	if BL_Totals.wpn then self.weapon:SetShortcut( Shortcut(Item,BL_Totals.wpn) ) 
	else self.weapon:SetBackground("Dusk/BirdingLog/Sword.tga") end
	self.weapon.ShortcutChanged = function( sender, args )
		BL_Totals.wpn = BL_Shortcut(sender,BL_Lang=="FR" and "Arme" or "Weapon")
	end

	-- Create a Shield label
	self:AddField(Label, UI.second, {x=210,y=107}, {x=70,y=16} )

	-- Create an shield field, shield slot=17
	self.shield = self:AddField(Quickslot, nil, {x=285,y=100}, {x=Qsize,y=Qsize} )
	if BL_Totals.shl then self.shield:SetShortcut( Shortcut(Item,BL_Totals.shl) ) 
	else self.shield:SetBackground("Dusk/BirdingLog/Shield.tga") end
	self.shield.ShortcutChanged = function( sender, args )
		BL_Totals.shl = BL_Shortcut(sender,BL_Lang=="FR" and "2e emplacement" or "2nd")
	end


	-- Location button: keep the proven working LOTRO Quickslot Alias overlay.
	-- The Quickslot covers the whole button and receives the real player click.
	self.locButton = self:AddField(Button, UI.setzone, {x=30,y=150}, {x=135,y=20} )

	local slot = Turbine.UI.Lotro.Quickslot()
	slot:SetParent( self.locButton )
    slot:SetPosition( 0,0 )
    slot:SetSize( self.locButton:GetWidth(), self.locButton:GetHeight() )
    slot:SetOpacity( 0 )
    slot:SetShortcut(Turbine.UI.Lotro.Shortcut( Alias,"/bll "..BL_Loc ))
    slot:SetAllowDrop( false )
    slot:SetUseOnRightClick( false )

    -- LOTRO can still draw a few Alias pixels outside an otherwise transparent
    -- Quickslot. Hide only that bleed in the empty gap below the button.
    local aliasBleedMask = Turbine.UI.Control()
    aliasBleedMask:SetParent( self )
    aliasBleedMask:SetPosition( 28,170 )
    aliasBleedMask:SetSize( 140,8 )
    aliasBleedMask:SetBackColor( backColor )
    aliasBleedMask:SetMouseVisible( false )
    aliasBleedMask:SetZOrder( 100 )
	-- Create a Zone menu button
	self.zoneMenu = self:AddField(DropMenu, "", {x=195,y=150}, {x=135,y=20} )
	local action = function(args)
		BL_LocStr = BL_Zname[args]
		if not BL_Locs[BL_LocStr] then BL_Locs[BL_LocStr] = {} end
		BL_Print(BL_Lang=="FR" and ("Zone sélectionnée : "..args) or ("Selected zone: "..args))
	end
	self.zoneMenu.Menu.Click = function()
		self.zoneMenu:BuildMenu(BL_Zlist,action,nil,function() end)
	end

	-- Create a sighting listing button
	self.birdsButton = self:AddField(Button, UI.zonebirds, {x=30,y=180}, {x=135,y=20} )
	self.birdsButton.Click = function( sender,args )
        BL_Command:Execute("bll","zone")
	end

	-- Create a zones button
	self.zonesButton = self:AddField(Button, UI.listzones, {x=195,y=180}, {x=135,y=20} )
	self.zonesButton.Click = function( sender,args )
        BL_Command:Execute("bl","zones")
	end

	-- Create a sighting listing button
	self.seenButton = self:AddField(Button, UI.seen, {x=30,y=210}, {x=135,y=20} )
	self.seenButton.Click = function( sender,args )
        BL_Command:Execute("bll","list")
	end

	-- Create a totals button
	self.totalsButton = self:AddField(Button, UI.totals, {x=195,y=210}, {x=135,y=20} )
	self.totalsButton.Click = function( sender,args )
        BL_Command:Execute("bl","sight")
	end

	-- Create an Add Bird label
	self:AddField(Label, UI.add, {x=35,y=250}, {x=75,y=16} )

	-- Create an Add Bird menu button. Use an explicit label->ID map so
	-- duplicate localized names can never increment the wrong bird.
	self.birdMenu = self:AddField(DropMenu, "", {x=110,y=250}, {x=220,y=20} )
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
		if type(BL_SaveRuntimeData)=="function" then BL_SaveRuntimeData() end
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