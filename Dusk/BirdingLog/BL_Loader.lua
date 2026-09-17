-- BirdingLog FR7.6 runtime hardening layer.
-- Loads the original main module, then replaces only the audited weak points.

import "Dusk.Common"

-- Guard BL_Options before BL_Main reads fields from it. The wrapper is restored
-- immediately after loading so other plugins keep the normal Common behavior.
local BL76_RawLoad = Turbine.PluginData.Load
Turbine.PluginData.Load = function(scope,key,callback)
    local value = BL76_RawLoad(scope,key,callback)
    if key=="BL_Options" and type(value)~="table" then return {} end
    return value
end

import "Dusk.BirdingLog.BL_Main"
Turbine.PluginData.Load = BL76_RawLoad

-- Remove the FR7.5 top-level Birding handler installed by BL_Main. If another
-- plugin was loaded before BirdingLog, its handler remains preserved below us.
if BL_ChatHandler and Turbine.Chat.Received==BL_ChatHandler then
    Turbine.Chat.Received = BL_PreviousChatHandler
end

-- A generation token makes buried old BirdingLog wrappers harmless. This is
-- important when FishingLog wraps the chat handler and plugins are reloaded in
-- different orders: stale Birding handlers may remain in the call chain, but
-- only the newest generation is allowed to process observations.
BL_ChatGeneration = (BL_ChatGeneration or 0)+1
local BL76_Generation = BL_ChatGeneration
local BL76_PreviousChat = Turbine.Chat.Received

local BL76_xpat = "<Examine:IIDDID:0x0%x+:0x700(%x+)>%[(.-)%]<\\Examine>"
local BL76_fpPat = "Your proficiency in Birding has increased to (%d+)."

local function BL76_ChatHandler(sender,args)
    if BL76_PreviousChat then BL76_PreviousChat(sender,args) end
    if BL76_Generation~=BL_ChatGeneration then return end

    local msg = args.Message
    if not msg then return end

    if args.ChatType==Turbine.ChatType.Advancement then
        local fp = msg:match(BL76_fpPat)
        if not fp then
            local low = string.lower(msg)
            if low:find("bird",1,true) or low:find("ornith",1,true) or low:find("vogel",1,true) then
                fp = msg:match("(%d+)")
            end
        end
        if fp then BL_Totals.fp = fp return end
    end

    if args.ChatType~=Turbine.ChatType.SelfLoot then return end

    local id,name = msg:match(BL76_xpat)
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
            if locTbl then
                locTbl[id] = (locTbl[id] or 0)+1
            end
        end
    elseif BL_TrackUnknown or BL_TrackHover then
        if BL_GID[id] then
            BL_Print(BL_Lang=="FR" and "Récompense d'observation de la zone." or "Zone birding reward.")
        else
            BL_PrintE((BL_Lang=="FR" and "Inconnu : " or "Unknown: ")..name..", id="..tostring(id))
        end
    end
end

-- Expose these names so the existing Unload routine restores our handler if it
-- is still on top of Turbine.Chat.Received.
BL_PreviousChatHandler = BL76_PreviousChat
BL_ChatHandler = BL76_ChatHandler
Turbine.Chat.Received = BL76_ChatHandler

-- Use the area label carried by ;loc whenever it matches a known Birding zone.
-- Coordinate rectangles remain the fallback for smaller sub-areas.
local BL76_OldExecute = BL_Command.Execute
local BL76_Zloc = "^%s*(.-)%s*:%s*(.-)%s*:%s*([%d%.,]+%s*[NS])%s*,%s*([%d%.,]+%s*[EWO])%s*$"

local function BL76_LocValue(str,neg)
    local clean = str:gsub("%s",""):gsub(",",".")
    local dir = clean:sub(-1)
    local nbr = tonumber(clean:sub(1,-2))
    if not nbr then return nil end
    if dir==neg or (neg=="W" and dir=="O") then nbr=-nbr end
    return nbr
end

function BL_Command:Execute(cmd,args)
    if cmd~="bll" then return BL76_OldExecute(self,cmd,args) end
    if args=="list" or args=="zone" then return BL76_OldExecute(self,cmd,args) end

    local reg,area,y,x = args:match(BL76_Zloc)
    if not y then return BL76_OldExecute(self,cmd,args) end

    reg = reg:gsub("^%s+",""):gsub("%s+$","")
    local r = BL_Region[reg]
    if not r and (reg=="Ériador" or reg=="Eriador") then r=BL_Region.Eriador end
    if not r then BL_PrintE((BL_Lang=="FR" and "Région inconnue : " or "Unknown region: ")..reg) return end
    if r>4 then BL_PrintE(BL_Lang=="FR" and "Aucun oiseau répertorié en Haradwaith." or "No birds found in Haradwaith.") return end

    local y1,x1 = BL76_LocValue(y,"S"),BL76_LocValue(x,"W")
    if not y1 or not x1 then
        BL_PrintE((BL_Lang=="FR" and "Coordonnées invalides : " or "Invalid coordinates: ")..tostring(y)..", "..tostring(x))
        return
    end

    BL_LocStr = nil
    local zc,zn,bestScore,bestArea
    local areaName = tostring(area or ""):gsub("^%s+",""):gsub("%s+$","")
    local directZone = BL_Zname[areaName]

    if directZone and BL_Zone[directZone] then
        local t=BL_Zone[directZone]
        local sameRegion = r==t.r or (r==4 and t.r==3)
        if sameRegion then zc,zn=directZone,t.z end
    end

    if not zc then
        for c,t in pairs(BL_Zone) do
            local sameRegion = r==t.r or (r==4 and t.r==3)
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

-- Invalidate this generation even when our chat handler is buried below
-- another plugin at unload time. Then let FR7.5 perform its normal saves.
local BL76_OldUnload = Plugins.BirdingLog.Unload
Plugins.BirdingLog.Unload = function(sender,args)
    if BL76_Generation==BL_ChatGeneration then BL_ChatGeneration=BL_ChatGeneration+1 end
    return BL76_OldUnload(sender,args)
end
