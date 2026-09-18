-- BirdingLog FR7.23 consolidated runtime.
-- BL_Loader716 performs preflight and constructs BL_Main once; this module is
-- the single owner of persistence, localization, chat, commands and unload.

import "Turbine.UI.Lotro"

local S=BL716
if type(S)~="table" or type(S.RawLoad)~="function" or type(S.RawSave)~="function" then
    error("BirdingLog FR7.16 preflight state is missing")
end

local BL716_SaveBusy=false
local BL716_SaveQueued=false
local BL716_SaveRetryPending=false
local BL716_SaveWarningShown=false
local BL716_ObservationsSinceSave=0
local BL716_LocalizationBusy=false
local BL716_LocalizationRunner=nil
local BL716_LocalizationGeneration=0
local BL716_LocalizationQueued=false
local BL716_LocalizationQueuedForce=false
local BL716_DeferredRefresh=false
local BL716_ShortcutGuard=false
local BL716_Unloading=false
local BL716_CommandRegistered=false

local BL716_SaveRuntimeData

-- ---------------------------------------------------------------------------
-- Async PluginData persistence
-- ---------------------------------------------------------------------------

local function BL716_SaveOne(scope,key,value,done)
    local finished=false
    local function finish(success,message)
        if finished then return end
        finished=true
        if done then done(success==true,message) end
    end

    local ok,err=pcall(S.RawSave,scope,key,value,function(success,message)
        finish(success,message)
    end)
    if not ok then finish(false,err) end
end

local function BL716_SaveBatch(items,done)
    if #items==0 then
        done(true,nil)
        return
    end

    local remaining=#items
    local allOK=true
    local firstError=nil
    for _,entry in ipairs(items) do
        BL716_SaveOne(entry.scope,entry.key,entry.value,function(success,message)
            if not success then
                allOK=false
                firstError=firstError or message
            end
            remaining=remaining-1
            if remaining==0 then done(allOK,firstError) end
        end)
    end
end

local function BL716_RuntimeSaveItems()
    local items={}
    local function add(scope,key,value)
        -- Never overwrite a save that failed to load during this session.
        if not S.LoadFailures[key] and type(value)=="table" then
            table.insert(items,{scope=scope,key=key,value=value})
        end
    end
    add(Turbine.DataScope.Server,"BL_Options",BL_Options)
    add(Turbine.DataScope.Server,"BL_Locs",BL_Locs)
    add(Turbine.DataScope.Server,"BL_Names",BL_Names)
    add(Turbine.DataScope.Server,"BL_GNames",BL_GNames)
    add(Turbine.DataScope.Character,"BL_Totals",BL_Totals)
    add(Turbine.DataScope.Character,"BL_PendingShortcuts",S.PendingShortcuts)
    return items
end

local function BL716_StartQueuedLocalizationIfPossible()
    if BL716_Unloading or BL716_SaveBusy or BL716_LocalizationBusy or not BL716_LocalizationQueued then return end
    local force=BL716_LocalizationQueuedForce
    BL716_LocalizationQueued=false
    BL716_LocalizationQueuedForce=false
    BL_AutoLocalize(force)
end

BL716_SaveRuntimeData=function()
    if BL716_Unloading then return false end
    if BL716_LocalizationBusy then
        BL716_SaveQueued=true
        return false
    end
    if BL716_SaveBusy then
        BL716_SaveQueued=true
        return false
    end

    BL716_SaveBusy=true
    BL716_SaveBatch(BL716_RuntimeSaveItems(),function(success,message)
        BL716_SaveBusy=false
        if BL716_Unloading then return end

        if success then
            BL716_ObservationsSinceSave=0
            BL716_SaveRetryPending=false
            BL716_SaveWarningShown=false
        else
            BL716_SaveRetryPending=true
            if not BL716_SaveWarningShown then
                BL716_SaveWarningShown=true
                pcall(function()
                    BL_PrintE(BL_Lang=="FR" and
                        "La sauvegarde automatique a échoué ; BirdingLog réessaiera au prochain changement." or
                        "Automatic save failed; BirdingLog will retry on the next change.")
                end)
            end
        end

        if BL716_SaveQueued then
            BL716_SaveQueued=false
            BL716_SaveRuntimeData()
            return
        end
        BL716_StartQueuedLocalizationIfPossible()
    end)
    return true
end

BL_SaveRuntimeData=BL716_SaveRuntimeData
BL_SaveOptions=function()
    return BL716_SaveRuntimeData()
end

function BL_ClearPendingShortcut(field)
    local pending=S.LoadPendingShortcuts()
    if pending[field]~=nil then pending[field]=nil end
end

-- ---------------------------------------------------------------------------
-- Official/localized names and old-save migration
-- ---------------------------------------------------------------------------

-- Add the known hobby hat as a recognized object. It is not a zone reward.
if BL_GID and not BL_GID["6B900"] then
    local nativeName="Birder's Hat"
    if BL_Lang=="DE" then nativeName="Hut des Vogelbeobachters" end
    BL_GID["6B900"]={n=nativeName,z=""}
