
import "Dusk.Common.Class"
import "Dusk.Common.Sort"
import "Dusk.Common.Type"

if Turbine.Shell.IsCommand("aide") or 
	Turbine.Shell.IsCommand("zusatzmodule") then -- Frenc or German?
	
	-- Prepares a table for saving.  Workaround for Turbine.PluginData.Save() bug.
	local function ExportTable(obj)
	    if (type(obj) == "number") then
	        local text = tostring(obj);
	        -- Change floating-point numbers to English format
	        return "#" .. string.gsub(text, ",", ".");
	    elseif (type(obj) == "string") then
	        return "$" .. obj;
	    elseif (type(obj) == "table") then
	        local newTable = {};
	        for i, v in pairs(obj) do
	            newTable[ExportTable(i)] = ExportTable(v);
	        end
	        return newTable;
	    else
	        return obj;
	    end
	end
	
	-- Prepares a loaded table for use.  Workaround for Turbine.PluginData.Save() bug.
	local function ImportTable(obj)
	    if (type(obj) == "string") then
	        local prefix = string.sub(obj, 1, 1);
	        if (prefix == "$") then
	            return string.sub(obj, 2);
	        elseif (prefix == "#") then
	            -- need to run it through interpreter, since tonumber() may only accept ","
	            return loadstring("return " .. string.sub(obj, 2))();
	        else -- shouldn't happen
	            return obj;
	        end
	    elseif (type(obj) == "table") then
	        local newTable = {};
	        for i, v in pairs(obj) do
	            newTable[ImportTable(i)] = ImportTable(v);
	        end
	        return newTable;
	    else
	        return obj;
	    end
	end
	
	-- Replace the built-in PluginData.Load function with a wrapper that reformats the data.
	local RawLoad = Turbine.PluginData.Load;
	function Turbine.PluginData.Load(dataScope, key, dataLoadEventHandler)
	    local success, diskData = pcall(RawLoad, dataScope, key, dataLoadEventHandler and function(diskData) 
	        dataLoadEventHandler(ImportTable(diskData)) 
	    end);
	    if (success and diskData) then
	        return ImportTable(diskData);
	    end
	end
	
	-- Replace the built-in PluginData.Save function with a wrapper that reformats the data.
	local RawSave = Turbine.PluginData.Save;
	function Turbine.PluginData.Save(dataScope, key, data, saveCompleteEventHandler)
	    return RawSave(dataScope, key, ExportTable(data), saveCompleteEventHandler);
	end
	
end
