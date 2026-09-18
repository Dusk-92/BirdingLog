import "Dusk.Common.Class"
import "Dusk.Common.Sort"
import "Dusk.Common.Type"

-- Plugin-local persistence helpers.
--
-- Older Dusk/Common revisions replaced Turbine.PluginData.Load/Save globally on
-- French/German clients. Because BirdingLog, FishingLog and TravelRef can share
-- the same Lua apartment, that made persistence depend on plugin load order and
-- could double-encode TravelRef saves. Keep the workaround local instead.
local NativeLoad = Turbine.PluginData.Load
local NativeSave = Turbine.PluginData.Save
local LocalizedPluginData =
    Turbine.Shell.IsCommand("aide") or Turbine.Shell.IsCommand("zusatzmodule")

local function ExportTable(obj)
    if type(obj) == "number" then
        return "#" .. string.gsub(tostring(obj), ",", ".")
    elseif type(obj) == "string" then
        return "$" .. obj
    elseif type(obj) == "table" then
        local out = {}
        for k,v in pairs(obj) do
            out[ExportTable(k)] = ExportTable(v)
        end
        return out
    end
    return obj
end

local function ImportNumber(text)
    local value = tonumber(text)
    if value ~= nil then return value end
    value = tonumber((string.gsub(text, "%.", ",")))
    if value ~= nil then return value end
    value = tonumber((string.gsub(text, ",", ".")))
    if value ~= nil then return value end
    return "#" .. text
end

local function ImportOnce(obj)
    if type(obj) == "string" then
        local prefix = string.sub(obj,1,1)
        if prefix == "$" then
            return string.sub(obj,2)
        elseif prefix == "#" then
            return ImportNumber(string.sub(obj,2))
        end
        return obj
    elseif type(obj) == "table" then
        local out = {}
        for k,v in pairs(obj) do
            local dk = ImportOnce(k)
            if dk ~= nil then out[dk] = ImportOnce(v) end
        end
        return out
    end
    return obj
end

local function LooksEncoded(value)
    if type(value) == "string" then
        local p = string.sub(value,1,1)
        return p == "$" or p == "#"
    end
    if type(value) ~= "table" then return false end

    local saw = false
    for k in pairs(value) do
        if type(k) == "string" then
            local p = string.sub(k,1,1)
            if p ~= "$" and p ~= "#" then return false end
            saw = true
        elseif type(k) == "number" then
            -- A raw numeric key proves this table is no longer an encoded layer.
            return false
        end
    end
    return saw
end

local function DecodeLegacy(value)
    -- Old load-order interactions could encode the same table twice. Peel a few
    -- complete marker layers; stop as soon as the root no longer looks encoded.
    local current = value
    for _=1,4 do
        if not LooksEncoded(current) then break end
        current = ImportOnce(current)
    end
    return current
end

function PluginDataLoadChecked(dataScope,key,dataLoadEventHandler)
    local wrapped
    if dataLoadEventHandler then
        wrapped = function(data)
            local ok,decoded = pcall(DecodeLegacy,data)
            dataLoadEventHandler(ok and decoded or data)
        end
    end

    local ok,diskData = pcall(NativeLoad,dataScope,key,wrapped)
    if not ok then return nil,false,diskData end

    local decodedOK,decoded = pcall(DecodeLegacy,diskData)
    if not decodedOK then return diskData,false,decoded end
    return decoded,true,nil
end

function PluginDataLoad(dataScope,key,dataLoadEventHandler)
    local data = PluginDataLoadChecked(dataScope,key,dataLoadEventHandler)
    return data
end

function PluginDataSave(dataScope,key,data,saveCompleteEventHandler)
    local payload = LocalizedPluginData and ExportTable(data) or data
    return NativeSave(dataScope,key,payload,saveCompleteEventHandler)
end

function PluginDataDecodeLegacy(value)
    return DecodeLegacy(value)
end