end
if BL_Lang=="FR" and BL_GID and BL_GID["6B900"] then
    BL_GID["6B900"].ln="Chapeau d'ornithologue"
end

-- BL_Main was deliberately given an empty BL_Names table during preflight, so
-- every .ln present here on the FR client came from the embedded BL_FR database.
BL_FR_OfficialIDs={}
if BL_Lang=="FR" then
    for id,t in pairs(BL_ID or {}) do
        if type(t)=="table" and type(t.ln)=="string" and t.ln~="" then
            BL_FR_OfficialIDs[id]=true
        end
    end
    for id,t in pairs(BL_GID or {}) do
        if type(t)=="table" and type(t.ln)=="string" and t.ln~="" then
            BL_FR_OfficialIDs[id]=true
        end
    end
end

BL_Names=S.PreloadedNames or {}
local BL716_LoadedGNames=S.Load(Turbine.DataScope.Server,"BL_GNames")
BL716_LoadedGNames=S.ValidateTableRoot("BL_GNames",BL716_LoadedGNames)
BL_GNames=S.SanitizeNameCache(BL716_LoadedGNames)

if BL_Lang=="FR" then
    for id,name in pairs(BL_Names) do
        local t=BL_ID and BL_ID[id]
        if t and not BL_FR_OfficialIDs[id] then t.ln=name end
    end
    for id,name in pairs(BL_GNames) do
        local t=BL_GID and BL_GID[id]
        if t and not BL_FR_OfficialIDs[id] then t.ln=name end
    end
end

-- Rebuild from scratch: a refreshed/changed learned name must not leave an old
-- alias pointing at the same bird forever.
function BL_RebuildNameIndex()
    BL_Bname={}
    for id,t in pairs(BL_ID or {}) do
        if type(t)=="table" then
            if type(t.n)=="string" then BL_Bname[t.n]=id end
            if type(t.ln)=="string" and t.ln~="" then BL_Bname[t.ln]=id end
        end
    end
end
BL_RebuildNameIndex()

-- Merge legacy location records into the modern per-zone layout without throwing
-- away modern records that already existed beside them.
if type(BL_Locs)~="table" then BL_Locs={} end
if type(S.PreloadedLocs)=="table" then
    for _,old in pairs(S.PreloadedLocs) do
        if type(old)=="table" and type(old.z)=="string" and BL_Zone and BL_Zone[old.z] then
            local target=BL_Locs[old.z]
            if type(target)~="table" then target={} BL_Locs[old.z]=target end
            for id,n in pairs(old) do
                if type(id)=="string" and #id==5 then
                    target[id]=S.SafeCount(target[id])+S.SafeCount(n)
                end
            end
        end
    end
end

for zc,loc in pairs(BL_Locs) do
    if BL_Zone and BL_Zone[zc] then
        if type(loc)~="table" then
            BL_Locs[zc]={}
        else
            for id,n in pairs(loc) do
                if type(id)=="string" and #id==5 then loc[id]=S.SafeCount(n) end
            end
        end
    end
end

if type(BL_Totals)~="table" then BL_Totals={} end
BL_Totals.fp=S.Integer(BL_Totals.fp,0)
for id,n in pairs(BL_Totals) do
    if type(id)=="string" and #id==5 then BL_Totals[id]=S.SafeCount(n) end
end
local function BL716_ClampMainWindow()
    if not BL_window then return end
    local x,y=BL_window:GetPosition()
    local scale=(BL_Options and S.Number(BL_Options.scale,0.5,2.0)) or 1
    local sw,sh=Turbine.UI.Display.GetWidth(),Turbine.UI.Display.GetHeight()
    local ww=math.floor((BL_window:GetWidth() or 0)*scale+0.5)
    local wh=math.floor((BL_window:GetHeight() or 0)*scale+0.5)
    x=math.max(0,math.min(S.Number(x) or 0,math.max(0,sw-ww)))
    y=math.max(0,math.min(S.Number(y) or 0,math.max(0,sh-wh)))
    BL_window:SetPosition(x,y)
    if BL_Options then BL_Options.pos1={x=x,y=y} end
end
BL716_ClampMainWindow()

-- Revalidate what the real window restored. A preflight-accepted shortcut can
-- still be rejected by the actual control a few instructions later; keep such a
-- value pending instead of destroying it.
local function BL716_ClearControl(control,background)
    if not control then return end
    local previous=control.ShortcutChanged
    control.ShortcutChanged=nil
    pcall(function()
        control:SetShortcut(Turbine.UI.Lotro.Shortcut())
        if background then control:SetBackground(background) end
    end)
    control.ShortcutChanged=previous
end

local function BL716_ValidateRestored(field,control,background)
    local saved=BL_Totals[field]
    if type(saved)~="string" or saved=="" or not control then return end

    local accepted=false
    local resolved=nil
    pcall(function()
        resolved=control:GetShortcut()
        accepted=resolved and
            resolved:GetType()==Turbine.UI.Lotro.ShortcutType.Item and
            resolved:GetData()==saved
    end)

    if not accepted then
        local pending=S.LoadPendingShortcuts()
        pending[field]=saved
        BL_Totals[field]=false
        BL716_ClearControl(control,background)
        return
    end

