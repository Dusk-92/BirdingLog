-- BirdingLog FR7.14 compatibility patch.
-- File name kept as BL_Loader712 to avoid another loader layer. Loaded before
-- FR7.11 so legacy shortcut data and window coordinates can be validated before
-- BL_Main creates any Turbine UI controls.

import "Turbine.UI.Lotro"
import "Dusk.Common"

local BL712_RawLoad = Turbine.PluginData.Load
local BL712_ShortcutProbe = nil
local BL714_UnresolvedKitData = nil
local BL714_DeferredRefresh = nil
local BL714_BypassProbeWait = false
local BL714_SaveWarningShown = false

local function BL712_Clamp(value,minValue,maxValue)
    local n=tonumber(value)
    if not n then return nil end
    if minValue and n<minValue then n=minValue end
    if maxValue and n>maxValue then n=maxValue end
    return n
end

-- Validate not only thrown errors but also Turbine's silent shortcut rejection.
-- For the birding kit, a shortcut that Turbine accepts but cannot resolve yet is
-- preserved; only a resolved item with the wrong category is rejected.
local function BL713_ValidateShortcutData(value,expectedCategory)
    if type(value)~="string" or value=="" then return nil,false end

    local ok,accepted,unresolved=pcall(function()
        if not BL712_ShortcutProbe then
            BL712_ShortcutProbe=Turbine.UI.Lotro.Quickslot()
            BL712_ShortcutProbe:SetSize(1,1)
            BL712_ShortcutProbe:SetVisible(false)
        end

        BL712_ShortcutProbe:SetShortcut(Turbine.UI.Lotro.Shortcut())
        local shortcut=Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Item,value)
        BL712_ShortcutProbe:SetShortcut(shortcut)

        local resolved=BL712_ShortcutProbe:GetShortcut()
        if not resolved or resolved:GetType()~=Turbine.UI.Lotro.ShortcutType.Item then
            return false,false
        end

        local resolvedData=resolved:GetData()
        if type(resolvedData)~="string" or resolvedData=="" or resolvedData~=value then
            return false,false
        end

        if expectedCategory~=nil then
            local item=resolved:GetItem()
            local info=item and item:GetItemInfo()
            if not info then
                return true,true
            end
            if info:GetCategory()~=expectedCategory then
                return false,false
            end
        end

        return true,false
    end)

    if not ok or not accepted then return nil,false end
    return value,unresolved==true
end

local function BL712_PreClampOptions(value)
    if type(value)~="table" then return value end
    local pos=value.pos1
    if type(pos)~="table" then return value end

    local x,y=tonumber(pos.x),tonumber(pos.y)
    if not x or not y then return value end

    local scale=BL712_Clamp(value.scale,0.5,2.0) or 1
    local sw,sh=Turbine.UI.Display.GetWidth(),Turbine.UI.Display.GetHeight()
    local ww=math.floor(340*scale+0.5)
    local wh=math.floor(275*scale+0.5)
    local maxX=math.max(0,sw-ww)
    local maxY=math.max(0,sh-wh)
    value.pos1={x=math.max(0,math.min(x,maxX)),y=math.max(0,math.min(y,maxY))}
    return value
end

Turbine.PluginData.Load=function(scope,key,callback)
    local value=BL712_RawLoad(scope,key,callback)
    if key=="BL_Options" then
        return BL712_PreClampOptions(value)
    end
    if key=="BL_Totals" and type(value)=="table" then
        local kit,kitUnresolved=BL713_ValidateShortcutData(value.kit,BL_BirdingKit)
        if kit and kitUnresolved then
            -- Keep the data out of BL_Main/FR7.11 while the item is unresolved.
            -- It will be restored quietly after those loaders finish.
            BL714_UnresolvedKitData=kit
            value.kit=nil
        else
            BL714_UnresolvedKitData=nil
            value.kit=kit
        end
        value.wpn=BL713_ValidateShortcutData(value.wpn)
        value.shl=BL713_ValidateShortcutData(value.shl)
    end
    return value
end

local BL712_LoadOK,BL712_LoadError=pcall(function()
    import "Dusk.BirdingLog.BL_Loader"
end)
Turbine.PluginData.Load=BL712_RawLoad
if not BL712_LoadOK then error(BL712_LoadError) end

