-- BirdingLog FR7.17 kit compatibility override.
-- LOTRO currently reports the Basic Birding Kit with an item category that does
-- not match the historical BL_BirdingKit=104 constant. FR7.17 therefore treats
-- the kit slot like a normal Item Quickslot and never rejects a kit by category.

import "Turbine.UI.Lotro"

local BL717_ItemType = Turbine.UI.Lotro.ShortcutType.Item
local BL717_Shortcut = Turbine.UI.Lotro.Shortcut
local BL717_KitGuard = false

local function BL717_ClearKit(sender)
    BL717_KitGuard=true
    pcall(function()
        sender:SetShortcut(BL717_Shortcut())
        sender:SetBackground("Dusk/BirdingLog/Kit.tga")
    end)
    BL717_KitGuard=false
end

local function BL717_ReadKit(sender)
    local shortcut=sender and sender:GetShortcut()
    if not shortcut then return nil end

    local itemType=shortcut:GetType()
    if itemType==0 then return nil end
    if itemType~=BL717_ItemType then
        BL717_ClearKit(sender)
        BL_Print(BL_Lang=="FR" and "Kit d’ornithologie réinitialisé." or "Birding Kit reset.")
        return nil
    end

    local itemData=shortcut:GetData()
    if type(itemData)~="string" or itemData=="" then
        BL717_ClearKit(sender)
        BL_PrintE(BL_Lang=="FR" and "Données de raccourci invalides." or "Invalid shortcut data.")
        return nil
    end

    local item=shortcut:GetItem()
    local itemName=item and item:GetName()
    if type(itemName)=="string" and itemName~="" then
        BL_Print(BL_Lang=="FR" and
            ("Kit d’ornithologie défini sur "..itemName) or
            ("Birding Kit set to "..itemName))
    else
        BL_Print(BL_Lang=="FR" and
            "Kit d’ornithologie enregistré ; résolution de l’objet différée." or
            "Birding Kit saved; item resolution deferred.")
    end

    return itemData
end

-- Runtime716 uses kitBypass only to skip its legacy category-104 validation.
-- In FR7.17 every valid Item shortcut in the kit slot must use that path.
if BL_Totals and type(BL_Totals.kit)=="string" and BL_Totals.kit~="" then
    BL_Totals.kitBypass=true
end

if BL_window and BL_window.kit then
    BL_window.kit.ShortcutChanged=function(sender,args)
        if BL717_KitGuard then return end

        local data=BL717_ReadKit(sender)
        BL_Totals.kit=data
        BL_Totals.kitBypass=data and true or nil

        if BL_ClearPendingShortcut then BL_ClearPendingShortcut("kit") end
        if BL_SaveRuntimeData then BL_SaveRuntimeData() end
    end
end