end

if BL_window then
    BL716_ValidateRestored("kit",BL_window.kit,"Dusk/BirdingLog/Kit.tga")
    BL716_ValidateRestored("wpn",BL_window.weapon,"Dusk/BirdingLog/Sword.tga")
    BL716_ValidateRestored("shl",BL_window.shield,"Dusk/BirdingLog/Shield.tga")
end

-- ---------------------------------------------------------------------------
-- Quickslots and immediate saves
-- ---------------------------------------------------------------------------

function BL_Shortcut(sender,name)
    local shortcut=sender:GetShortcut()
    local itemType=shortcut:GetType()
    if itemType==0 then return nil end

    local itemData=shortcut:GetData()
    if sender:IsAltKeyDown() then
        BL_Print("Type="..tostring(itemType)..", "..(BL_Lang=="FR" and "Données=" or "Data=")..tostring(itemData))
    end

    local function clearSlot()
        BL716_ShortcutGuard=true
        sender:SetShortcut(Turbine.UI.Lotro.Shortcut())
        BL716_ShortcutGuard=false
    end

    if itemType~=Turbine.UI.Lotro.ShortcutType.Item then
        clearSlot()
        BL_Print(BL_Lang=="FR" and (name.." réinitialisé.") or (name.." reset."))
        return nil
    end

    if type(itemData)~="string" or itemData=="" then
        clearSlot()
        BL_PrintE(BL_Lang=="FR" and "Données de raccourci invalides." or "Invalid shortcut data.")
        return nil
    end

    local item=shortcut:GetItem()
    if not item then
        BL_Print(BL_Lang=="FR" and
            (name.." enregistré ; résolution de l’objet différée.") or
            (name.." saved; item resolution deferred."))
        return itemData
    end

    BL_Print(BL_Lang=="FR" and (name.." défini sur "..item:GetName()) or (name.." set to "..item:GetName()))
    return itemData
end

if BL_window then
    if BL_window.kit then
        BL_window.kit.ShortcutChanged=function(sender,args)
            if BL716_ShortcutGuard then return end
            local data=BL_Shortcut(sender,BL_Lang=="FR" and "Kit d’ornithologie" or "Birding Kit")
            BL_Totals.kit=data
            BL_ClearPendingShortcut("kit")
            BL716_SaveRuntimeData()
        end
    end
    if BL_window.weapon then
        BL_window.weapon.ShortcutChanged=function(sender,args)
            if BL716_ShortcutGuard then return end
            BL_Totals.wpn=BL_Shortcut(sender,BL_Lang=="FR" and "Arme" or "Weapon")
            BL_ClearPendingShortcut("wpn")
            BL716_SaveRuntimeData()
        end
    end
    if BL_window.shield then
        BL_window.shield.ShortcutChanged=function(sender,args)
            if BL716_ShortcutGuard then return end
            BL_Totals.shl=BL_Shortcut(sender,BL_Lang=="FR" and "2e emplacement" or "2nd")
            BL_ClearPendingShortcut("shl")
            BL716_SaveRuntimeData()
        end
    end
end

-- ---------------------------------------------------------------------------
-- FR localization -- one exact runtime owner, no frame-count proxy
-- ---------------------------------------------------------------------------

local function BL716_LocalizationSignature()
    local ids={}
    for id in pairs(BL_ID or {}) do table.insert(ids,"B:"..tostring(id)) end
    for id in pairs(BL_GID or {}) do table.insert(ids,"G:"..tostring(id)) end
    table.sort(ids)
    return "BL716|"..table.concat(ids,"|")
end

local BL716_LocalizeProbe=nil
local function BL716_ProbeLocalizedItemName(id)
    local ok,name=pcall(function()
        if not BL716_LocalizeProbe then
            BL716_LocalizeProbe=Turbine.UI.Lotro.Quickslot()
            BL716_LocalizeProbe:SetSize(1,1)
            BL716_LocalizeProbe:SetVisible(false)
        end
        local data="0x0000000000000000,0x700"..id
        BL716_LocalizeProbe:SetShortcut(Turbine.UI.Lotro.Shortcut())
        BL716_LocalizeProbe:SetShortcut(
            Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Item,data)
        )
        local resolved=BL716_LocalizeProbe:GetShortcut()
        if not resolved or resolved:GetType()~=Turbine.UI.Lotro.ShortcutType.Item then return nil end
        if resolved:GetData()~=data then return nil end
        local item=resolved:GetItem()
        if not item then return nil end
        return item:GetName()
    end)
    if ok and type(name)=="string" and name~="" and name~="?" then return name end
    return nil
end

