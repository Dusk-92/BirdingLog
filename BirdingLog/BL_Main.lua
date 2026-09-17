-- Birding Log by David Down
-- coding: utf-8 '�

import "Turbine.Gameplay"
import "Turbine.UI.Lotro"
import "Dusk.Common.EII_ID"
import "Dusk.Common.Sort"
-- Detect the client language from localized shell commands.
-- French does not need a separate bird database: item IDs are language-independent.
if Turbine.Shell.IsCommand("aide") then
  BL_Lang = "FR"
  import "Dusk.BirdingLog.BL_Data"
  import "Dusk.BirdingLog.BL_FR"
elseif Turbine.Shell.IsCommand("zusatzmodule") then
  BL_Lang = "DE"
  import "Dusk.BirdingLog.BL_Data_DE"
else
  BL_Lang = "EN"
  import "Dusk.BirdingLog.BL_Data"
end

function BL_Print(text) Turbine.Shell.WriteLine("<rgb=#00FFFF>BL:</rgb> "..tostring(text)) end
function BL_PrintH(text) BL_Print("<rgb=#00FF00>"..text.."</rgb>") end
function BL_PrintE(text) BL_Print("<rgb=#FF6040>"..(BL_Lang=="FR" and "Erreur : " or "Error: ")..text.."</rgb>") end

import "Dusk.Common.Help"

local xlink = "<Examine:IIDDID:0x0000000000000000:0x700%s>[%s]<\\Examine>"
local xpat = "<Examine:IIDDID:0x0%x+:0x700(%x+)>%[(.-)%]<\\Examine>"
local fpPat = "Your proficiency in Birding has increased to (%d+)."
local nPat = "(%d+) (.+)"
-- ;loc is normally returned in English even on localized clients, but accept
-- French decimal commas and O (Ouest) as well to be safe.
local Zloc = "^%s*(.-)%s*:%s*(.-)%s*:%s*([%d%.,]+%s*[NS])%s*,%s*([%d%.,]+%s*[EWO])%s*$"
BL_LocStr = false
-- Separate persistent unknown-item tracking from temporary hover tracking.
BL_TrackUnknown = false
BL_TrackHover = false
-- Your proficiency in Birding has increased to 9.

BL_Options = Turbine.PluginData.Load(Turbine.DataScope.Server,"BL_Options")
if not BL_Options then BL_Options = {} end

-- Cache localized bird names learned directly from LOTRO loot links.
BL_Names = Turbine.PluginData.Load(Turbine.DataScope.Server,"BL_Names")
if type(BL_Names) ~= "table" then BL_Names = {} end
for id,name in pairs(BL_Names) do
    if BL_ID[id] and (not BL_ID[id].ln or BL_ID[id].ln=="") and type(name)=="string" and name~="" then BL_ID[id].ln = name end
end
if BL_RebuildNameIndex then BL_RebuildNameIndex() end


-- Ask the LOTRO client itself for localized item names from the known item IDs.
-- This runs progressively to avoid a visible hitch when the plugin loads.
local BL_AutoFRRunner = nil
local BL_AutoFRProbe = nil
local BL_AutoFRBusy = false

local function BL_ProbeLocalizedName(id)
    local ok,name = pcall(function()
        if not BL_AutoFRProbe then
            BL_AutoFRProbe = Turbine.UI.Lotro.Quickslot()
            BL_AutoFRProbe:SetSize(1,1)
            BL_AutoFRProbe:SetVisible(false)
        end
        local data = "0x0000000000000000,0x700"..id
        local shortcut = Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Item,data)
        BL_AutoFRProbe:SetShortcut(shortcut)
        local resolved = BL_AutoFRProbe:GetShortcut()
        if not resolved then return nil end
        local item = resolved:GetItem()
        if not item then return nil end
        return item:GetName()
    end)
    if ok and type(name)=="string" and name~="" and name~="?" then return name end
    return nil
end

