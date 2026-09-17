-- BirdingLog FR7.8 runtime hardening layer.
-- Keeps the original BL_Main intact while fixing audited edge cases safely.

import "Dusk.Common"

-- Validate BL_Options before BL_Main reads it. The temporary wrapper is restored
-- even if BL_Main itself throws, so no other plugin inherits our guard.
local BL78_RawLoad = Turbine.PluginData.Load
Turbine.PluginData.Load = function(scope,key,callback)
    local value = BL78_RawLoad(scope,key,callback)
    if key=="BL_Options" and type(value)~="table" then return {} end
    return value
end

local BL78_LoadOK,BL78_LoadError = pcall(function()
    import "Dusk.BirdingLog.BL_Main"
end)
Turbine.PluginData.Load = BL78_RawLoad
if not BL78_LoadOK then error(BL78_LoadError) end

-- FR7.8: do not rely only on a hard-coded probe version. If a future BL_Data
-- update adds birds for which BL_FR has no localized name yet, automatically
-- allow the client-name probe to run again. This keeps future database updates
-- self-healing without forcing users to type /bl fr.
local BL78_BaseAutoLocalize = BL_AutoLocalize
if type(BL78_BaseAutoLocalize)=="function" then
    BL_AutoLocalize = function(force)
        if force then return BL78_BaseAutoLocalize(true) end
        if BL_Lang~="FR" then return end

        local missing = false
        for _,t in pairs(BL_ID or {}) do
            if type(t)=="table" and (not t.ln or t.ln=="") then
                missing = true
                break
            end
        end
        if not missing then return end

        -- BL_Main 1.3 used this value as a one-shot gate. Clear only the old
        -- gate when names are genuinely missing, then let the original gradual
        -- probe do its normal work and persistence.
        if BL_Options then BL_Options.frProbeVersion = nil end
        return BL78_BaseAutoLocalize(false)
    end

    -- BL_Main may have skipped its startup probe because an older save already
    -- contained frProbeVersion=3. Re-check once after the database is loaded.
    BL_AutoLocalize(false)
end

-- BL_Main installs its normal handler. Remove it from the top before installing
-- the generation-protected one below; older buried handlers are made inert.
if BL_ChatHandler and Turbine.Chat.Received==BL_ChatHandler then
    Turbine.Chat.Received = BL_PreviousChatHandler
end

BL_ChatGeneration = (BL_ChatGeneration or 0)+1
local BL78_Generation = BL_ChatGeneration
local BL78_PreviousChat = Turbine.Chat.Received

local BL78_xpat = "<Examine:IIDDID:0x0%x+:0x700(%x+)>%[(.-)%]<\\Examine>"
local BL78_fpPat = "Your proficiency in Birding has increased to (%d+)."

local function BL78_ChatHandler(sender,args)
    if BL78_PreviousChat then BL78_PreviousChat(sender,args) end
    if BL78_Generation~=BL_ChatGeneration then return end

    local msg = args.Message
    if not msg then return end

    if args.ChatType==Turbine.ChatType.Advancement then
        local fp = msg:match(BL78_fpPat)
        if not fp then
            local low = string.lower(msg)
            if low:find("bird",1,true) or low:find("ornith",1,true) or low:find("vogel",1,true) then
                fp = msg:match("(%d+)")
            end
        end
        if fp then BL_Totals.fp = fp return end
    end

    if args.ChatType~=Turbine.ChatType.SelfLoot then return end

    local id,name = msg:match(BL78_xpat)
    if not id then id,name = Dusk.Common.EII_ID(msg) end
    if not id then return end
    name = name or "?"
    if name:sub(-5)=="Frame" then return end

    if BL_ID[id] then
        if name~="?" and (not BL_ID[id].ln or BL_ID[id].ln=="") then
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
            if locTbl then locTbl[id] = (locTbl[id] or 0)+1 end
        end
    elseif BL_TrackUnknown or BL_TrackHover then
        if BL_GID[id] then
            BL_Print(BL_Lang=="FR" and "Récompense d'observation de la zone." or "Zone birding reward.")
        else
            BL_PrintE((BL_Lang=="FR" and "Inconnu : " or "Unknown: ")..name..", id="..tostring(id))
        end
    end
end

BL_PreviousChatHandler = BL78_PreviousChat
BL_ChatHandler = BL78_ChatHandler
Turbine.Chat.Received = BL78_ChatHandler

-- Revalidate a kit restored from an old save. BL_Window originally validated
-- only a shortcut changed by the player after startup.
if BL_Totals and BL_Totals.kit and BL_window and BL_window.kit then
    local savedShortcut = BL_window.kit:GetShortcut()
    local savedItem = savedShortcut and savedShortcut:GetItem()
    local savedInfo = savedItem and savedItem:GetItemInfo()
    if not savedInfo or savedInfo:GetCategory()~=BL_BirdingKit then
        BL_Totals.kit = nil
        BL_window.kit:SetShortcut(Turbine.UI.Lotro.Shortcut())
        BL_window.kit:SetBackground("Dusk/BirdingLog/Kit.tga")
    end
end

local BL78_OldExecute = BL_Command.Execute
local BL78_Zloc = "^%s*(.-)%s*:%s*(.-)%s*:%s*([%d%.,]+%s*[NS])%s*,%s*([%d%.,]+%s*[EWO])%s*$"
local BL78_xlink = "<Examine:IIDDID:0x0000000000000000:0x700%s>[%s]<\\Examine>"