local function BL716_EndLocalization(success,found,message)
    if BL_RebuildNameIndex then BL_RebuildNameIndex() end
    BL716_LocalizationBusy=false
    BL716_LocalizationRunner=nil

    if not success then
        BL_PrintE(BL_Lang=="FR" and
            "La sauvegarde de la localisation FR a échoué ; une prochaine session réessaiera." or
            "Localization save failed; a later session will retry.")
    elseif found>0 then
        BL_Print("Localisation FR : "..found.." nom(s) récupéré(s) depuis LOTRO.")
    end

    local refresh=BL716_DeferredRefresh
    BL716_DeferredRefresh=false

    if BL716_SaveQueued then
        BL716_SaveQueued=false
        if refresh then
            BL716_LocalizationQueued=true
            BL716_LocalizationQueuedForce=true
        end
        BL716_SaveRuntimeData()
    elseif refresh then
        BL_AutoLocalize(true)
    else
        BL716_StartQueuedLocalizationIfPossible()
    end
end

local function BL716_PersistLocalization(signature,found,generation)
    local cacheItems={
        {scope=Turbine.DataScope.Server,key="BL_Names",value=BL_Names},
        {scope=Turbine.DataScope.Server,key="BL_GNames",value=BL_GNames},
    }
    BL716_SaveBatch(cacheItems,function(cacheOK,message)
        if generation~=BL716_LocalizationGeneration or BL716_Unloading then return end
        if not cacheOK or type(BL_Options)~="table" then
            BL716_EndLocalization(false,found,message)
            return
        end

        local oldVersion,oldSignature=BL_Options.frProbeVersion,BL_Options.frProbeSignature
        BL_Options.frProbeVersion=4
        BL_Options.frProbeSignature=signature
        BL716_SaveOne(Turbine.DataScope.Server,"BL_Options",BL_Options,function(optionsOK,optionsMessage)
            if generation~=BL716_LocalizationGeneration or BL716_Unloading then return end
            if not optionsOK then
                BL_Options.frProbeVersion=oldVersion
                BL_Options.frProbeSignature=oldSignature
                BL716_EndLocalization(false,found,optionsMessage)
                return
            end
            BL716_EndLocalization(true,found,nil)
        end)
    end)
end

function BL_IsLocalizationBusy()
    return BL716_LocalizationBusy==true
end

function BL_CancelLocalization()
    BL716_LocalizationGeneration=BL716_LocalizationGeneration+1
    if BL716_LocalizationRunner then
        BL716_LocalizationRunner:SetWantsUpdates(false)
        BL716_LocalizationRunner=nil
    end
    BL716_LocalizationBusy=false
    BL716_DeferredRefresh=false
    BL716_LocalizationQueued=false
    BL716_LocalizationQueuedForce=false
end

function BL_AutoLocalize(force)
    if BL_Lang~="FR" or BL716_Unloading then return end
    if S.LoadFailures["BL_Names"] or S.LoadFailures["BL_GNames"] or S.LoadFailures["BL_Options"] then
        if force then
            BL_PrintE("Rafraîchissement FR ignoré : une sauvegarde de localisation n’a pas pu être lue.")
        end
        return
    end

    if BL716_SaveBusy then
        if force and not BL716_LocalizationQueuedForce then
            BL_Print("Sauvegarde en cours ; le rafraîchissement FR sera lancé juste après.")
        end
        BL716_LocalizationQueued=true
        BL716_LocalizationQueuedForce=BL716_LocalizationQueuedForce or force==true
        return
    end

    if BL716_LocalizationBusy then
        if force and not BL716_DeferredRefresh then
            BL_Print("Localisation FR déjà en cours ; le rafraîchissement manuel sera relancé juste après.")
        end
        if force then BL716_DeferredRefresh=true end
        return
    end

    local signature=BL716_LocalizationSignature()
    if not force and BL_Options and BL_Options.frProbeSignature==signature then return end

    local queue={}
    for id,t in pairs(BL_ID or {}) do
        local official=BL_FR_OfficialIDs[id]
        local missing=type(t)~="table" or not t.ln or t.ln==""
        if not official and (missing or force) then
            table.insert(queue,{kind="B",id=id})
        end
    end
    for id,t in pairs(BL_GID or {}) do
        local official=BL_FR_OfficialIDs[id]
        local missing=type(t)~="table" or not t.ln or t.ln==""
        if not official and (missing or force) then
            table.insert(queue,{kind="G",id=id})
        end
    end
    table.sort(queue,function(a,b)
        if a.kind==b.kind then return a.id<b.id end
        return a.kind<b.kind
    end)

    BL716_LocalizationGeneration=BL716_LocalizationGeneration+1
    local generation=BL716_LocalizationGeneration
    BL716_LocalizationBusy=true

    if #queue==0 then
        BL716_PersistLocalization(signature,0,generation)
        return
    end

    local ix,found=1,0
    BL716_LocalizationRunner=Turbine.UI.Control()
    BL716_LocalizationRunner:SetWantsUpdates(true)
    BL716_LocalizationRunner.Update=function(sender,args)
        if generation~=BL716_LocalizationGeneration then
            sender:SetWantsUpdates(false)
            return
        end
        for _=1,8 do
            local entry=queue[ix]
            if not entry then
                sender:SetWantsUpdates(false)
                BL716_LocalizationRunner=nil
                BL716_PersistLocalization(signature,found,generation)
                return
            end
            ix=ix+1
            local source=entry.kind=="B" and BL_ID or BL_GID
            local t=source and source[entry.id]
            local name=BL716_ProbeLocalizedItemName(entry.id)
            if name and t and name~=t.n then
                if entry.kind=="B" then
                    if BL_Names[entry.id]~=name then found=found+1 end
                    BL_Names[entry.id]=name
                else
                    if BL_GNames[entry.id]~=name then found=found+1 end
                    BL_GNames[entry.id]=name
                end
                t.ln=name
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Chat -- exactly one active BirdingLog owner
-- ---------------------------------------------------------------------------