function BL_AutoLocalize(force)
    if BL_Lang~="FR" or BL_AutoFRBusy then return end
    if not force and BL_Options.frProbeVersion==3 then return end

    local queue = {}
    for id,t in pairs(BL_ID) do
        if not t.ln or t.ln=="" then table.insert(queue,id) end
    end
    table.sort(queue)

    local ix,found = 1,0
    BL_AutoFRBusy = true
    BL_AutoFRRunner = Turbine.UI.Control()
    BL_AutoFRRunner:SetWantsUpdates(true)
    BL_AutoFRRunner.Update = function(sender,args)
        -- A small batch per frame keeps plugin loading smooth.
        for n=1,8 do
            local id = queue[ix]
            if not id then
                sender:SetWantsUpdates(false)
                BL_AutoFRBusy = false
                BL_Options.frProbeVersion = 3
                if BL_RebuildNameIndex then BL_RebuildNameIndex() end
                Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_Names",BL_Names)
                Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_Options",BL_Options)
                if found>0 then
                    BL_Print("Localisation FR automatique : "..found.." nom(s) récupéré(s) depuis LOTRO.")
                end
                return
            end
            ix = ix+1
            local t = BL_ID[id]
            local name = BL_ProbeLocalizedName(id)
            -- Do not cache an unchanged English name: a later loot link may still
            -- teach us a genuinely localized name on clients where probing fails.
            if name and t and name~=t.n then
                if BL_Names[id]~=name then found=found+1 end
                t.ln = name
                BL_Names[id] = name
                if BL_Bname then BL_Bname[name] = id end
            end
        end
    end
end

local BL_VersionText = "Birding Log "..Plugins["BirdingLog"]:GetVersion()

BL_Locs = Turbine.PluginData.Load(Turbine.DataScope.Server,"BL_Locs")
if type(BL_Locs) == "table" then
	local needsConversion = false
	for key,value in pairs(BL_Locs) do
		if not BL_Zone[key] and type(value)=="table" and value.z then
			needsConversion = true
			break
		end
	end
	if needsConversion then
		BL_Print(BL_Lang=="FR" and "Conversion des anciens lieux en zones…" or "Converting Locs to Zones..")
		local zt = {}
		for zoneCode in pairs(BL_Zone) do zt[zoneCode] = {} end
		for _,oldLoc in pairs(BL_Locs) do
			local zoneData = type(oldLoc)=="table" and zt[oldLoc.z] or nil
			if zoneData then
				for id,n in pairs(oldLoc) do
					if type(id)=="string" and #id==5 and type(n)=="number" then
						zoneData[id] = (zoneData[id] or 0)+n
					end
				end
			end
		end
		BL_Locs = zt
	end
else BL_Locs = {} end

BL_Totals = Turbine.PluginData.Load(Turbine.DataScope.Character,"BL_Totals")
if type(BL_Totals) ~= "table" then 
	BL_Totals = {} 
	BL_Print(BL_Lang=="FR" and "Nouveau carnet d’ornithologie créé." or "Created new birding record")
end

import "Dusk.BirdingLog.BL_Window"
import "Dusk.BirdingLog.BL_Icon"

-- First-run FR database enrichment. Use /bl fr to run it again manually.
BL_AutoLocalize(false)

BL_PrintH(BL_VersionText..(BL_Lang=="FR" and ", données chargées." or ", data loaded."))


local Chat = Turbine.Chat.Received
Turbine.Chat.Received = function (sender,args)
	if Chat then Chat(sender,args) end
	local msg = args.Message
	if not msg then return end
	if args.ChatType==Turbine.ChatType.Advancement then
        local fp = msg:match(fpPat)
        if not fp then
            -- Localized clients use a translated advancement message.
            -- Detect the hobby name and take the numeric proficiency value.
            local low = string.lower(msg)
            if low:find("bird",1,true) or low:find("ornith",1,true) or low:find("vogel",1,true) then
                fp = msg:match("(%d+)")
            end
        end
        if fp then BL_Totals.fp = fp return end
    end
