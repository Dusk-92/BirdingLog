-- BirdingLog FR7.16 consolidated runtime.
-- This is the only active compatibility layer: it preflights saved data, loads
-- BL_Main directly, then owns localization, chat, autosave, commands and unload.

import "Turbine.UI.Lotro"
import "Dusk.Common"

local BL716_RawLoad = Turbine.PluginData.Load
local BL716_RawSave = Turbine.PluginData.Save
local BL716_ShortcutProbe = nil
local BL716_OptionsCaptured = false
local BL716_SavedProbeVersion = nil
local BL716_SavedProbeSignature = nil
local BL716_PreloadedNames = {}
local BL716_PreloadedLocs = nil
local BL716_PendingShortcuts = nil
local BL716_SaveBusy = false
local BL716_SaveRetryPending = false
local BL716_SaveWarningShown = false
local BL716_ObservationsSinceSave = 0
local BL716_LocalizationBusy = false
local BL716_LocalizationRunner = nil
local BL716_DeferredRefresh = false
local BL716_ShortcutGuard = false

local BL716_ZoneCodes = {
    Ag=true,An=true,Ar=true,Bf=true,Br=true,Ca=true,Cl=true,Du=true,Ef=true,En=true,
    EL=true,Er=true,Ev=true,Ew=true,Fg=true,Fo=true,GR=true,It=true,Ld=true,Le=true,
    Lh=true,La=true,Ll=true,Lo=true,Mw=true,MM=true,ND=true,Sh=true,Sw=true,Tr=true,
    TW=true,tW=true,Wf=true
}

local function BL716_Finite(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end

local function BL716_Number(value,minValue,maxValue)
    local n=tonumber(value)
    if not BL716_Finite(n) then return nil end
    if minValue and n<minValue then n=minValue end
    if maxValue and n>maxValue then n=maxValue end
    return n
end

local function BL716_SafeCount(value)
    local n=BL716_Number(value,0)
    return n or 0
end

local function BL716_Point(value)
    if type(value)~="table" then return nil end
    local x,y=BL716_Number(value.x),BL716_Number(value.y)
    if not x or not y then return nil end
    return {x=x,y=y}
end

local function BL716_SafeSave(scope,key,value)
    local ok=pcall(BL716_RawSave,scope,key,value)
    return ok
end

local function BL716_SanitizeNameCache(value)
    local out={}
    if type(value)~="table" then return out end
    for id,name in pairs(value) do
        if type(id)=="string" and type(name)=="string" and name~="" then
            out[id]=name
        end
    end
    return out
end

local function BL716_LoadPending()
    if BL716_PendingShortcuts then return BL716_PendingShortcuts end
    local pending=BL716_RawLoad(Turbine.DataScope.Character,"BL_PendingShortcuts")
    if type(pending)~="table" then pending={} end
    BL716_PendingShortcuts=pending
    return pending
end

local function BL716_SavePending()
    if not BL716_PendingShortcuts then return true end
    return BL716_SafeSave(Turbine.DataScope.Character,"BL_PendingShortcuts",BL716_PendingShortcuts)
end

function BL_ClearPendingShortcut(field)
    local pending=BL716_LoadPending()
    local changed=false
    if pending[field]~=nil then pending[field]=nil changed=true end
    if field=="kit" and pending.kitBypass~=nil then pending.kitBypass=nil changed=true end
    if changed then BL716_SavePending() end
end

local function BL716_IsShortcutUsable(value)
    if type(value)~="string" or value=="" then return false end
    local ok,usable=pcall(function()
        if not BL716_ShortcutProbe then
            BL716_ShortcutProbe=Turbine.UI.Lotro.Quickslot()
            BL716_ShortcutProbe:SetSize(1,1)
            BL716_ShortcutProbe:SetVisible(false)
        end
        BL716_ShortcutProbe:SetShortcut(Turbine.UI.Lotro.Shortcut())
        BL716_ShortcutProbe:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Item,value))
        local restored=BL716_ShortcutProbe:GetShortcut()
        if not restored or restored:GetType()~=Turbine.UI.Lotro.ShortcutType.Item then return false end
        return restored:GetData()==value
    end)
    return ok and usable==true
end