local function BL78_LocValue(str,neg)
    local clean = str:gsub("%s",""):gsub(",",".")
    local dir = clean:sub(-1)
    local nbr = tonumber(clean:sub(1,-2))
    if not nbr then return nil end
    if dir==neg or (neg=="W" and dir=="O") then nbr=-nbr end
    return nbr
end

local function BL78_PrintList(list)
    local ids,total = {},0
    if type(list)~="table" then list={} end
    for id,n in pairs(list) do
        if type(id)=="string" and #id==5 and BL_ID[id] and type(n)=="number" then
            table.insert(ids,id)
        end
    end
    table.sort(ids,function(a,b)
        return (BL_ID[a].ln or BL_ID[a].n)<(BL_ID[b].ln or BL_ID[b].n)
    end)
    for _,id in ipairs(ids) do
        local t,n=BL_ID[id],list[id]
        BL_Print(string.format(BL78_xlink,id,t.ln or t.n)..": "..n)
        total=total+n
    end
    BL_Print((BL_Lang=="FR" and "Nombre total d’observations : " or "Total sighting count: ")..total)
end

function BL_Command:Execute(cmd,args)
    -- Safe listing: ignore stale/corrupt five-character IDs from very old saves.
    if cmd=="bll" and args=="list" then
        if BL_LocStr then
            BL_PrintH((BL_Lang=="FR" and "Oiseaux observés dans " or "Birds sighted in ")..(BL_Zone[BL_LocStr].ln or BL_Zone[BL_LocStr].z))
            BL78_PrintList(BL_Locs[BL_LocStr])
        else
            BL_PrintE(BL_Lang=="FR" and "Aucune zone sélectionnée" or "No zone selected")
        end
        return
    end
    if args=="sight" then
        BL_PrintH(BL_Lang=="FR" and "Historique des observations :" or "Birding sighting record:")
        BL78_PrintList(BL_Totals)
        return
    end
    if args=="zones" then
        BL_PrintH(BL_Lang=="FR" and "Oiseaux trouvés par zone :" or "Birds found by zone:")
        for _,zt in Sort(BL_Zone) do
            local total,seen=0,0
            for id in pairs(zt.id) do
                total=total+1
                if (tonumber(BL_Totals[id]) or 0)>0 then seen=seen+1 end
            end
            BL_Print((zt.ln or zt.z)..": "..seen.."/"..total)
        end
        return
    end

    -- Leave all non-location commands to the original implementation.
    if cmd~="bll" or args=="zone" then return BL78_OldExecute(self,cmd,args) end

    local reg,area,y,x = args:match(BL78_Zloc)
    if not y then return BL78_OldExecute(self,cmd,args) end

    reg = reg:gsub("^%s+",""):gsub("%s+$","")
    local r = BL_Region[reg]
    if not r and (reg=="Ériador" or reg=="Eriador") then r=BL_Region.Eriador end
    if not r then BL_PrintE((BL_Lang=="FR" and "Région inconnue : " or "Unknown region: ")..reg) return end
    if r>4 then BL_PrintE(BL_Lang=="FR" and "Aucun oiseau répertorié en Haradwaith." or "No birds found in Haradwaith.") return end

    local y1,x1 = BL78_LocValue(y,"S"),BL78_LocValue(x,"W")
    if not y1 or not x1 then
        BL_PrintE((BL_Lang=="FR" and "Coordonnées invalides : " or "Invalid coordinates: ")..tostring(y)..", "..tostring(x))
        return
    end

    BL_LocStr=nil
    local zc,zn,bestScore,bestArea
    local areaName=tostring(area or ""):gsub("^%s+",""):gsub("%s+$","")
    local directZone=BL_Zname[areaName]

    if directZone and BL_Zone[directZone] then
        local t=BL_Zone[directZone]
        local sameRegion=r==t.r or (r==4 and t.r==3)
        if sameRegion then zc,zn=directZone,t.z end
    end

    if not zc then
        for c,t in pairs(BL_Zone) do
            local sameRegion=r==t.r or (r==4 and t.r==3)
            if sameRegion and y1<t.n and y1>t.s and x1<t.e and x1>t.w then
                local h,w=t.n-t.s,t.e-t.w
                local yMargin=math.min(t.n-y1,y1-t.s)/h
                local xMargin=math.min(t.e-x1,x1-t.w)/w
                local score=math.min(yMargin,xMargin)
                local rectArea=h*w
                if not bestScore or score>bestScore or
                   (score==bestScore and (rectArea<bestArea or (rectArea==bestArea and c<zc))) then
                    zc,zn,bestScore,bestArea=c,t.z,score,rectArea
                end
            end
        end
    end

    if zn then
        BL_Print((BL_Lang=="FR" and "Zone : " or "Zone: ")..(BL_Zone[zc].ln or zn))
        BL_LocStr=zc
        if not BL_Locs[zc] then BL_Locs[zc]={} end
        BL_window.zoneMenu:SetText(BL_Zone[zc].ln or BL_Zone[zc].z)
    else
        BL_PrintE(BL_Lang=="FR" and "Zone introuvable." or "Zone not found.")
    end
end

-- Invalidate our generation even when another plugin sits above our handler.
local BL78_OldUnload = Plugins.BirdingLog.Unload
Plugins.BirdingLog.Unload = function(sender,args)
    if BL78_Generation==BL_ChatGeneration then BL_ChatGeneration=BL_ChatGeneration+1 end
    return BL78_OldUnload(sender,args)
end
