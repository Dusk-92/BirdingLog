-- BirdingLog FR7.11 runtime hardening layer.
-- Keeps the original BL_Main intact while fixing audited edge cases safely.

import "Dusk.Common"

-- Sanitize the save fields BL_Main/BL_Window can consume during their own import.
-- This must happen before BL_Main creates the window and options panel.
local function BL711_Number(value,minValue,maxValue)
    local n=tonumber(value)
    if not n then return nil end
    if minValue and n<minValue then n=minValue end
    if maxValue and n>maxValue then n=maxValue end
    return n
end

local function BL711_Point(value)
    if type(value)~="table" then return nil end
    local x,y=tonumber(value.x),tonumber(value.y)
    if not x or not y then return nil end
    return {x=x,y=y}
end

local function BL711_SanitizeOptions(value)
    if type(value)~="table" then value={} end
    value.pos1=BL711_Point(value.pos1)
    value.pos2=BL711_Point(value.pos2)
    value.iconPos=BL711_Point(value.iconPos)
    if value.scale~=nil then value.scale=BL711_Number(value.scale,0.5,2.0) end
    if value.frProbeVersion~=nil then value.frProbeVersion=tonumber(value.frProbeVersion) end
    if value.frProbeSignature~=nil and type(value.frProbeSignature)~="string" then
        value.frProbeSignature=nil
    end
    return value
end

local function BL711_SanitizeShortcut(value)
    if type(value)=="string" and value~="" then return value end
    return nil
end

local function BL711_SanitizeTotals(value)
    if type(value)~="table" then return {} end
    local fp=tonumber(value.fp)
    value.fp=(fp and fp>=0) and fp or nil
    value.kit=BL711_SanitizeShortcut(value.kit)
    value.wpn=BL711_SanitizeShortcut(value.wpn)
    value.shl=BL711_SanitizeShortcut(value.shl)
    return value
end

-- Validate sensitive save data before BL_Main reads it. The temporary wrapper is
-- restored even if BL_Main itself throws, so no other plugin inherits our guard.
local BL710_RawLoad = Turbine.PluginData.Load
Turbine.PluginData.Load = function(scope,key,callback)
    local value = BL710_RawLoad(scope,key,callback)
    if key=="BL_Options" then return BL711_SanitizeOptions(value) end
    if key=="BL_Totals" then return BL711_SanitizeTotals(value) end
    return value
end

local BL710_LoadOK,BL710_LoadError = pcall(function()
    import "Dusk.BirdingLog.BL_Main"
end)
Turbine.PluginData.Load = BL710_RawLoad
if not BL710_LoadOK then error(BL710_LoadError) end

-- Counts from very old/corrupt saves must never reach arithmetic unchanged.
local function BL710_SafeCount(value)
    local n=tonumber(value)
    if not n or n<0 then return 0 end
    return n
end

if type(BL_Totals)~="table" then BL_Totals={} end
local fp=tonumber(BL_Totals.fp)
BL_Totals.fp=(fp and fp>=0) and fp or nil
for id in pairs(BL_ID or {}) do
    if BL_Totals[id]~=nil then BL_Totals[id]=BL710_SafeCount(BL_Totals[id]) end
end

if type(BL_Locs)~="table" then BL_Locs={} end
for zoneCode,loc in pairs(BL_Locs) do
    if BL_Zone and BL_Zone[zoneCode] then
        if type(loc)~="table" then
            BL_Locs[zoneCode]={}
        else
            for id in pairs(BL_ID or {}) do
                if loc[id]~=nil then loc[id]=BL710_SafeCount(loc[id]) end
            end
        end
    end
end

-- Keep a restored window reachable after resolution/monitor changes.
if BL_window then
    local x,y=BL_window:GetPosition()
    local sw,sh=Turbine.UI.Display.GetWidth(),Turbine.UI.Display.GetHeight()
    local scale=(BL_Options and tonumber(BL_Options.scale)) or 1
    local width=math.floor((BL_window:GetWidth() or 0)*scale+0.5)
    local height=math.floor((BL_window:GetHeight() or 0)*scale+0.5)
    local maxX=math.max(0,sw-width)
    local maxY=math.max(0,sh-height)
    x=math.max(0,math.min(tonumber(x) or 0,maxX))
    y=math.max(0,math.min(tonumber(y) or 0,maxY))
    BL_window:SetPosition(x,y)
    if BL_Options then BL_Options.pos1={x=x,y=y} end
end

-- BL_Names is a French learned-name cache. If the same saved data is loaded on
-- an EN/DE client, remove only names that came from that cache so they cannot
-- override the language-native BL_Data/BL_Data_DE names.
if BL_Lang~="FR" and type(BL_Names)=="table" then
    for id,name in pairs(BL_Names) do
        local t=BL_ID and BL_ID[id]
        if t and t.ln==name then t.ln=nil end
    end
    BL_Bname={}
    if BL_RebuildNameIndex then BL_RebuildNameIndex() end