--	print("Chat type="..args.ChatType)
	if args.ChatType==Turbine.ChatType.SelfLoot then
        -- Do not depend on the localized prefix ("You have acquired", etc.).
        -- The Examine item ID is stable across EN/FR/DE clients.
        local id,name = msg:match(xpat)
        if not id then id,name = Dusk.Common.EII_ID(msg) end
        if not id then return end
        name = name or "?"
        if name:sub(-5)=="Frame" then return end
        if BL_ID[id] then
            -- Remember the localized name seen in chat for nicer FR/DE output.
            if name ~= "?" and (not BL_ID[id].ln or BL_ID[id].ln=="") then
                BL_ID[id].ln = name
                BL_Names[id] = name
                if BL_Bname then BL_Bname[name] = id end
            end
            if not BL_Totals[id] then
                BL_Totals[id] = 0
                BL_Print(BL_Lang=="FR" and "Nouveau type d'oiseau observé." or "New type of bird found.")
            end
            BL_Totals[id] = BL_Totals[id]+1
            local birdName = BL_ID[id].ln or BL_ID[id].n
            if BL_Lang=="FR" then
                BL_Print("Observation : "..birdName..", total="..BL_Totals[id])
            else
                BL_Print("Saw a "..birdName..", count="..BL_Totals[id])
            end
            if BL_LocStr then
                local locTbl = BL_Locs[BL_LocStr]
                if not locTbl then return end
                if not locTbl[id] then locTbl[id] = 0 end
                locTbl[id] = locTbl[id]+1
            end
        elseif BL_TrackUnknown or BL_TrackHover then
            if BL_GID[id] then BL_Print(BL_Lang=="FR" and "Récompense d'observation de la zone." or "Zone birding reward.")
            else BL_PrintE((BL_Lang=="FR" and "Inconnu : " or "Unknown: ")..name..", id="..tostring(id)) end
        end
	end
end

local function distance(dy,dx) return math.sqrt(dy*dy+dx*dx) end

local function locV(str,neg)
    local clean = str:gsub("%s",""):gsub(",",".")
    local dir = clean:sub(-1)
    local nbr = tonumber(clean:sub(1,-2))
    if not nbr then return nil end
    if dir==neg or (neg=="W" and dir=="O") then nbr = -nbr end
    return nbr
end

local function print_list(list)
	local nr,t = 0,{}
	for id,n in pairs(list) do
		if #id==5 then
			table.insert(t,id)
		end
	end
	table.sort(t, function(a,b) return (BL_ID[a].ln or BL_ID[a].n)<(BL_ID[b].ln or BL_ID[b].n) end )
	for i,id in ipairs(t) do
		local t,n = BL_ID[id],list[id]
		local s = string.format(xlink,id,t.ln or t.n)
		BL_Print(s..': '..n)
		nr = nr + n
	end
	BL_Print((BL_Lang=="FR" and "Nombre total d’observations : " or "Total sighting count: ")..nr)
	return
end

BL_Command = Turbine.ShellCommand()
function BL_Command:GetShortHelp() return Dusk.Common.Help(BL_Help,"??") end
function BL_Command:GetHelp() return Dusk.Common.Help(BL_Help,"help") end