local function BL716_SanitizeOptions(value)
    if type(value)~="table" then value={} end
    value.pos1=BL716_Point(value.pos1)
    value.pos2=BL716_Point(value.pos2)
    value.iconPos=BL716_Point(value.iconPos)
    value.scale=BL716_Number(value.scale,0.5,2.0) or 1

    if type(value.auto)=="table" then
        value.auto=BL716_Point(value.auto)
    elseif type(value.auto)~="boolean" then
        value.auto=nil
    end
    if type(value.esc)~="boolean" then value.esc=nil end

    local probeVersion=BL716_Number(value.frProbeVersion,0)
    value.frProbeVersion=probeVersion
    if value.frProbeSignature~=nil and type(value.frProbeSignature)~="string" then
        value.frProbeSignature=nil
    end

    if not BL716_OptionsCaptured then
        BL716_OptionsCaptured=true
        BL716_SavedProbeVersion=value.frProbeVersion
        BL716_SavedProbeSignature=value.frProbeSignature
    end

    -- Suppress BL_Main's legacy startup probe. FR7.16 owns localization after load.
    value.frProbeVersion=3

    if value.pos1 then
        local sw,sh=Turbine.UI.Display.GetWidth(),Turbine.UI.Display.GetHeight()
        local ww=math.floor(340*value.scale+0.5)
        local wh=math.floor(275*value.scale+0.5)
        value.pos1.x=math.max(0,math.min(value.pos1.x,math.max(0,sw-ww)))
        value.pos1.y=math.max(0,math.min(value.pos1.y,math.max(0,sh-wh)))
    end
    return value
end

local function BL716_ProcessShortcutField(value,pending,field)
    local saved=value[field]
    local waiting=pending[field]

    if saved~=nil then
        if BL716_IsShortcutUsable(saved) then
            if waiting~=nil then pending[field]=nil end
            if field=="kit" and waiting~=nil then pending.kitBypass=nil end
        elseif type(saved)=="string" and saved~="" then
            pending[field]=saved
            if field=="kit" then pending.kitBypass=value.kitBypass==true and true or nil end
            value[field]=nil
            if field=="kit" then value.kitBypass=nil end
        else
            value[field]=nil
            if field=="kit" then value.kitBypass=nil end
        end
    elseif type(waiting)=="string" and waiting~="" and BL716_IsShortcutUsable(waiting) then
        value[field]=waiting
        pending[field]=nil
        if field=="kit" then
            value.kitBypass=pending.kitBypass==true and true or nil
            pending.kitBypass=nil
        end
    elseif waiting~=nil and type(waiting)~="string" then
        pending[field]=nil
        if field=="kit" then pending.kitBypass=nil end
    end
end

local function BL716_SanitizeTotals(value)
    if type(value)~="table" then value={} end
    local fp=BL716_Number(value.fp,0)
    value.fp=fp
    value.kitBypass=value.kitBypass==true and true or nil

    for id,n in pairs(value) do
        if type(id)=="string" and #id==5 then
            local count=BL716_Number(n,0)
            value[id]=count or 0
        end
    end

    local pending=BL716_LoadPending()
    BL716_ProcessShortcutField(value,pending,"kit")
    BL716_ProcessShortcutField(value,pending,"wpn")
    BL716_ProcessShortcutField(value,pending,"shl")
    BL716_SavePending()
    return value
end

local function BL716_PreflightLocs(value)
    if type(value)~="table" then
        BL716_PreloadedLocs={}
        return {}
    end
    BL716_PreloadedLocs=value

    local hasLegacy=false
    for key,t in pairs(value) do
        if not BL716_ZoneCodes[key] and type(t)=="table" and type(t.z)=="string" then
            hasLegacy=true
            break
        end
    end
    if not hasLegacy then return value end

    -- Keep modern zone entries visible to BL_Main; legacy locations are merged
    -- after BL_Data has been loaded so mixed old/new saves cannot lose data.
    local modern={}
    for key,t in pairs(value) do
        if BL716_ZoneCodes[key] and type(t)=="table" then modern[key]=t end
    end
    return modern
end

local function BL716_TransformLoad(scope,key,value)
    if key=="BL_Options" then return BL716_SanitizeOptions(value) end
    if key=="BL_Totals" then return BL716_SanitizeTotals(value) end
    if key=="BL_Locs" then return BL716_PreflightLocs(value) end
    if key=="BL_Names" then
        BL716_PreloadedNames=BL716_SanitizeNameCache(value)
        -- Let BL_FR establish the official names without a learned cache masking them.
        return {}
    end
    return value
end