end

-- Persist localized names for reward/garment objects too. BL_Names remains the
-- bird cache for backwards compatibility; BL_GNames is deliberately separate.
BL_GNames = Turbine.PluginData.Load(Turbine.DataScope.Server,"BL_GNames")
if type(BL_GNames)~="table" then BL_GNames={} end
if BL_Lang=="FR" then
    for id,name in pairs(BL_GNames) do
        local t=BL_GID and BL_GID[id]
        if t and (not t.ln or t.ln=="") and type(name)=="string" and name~="" then
            t.ln=name
        end
    end
end

-- Build a deterministic signature from the IDs in the current bird/reward DB.
-- The BL710 prefix remains valid because FR7.11 does not change localization IDs.
local function BL710_LocalizationSignature()
    local ids={}
    for id in pairs(BL_ID or {}) do table.insert(ids,"B:"..tostring(id)) end
    for id in pairs(BL_GID or {}) do table.insert(ids,"G:"..tostring(id)) end
    table.sort(ids)
    return "BL710|"..table.concat(ids,"|")
end

local BL710_GIDProbe=nil
local BL710_GIDQuickslot=nil
local BL710_GIDBusy=false
local BL710_SignatureWaiter=nil

local function BL710_ProbeLocalizedItemName(id)
    local ok,name=pcall(function()
        if not BL710_GIDQuickslot then
            BL710_GIDQuickslot=Turbine.UI.Lotro.Quickslot()
            BL710_GIDQuickslot:SetSize(1,1)
            BL710_GIDQuickslot:SetVisible(false)
        end
        local data="0x0000000000000000,0x700"..id
        local shortcut=Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Item,data)
        BL710_GIDQuickslot:SetShortcut(shortcut)
        local resolved=BL710_GIDQuickslot:GetShortcut()
        if not resolved then return nil end
        local item=resolved:GetItem()
        if not item then return nil end
        return item:GetName()
    end)
    if ok and type(name)=="string" and name~="" and name~="?" then return name end
    return nil
end

local function BL710_StartGIDProbe()
    if BL_Lang~="FR" or BL710_GIDBusy then return end

    local queue={}
    for id,t in pairs(BL_GID or {}) do
        if type(t)=="table" and (not t.ln or t.ln=="") then table.insert(queue,id) end
    end
    if #queue==0 then return end
    table.sort(queue)

    local ix,found=1,0
    BL710_GIDBusy=true
    BL710_GIDProbe=Turbine.UI.Control()
    BL710_GIDProbe:SetWantsUpdates(true)
    BL710_GIDProbe.Update=function(sender,args)
        for n=1,4 do
            local id=queue[ix]
            if not id then
                sender:SetWantsUpdates(false)
                BL710_GIDBusy=false
                Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_GNames",BL_GNames)
                if found>0 then
                    BL_Print("Localisation FR : "..found.." objet(s) d'ornithologie supplémentaire(s) récupéré(s).")
                end
                return
            end
            ix=ix+1
            local t=BL_GID[id]
            local name=BL710_ProbeLocalizedItemName(id)
            if name and t and name~=t.n then
                if BL_GNames[id]~=name then found=found+1 end
                t.ln=name
                BL_GNames[id]=name
            end
        end
    end
end

-- Commit the database signature only after every asynchronous localization job
-- that was required for this pass has really finished. If the plugin unloads
-- first, no signature is written and the next login safely retries the pass.
local function BL710_CommitSignatureWhenFinished(signature,waitForBirdProbe)
    if BL710_SignatureWaiter then
        BL710_SignatureWaiter:SetWantsUpdates(false)
        BL710_SignatureWaiter=nil
    end

    local function isDone()
        local birdDone=(not waitForBirdProbe) or (BL_Options and BL_Options.frProbeVersion==3)
        return birdDone and not BL710_GIDBusy
    end

    local function commit()
        if BL_Options then
            BL_Options.frProbeSignature=signature
            Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_Options",BL_Options)
        end
    end

    if isDone() then
        commit()
        return
    end

    local frames=0
    BL710_SignatureWaiter=Turbine.UI.Control()
    BL710_SignatureWaiter:SetWantsUpdates(true)
    BL710_SignatureWaiter.Update=function(sender,args)
        frames=frames+1
        if isDone() then
            sender:SetWantsUpdates(false)
            BL710_SignatureWaiter=nil
            commit()
        elseif frames>=3600 then
            -- Do not mark the signature complete on timeout. A later login will retry.
            sender:SetWantsUpdates(false)
            BL710_SignatureWaiter=nil
        end
    end
end