-- Restore a prevalidated but unresolved kit without firing the historical
-- ShortcutChanged callback. Revalidate once more in case LOTRO resolved it while
-- the rest of the plugin was loading; a newly resolved wrong category is rejected.
if BL714_UnresolvedKitData and BL_Totals and BL_window and BL_window.kit then
    local control=BL_window.kit
    local previousChanged=control.ShortcutChanged
    control.ShortcutChanged=nil

    local valid=false
    local ok=pcall(function()
        local shortcut=Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Item,BL714_UnresolvedKitData)
        control:SetShortcut(shortcut)
        local resolved=control:GetShortcut()
        if not resolved or resolved:GetType()~=Turbine.UI.Lotro.ShortcutType.Item then return end
        if resolved:GetData()~=BL714_UnresolvedKitData then return end

        local item=resolved:GetItem()
        local info=item and item:GetItemInfo()
        if info and info:GetCategory()~=BL_BirdingKit then return end
        valid=true
    end)

    if not ok or not valid then
        pcall(function()
            control:SetShortcut(Turbine.UI.Lotro.Shortcut())
            control:SetBackground("Dusk/BirdingLog/Kit.tga")
        end)
    end

    control.ShortcutChanged=previousChanged
    BL_Totals.kit=(ok and valid) and BL714_UnresolvedKitData or nil
    BL714_UnresolvedKitData=nil
end

-- /bl fr must really refresh names learned dynamically. If a previous automatic
-- bird-name probe is still finishing, defer the manual refresh until that pass
-- completes instead of silently losing the user's request.
local BL712_PreviousAutoLocalize=BL_AutoLocalize
local function BL714_ScheduleDeferredRefresh()
    if BL714_DeferredRefresh then return end

    BL_Print(BL_Lang=="FR" and
        "Localisation FR déjà en cours ; le rafraîchissement manuel sera relancé juste après." or
        "Localization already in progress; the manual refresh will run afterwards.")

    local frames=0
    BL714_DeferredRefresh=Turbine.UI.Control()
    BL714_DeferredRefresh:SetWantsUpdates(true)
    BL714_DeferredRefresh.Update=function(sender,args)
        frames=frames+1
        local finished=BL_Options and BL_Options.frProbeVersion==3
        if finished or frames>=240 then
            sender:SetWantsUpdates(false)
            BL714_DeferredRefresh=nil
            if not finished then BL714_BypassProbeWait=true end
            BL_AutoLocalize(true)
        end
    end
end

if type(BL712_PreviousAutoLocalize)=="function" then
    BL_AutoLocalize=function(force)
        if not force or BL_Lang~="FR" then
            return BL712_PreviousAutoLocalize(force)
        end

        if not BL714_BypassProbeWait and BL_Options and BL_Options.frProbeVersion~=3 then
            BL714_ScheduleDeferredRefresh()
            return
        end
        BL714_BypassProbeWait=false

        local restoreBirds,restoreGIDs={},{}

        for id,t in pairs(BL_ID or {}) do
            local cached=BL_Names and BL_Names[id]
            if type(cached)=="string" and cached~="" and
               type(t)=="table" and t.ln==cached then
                restoreBirds[id]=cached
                t.ln=nil
            end
        end

        for id,t in pairs(BL_GID or {}) do
            local cached=BL_GNames and BL_GNames[id]
            if type(cached)=="string" and cached~="" and
               type(t)=="table" and t.ln==cached then
                restoreGIDs[id]=cached
                t.ln=nil
            end
        end

        local ok,result=pcall(BL712_PreviousAutoLocalize,true)

        -- The underlying probes build their queues synchronously before returning.
        -- Restore previous learned names now; successful probes will overwrite them.
        for id,name in pairs(restoreBirds) do
            local t=BL_ID and BL_ID[id]
            if t and (not t.ln or t.ln=="") then t.ln=name end
        end
        for id,name in pairs(restoreGIDs) do
            local t=BL_GID and BL_GID[id]
            if t and (not t.ln or t.ln=="") then t.ln=name end
        end

        if not ok then error(result) end
        return result
    end
end

local BL712_SaveBusy=false
local BL712_ObservationsSinceSave=0
local function BL712_SaveRuntimeData()
    if BL712_SaveBusy then return false end
    BL712_SaveBusy=true
    local ok=pcall(function()
        if type(BL_Locs)=="table" then
            Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_Locs",BL_Locs)
        end
        if type(BL_Names)=="table" then
            Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_Names",BL_Names)
        end
        if type(BL_GNames)=="table" then
            Turbine.PluginData.Save(Turbine.DataScope.Server,"BL_GNames",BL_GNames)
        end
        if type(BL_Totals)=="table" then
            Turbine.PluginData.Save(Turbine.DataScope.Character,"BL_Totals",BL_Totals)
        end
    end)
    BL712_SaveBusy=false

    if ok then
        BL712_ObservationsSinceSave=0
        BL714_SaveWarningShown=false
    elseif not BL714_SaveWarningShown then
        BL714_SaveWarningShown=true
        pcall(function()
            BL_PrintE(BL_Lang=="FR" and
                "La sauvegarde automatique a échoué ; BirdingLog réessaiera au prochain changement." or
                "Automatic save failed; BirdingLog will retry on the next change.")
        end)
    end
    return ok
end