Turbine.PluginData.Load=function(scope,key,callback)
    local wrapped=callback and function(data)
        callback(BL716_TransformLoad(scope,key,data))
    end or nil
    local value=BL716_RawLoad(scope,key,wrapped)
    return BL716_TransformLoad(scope,key,value)
end

local BL716_LoadOK,BL716_LoadError=pcall(function()
    import "Dusk.BirdingLog.BL_Main"
end)
Turbine.PluginData.Load=BL716_RawLoad
if not BL716_LoadOK then error(BL716_LoadError) end

-- Restore the real localization markers hidden from BL_Main during startup.
if BL_Options then
    BL_Options.frProbeVersion=BL716_SavedProbeVersion
    BL_Options.frProbeSignature=BL716_SavedProbeSignature
end

-- Mark official FR bird names before the learned cache is reapplied.
BL_FR_OfficialIDs=BL_FR_OfficialIDs or {}
if BL_Lang=="FR" then
    for id,t in pairs(BL_ID or {}) do
        if type(t)=="table" and type(t.ln)=="string" and t.ln~="" then
            BL_FR_OfficialIDs[id]=true
        end
    end
end

-- The original data file comments out the hat; activate it without changing the
-- historical tables. It is a known hobby object, not a zone reward.
if BL_GID and not BL_GID["6B900"] then
    local hatName="Birder's Hat"
    if BL_Lang=="DE" then hatName="Hut des Vogelbeobachters" end
    BL_GID["6B900"]={n=hatName,z=""}
end
if BL_Lang=="FR" and BL_GID and BL_GID["6B900"] then
    BL_GID["6B900"].ln="Chapeau d'ornithologue"
    BL_FR_OfficialIDs["6B900"]=true
end

-- Runtime-sync old German geometry and two reward zone-name case mismatches with
-- the language-neutral data used by EN/FR.
if BL_Lang=="DE" and BL_Zone then
    local geometry={
        Ar={n=-40,s=-72,e=-13,w=-47}, Bf={n=-72,s=-93.4,e=-60,w=-74},
        Ef={n=-53,s=-74,e=-53,w=-76.4}, It={n=-41,s=-77,e=-3,w=-19},
        Wf={n=-53.5,s=-66,e=-76.4,w=-91}
    }
    for zc,g in pairs(geometry) do
        local z=BL_Zone[zc]
        if z then z.n,z.s,z.e,z.w=g.n,g.s,g.e,g.w end
    end
    if BL_GID and BL_GID["6B927"] then BL_GID["6B927"].z="Das Nebelgebirge" end
    if BL_GID and BL_GID["6B92E"] then BL_GID["6B92E"].z="Die Trollhöhen" end
end

-- Reapply learned FR names only to IDs that were not supplied by BL_FR.
BL_Names=BL716_PreloadedNames or {}
if BL_Lang=="FR" then
    for id,name in pairs(BL_Names) do
        local t=BL_ID and BL_ID[id]
        if t and not BL_FR_OfficialIDs[id] and type(name)=="string" and name~="" then
            t.ln=name
        end
    end
end

BL_GNames=BL716_SanitizeNameCache(BL716_RawLoad(Turbine.DataScope.Server,"BL_GNames"))
if BL_Lang=="FR" then
    for id,name in pairs(BL_GNames) do
        local t=BL_GID and BL_GID[id]
        if t and not BL_FR_OfficialIDs[id] and type(name)=="string" and name~="" then
            t.ln=name
        end
    end
    for id,t in pairs(BL_GID or {}) do
        if type(t)=="table" and type(t.ln)=="string" and t.ln~="" and BL_GNames[id]==nil then
            BL_FR_OfficialIDs[id]=true
        end
    end
end

-- Always rebuild from scratch so stale learned aliases cannot survive a refresh.
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

-- Merge legacy location records into any modern zone records returned to BL_Main.
if type(BL_Locs)~="table" then BL_Locs={} end
if type(BL716_PreloadedLocs)=="table" then
    for key,old in pairs(BL716_PreloadedLocs) do
        if not BL716_ZoneCodes[key] and type(old)=="table" and BL_Zone and BL_Zone[old.z] then
            local target=BL_Locs[old.z]
            if type(target)~="table" then target={} BL_Locs[old.z]=target end
            for id,n in pairs(old) do
                if type(id)=="string" and #id==5 and BL_ID and BL_ID[id] then
                    target[id]=BL716_SafeCount(target[id])+BL716_SafeCount(n)
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
                if type(id)=="string" and #id==5 then
                    if BL_ID and BL_ID[id] then loc[id]=BL716_SafeCount(n) else loc[id]=nil end
                end
            end
        end
    end