if BL_ChatHandler and Turbine.Chat.Received==BL_ChatHandler then
    Turbine.Chat.Received=BL_PreviousChatHandler
end
BL_ChatGeneration=(BL_ChatGeneration or 0)+1
local BL716_ChatGeneration=BL_ChatGeneration
local BL716_PreviousChat=Turbine.Chat.Received
local BL716_XPat="<Examine:IIDDID:0x0%x+:0x700(%x+)>%[(.-)%]<\\Examine>"
local BL716_FPPat="Your proficiency in Birding has increased to (%d+)."

local function BL716_DecodeMessage(msg)
    local id,name=msg:match(BL716_XPat)
    if not id and Dusk and Dusk.Common and Dusk.Common.EII_ID then
        local ok,a,b=pcall(Dusk.Common.EII_ID,msg)
        if ok then id,name=a,b end
    end
    return id,name
end

local function BL716_ChatHandler(sender,args)
    if BL716_PreviousChat then BL716_PreviousChat(sender,args) end
    if BL716_ChatGeneration~=BL_ChatGeneration then return end
    if not args then return end

    local msg=args.Message
    if type(msg)~="string" then return end

    if args.ChatType==Turbine.ChatType.Advancement then
        local fp=msg:match(BL716_FPPat)
        if not fp then
            local low=string.lower(msg)
            if low:find("bird",1,true) or low:find("ornith",1,true) or low:find("vogel",1,true) then
                fp=msg:match("(%d+)")
            end
        end
        local n=S.Integer(fp,0)
        if n then
            local changed=BL_Totals.fp~=n
            BL_Totals.fp=n
            if changed and BL_window and BL_window.RefreshProficiency then
                BL_window:RefreshProficiency()
            end
            if changed or BL716_SaveRetryPending then BL716_SaveRuntimeData() end
        end
        return
    end

    if args.ChatType~=Turbine.ChatType.SelfLoot then return end
    local id,name=BL716_DecodeMessage(msg)
    if not id then return end
    name=name or "?"
    if name:sub(-5)=="Frame" then return end

    if BL_ID and BL_ID[id] then
        local learned=false
        if BL_Lang=="FR" and name~="?" and not BL_FR_OfficialIDs[id] then
            if BL_Names[id]~=name then learned=true end
            BL_ID[id].ln=name
            BL_Names[id]=name
            if learned and BL_RebuildNameIndex then BL_RebuildNameIndex() end
        end

        local before=S.SafeCount(BL_Totals[id])
        if before==0 and BL_Totals[id]==nil then
            BL_Print(BL_Lang=="FR" and "Nouveau type d'oiseau observé." or "New type of bird found.")
        end
        BL_Totals[id]=before+1
        BL_Print((BL_Lang=="FR" and "Observation : " or "Saw a ")..(BL_ID[id].ln or BL_ID[id].n)..
            (BL_Lang=="FR" and ", total=" or ", count=")..BL_Totals[id])
        if BL_deedsWindow and BL_deedsWindow:IsVisible() then BL_deedsWindow:Refresh() end

        if BL_LocStr then
            local loc=BL_Locs[BL_LocStr]
            if type(loc)~="table" then loc={} BL_Locs[BL_LocStr]=loc end
            loc[id]=S.SafeCount(loc[id])+1
        end

        BL716_ObservationsSinceSave=BL716_ObservationsSinceSave+1
        if learned or BL716_SaveRetryPending or BL716_ObservationsSinceSave>=10 then
            BL716_SaveRuntimeData()
        end
        return
    end

    if BL_GID and BL_GID[id] then
        local learned=false
        if BL_Lang=="FR" and name~="?" and not BL_FR_OfficialIDs[id] then
            if BL_GNames[id]~=name then learned=true end
            BL_GID[id].ln=name
            BL_GNames[id]=name
        end
        local zoneReward=type(BL_GID[id].z)=="string" and BL_GID[id].z~=""
        BL_Print(BL_Lang=="FR" and
            (zoneReward and "Récompense d'observation de la zone." or "Objet d'ornithologie reconnu.") or
            (zoneReward and "Zone birding reward." or "Known birding item."))
        if learned or BL716_SaveRetryPending then BL716_SaveRuntimeData() end
        return
    end

    if BL_TrackUnknown or BL_TrackHover then
        BL_PrintE((BL_Lang=="FR" and "Inconnu : " or "Unknown: ")..name..", id="..tostring(id))
    end
end

