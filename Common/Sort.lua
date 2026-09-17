-- Common Sort function for plugins by David Down.

function _G.Sort( tbl, sort, ix )
	local Keys = { }

	-- Generate a temp table of keys.
	for key in pairs( tbl ) do
		table.insert(Keys, key)
	end

	-- Sort the keys.
	table.sort( Keys, sort )
    if ix then return Keys end

	-- Return an iterator to step over sorted keys
	local ix = 0
	return function()
		ix = ix + 1
		local key = Keys[ix]
		if key then return key,tbl[key] end
	end
end