-- Persist manual UI additions/count edits immediately without rewriting the
-- original BL_Window local callbacks.
local BL712_BasePrint=BL_Print
local function BL712_Print(text)
    local result=BL712_BasePrint(text)
    if type(text)=="string" then
        local manualAdd=text:find("^Observation ajoutée : ")~=nil or
                        (text:find("^Added ")~=nil and text:find(" sighting",1,true)~=nil)
        local manualCount=text:find("^Total d’observations réglé sur ")~=nil or
                          text:find("^Total sightings set to ")~=nil
        if manualAdd or manualCount then BL712_SaveRuntimeData() end
    end
    return result
end
BL_Print=BL712_Print

-- Save equipment changes immediately, matching the crash-loss protection already
-- used by FishingLog.
local function BL712_WrapShortcut(control)
    if not control or type(control.ShortcutChanged)~="function" then return end
    local previous=control.ShortcutChanged
    control.ShortcutChanged=function(sender,args)
        local result=previous(sender,args)
        BL712_SaveRuntimeData()
        return result
    end
end
if BL_window then
    BL712_WrapShortcut(BL_window.kit)
    BL712_WrapShortcut(BL_window.weapon)
    BL712_WrapShortcut(BL_window.shield)
end

-- Autosave every ten recognised observations. Proficiency changes and newly
-- learned dynamic names are rare and are persisted immediately.
local BL712_BaseChat=Turbine.Chat.Received
local BL712_BaseBLHandler=BL_ChatHandler
local BL712_BaseBLPrevious=BL_PreviousChatHandler
BL712_ChatGeneration=(BL712_ChatGeneration or 0)+1
local BL712_Generation=BL712_ChatGeneration
local BL712_XPat="<Examine:IIDDID:0x0%x+:0x700(%x+)>%[(.-)%]<\\Examine>"

local function BL712_MessageID(msg)
    if type(msg)~="string" then return nil end
    local id=msg:match(BL712_XPat)
    if not id and Dusk and Dusk.Common and Dusk.Common.EII_ID then
        id=Dusk.Common.EII_ID(msg)
    end
    return id
end

local function BL712_ChatHandler(sender,args)
    if BL712_Generation~=BL712_ChatGeneration then
        if BL712_BaseChat then return BL712_BaseChat(sender,args) end
        return
    end

    local beforeFP=BL_Totals and BL_Totals.fp
    local itemID,birdID,rewardID,beforeCount,beforeBirdName,beforeRewardName
    if args and args.ChatType==Turbine.ChatType.SelfLoot then
        itemID=BL712_MessageID(args.Message)
        if itemID and BL_ID and BL_ID[itemID] then
            birdID=itemID
            beforeCount=tonumber(BL_Totals and BL_Totals[birdID]) or 0
            beforeBirdName=BL_Names and BL_Names[birdID]
        elseif itemID and BL_GID and BL_GID[itemID] then
            rewardID=itemID
            beforeRewardName=BL_GNames and BL_GNames[rewardID]
        end
    end

    local result
    if BL712_BaseChat then result=BL712_BaseChat(sender,args) end

    local learnedName=false
    if birdID and BL_Names and BL_Names[birdID]~=beforeBirdName then learnedName=true end
    if rewardID and BL_GNames and BL_GNames[rewardID]~=beforeRewardName then learnedName=true end

    local afterFP=BL_Totals and BL_Totals.fp
    local importantChange=learnedName or afterFP~=beforeFP
    if importantChange then BL712_SaveRuntimeData() end

    if birdID then
        local afterCount=tonumber(BL_Totals and BL_Totals[birdID]) or 0
        if afterCount>beforeCount and not importantChange then
            BL712_ObservationsSinceSave=BL712_ObservationsSinceSave+1
            if BL712_ObservationsSinceSave>=10 then
                BL712_SaveRuntimeData()
            end
        end
    end

    return result
end

BL_PreviousChatHandler=BL712_BaseChat
BL_ChatHandler=BL712_ChatHandler
Turbine.Chat.Received=BL712_ChatHandler

-- Persist any sanitation performed during startup once, so bad legacy shortcut
-- data does not return after a crash before normal unload.
BL712_SaveRuntimeData()

local BL712_OldUnload=Plugins.BirdingLog.Unload
Plugins.BirdingLog.Unload=function(sender,args)
    if BL712_Generation==BL712_ChatGeneration then
        BL712_ChatGeneration=BL712_ChatGeneration+1
    end
    if BL714_DeferredRefresh then
        BL714_DeferredRefresh:SetWantsUpdates(false)
        BL714_DeferredRefresh=nil
    end
    BL712_SaveRuntimeData()

    if Turbine.Chat.Received==BL712_ChatHandler then
        Turbine.Chat.Received=BL712_BaseChat
    end
    BL_ChatHandler=BL712_BaseBLHandler
    BL_PreviousChatHandler=BL712_BaseBLPrevious
    if BL_Print==BL712_Print then BL_Print=BL712_BasePrint end

    return BL712_OldUnload(sender,args)
end