BL_PreviousChatHandler=BL716_PreviousChat
BL_ChatHandler=BL716_ChatHandler
Turbine.Chat.Received=BL716_ChatHandler

-- ---------------------------------------------------------------------------
-- Commands -- scoped to their real aliases, safe listings and deterministic loc
-- ---------------------------------------------------------------------------

local BL716_Zloc="^%s*(.-)%s*:%s*(.-)%s*:%s*([%d%.,]+%s*[NS])%s*,%s*([%d%.,]+%s*[EWO])%s*$"
local BL716_XLink="<Examine:IIDDID:0x0000000000000000:0x700%s>[%s]<\\Examine>"

local function BL716_LocValue(str,neg)
    local clean=tostring(str):gsub("%s",""):gsub(",",".")
    local dir=clean:sub(-1)
    local nbr=S.Number(clean:sub(1,-2))
    if not nbr then return nil end
    if dir==neg or (neg=="W" and dir=="O") then nbr=-nbr end
    return nbr
end

local function BL716_PrintList(list)
    local ids,total={},0
    if type(list)~="table" then list={} end
    for id,n in pairs(list) do
        if type(id)=="string" and #id==5 and BL_ID[id] and S.Number(n,0) then
            table.insert(ids,id)
        end
    end
    table.sort(ids,function(a,b)
        local an,bn=BL_ID[a].ln or BL_ID[a].n,BL_ID[b].ln or BL_ID[b].n
        if an==bn then return a<b end
        return an<bn
    end)
    for _,id in ipairs(ids) do
        local n=S.SafeCount(list[id])
        BL_Print(string.format(BL716_XLink,id,BL_ID[id].ln or BL_ID[id].n)..": "..n)
        total=total+n
    end
    BL_Print((BL_Lang=="FR" and "Nombre total d’observations : " or "Total sighting count: ")..total)
end