-- Wrap the original bird-name probe with the database signature. /bl fr still
-- forces a manual retry, while normal logins probe only once per completed ID set.
local BL710_BaseAutoLocalize=BL_AutoLocalize
if type(BL710_BaseAutoLocalize)=="function" then
    BL_AutoLocalize=function(force)
        if BL_Lang~="FR" then return end

        local signature=BL710_LocalizationSignature()
        if not force and BL_Options and BL_Options.frProbeSignature==signature then return end

        local missingBird=false
        for _,t in pairs(BL_ID or {}) do
            if type(t)=="table" and (not t.ln or t.ln=="") then
                missingBird=true
                break
            end
        end

        local waitForBirdProbe=false
        if force then
            if BL_Options then BL_Options.frProbeVersion=nil end
            BL710_BaseAutoLocalize(true)
            waitForBirdProbe=true
        elseif missingBird then
            if BL_Options then BL_Options.frProbeVersion=nil end
            BL710_BaseAutoLocalize(false)
            waitForBirdProbe=true
        end

        BL710_StartGIDProbe()
        BL710_CommitSignatureWhenFinished(signature,waitForBirdProbe)
    end

    -- BL_Main may have skipped its startup probe because an older save already
    -- contained frProbeVersion=3. Apply the completion-aware check once now.
    BL_AutoLocalize(false)
end

-- BL_Main installs its normal handler. Remove it from the top before installing
-- the generation-protected one below; older buried handlers are made inert.
if BL_ChatHandler and Turbine.Chat.Received==BL_ChatHandler then
    Turbine.Chat.Received=BL_PreviousChatHandler
end

BL_ChatGeneration=(BL_ChatGeneration or 0)+1
local BL710_Generation=BL_ChatGeneration
local BL710_PreviousChat=Turbine.Chat.Received

local BL710_xpat="<Examine:IIDDID:0x0%x+:0x700(%x+)>%[(.-)%]<\\Examine>"
local BL710_fpPat="Your proficiency in Birding has increased to (%d+)."

local function BL710_ChatHandler(sender,args)
    if BL710_PreviousChat then BL710_PreviousChat(sender,args) end
    if BL710_Generation~=BL_ChatGeneration then return end

    local msg=args.Message
    if not msg then return end

    if args.ChatType==Turbine.ChatType.Advancement then
        local fp=msg:match(BL710_fpPat)
        if not fp then
            local low=string.lower(msg)
            if low:find("bird",1,true) or low:find("ornith",1,true) or low:find("vogel",1,true) then
                fp=msg:match("(%d+)")
            end
        end
        if fp then BL_Totals.fp=tonumber(fp) return end
    end

    if args.ChatType~=Turbine.ChatType.SelfLoot then return end

    local id,name=msg:match(BL710_xpat)
    if not id then id,name=Dusk.Common.EII_ID(msg) end
    if not id then return end
    name=name or "?"
    if BL_ID[id] then
        if BL_Lang=="FR" and name~="?" and (not BL_ID[id].ln or BL_ID[id].ln=="") then
            BL_ID[id].ln=name
            BL_Names[id]=name
            if BL_Bname then BL_Bname[name]=id end
        end

        local previous=BL710_SafeCount(BL_Totals[id])
        if previous==0 and BL_Totals[id]==nil then
            BL_Print(BL_Lang=="FR" and "Nouveau type d'oiseau observé." or "New type of bird found.")
        end
        BL_Totals[id]=previous+1

        local birdName=BL_ID[id].ln or BL_ID[id].n
        if BL_Lang=="FR" then
            BL_Print("Observation : "..birdName..", total="..BL_Totals[id])
        else
            BL_Print("Saw a "..birdName..", count="..BL_Totals[id])
        end

        if BL_LocStr then
            local locTbl=BL_Locs[BL_LocStr]
            if type(locTbl)~="table" then
                locTbl={}
                BL_Locs[BL_LocStr]=locTbl
            end
            locTbl[id]=BL710_SafeCount(locTbl[id])+1
        end
        return
    end

    -- A known reward is always recognized, independently of /bl track. Tracking
    -- remains only for genuinely unknown items.
    if BL_GID[id] then
        if BL_Lang=="FR" and name~="?" and (not BL_GID[id].ln or BL_GID[id].ln=="") then
            BL_GID[id].ln=name
            BL_GNames[id]=name
        end
        BL_Print(BL_Lang=="FR" and "Récompense d'observation de la zone." or "Zone birding reward.")
        return
    end

    if BL_TrackUnknown then
        BL_PrintE((BL_Lang=="FR" and "Objet inconnu : " or "Unknown item: ")..name..", id="..tostring(id))
    end
end

BL_PreviousChatHandler=BL710_PreviousChat
BL_ChatHandler=BL710_ChatHandler
Turbine.Chat.Received=BL710_ChatHandler

