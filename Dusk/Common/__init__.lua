import "Dusk.Common.Class"
import "Dusk.Common.Sort"
import "Dusk.Common.Type"

if Turbine.Shell.IsCommand("aide") or
    Turbine.Shell.IsCommand("zusatzmodule") then -- French or German?

    -- Prepares a table for saving. Workaround for Turbine.PluginData.Save() bug.
    local function ExportTable(obj)
        if type(obj) == "number" then
            local text = tostring(obj)
            -- Store floating-point numbers with a locale-independent decimal point.
            return "#" .. string.gsub(text, ",", ".")
        elseif type(obj) == "string" then
            return "$" .. obj
        elseif type(obj) == "table" then
            local newTable = {}
            for i,v in pairs(obj) do
                newTable[ExportTable(i)] = ExportTable(v)
            end
            return newTable
        else
            return obj
        end
    end

    -- Decode a saved number without executing save-file text as Lua code.
    -- LOTRO clients may use either '.' or ',' as their decimal separator.
    local function ImportNumber(text)
        local value = tonumber(text)
        if value ~= nil then return value end

        value = tonumber((string.gsub(text, "\u0025.", ",")))
        if value ~= nil then return value end

        -- Corrupt/unknown numeric data is kept as text rather than throwing.
        return "#" .. text
    end

    -- Prepares a loaded table for use. Workaround for Turbine.PluginData.Save() bug.
    local function ImportTable(obj)
        if type(obj) == "string" then
            local prefix = string.sub(obj,1,1)
            if prefix == "$" then
                return string.sub(obj,2)
            elseif prefix == "#" then
                return ImportNumber(string.sub(obj,2))
            else
                return obj
            end
        elseif type(obj) == "table" then
            local newTable = {}
            for i,v in pairs(obj) do
                local key = ImportTable(i)
                if key ~= nil then newTable[key] = ImportTable(v) end
            end
            return newTable
        else
            return obj
        end
    end

    -- Replace the built-in PluginData.Load function with a wrapper that reformats the data.
    local RawLoad = Turbine.PluginData.Load
    function Turbine.PluginData.Load(dataScope,key,dataLoadEventHandler)
        local success,diskData = pcall(RawLoad,dataScope,key,dataLoadEventHandler and function(data)
            local ok,imported = pcall(ImportTable,data)
            dataLoadEventHandler(ok and imported or data)
        end)
        if success and diskData then
            local ok,imported = pcall(ImportTable,diskData)
            if ok then return imported end
            return diskData
        end
    end

    -- Replace the built-in PluginData.Save function with a wrapper that reformats the data.
    local RawSave = Turbine.PluginData.Save
    function Turbine.PluginData.Save(dataScope,key,data,saveCompleteEventHandler)
        return RawSave(dataScope,key,ExportTable(data),saveCompleteEventHandler)
    end
end