function BL_Command:Execute( cmd,args )
	if Dusk.Common.HelpCmd(cmd,args,BL_Help) then return end
    if cmd=="bll" then
		if args=="list" then
			if BL_LocStr then
				BL_PrintH((BL_Lang=="FR" and "Oiseaux observés dans " or "Birds sighted in ")..(BL_Zone[BL_LocStr].ln or BL_Zone[BL_LocStr].z))
				print_list(BL_Locs[BL_LocStr])
			else BL_PrintE(BL_Lang=="FR" and "Aucune zone sélectionnée" or "No zone selected") end
			return
		end
		if args=="zone" then
			if BL_LocStr then
				local zt = BL_Zone[BL_LocStr]
				local seen,nbr = 0,0
				BL_PrintH((BL_Lang=="FR" and "Oiseaux à observer dans " or "Birds to see in ")..(zt.ln or zt.z))
				for id in Sort(zt.id,function(a,b) return (BL_ID[a].ln or BL_ID[a].n)<(BL_ID[b].ln or BL_ID[b].n) end) do
					local t,n = BL_ID[id], BL_Totals[id] or 0
					local s = string.format(xlink,id,t.ln or t.n)
					BL_Print(s..': '..n)
					nbr = nbr+1
					if n>0 then seen = seen+1 end
				end
				BL_Print((BL_Lang=="FR" and "Oiseaux vus : " or "Birds seen: ")..seen..'/'..nbr)
			else BL_PrintE(BL_Lang=="FR" and "Aucune zone sélectionnée" or "No zone selected") end
			return
		end
		local reg,a,y,x = args:match(Zloc)
		if y then
            reg = reg:gsub("^%s+",""):gsub("%s+$","")
            local r = BL_Region[reg]
            if not r and (reg=="Ériador" or reg=="Eriador") then r = BL_Region.Eriador end
			if not r then BL_PrintE((BL_Lang=="FR" and "Région inconnue : " or "Unknown region: ")..reg) return end
			if r>4 then BL_PrintE(BL_Lang=="FR" and "Aucun oiseau répertorié en Haradwaith." or "No birds found in Haradwaith.") return end
			local y1,x1,ln = locV(y,'S'), locV(x,'W')
            if not y1 or not x1 then BL_PrintE((BL_Lang=="FR" and "Coordonnées invalides : " or "Invalid coordinates: ")..tostring(y)..", "..tostring(x)) return end
			BL_LocStr = nil
			local zc,zn
			for c,t in pairs(BL_Zone) do
				local rg = r==t.r or (r==4 and t.r==3) -- KG and Gondor share birds
				if rg and y1<t.n and y1>t.s and x1<t.e and x1>t.w then
					zc = c; zn = t.z break end
			end
			if zn then 
				BL_Print((BL_Lang=="FR" and "Zone : " or "Zone: ")..(BL_Zone[zc].ln or zn))
				BL_LocStr = zc
				if not BL_Locs[zc] then BL_Locs[zc] = {} end
				BL_window.zoneMenu:SetText( BL_Zone[zc].ln or BL_Zone[zc].z )
			else BL_PrintE(BL_Lang=="FR" and "Zone introuvable." or "Zone not found.") end
		else BL_PrintE(BL_Lang=="FR" and "Lieu d’ornithologie inconnu." or "Unknown location for Birding.") end
		return
	end
    if cmd=="blg" then
		if BL_LocStr then
			local zname = BL_Zone[BL_LocStr].z
			if BL_Lang~="FR" then BL_Print("zname="..zname) end
			for id,t in pairs(BL_GID) do
				if t.z==zname then
					BL_PrintH(BL_Lang=="FR" and ("En terminant la prouesse d’ornithologie de "..(BL_Zone[BL_LocStr].ln or zname).." :") or ('Upon completing the deed \"All the Birds of '..zname..'\",'))
					BL_Print((BL_Lang=="FR" and "Récompense : " or "You will receive: ")..string.format(xlink,id,t.ln or t.n))
					return
				end
			end
			BL_Print(BL_Lang=="FR" and ("Aucune récompense d’ornithologie connue pour "..(BL_Zone[BL_LocStr].ln or zname)) or ("No known Birding reward for "..zname))
		else BL_PrintE(BL_Lang=="FR" and "Aucune zone sélectionnée" or "No zone selected") end
		return
	end
    if args=="fr" and BL_Lang=="FR" then
        BL_Print("Nouvelle analyse des noms français depuis les données LOTRO…")
        BL_AutoLocalize(true)
        return
    end
	if args=="show" or cmd=="blw" then
		BL_window:SetVisible( true )
		return
	end
    if args=="sight" then
		BL_PrintH(BL_Lang=="FR" and "Historique des observations :" or "Birding sighting record:")
		print_list(BL_Totals)
		return
	end
    if args=="track" then
		BL_TrackUnknown = not BL_TrackUnknown
		BL_Print(BL_Lang=="FR" and (BL_TrackUnknown and "Suivi activé." or "Suivi désactivé.") or ((BL_TrackUnknown and "En" or "Dis").."abled Tracking."))
		return
	end
	if args=="zones" then
		BL_PrintH(BL_Lang=="FR" and "Oiseaux trouvés par zone :" or "Birds found by zone:")
		for zc,zt in Sort(BL_Zone) do
			local zn,pn = 0,0
			for id in pairs(zt.id) do
				zn = zn+1
				if BL_Totals[id] then pn = pn+1 end
			end
			BL_Print((zt.ln or zt.z)..': '..pn..'/'..zn)
		end
		return
	end
    if args=="" then
		local fp = BL_Totals.fp
		if fp then 
			local s,fp,pv = '', tonumber(fp), 0
			if fp>9 then
				for p,n in pairs(BL_Title) do
					if fp>=p and p>pv then pv = p end
				end
				if pv>0 then s = ', '..((BL_Lang=="FR" and BL_TitleFR and BL_TitleFR[pv]) or BL_Title[pv]) end
			end
			BL_Print((BL_Lang=="FR" and "Maîtrise d’ornithologie : " or "Birding proficiency is ")..fp..s)
		else BL_Print(BL_Lang=="FR" and "Maîtrise d’ornithologie inconnue." or "Unknown Birding proficiency.") end
		return
	end
	local n,bird = args:match(nPat)
	if n and bird then
		n = tonumber(n)
		local matches = {}
		for id,t in pairs(BL_ID) do
			if t.n==bird or t.ln==bird then table.insert(matches,id) end
		end

		-- Official localized names are not guaranteed to be unique.
		if #matches>1 and BL_LocStr and BL_Zone[BL_LocStr] then
			local inZone = {}
			for _,id in ipairs(matches) do
				if BL_Zone[BL_LocStr].id[id] then table.insert(inZone,id) end
			end
			if #inZone==1 then matches = inZone end
		end

		if #matches==0 then
			BL_PrintE(BL_Lang=="FR" and ("Oiseau '"..bird.."' introuvable") or ("Bird '"..bird.."' not found"))
			return
		elseif #matches>1 then
			BL_PrintE(BL_Lang=="FR" and ("Nom d’oiseau ambigu : "..bird..". Sélectionnez sa zone ou utilisez son nom anglais exact.") or ("Ambiguous bird name: "..bird..". Select its zone or use the exact English name."))
			return
		end

		local id = matches[1]
		local birdData = BL_ID[id]
		local s
		for i,z in ipairs(birdData.f) do
			if not s then s = ''
			elseif i<#birdData.f then s = s..', '
			else s = s..' and ' end
			s = s..(BL_Zone[z].ln or BL_Zone[z].z)
		end
		BL_Print(BL_Lang=="FR" and (bird.." se trouve dans : "..s) or ("The "..bird.." is found in "..s))
		BL_Totals[id] = n
		BL_Print((BL_Lang=="FR" and "Total d’observations réglé sur " or "Total sightings set to ")..n)
		return
	end
    BL_PrintE((BL_Lang=="FR" and "Commande inconnue : " or "Unknown command, ")..args)