end

if type(BL_Totals)~="table" then BL_Totals={} end
BL_Totals.fp=BL716_Number(BL_Totals.fp,0)
for id in pairs(BL_ID or {}) do
    if BL_Totals[id]~=nil then BL_Totals[id]=BL716_SafeCount(BL_Totals[id]) end
end
if not BL_Totals.kit then BL_Totals.kitBypass=nil end

local function BL716_ClampMainWindow()
    if not BL_window then return end
    local x,y=BL_window:GetPosition()
    local scale=(BL_Options and BL716_Number(BL_Options.scale,0.5,2.0)) or 1
    local sw,sh=Turbine.UI.Display.GetWidth(),Turbine.UI.Display.GetHeight()
    local ww=math.floor((BL_window:GetWidth() or 0)*scale+0.5)
    local wh=math.floor((BL_window:GetHeight() or 0)*scale+0.5)
    x=math.max(0,math.min(BL716_Number(x) or 0,math.max(0,sw-ww)))
    y=math.max(0,math.min(BL716_Number(y) or 0,math.max(0,sh-wh)))
    BL_window:SetPosition(x,y)
    if BL_Options then BL_Options.pos1={x=x,y=y} end
end
BL716_ClampMainWindow()

-- A normal kit must be category 104 once LOTRO resolves it. Shift-bypassed kits
-- deliberately skip this check and remain valid across reloads.
if BL_Totals.kit and not BL_Totals.kitBypass and BL_window and BL_window.kit then
    local shortcut=BL_window.kit:GetShortcut()
    local item=shortcut and shortcut:GetItem()
    local info=item and item:GetItemInfo()
    if info and info:GetCategory()~=BL_BirdingKit then
        local changed=BL_window.kit.ShortcutChanged
        BL_window.kit.ShortcutChanged=nil
        pcall(function()
            BL_window.kit:SetShortcut(Turbine.UI.Lotro.Shortcut())
            BL_window.kit:SetBackground("Dusk/BirdingLog/Kit.tga")
        end)
        BL_window.kit.ShortcutChanged=changed
        BL_Totals.kit=nil
        BL_Totals.kitBypass=nil
    end
end

local function BL716_SaveOptions()
    if type(BL_Options)~="table" then return true end
    return BL716_SafeSave(Turbine.DataScope.Server,"BL_Options",BL_Options)
end

local function BL716_SaveRuntimeData()
    if BL716_SaveBusy then
        BL716_SaveRetryPending=true
        return false
    end
    BL716_SaveBusy=true
    local ok=true
    if type(BL_Locs)=="table" then ok=BL716_SafeSave(Turbine.DataScope.Server,"BL_Locs",BL_Locs) and ok end
    if type(BL_Names)=="table" then ok=BL716_SafeSave(Turbine.DataScope.Server,"BL_Names",BL_Names) and ok end
    if type(BL_GNames)=="table" then ok=BL716_SafeSave(Turbine.DataScope.Server,"BL_GNames",BL_GNames) and ok end
    if type(BL_Totals)=="table" then ok=BL716_SafeSave(Turbine.DataScope.Character,"BL_Totals",BL_Totals) and ok end
    BL716_SaveBusy=false

    if ok then
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
    return ok
end
BL_SaveRuntimeData=BL716_SaveRuntimeData

