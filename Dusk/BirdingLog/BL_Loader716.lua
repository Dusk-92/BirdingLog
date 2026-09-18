-- BirdingLog FR7.27 consolidated loader.
-- One active entry point: sanitize persistent data, construct the UI/core once,
-- then hand all runtime ownership to BL_Runtime716.

import "Turbine.UI.Lotro"
import "Dusk.Common"

BL_ConsolidatedRuntime=true

BL716 = {
    NativeLoad = Turbine.PluginData.Load,
    NativeSave = Turbine.PluginData.Save,
    RawLoad = (Dusk.Common and Dusk.Common.PluginDataLoad) or Turbine.PluginData.Load,
    RawLoadChecked = Dusk.Common and Dusk.Common.PluginDataLoadChecked,
    RawSave = (Dusk.Common and Dusk.Common.PluginDataSave) or Turbine.PluginData.Save,
    LoadFailures = {},
    ShortcutProbe = nil,
    OptionsCaptured = false,
    SavedProbeVersion = nil,
    SavedProbeSignature = nil,
    PreloadedNames = {},
    PreloadedLocs = nil,
    PendingShortcuts = nil,
}
local S = BL716

function S.Load(scope,key,callback)
    if type(S.RawLoadChecked)=="function" then
        local value,ok,err=S.RawLoadChecked(scope,key,callback)
        if ok==false then S.LoadFailures[key]=tostring(err or "load failed") end
        return value
    end
    local ok,value=pcall(S.RawLoad,scope,key,callback)
    if not ok then
        S.LoadFailures[key]=tostring(value)
        return nil
    end
    return value
end

function S.MarkLoadFailure(key,message)
    if not S.LoadFailures[key] then
        S.LoadFailures[key]=tostring(message or "load failed")
    end
end

function S.ValidateTableRoot(key,value)
    if value~=nil and type(value)~="table" then
        S.MarkLoadFailure(key,"invalid root type: "..type(value))
        return {}
    end
    return value
end

function S.PairShortcutStateFailures()
    local totalError=S.LoadFailures["BL_Totals"]
    local pendingError=S.LoadFailures["BL_PendingShortcuts"]
    if totalError or pendingError then
        S.MarkLoadFailure("BL_Totals",pendingError and "paired shortcut state unavailable" or totalError)
        S.MarkLoadFailure("BL_PendingShortcuts",totalError and "paired shortcut state unavailable" or pendingError)
    end
end

function S.Finite(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end

function S.Number(value,minValue,maxValue)
    local n=tonumber(value)
    if not S.Finite(n) then return nil end
    if minValue and n<minValue then n=minValue end
    if maxValue and n>maxValue then n=maxValue end
    return n
end

function S.Integer(value,minValue,maxValue)
    local n=S.Number(value,minValue,maxValue)
    if not n then return nil end
    return math.floor(n)
end

function S.SafeCount(value)
    return S.Integer(value,0) or 0
end

function S.Point(value)
    if type(value)~="table" then return nil end
    local x,y=S.Number(value.x),S.Number(value.y)
    if not x or not y then return nil end
    return {x=x,y=y}
end

function S.SanitizeNameCache(value)
    local out={}
    if type(value)~="table" then return out end
    for id,name in pairs(value) do
        if type(id)=="string" and #id==5 and type(name)=="string" and name~="" then
            out[id]=name
        end
    end
    return out
end

function S.LoadPendingShortcuts()
    if S.PendingShortcuts then return S.PendingShortcuts end
    local pending=S.Load(Turbine.DataScope.Character,"BL_PendingShortcuts")
    pending=S.ValidateTableRoot("BL_PendingShortcuts",pending)
    if type(pending)~="table" then pending={} end
    pending.kitBypass=nil
    S.PendingShortcuts=pending
    S.PairShortcutStateFailures()
    return pending
end

function S.IsShortcutUsable(value)
    if type(value)~="string" or value=="" then return false end
    local ok,usable=pcall(function()
        if not S.ShortcutProbe then
            S.ShortcutProbe=Turbine.UI.Lotro.Quickslot()
            S.ShortcutProbe:SetSize(1,1)
            S.ShortcutProbe:SetVisible(false)
        end
        S.ShortcutProbe:SetShortcut(Turbine.UI.Lotro.Shortcut())
        S.ShortcutProbe:SetShortcut(
            Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Item,value)
        )
        local restored=S.ShortcutProbe:GetShortcut()
        if not restored or restored:GetType()~=Turbine.UI.Lotro.ShortcutType.Item then
            return false
        end
        local data=restored:GetData()
        return type(data)=="string" and data~="" and data==value
    end)
    return ok and usable==true
end

local function SanitizeOptions(value)
    if type(value)~="table" then value={} end

    value.pos1=S.Point(value.pos1)
    value.pos2=S.Point(value.pos2)
    value.iconPos=S.Point(value.iconPos)
    value.scale=S.Number(value.scale,0.5,2.0) or 1

    if type(value.auto)=="table" then
        value.auto=S.Point(value.auto)
    elseif type(value.auto)~="boolean" then
        value.auto=nil
    end
    if type(value.esc)~="boolean" then value.esc=nil end

    if value.frProbeVersion~=nil then
        value.frProbeVersion=S.Number(value.frProbeVersion,0)
    end
    if value.frProbeSignature~=nil and type(value.frProbeSignature)~="string" then
        value.frProbeSignature=nil
    end

    if not S.OptionsCaptured then
        S.OptionsCaptured=true
        S.SavedProbeVersion=value.frProbeVersion
        S.SavedProbeSignature=value.frProbeSignature
    end

    -- BL_Main owns the historical probe. Hide its marker only while BL_Main loads,
    -- so that old asynchronous controls never start. The consolidated runtime
    -- restores the marker afterwards and owns localization from that point forward.
    value.frProbeVersion=3

    if value.pos1 then
        local sw,sh=Turbine.UI.Display.GetWidth(),Turbine.UI.Display.GetHeight()
        local ww=math.floor(360*value.scale+0.5)
        local wh=math.floor(295*value.scale+0.5)
        value.pos1.x=math.max(0,math.min(value.pos1.x,math.max(0,sw-ww)))
        value.pos1.y=math.max(0,math.min(value.pos1.y,math.max(0,sh-wh)))
    end
    return value