-- Revalidate a kit restored from an old save. BL_Window originally validated
-- only a shortcut changed by the player after startup.
if BL_Totals and BL_Totals.kit and BL_window and BL_window.kit then
    local savedShortcut=BL_window.kit:GetShortcut()
    local savedItem=savedShortcut and savedShortcut:GetItem()
    local savedInfo=savedItem and savedItem:GetItemInfo()
    if not savedInfo or savedInfo:GetCategory()~=BL_BirdingKit then
        BL_Totals.kit=nil
        BL_window.kit:SetShortcut(Turbine.UI.Lotro.Shortcut())
        BL_window.kit:SetBackground("Dusk/BirdingLog/Kit.tga")
    end
end

local BL710_OldExecute=BL_Command.Execute
local BL710_Zloc="^%s*(.-)%s*:%s*(.-)%s*:%s*([%d%.,]+%s*[NS])%s*,%s*([%d%.,]+%s*[EWO])%s*$"
local BL710_xlink="<Examine:IIDDID:0x0000000000000000:0x700%s>[%s]<\\Examine>"

local function BL710_LocValue(str,neg)
    local clean=str:gsub("%s",""):gsub(",",".")
    local dir=clean:sub(-1)
    local nbr=tonumber(clean:sub(1,-2))
    if not nbr then return nil end
    if dir==neg or (neg=="W" and dir=="O") then nbr=-nbr end
    return nbr
end

local function BL710_PrintList(list)
    local ids,total={},0
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
        BL_Print(string.format(BL710_xlink,id,t.ln or t.n)..": "..n)
        total=total+n
    end
    BL_Print((BL_Lang=="FR" and "Nombre total d’observations : " or "Total sighting count: ")..total)
end

function BL_Command:Execute(cmd,args)
    -- Safe listing: ignore stale/corrupt five-character IDs from very old saves.
    if cmd=="bll" and args=="list" then
        if BL_LocStr then
            BL_PrintH((BL_Lang=="FR" and "Oiseaux observés dans " or "Birds sighted in ")..(BL_Zone[BL_LocStr].ln or BL_Zone[BL_LocStr].z))
            BL710_PrintList(BL_Locs[BL_LocStr])
        else
            BL_PrintE(BL_Lang=="FR" and "Aucune zone sélectionnée" or "No zone selected")
        end
        return
    end

    if args=="sight" then
        BL_PrintH(BL_Lang=="FR" and "Historique des observations :" or "Birding sighting record:")
        BL710_PrintList(BL_Totals)
        return
    end

    if args=="zones" then
        BL_PrintH(BL_Lang=="FR" and "Oiseaux trouvés par zone :" or "Birds found by zone:")
        for _,zt in Sort(BL_Zone) do
            local total,seen=0,0
            for id in pairs(zt.id) do
                total=total+1
                if BL710_SafeCount(BL_Totals[id])>0 then seen=seen+1 end
            end
            BL_Print((zt.ln or zt.z)..": "..seen.."/"..total)
        end
        return
    end

    -- Leave all non-location commands to the original implementation.
    if cmd~="bll" or args=="zone" then return BL710_OldExecute(self,cmd,args) end

    local reg,area,y,x=args:match(BL710_Zloc)
    if not y then return BL710_OldExecute(self,cmd,args) end

    reg=reg:gsub("^%s+",""):gsub("%s+$","")
    local r=BL_Region[reg]
    if not r and (reg=="Ériador" or reg=="Eriador") then r=BL_Region.Eriador end
    if not r then BL_PrintE((BL_Lang=="FR" and "Région inconnue : " or "Unknown region: ")..reg) return end
    if r>4 then BL_PrintE(BL_Lang=="FR" and "Aucun oiseau répertorié en Haradwaith." or "No birds found in Haradwaith.") return end

    local y1,x1=BL710_LocValue(y,"S"),BL710_LocValue(x,"W")
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
        if type(BL_Locs[zc])~="table" then BL_Locs[zc]={} end
        BL_window.zoneMenu:SetText(BL_Zone[zc].ln or BL_Zone[zc].z)
    else
        BL_PrintE(BL_Lang=="FR" and "Zone introuvable." or "Zone not found.")
    end
end

-- Invalidate our generation even when another plugin sits above our handler.
local BL710_OldUnload=Plugins.BirdingLog.Unload
Plugins.BirdingLog.Unload=function(sender,args)
    if BL710_Generation==BL_ChatGeneration then BL_ChatGeneration=BL_ChatGeneration+1 end
    if BL710_GIDProbe then BL710_GIDProbe:SetWantsUpdates(false) end
    if BL710_SignatureWaiter then BL710_SignatureWaiter:SetWantsUpdates(false) end
    Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_GNames",BL_GNames)
    return BL710_OldUnload(sender,args)
end