-- Replace shortcut validation so the historical Shift bypass is persisted.
function BL_Shortcut(sender,name,iname,icat)
    local shortcut=sender:GetShortcut()
    local itemType=shortcut:GetType()
    if itemType==0 then return nil,false end
    local itemData=shortcut:GetData()
    if sender:IsAltKeyDown() then BL_Print("Type="..itemType..", "..(BL_Lang=="FR" and "Données=" or "Data=")..tostring(itemData)) end

    local function clearSlot()
        BL716_ShortcutGuard=true
        sender:SetShortcut(Turbine.UI.Lotro.Shortcut())
        BL716_ShortcutGuard=false
    end

    if itemType~=Turbine.UI.Lotro.ShortcutType.Item then
        clearSlot()
        BL_Print(BL_Lang=="FR" and (name.." réinitialisé.") or (name.." reset."))
        return nil,false
    end

    local item=shortcut:GetItem()
    if not item then
        BL_PrintE(BL_Lang=="FR" and "Objet introuvable." or "Item is null.")
        return nil,false
    end

    local bypass=sender:IsShiftKeyDown()==true
    if bypass then iname=nil icat=nil end
    if icat then
        local info=item:GetItemInfo()
        local category=info and info:GetCategory()
        if category~=icat then
            BL_PrintE(BL_Lang=="FR" and (item:GetName().." n’est pas un kit d’ornithologie valide.") or (item:GetName().." is not a valid Birding Kit."))
            clearSlot()
            return nil,false
        end
    end
    if iname and item:GetName():sub(-#iname)~=iname then
        BL_PrintE(BL_Lang=="FR" and (item:GetName().." n’est pas un objet valide pour cet emplacement.") or (item:GetName().." is not a "..iname))
        clearSlot()
        return nil,false
    end
    BL_Print(BL_Lang=="FR" and (name.." défini sur "..item:GetName()) or (name.." set to "..item:GetName()))
    return itemData,bypass
end

if BL_window then
    if BL_window.kit then
        BL_window.kit.ShortcutChanged=function(sender,args)
            if BL716_ShortcutGuard then return end
            local data,bypass=BL_Shortcut(sender,BL_Lang=="FR" and "Kit d’ornithologie" or "Birding Kit",nil,BL_BirdingKit)
            BL_Totals.kit=data
            BL_Totals.kitBypass=(data and bypass) and true or nil
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

-- The Add Bird callback is local to BL_Window; recognize only its success line.
local BL716_BasePrint=BL_Print
BL_Print=function(text)
    local result=BL716_BasePrint(text)
    if type(text)=="string" then
        local manualAdd=text:find("^Observation ajoutée : ")~=nil or
                        (text:find("^Added ")~=nil and text:find(" sighting",1,true)~=nil)
        if manualAdd then BL716_SaveRuntimeData() end
    end
    return result
end

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
        BL716_LocalizeProbe:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Item,data))
        local resolved=BL716_LocalizeProbe:GetShortcut()
        local item=resolved and resolved:GetItem()
        if not item then return nil end
        return item:GetName()
    end)
    if ok and type(name)=="string" and name~="" and name~="?" then return name end
    return nil
end

local function BL716_FinishLocalization(signature,found)
    local namesOK=BL716_SafeSave(Turbine.DataScope.Server,"BL_Names",BL_Names)
    local gNamesOK=BL716_SafeSave(Turbine.DataScope.Server,"BL_GNames",BL_GNames)
    local optionsOK=false
    if namesOK and gNamesOK and BL_Options then
        local oldVersion,oldSignature=BL_Options.frProbeVersion,BL_Options.frProbeSignature
        BL_Options.frProbeVersion=4
        BL_Options.frProbeSignature=signature
        optionsOK=BL716_SaveOptions()
        if not optionsOK then
            BL_Options.frProbeVersion=oldVersion
            BL_Options.frProbeSignature=oldSignature
        end
    end

    if BL_RebuildNameIndex then BL_RebuildNameIndex() end
    BL716_LocalizationBusy=false
    BL716_LocalizationRunner=nil

    if not (namesOK and gNamesOK and optionsOK) then
        BL_PrintE(BL_Lang=="FR" and
            "La sauvegarde de la localisation FR a échoué ; une prochaine session réessaiera." or
            "Localization save failed; a later session will retry.")
    elseif found>0 then
        BL_Print("Localisation FR : "..found.." nom(s) récupéré(s) depuis LOTRO.")
    end

    if BL716_DeferredRefresh then
        BL716_DeferredRefresh=false
        BL_AutoLocalize(true)
    end
end

function BL_IsLocalizationBusy()
    return BL716_LocalizationBusy==true
end

function BL_CancelLocalization()
    if BL716_LocalizationRunner then
        BL716_LocalizationRunner:SetWantsUpdates(false)
        BL716_LocalizationRunner=nil
    end
    BL716_LocalizationBusy=false
    BL716_DeferredRefresh=false
end