function BL_Command:Execute(cmd,args)
    args=tostring(args or ""):gsub("^%s+",""):gsub("%s+$","")
    if Dusk.Common.HelpCmd(cmd,args,BL_Help) then return end

    if cmd=="bll" then
        if args=="list" then
            if BL_LocStr and BL_Zone[BL_LocStr] then
                BL_PrintH((BL_Lang=="FR" and "Oiseaux observés dans " or "Birds sighted in ")..(BL_Zone[BL_LocStr].ln or BL_Zone[BL_LocStr].z))
                BL716_PrintList(BL_Locs[BL_LocStr])
            else
                BL_PrintE(BL_Lang=="FR" and "Aucune zone sélectionnée" or "No zone selected")
            end
            return
        end

        if args=="zone" then
            if BL_LocStr and BL_Zone[BL_LocStr] then
                local zt=BL_Zone[BL_LocStr]
                local ids,total,seen={},0,0
                for id in pairs(zt.id or {}) do table.insert(ids,id) end
                table.sort(ids,function(a,b)
                    local an,bn=BL_ID[a].ln or BL_ID[a].n,BL_ID[b].ln or BL_ID[b].n
                    if an==bn then return a<b end
                    return an<bn
                end)
                BL_PrintH((BL_Lang=="FR" and "Oiseaux à observer dans " or "Birds to see in ")..(zt.ln or zt.z))
                for _,id in ipairs(ids) do
                    local n=S.SafeCount(BL_Totals[id])
                    BL_Print(string.format(BL716_XLink,id,BL_ID[id].ln or BL_ID[id].n)..": "..n)
                    total=total+1
                    if n>0 then seen=seen+1 end
                end
                BL_Print((BL_Lang=="FR" and "Oiseaux vus : " or "Birds seen: ")..seen.."/"..total)
            else
                BL_PrintE(BL_Lang=="FR" and "Aucune zone sélectionnée" or "No zone selected")
            end
            return
        end

        local reg,area,y,x=args:match(BL716_Zloc)
        if not y then
            BL_PrintE(BL_Lang=="FR" and "Lieu d’ornithologie inconnu." or "Unknown location for Birding.")
            return
        end
        reg=reg:gsub("^%s+",""):gsub("%s+$","")
        local r=BL_Region[reg]
        if not r and (reg=="Ériador" or reg=="Eriador") then r=BL_Region.Eriador end
        if not r then
            BL_PrintE((BL_Lang=="FR" and "Région inconnue : " or "Unknown region: ")..reg)
            return
        end
        if r>4 then
            BL_PrintE(BL_Lang=="FR" and "Aucun oiseau répertorié en Haradwaith." or "No birds found in Haradwaith.")
            return
        end

        local y1,x1=BL716_LocValue(y,"S"),BL716_LocValue(x,"W")
        if not y1 or not x1 then
            BL_PrintE(BL_Lang=="FR" and "Coordonnées invalides." or "Invalid coordinates.")
            return
        end

        BL_LocStr=nil
        local zc,zn,bestScore,bestArea
        local areaName=tostring(area or ""):gsub("^%s+",""):gsub("%s+$","")
        local direct=BL_Zname[areaName]
        if direct and BL_Zone[direct] then
            local z=BL_Zone[direct]
            if r==z.r or (r==4 and z.r==3) then zc,zn=direct,z.z end
        end

        if not zc then
            for code,z in pairs(BL_Zone) do
                local same=r==z.r or (r==4 and z.r==3)
                if same and y1<z.n and y1>z.s and x1<z.e and x1>z.w then
                    local h,w=z.n-z.s,z.e-z.w
                    local score=math.min(
                        math.min(z.n-y1,y1-z.s)/h,
                        math.min(z.e-x1,x1-z.w)/w
                    )
                    local rectArea=h*w
                    if not bestScore or score>bestScore or
                        (score==bestScore and (rectArea<bestArea or (rectArea==bestArea and code<zc))) then
                        zc,zn,bestScore,bestArea=code,z.z,score,rectArea
                    end
                end
            end
        end

        if zn then
            BL_LocStr=zc
            if type(BL_Locs[zc])~="table" then BL_Locs[zc]={} end
            BL_window.zoneMenu:SetText(BL_Zone[zc].ln or BL_Zone[zc].z)
            BL_Print((BL_Lang=="FR" and "Zone : " or "Zone: ")..(BL_Zone[zc].ln or zn))
        else
            BL_PrintE(BL_Lang=="FR" and "Zone introuvable." or "Zone not found.")
        end
        return
    end

    if cmd=="blg" then
        if not BL_LocStr or not BL_Zone[BL_LocStr] then
            BL_PrintE(BL_Lang=="FR" and "Aucune zone sélectionnée" or "No zone selected")
            return
        end
        local zname=BL_Zone[BL_LocStr].z
        for id,t in pairs(BL_GID or {}) do
            if t.z==zname then
                BL_PrintH(BL_Lang=="FR" and
                    ("En terminant la prouesse d’ornithologie de "..(BL_Zone[BL_LocStr].ln or zname).." :") or
                    ('Upon completing the deed "All the Birds of '..zname..'",'))
                BL_Print((BL_Lang=="FR" and "Récompense : " or "You will receive: ")..string.format(BL716_XLink,id,t.ln or t.n))
                return
            end
        end
        BL_Print(BL_Lang=="FR" and
            ("Aucune récompense d’ornithologie connue pour "..(BL_Zone[BL_LocStr].ln or zname)) or
            ("No known Birding reward for "..zname))
        return
    end

    if cmd=="blw" then
        BL_window:SetVisible(true)
        BL_window:SetZOrder(2)
        return
    end

    if cmd~="bl" then return end

    if args=="fr" and BL_Lang=="FR" then
        BL_Print("Nouvelle analyse des noms français depuis les données LOTRO…")
        BL_AutoLocalize(true)
        return
    end
    if args=="show" then
        BL_window:SetVisible(true)
        BL_window:SetZOrder(2)
        return
    end
    if args=="sight" then
        BL_PrintH(BL_Lang=="FR" and "Historique des observations :" or "Birding sighting record:")
        BL716_PrintList(BL_Totals)
        return
    end
    if args=="track" then
        BL_TrackUnknown=not BL_TrackUnknown
        BL_Print(BL_Lang=="FR" and
            (BL_TrackUnknown and "Suivi activé." or "Suivi désactivé.") or
            ((BL_TrackUnknown and "En" or "Dis").."abled Tracking."))
        return
    end
    if args=="deeds" then
        if type(BL_OpenDeeds)=="function" then BL_OpenDeeds() end
        return
    end
    if args=="deed" then
        if type(BL_OpenDeeds)=="function" then BL_OpenDeeds(BL_LocStr) end
        return
    end
    local deedZone=args:match("^deed%s+(.+)$")
    if deedZone then
        if type(BL_OpenDeedByName)~="function" or not BL_OpenDeedByName(deedZone) then
            BL_PrintE((BL_Lang=="FR" and "Zone de prouesse introuvable : " or "Deed zone not found: ")..deedZone)
        end
        return
    end
    if args=="zones" then
        BL_PrintH(BL_Lang=="FR" and "Oiseaux trouvés par zone :" or "Birds found by zone:")
        for _,zt in Sort(BL_Zone) do
            local total,seen=0,0
            for id in pairs(zt.id or {}) do
                total=total+1
                if S.SafeCount(BL_Totals[id])>0 then seen=seen+1 end
            end
            BL_Print((zt.ln or zt.z)..": "..seen.."/"..total)
        end
        return
    end
    if args=="" then
        local fp=S.Number(BL_Totals.fp,0)
        if not fp then
            BL_Print(BL_Lang=="FR" and "Maîtrise d’ornithologie inconnue." or "Unknown Birding proficiency.")
            return
        end
        local title,best="",0
        for p in pairs(BL_Title or {}) do
            if fp>=p and p>best then best=p end
        end
        if best>0 then
            title=", "..((BL_Lang=="FR" and BL_TitleFR and BL_TitleFR[best]) or BL_Title[best])
        end
        BL_Print((BL_Lang=="FR" and "Maîtrise d’ornithologie : " or "Birding proficiency is ")..fp..title)
        return
    end

    local n,bird=args:match("^(%d+)%s+(.+)$")
    if n and bird then
        n=S.Integer(n,0)
        bird=bird:gsub("^%s+",""):gsub("%s+$","")
        if not n or bird=="" then
            BL_PrintE(BL_Lang=="FR" and "Nombre d’observations invalide." or "Invalid sighting count.")
            return
        end

        local matches={}
        for id,t in pairs(BL_ID or {}) do
            if t.n==bird or t.ln==bird then table.insert(matches,id) end
        end
        if #matches>1 and BL_LocStr and BL_Zone[BL_LocStr] then
            local inZone={}
            for _,id in ipairs(matches) do
                if BL_Zone[BL_LocStr].id[id] then table.insert(inZone,id) end
            end
            if #inZone==1 then matches=inZone end
        end

        if #matches==0 then
            BL_PrintE(BL_Lang=="FR" and ("Oiseau '"..bird.."' introuvable") or ("Bird '"..bird.."' not found"))
            return
        elseif #matches>1 then
            BL_PrintE(BL_Lang=="FR" and
                ("Nom d’oiseau ambigu : "..bird..". Sélectionnez sa zone ou utilisez son nom anglais exact.") or
                ("Ambiguous bird name: "..bird..". Select its zone or use the exact English name."))
            return
        end

        local id=matches[1]
        local places={}
        for _,zoneCode in ipairs(BL_ID[id].f or {}) do
            local zone=BL_Zone[zoneCode]
            if zone then table.insert(places,zone.ln or zone.z) end
        end
        BL_Print(BL_Lang=="FR" and
            (bird.." se trouve dans : "..table.concat(places,", ")) or
            ("The "..bird.." is found in "..table.concat(places,", ")))
        BL_Totals[id]=n
        BL_Print((BL_Lang=="FR" and "Total d’observations réglé sur " or "Total sightings set to ")..n)
        BL716_SaveRuntimeData()
        return
    end

    BL_PrintE((BL_Lang=="FR" and "Commande inconnue : " or "Unknown command, ")..args)
