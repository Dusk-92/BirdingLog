-- Birding Log by David Down
-- FR7.22: construction/data/UI only; BL_Runtime716 owns runtime behavior.

import "Turbine"
import "Turbine.Gameplay"
import "Turbine.UI.Lotro"
import "Dusk.Common.EII_ID"
import "Dusk.Common.Sort"

local language = Turbine.Engine.GetLanguage()
if language == Turbine.Language.French then
    BL_Lang = "FR"
    import "Dusk.BirdingLog.BL_Data"
    import "Dusk.BirdingLog.BL_FR"
elseif language == Turbine.Language.German then
    BL_Lang = "DE"
    import "Dusk.BirdingLog.BL_Data_DE"
else
    BL_Lang = "EN"
    import "Dusk.BirdingLog.BL_Data"
end

function BL_Print(text)
    Turbine.Shell.WriteLine("<rgb=#00FFFF>BL:</rgb> "..tostring(text))
end
function BL_PrintH(text)
    BL_Print("<rgb=#00FF00>"..tostring(text).."</rgb>")
end
function BL_PrintE(text)
    BL_Print("<rgb=#FF6040>"..(BL_Lang=="FR" and "Erreur : " or "Error: ")..tostring(text).."</rgb>")
end

import "Dusk.Common.Help"

BL_LocStr = false
BL_TrackUnknown = false
BL_TrackHover = false

BL_Options = Turbine.PluginData.Load(Turbine.DataScope.Server,"BL_Options")
if type(BL_Options) ~= "table" then BL_Options = {} end

-- Preflight hides learned names while BL_FR loads so official embedded names win.
BL_Names = Turbine.PluginData.Load(Turbine.DataScope.Server,"BL_Names")
if type(BL_Names) ~= "table" then BL_Names = {} end

BL_Locs = Turbine.PluginData.Load(Turbine.DataScope.Server,"BL_Locs")
if type(BL_Locs) ~= "table" then BL_Locs = {} end

BL_Totals = Turbine.PluginData.Load(Turbine.DataScope.Character,"BL_Totals")
if type(BL_Totals) ~= "table" then
    BL_Totals = {}
    BL_Print(BL_Lang=="FR" and "Nouveau carnet d’ornithologie créé." or "Created new birding record")
end

import "Dusk.BirdingLog.BL_Window"
import "Dusk.BirdingLog.BL_Icon"

local BL_VersionText = "Birding Log "..Plugins["BirdingLog"]:GetVersion()
BL_PrintH(BL_VersionText..(BL_Lang=="FR" and ", données chargées." or ", data loaded."))

BL_Command = Turbine.ShellCommand()
function BL_Command:GetShortHelp()
    return Dusk.Common.Help(BL_Help,"??")
end
function BL_Command:GetHelp()
    return Dusk.Common.Help(BL_Help,"help")
end

Plugins.BirdingLog.Open = function(sender,args)
    if BL_window then
        BL_window:SetVisible(true)
        BL_window:SetZOrder(2)
    end
end

import "Dusk.Common.Options"
if not BL_Options.scale then BL_Options.scale = 1 end
BL_OP = Dusk.Common.Options_Init(BL_Print,BL_Options,BL_window,"BL_Options")

BL_Help = {
    pre = "bl",
    arg = {
        [""] = "Display personal birding details.",
        [" "] = "Display birding proficiency.",
        ["# <name>"] = "Set count for <name> to #.",
        sight = "List birding sighting records.",
        track = "Toggle unknown bird tracking.",
        fr = "Refresh French names from LOTRO.",
        zones = "List birding zones and counts.",
    },
    cmd = {
        bll = {
            [" "] = "Birding location commands.",
            [BL_Loc] = "Set the current birding zone.",
            list = "List sightings in the current zone.",
            zone = "List all birds and sightings in the zone.",
        },
        blg = "Show birding garment for selected zone.",
        blw = "Open Birding Log window.",
    },
}

if BL_Lang=="FR" then
    BL_Help = {
        pre = "bl",
        arg = {
            [""] = "Afficher les informations personnelles d’ornithologie.",
            [" "] = "Afficher la maîtrise d’ornithologie.",
            ["# <nom>"] = "Définir manuellement le nombre d’observations de <nom>.",
            sight = "Afficher l’historique des observations.",
            track = "Activer/désactiver le suivi des oiseaux inconnus.",
            fr = "Relancer la localisation automatique française.",
            zones = "Afficher les zones et leur progression.",
        },
        cmd = {
            bll = {
                [" "] = "Commandes liées à la zone d’ornithologie.",
                [BL_Loc] = "Détecter/définir la zone actuelle.",
                list = "Lister les observations de la zone actuelle.",
                zone = "Lister tous les oiseaux de la zone et leur progression.",
            },
            blg = "Afficher la récompense d’ornithologie de la zone.",
            blw = "Ouvrir le Carnet d’ornithologie.",
        },
    }
end