function BL_AutoLocalize(force)
    if BL_Lang~="FR" then return end
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
        local official=BL_FR_OfficialIDs and BL_FR_OfficialIDs[id]
        local missing=type(t)~="table" or not t.ln or t.ln==""
        if not official and (missing or force) then table.insert(queue,{kind="B",id=id}) end
    end
    for id,t in pairs(BL_GID or {}) do
        local official=BL_FR_OfficialIDs and BL_FR_OfficialIDs[id]
        local missing=type(t)~="table" or not t.ln or t.ln==""
        if not official and (missing or force) then table.insert(queue,{kind="G",id=id}) end
    end
    table.sort(queue,function(a,b) return a.kind==b.kind and a.id<b.id or a.kind<b.kind end)

    if #queue==0 then
        BL716_FinishLocalization(signature,0)
        return
    end

    BL716_LocalizationBusy=true
    local ix,found=1,0
    BL716_LocalizationRunner=Turbine.UI.Control()
    BL716_LocalizationRunner:SetWantsUpdates(true)
    BL716_LocalizationRunner.Update=function(sender,args)
        for n=1,8 do
            local entry=queue[ix]
            if not entry then
                sender:SetWantsUpdates(false)
                BL716_FinishLocalization(signature,found)
                return
            end
            ix=ix+1
            local t=(entry.kind=="B" and BL_ID or BL_GID)[entry.id]
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

-- Remove BL_Main's handler and install one generation-protected owner.
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
        local n=BL716_Number(fp,0)
        if n then
            local changed=BL_Totals.fp~=n
            BL_Totals.fp=n
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
        if BL_Lang=="FR" and name~="?" and not (BL_FR_OfficialIDs and BL_FR_OfficialIDs[id]) then
            if BL_Names[id]~=name then learned=true end
            BL_ID[id].ln=name
            BL_Names[id]=name
        end

        local before=BL716_SafeCount(BL_Totals[id])
        if before==0 and BL_Totals[id]==nil then
            BL_Print(BL_Lang=="FR" and "Nouveau type d'oiseau observé." or "New type of bird found.")
        end
        BL_Totals[id]=before+1
        BL_Print((BL_Lang=="FR" and "Observation : " or "Saw a ")..(BL_ID[id].ln or BL_ID[id].n)..
            (BL_Lang=="FR" and ", total=" or ", count=")..BL_Totals[id])

        if BL_LocStr then
            local loc=BL_Locs[BL_LocStr]
            if type(loc)~="table" then loc={} BL_Locs[BL_LocStr]=loc end
            loc[id]=BL716_SafeCount(loc[id])+1
        end

        BL716_ObservationsSinceSave=BL716_ObservationsSinceSave+1
        if learned or BL716_SaveRetryPending or BL716_ObservationsSinceSave>=10 then
            BL716_SaveRuntimeData()
        end
        return
    end

    if BL_GID and BL_GID[id] then
        local learned=false
        if BL_Lang=="FR" and name~="?" and not (BL_FR_OfficialIDs and BL_FR_OfficialIDs[id]) then
            if BL_GNames[id]~=name then learned=true end
            BL_GID[id].ln=name
            BL_GNames[id]=name
        end
        local isZoneReward=type(BL_GID[id].z)=="string" and BL_GID[id].z~=""
        BL_Print(BL_Lang=="FR" and
            (isZoneReward and "Récompense d'observation de la zone." or "Objet d'ornithologie reconnu.") or
            (isZoneReward and "Zone birding reward." or "Known birding item."))
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

local BL716_Zloc="^%s*(.-)%s*:%s*(.-)%s*:%s*([%d%.,]+%s*[NS])%s*,%s*([%d%.,]+%s*[EWO])%s*$"
local BL716_XLink="<Examine:IIDDID:0x0000000000000000:0x700%s>[%s]<\\Examine>"
local function BL716_LocValue(str,neg)
    local clean=tostring(str):gsub("%s",""):gsub(",",".")
    local dir=clean:sub(-1)
    local nbr=BL716_Number(clean:sub(1,-2))
    if not nbr then return nil end
    if dir==neg or (neg=="W" and dir=="O") then nbr=-nbr end
    return nbr
end

local function BL716_PrintList(list)
    local ids,total={},0
    if type(list)~="table" then list={} end
    for id,n in pairs(list) do
        if type(id)=="string" and #id==5 and BL_ID[id] and BL716_Number(n,0) then
            table.insert(ids,id)
        end
    end
    table.sort(ids,function(a,b)
        local an,bn=BL_ID[a].ln or BL_ID[a].n,BL_ID[b].ln or BL_ID[b].n
        return an==bn and a<b or an<bn
    end)
    for _,id in ipairs(ids) do
        local n=BL716_SafeCount(list[id])
        BL_Print(string.format(BL716_XLink,id,BL_ID[id].ln or BL_ID[id].n)..": "..n)
        total=total+n
    end
    BL_Print((BL_Lang=="FR" and "Nombre total d’observations : " or "Total sighting count: ")..total)
