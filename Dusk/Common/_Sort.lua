-- Common Sort function for plugins by David Down
-- coding: utf-8

function Sort(tbl,func)
    local ix = {}
    for key in pairs(tbl) do
        table.insert(ix,key)
    end
    table.sort(ix,func)
    return ix
end