end

local function ProcessShortcutField(value,pending,field)
    local saved=value[field]
    local waiting=pending[field]

    if saved==false then
        if type(waiting)=="string" and waiting~="" and S.IsShortcutUsable(waiting) then
            value[field]=waiting
            pending[field]=nil
        elseif waiting==nil then
            value[field]=nil
        elseif type(waiting)~="string" or waiting=="" then
            pending[field]=nil
            value[field]=nil
        end
        return
    end

    if saved==nil then
        if waiting~=nil then pending[field]=nil end
        return
    end

    if S.IsShortcutUsable(saved) then
        if waiting~=nil then pending[field]=nil end
        return
    end

    if type(saved)=="string" and saved~="" then
        pending[field]=saved
        value[field]=false
    else
        value[field]=nil
        if waiting~=nil then pending[field]=nil end
    end
end

local function SanitizeTotals(value)
    if type(value)~="table" then value={} end

    value.fp=S.Integer(value.fp,0)
    value.kitBypass=nil

    for id,n in pairs(value) do
        if type(id)=="string" and #id==5 then
            local count=S.Number(n,0)
            value[id]=count or 0
        end
    end

    local pending=S.LoadPendingShortcuts()
    ProcessShortcutField(value,pending,"kit")
    ProcessShortcutField(value,pending,"wpn")
    ProcessShortcutField(value,pending,"shl")
    S.PairShortcutStateFailures()
    return value
end

local function PreflightLocs(value)
    if type(value)~="table" then
        S.PreloadedLocs={}
        return {}
    end
    S.PreloadedLocs=value

    local hasLegacy=false
    for _,entry in pairs(value) do
        if type(entry)=="table" and type(entry.z)=="string" then
            hasLegacy=true
            break
        end
    end
    if not hasLegacy then return value end

    -- A legacy entry has its target zone stored in entry.z. Keep every other
    -- entry visible to BL_Main, including future zone codes unknown to this fork.
    -- The omitted legacy records are merged after BL_Data has been imported.
    local modern={}
    for key,entry in pairs(value) do
        if not (type(entry)=="table" and type(entry.z)=="string") then
            modern[key]=entry
        end
    end
    return modern
end

local function TransformLoad(scope,key,value)
    if key=="BL_Options" or key=="BL_Totals" or key=="BL_Locs" or key=="BL_Names" then
        value=S.ValidateTableRoot(key,value)
    end
    if key=="BL_Options" then return SanitizeOptions(value) end
    if key=="BL_Totals" then return SanitizeTotals(value) end
    if key=="BL_Locs" then return PreflightLocs(value) end
    if key=="BL_Names" then
        S.PreloadedNames=S.SanitizeNameCache(value)
        -- Official BL_FR names must win over learned cache entries.
        return {}
    end
    return value
end

Turbine.PluginData.Load=function(scope,key,callback)
    local wrapped=callback and function(data)
        callback(TransformLoad(scope,key,data))
    end or nil
    local value=S.Load(scope,key,wrapped)
    return TransformLoad(scope,key,value)
end

local mainOK,mainError=pcall(function()
    import "Dusk.BirdingLog.BL_Main"
end)
Turbine.PluginData.Load=S.NativeLoad
if not mainOK then
    pcall(function() if BL_AutoFRRunner then BL_AutoFRRunner:SetWantsUpdates(false) end end)
    pcall(function()
        if BL_window then
            BL_window:SetWantsKeyEvents(false)
            BL_window:SetWantsUpdates(false)
            BL_window:SetVisible(false)
        end
    end)
    pcall(function() if BL_IconWindow then BL_IconWindow:SetVisible(false) end end)
    pcall(function()
        if BL_ChatHandler and Turbine.Chat.Received==BL_ChatHandler then
            Turbine.Chat.Received=BL_PreviousChatHandler
        end
    end)
    pcall(function() if BL_Command then Turbine.Shell.RemoveCommand(BL_Command) end end)
    error(mainError)
end

if BL_Options then
    BL_Options.frProbeVersion=S.SavedProbeVersion
    BL_Options.frProbeSignature=S.SavedProbeSignature
end

local runtimeOK,runtimeError=pcall(function()
    import "Dusk.BirdingLog.BL_Runtime716"
end)
if not runtimeOK then
    -- BL_Main has already created UI/chat/shell objects. If the modern runtime
    -- fails to import, unwind those side effects before surfacing the error.
    pcall(function()
        if Turbine.Chat.Received==BL_ChatHandler then
            Turbine.Chat.Received=BL_PreviousChatHandler
        end
    end)
    pcall(function() if BL_Command then Turbine.Shell.RemoveCommand(BL_Command) end end)
    pcall(function()
        if BL_window then
            BL_window:SetWantsKeyEvents(false)
            BL_window:SetWantsUpdates(false)
            BL_window:SetVisible(false)
        end
    end)
    pcall(function() if BL_IconWindow then BL_IconWindow:SetVisible(false) end end)
    error(runtimeError)
end