end

function BL_Command:Execute(cmd,args)
    args=tostring(args or "")
    if Dusk.Common.HelpCmd(cmd,args,BL_Help) then return end

    if cmd=="bll" then
        if args=="list" then
            if BL_LocStr and BL_Zone[BL_LocStr] then
                BL_PrintH((BL_Lang=="FR" and "Oiseaux observés dans " or "Birds sighted in ")..(BL_Zone[BL_LocStr].ln or BL_Zone[BL_LocStr].z))
                BL716_PrintList(BL_Locs[BL_LocStr])
            else BL_PrintE(BL_Lang=="FR" and "Aucune zone sélectionnée" or "No zone selected") end
            return
        end
        if args=="zone" then
            if BL_LocStr and BL_Zone[BL_LocStr] then
                local zt=BL_Zone[BL_LocStr]
                local ids,total,seen={},0,0
                for id in pairs(zt.id or {}) do table.insert(ids,id) end
                table.sort(ids,function(a,b)
                    local an,bn=BL_ID[a].ln or BL_ID[a].n,BL_ID[b].ln or BL_ID[b].n
                    return an==bn and a<b or an<bn
                end)
                BL_PrintH((BL_Lang=="FR" and "Oiseaux à observer dans " or "Birds to see in ")..(zt.ln or zt.z))
                for _,id in ipairs(ids) do
                    local n=BL716_SafeCount(BL_Totals[id])
                    BL_Print(string.format(BL716_XLink,id,BL_ID[id].ln or BL_ID[id].n)..": "..n)
                    total=total+1
                    if n>0 then seen=seen+1 end
                end
                BL_Print((BL_Lang=="FR" and "Oiseaux vus : " or "Birds seen: ")..seen.."/"..total)
            else BL_PrintE(BL_Lang=="FR" and "Aucune zone sélectionnée" or "No zone selected") end
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
        if not r then BL_PrintE((BL_Lang=="FR" and "Région inconnue : " or "Unknown region: ")..reg) return end
        if r>4 then BL_PrintE(BL_Lang=="FR" and "Aucun oiseau répertorié en Haradwaith." or "No birds found in Haradwaith.") return end
        local y1,x1=BL716_LocValue(y,"S"),BL716_LocValue(x,"W")
        if not y1 or not x1 then BL_PrintE(BL_Lang=="FR" and "Coordonnées invalides." or "Invalid coordinates.") return end

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
                    local score=math.min(math.min(z.n-y1,y1-z.s)/h,math.min(z.e-x1,x1-z.w)/w)
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
        else BL_PrintE(BL_Lang=="FR" and "Zone introuvable." or "Zone not found.") end
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
                BL_PrintH(BL_Lang=="FR" and ("En terminant la prouesse d’ornithologie de "..(BL_Zone[BL_LocStr].ln or zname).." :") or ('Upon completing the deed "All the Birds of '..zname..'",'))
                BL_Print((BL_Lang=="FR" and "Récompense : " or "You will receive: ")..string.format(BL716_XLink,id,t.ln or t.n))
                return
            end
        end
        BL_Print(BL_Lang=="FR" and ("Aucune récompense d’ornithologie connue pour "..(BL_Zone[BL_LocStr].ln or zname)) or ("No known Birding reward for "..zname))
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
    if args=="show" then BL_window:SetVisible(true) BL_window:SetZOrder(2) return end
    if args=="sight" then
        BL_PrintH(BL_Lang=="FR" and "Historique des observations :" or "Birding sighting record:")
        BL716_PrintList(BL_Totals)
        return
    end
    if args=="track" then
        BL_TrackUnknown=not BL_TrackUnknown
        BL_Print(BL_Lang=="FR" and (BL_TrackUnknown and "Suivi activé." or "Suivi désactivé.") or ((BL_TrackUnknown and "En" or "Dis").."abled Tracking."))
        return
    end
    if args=="zones" then
        BL_PrintH(BL_Lang=="FR" and "Oiseaux trouvés par zone :" or "Birds found by zone:")
        for _,zt in Sort(BL_Zone) do
            local total,seen=0,0
            for id in pairs(zt.id or {}) do
                total=total+1
                if BL716_SafeCount(BL_Totals[id])>0 then seen=seen+1 end
            end
            BL_Print((zt.ln or zt.z)..": "..seen.."/"..total)
        end
        return
    end
    if args=="" then
        local fp=BL716_Number(BL_Totals.fp,0)
        if not fp then BL_Print(BL_Lang=="FR" and "Maîtrise d’ornithologie inconnue." or "Unknown Birding proficiency.") return end
        local title,best="",0
        for p in pairs(BL_Title or {}) do
            if fp>=p and p>best then best=p end
        end
        if best>0 then title=", "..((BL_Lang=="FR" and BL_TitleFR and BL_TitleFR[best]) or BL_Title[best]) end
        BL_Print((BL_Lang=="FR" and "Maîtrise d’ornithologie : " or "Birding proficiency is ")..fp..title)
        return
    end

    local n,bird=args:match("^%s*(%d+)%s+(.+.-)%s*$")
    if n and bird then
        n=BL716_Number(n,0)
        if not n then BL_PrintE(BL_Lang=="FR" and "Nombre d’observations invalide." or "Invalid sighting count.") return end
        local matches={}
        for id,t in pairs(BL_ID) do if t.n==bird or t.ln==bird then table.insert(matches,id) end end
        if #matches>1 and BL_LocStr and BL_Zone[BL_LocStr] then
            local inZone={}
            for _,id in ipairs(matches) do if BL_Zone[BL_LocStr].id[id] then table.insert(inZone,id) end end
            if #inZone==1 then matches=inZone end
        end
        if #matches==0 then
            BL_PrintE(BL_Lang=="FR" and ("Oiseau '"..bird.."' introuvable") or ("Bird '"..bird.."' not found"))
            return
        elseif #matches>1 then
            BL_PrintE(BL_Lang=="FR" and ("Nom d’oiseau ambigu : "..bird..". Sélectionnez sa zone ou utilisez son nom anglais exact.") or ("Ambiguous bird name: "..bird..". Select its zone or use the exact English name."))
            return
        end
        local id=matches[1]
        local places={}
        for _,zc in ipairs(BL_ID[id].f or {}) do table.insert(places,BL_Zone[zc].ln or BL_Zone[zc].z) end
        BL_Print(BL_Lang=="FR" and (bird.." se trouve dans : "..table.concat(places,", ")) or ("The "..bird.." is found in "..table.concat(places,", ")))
        BL_Totals[id]=n
        BL_Print((BL_Lang=="FR" and "Total d’observations réglé sur " or "Total sightings set to ")..n)
        BL716_SaveRuntimeData()
        return
    end
    BL_PrintE((BL_Lang=="FR" and "Commande inconnue : " or "Unknown command, ")..args)