end

-- Register commands only after the consolidated Execute implementation exists.
local BL716_CommandOK,BL716_CommandResult=pcall(
    Turbine.Shell.AddCommand,
    "bl;blg;bll;blw;bl?",
    BL_Command
)
if not BL716_CommandOK or (type(BL716_CommandResult)=="number" and BL716_CommandResult<=0) then
    error("BirdingLog could not register its shell commands")
end
BL716_CommandRegistered=true

-- ---------------------------------------------------------------------------
-- Startup persistence and clean unload
-- ---------------------------------------------------------------------------

-- Report read failures before any write. Failed keys stay excluded from all
-- runtime save batches so a transient read error cannot erase valid disk data.
for key,err in pairs(S.LoadFailures) do
    BL_PrintE((BL_Lang=="FR" and "Sauvegarde non chargée, écriture désactivée pour cette session : " or
        "Save failed to load; writes disabled for this session: ")..tostring(key))
end

-- Let localization go first. Runtime persistence is serialized behind it, so
-- migration/sanitization is still saved before any later gameplay change.
if BL_Lang=="FR" then BL_AutoLocalize(false) end
BL716_SaveRuntimeData()

local function BL716_FlushOnUnload()
    -- Unload cannot wait for async callbacks. Issue one last snapshot for every
    -- persistent table, matching the standard LOTRO unload pattern.
    for _,entry in ipairs(BL716_RuntimeSaveItems()) do
        pcall(S.RawSave,entry.scope,entry.key,entry.value)
    end
end

Plugins.BirdingLog.Unload=function(sender,args)
    BL716_Unloading=true
    if BL716_ChatGeneration==BL_ChatGeneration then
        BL_ChatGeneration=BL_ChatGeneration+1
    end

    BL_CancelLocalization()
    BL_TrackHover=false

    if BL_window and BL_Options then
        local x,y=BL_window:GetPosition()
        BL_Options.pos1={
            x=math.floor((S.Number(x) or 0)+0.5),
            y=math.floor((S.Number(y) or 0)+0.5),
        }
    end
    if BL_SaveIconPosition then pcall(BL_SaveIconPosition) end
    BL716_FlushOnUnload()

    if Turbine.Chat.Received==BL716_ChatHandler then
        Turbine.Chat.Received=BL716_PreviousChat
    end
    BL_ChatHandler=nil
    BL_PreviousChatHandler=BL716_PreviousChat
    if BL_window then
        BL_window:SetWantsUpdates(false)
        BL_window:SetVisible(false)
    end
    if BL_deedsWindow then BL_deedsWindow:SetVisible(false) end
    if BL_IconWindow then BL_IconWindow:SetVisible(false) end
    if BL716_CommandRegistered then
        pcall(function() Turbine.Shell.RemoveCommand(BL_Command) end)
        BL716_CommandRegistered=false
    end

    BL_Print(BL_Lang=="FR" and "Carnet d’ornithologie enregistré." or "Birding record saved.")

    BL_SaveRuntimeData=nil
    BL_SaveOptions=nil
    BL_IsLocalizationBusy=nil
    BL_CancelLocalization=nil
end