end

Turbine.Shell.AddCommand( "bl;blg;bll;blw;bl?", BL_Command )

Plugins.BirdingLog.Open = function(sender,args)
	BL_window:SetVisible( true )
	BL_window:SetZOrder( 2 )
end

Plugins.BirdingLog.Unload = function(sender,args)
    Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_Options",BL_Options)
    Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_Locs",BL_Locs)
    Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_Names",BL_Names)
    Turbine.PluginData.Save(Turbine.DataScope.Character,"BL_Totals",BL_Totals)
    BL_Print(BL_Lang=="FR" and "Carnet d’ornithologie enregistré." or "Birding record saved.")
end

--~ if Event[-1] then FR_Command:Execute("fr","") end

-- Options panel
import "Dusk.Common.Options"
if not BL_Options.scale then BL_Options.scale = 1 end
BL_OP = Dusk.Common.Options_Init(BL_Print,BL_Options,BL_window,"BL_Options")

-- Help text
BL_Help = {
	pre = "bl",
	arg = {
		[""] = "Display personal birding details.",
		[" "] = "Display birding proficiency.",
		["# <name>"] = "Set count for <name> to #.",
		sight = "List birding sighting records.",
		track = "Toggle unknown bird tracking.",
		fr = "Relancer la localisation automatique française.",
		zones = "List birding zones and counts.",
	},
	cmd = {
		bll = {
			[" "] = "Birding location commands.",
			[BL_Loc] = "Set the current birding zone.",
			list = "List sightings in the current zone.",
			zone = "List all birds and sightings in the zone.",
		},
		blg = "Show birding garment for selected zone.",
		blw = "Open Birding Log window.",
	},
}

-- French help override
if BL_Lang=="FR" then
    BL_Help = {
        pre = "bl",
        arg = {
            [""] = "Afficher les informations personnelles d’ornithologie.",
            [" "] = "Afficher la maîtrise d’ornithologie.",
            ["# <nom>"] = "Définir manuellement le nombre d’observations de <nom>.",
            sight = "Afficher l’historique des observations.",
            track = "Activer/désactiver le suivi des oiseaux inconnus.",
            fr = "Relancer la localisation automatique française.",
            zones = "Afficher les zones et leur progression.",
        },
        cmd = {
            bll = {
                [" "] = "Commandes liées à la zone d’ornithologie.",
                [BL_Loc] = "Détecter/définir la zone actuelle.",
                list = "Lister les observations de la zone actuelle.",
                zone = "Lister tous les oiseaux de la zone et leur progression.",
            },
            blg = "Afficher la récompense d’ornithologie de la zone.",
            blw = "Ouvrir le Carnet d’ornithologie.",
        },
    }
end