end

-- One clean initial persistence pass records migration/sanitization before a crash.
BL716_SaveRuntimeData()
BL716_SaveOptions()
if BL_Lang=="FR" then BL_AutoLocalize(false) end

Plugins.BirdingLog.Unload=function(sender,args)
    if BL716_ChatGeneration==BL_ChatGeneration then BL_ChatGeneration=BL_ChatGeneration+1 end
    BL_CancelLocalization()
    BL_TrackHover=false

    if BL_window and BL_Options then
        local x,y=BL_window:GetPosition()
        BL_Options.pos1={x=math.floor((BL716_Number(x) or 0)+0.5),y=math.floor((BL716_Number(y) or 0)+0.5)}
    end
    if BL_SaveIconPosition then pcall(BL_SaveIconPosition) end
    BL716_SaveRuntimeData()
    BL716_SaveOptions()
    BL716_SavePending()

    if Turbine.Chat.Received==BL716_ChatHandler then Turbine.Chat.Received=BL716_PreviousChat end
    BL_ChatHandler=nil
    BL_PreviousChatHandler=BL716_PreviousChat
    if BL_Print==nil or BL_Print~=BL716_BasePrint then BL_Print=BL716_BasePrint end
    if BL_window then BL_window:SetVisible(false) end
    if BL_IconWindow then BL_IconWindow:SetVisible(false) end
    pcall(function() Turbine.Shell.RemoveCommand(BL_Command) end)

    BL716_BasePrint(BL_Lang=="FR" and "Carnet d’ornithologie enregistré." or "Birding record saved.")
end
