#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []


def read(path: str) -> str:
    p = ROOT / path
    try:
        return p.read_text(encoding="utf-8")
    except Exception as exc:
        errors.append(f"cannot read {path}: {exc}")
        return ""


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def active_lines(text: str) -> str:
    # Data tables use whole-line -- comments for disabled entries. Keeping inline
    # comments is harmless for the simple structural regexes below.
    return "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("--"))


plugin = read("Dusk/BirdingLog.plugin")
readme = read("README.md")
updates = read("Dusk/BirdingLog/Updates.txt")
changelog = read("CHANGELOG.md")
loader716 = read("Dusk/BirdingLog/BL_Loader716.lua")
legacy_loader = read("Dusk/BirdingLog/BL_Loader.lua")
main = read("Dusk/BirdingLog/BL_Main.lua")
runtime716 = read("Dusk/BirdingLog/BL_Runtime716.lua")
window = read("Dusk/BirdingLog/BL_Window.lua")
deeds = read("Dusk/BirdingLog/BL_Deeds.lua")
area_resolver = read("Dusk/BirdingLog/BL_AreaResolver.lua")
workflow = read(".github/workflows/audit.yml")
common = read("Dusk/Common/__init__.lua")
icon = read("Dusk/BirdingLog/BL_Icon.lua")
data_en = active_lines(read("Dusk/BirdingLog/BL_Data.lua"))
data_de = active_lines(read("Dusk/BirdingLog/BL_Data_DE.lua"))
data_fr = active_lines(read("Dusk/BirdingLog/BL_FR.lua"))

version_match = re.search(r"<Version>([^<]+)</Version>", plugin)
package_match = re.search(r"<Package>([^<]+)</Package>", plugin)
require(version_match is not None, "plugin version is missing")
require(package_match is not None, "plugin package is missing")
version = version_match.group(1).strip() if version_match else ""
package = package_match.group(1).strip() if package_match else ""
fr_match = re.search(r"FR7\.(\d+)$", version)
fr_revision = int(fr_match.group(1)) if fr_match else 0

require(f"**{version}**" in readme, f"README version does not match {version}")
require(readme.count("# BirdingLog FR") == 1,
        "README contains a duplicated/pasted BirdingLog document")
require(readme.count("## Installation") == 1 and readme.count("## Commandes principales") == 1,
        "README contains duplicated top-level sections")
first_update = next((line for line in updates.splitlines() if line.strip()), "")
require(version in first_update, f"Updates.txt first entry does not match {version}")
require(f"## {version} " in changelog or f"## {version} —" in changelog,
        f"CHANGELOG has no section for {version}")

package_path = ROOT / (package.replace(".", "/") + ".lua") if package else None
require(bool(package_path and package_path.exists()), f"plugin package target does not exist: {package}")

# FR7.16+ keeps BL_Loader716 as the single plugin entry point. Later runtime
# compatibility fixes may be imported from that loader, but the old loader stack
# must never become active again.
if fr_revision >= 16:
    require(package == "Dusk.BirdingLog.BL_Loader716",
            "FR7.16+ must use BL_Loader716 as its only plugin entry point")

require('import "Dusk.BirdingLog.BL_Main"' in loader716,
        "BL_Loader716 must import BL_Main directly")
require('import "Dusk.BirdingLog.BL_Runtime716"' in loader716,
        "BL_Loader716 must hand off to BL_Runtime716")
require('import "Dusk.BirdingLog.BL_Loader"' not in loader716 and
        'import "Dusk.BirdingLog.BL_Loader712"' not in loader716,
        "BL_Loader716 must not stack an older compatibility loader")

for needle, description in [
    ("BL_PendingShortcuts", "pending shortcut recovery"),
    ("saved==false", "explicit pending-shortcut sentinel"),
    ("BL716_SaveOne", "callback-based PluginData saves"),
    ("BL716_SaveBatch", "batched save result tracking"),
    ("BL_FR_OfficialIDs={}", "fresh official-name index"),
    ('BL_GID["6B900"]', "known Birder's Hat registration"),
    ("BL_CancelLocalization", "localization cancellation"),
    ("Turbine.Shell.RemoveCommand(BL_Command)", "shell-command cleanup"),
    ("BL716_ProbeLocalizedItemName", "single localization probe owner"),
    ('return "BL716|"', "FR7.16 localization signature"),
]:
    require(needle in (loader716 + "\n" + runtime716),
            f"FR7.16 runtime is missing {description}")

require("GIDFrames" not in runtime716,
        "FR7.16 must not reintroduce frame-count localization busy estimation")

if fr_revision >= 17:
    require('import "Dusk.BirdingLog.BL_Runtime717"' not in loader716,
            "kit compatibility must stay consolidated in BL_Runtime716")
    require('BL_Shortcut(sender,BL_Lang=="FR" and "Kit d’ornithologie" or "Birding Kit")' in runtime716,
            "active kit handler must accept a normal Item shortcut without category 104")

if fr_revision >= 18:
    require("BL_IconWindow:SetZOrder(0)" in icon,
            "FR7.18+ launcher must stay on the normal LOTRO UI layer")
    require("BL_IconWindow:SetZOrder(1000)" not in icon,
            "FR7.18+ must not restore the always-on-top launcher layer")

if fr_revision >= 19:
    require("function BL_Window:RefreshProficiency()" in window,
            "FR7.19+ main window lost its Birding proficiency refresh method")
    require("Ornithologie : niveau " in window and "Birding: level " in window,
            "FR7.19+ main window lost localized proficiency text")
    require("pairs(BL_Title or {})" in window,
            "FR7.19+ proficiency display no longer resolves the highest Birding title")
    require("self:SetWantsUpdates( true )" not in window,
            "proficiency display must not poll every frame")
    require("BL_window:RefreshProficiency()" in runtime716,
            "proficiency display must refresh directly when the advancement value changes")

if fr_revision >= 21:
    require('Apartment="BirdingLog"' in plugin,
            "FR7.21+ must use an isolated Lua apartment")
    require("PluginDataLoadChecked" in common and "PluginDataSave" in common,
            "FR7.21+ common persistence helpers are missing")
    require("function Turbine.PluginData.Load" not in common and
            "function Turbine.PluginData.Save" not in common,
            "FR7.21+ must not monkeypatch Turbine.PluginData globally")
    require("math.floor(360*value.scale+0.5)" in loader716 and
            "math.floor(295*value.scale+0.5)" in loader716,
            "preflight window bounds must match the 360x295 FR7.20 layout")
    require('if type(BL_SaveRuntimeData)=="function" then BL_SaveRuntimeData() end' in window,
            "manual Add Bird action must save directly instead of depending on printed text")
    require("BL_TitleFR" in window,
            "French proficiency display must use BL_TitleFR")

if fr_revision >= 22:
    require("Turbine.Engine.GetLanguage()" in main,
            "FR7.22+ must detect the LOTRO client language through Engine.GetLanguage")
    require("Turbine.Shell.IsCommand" not in main,
            "FR7.22+ main must not infer the client language from localized shell commands")
    require("Turbine.Chat.Received" not in main,
            "FR7.22+ BL_Main must not own a chat handler")
    require("Turbine.Shell.AddCommand" not in main,
            "FR7.22+ BL_Main must not register shell commands")
    require("Plugins.BirdingLog.Unload" not in main,
            "FR7.22+ BL_Main must not own unload")
    require("Turbine.Shell.AddCommand" in runtime716 and
            "BL716_CommandRegistered" in runtime716,
            "FR7.22+ runtime must own command registration and cleanup")
    require("ShortcutChanged" not in window,
            "FR7.22+ window constructor must not own Quickslot handlers")
    require("kitBypass" not in runtime716,
            "FR7.22+ runtime must not retain obsolete kitBypass state")
    require("S.PairShortcutStateFailures()" in loader716 and
            'S.MarkLoadFailure("BL_Totals"' in loader716 and
            'S.MarkLoadFailure("BL_PendingShortcuts"' in loader716,
            "FR7.22+ must protect totals and pending shortcuts as one recovery group")
    require("invalid root type:" in loader716 and "S.ValidateTableRoot" in loader716,
            "FR7.22+ must quarantine structurally invalid PluginData roots")
    require("return math.floor(n)" in loader716,
            "FR7.22+ counters must normalize to non-negative integers")
    require("Turbine.PluginData.Load(" not in icon and
            "Turbine.PluginData.Save(" not in icon and
            "PluginDataLoadChecked" in icon and "PluginDataSave" in icon,
            "FR7.22+ icon persistence must use protected local helpers")
    require("VisibleChanged" in window and "SetWantsKeyEvents(sender:IsVisible())" in window,
            "FR7.22+ key events must follow main-window visibility")
    for title in [
        "Amateur d'oiseaux", "Oiseleur", "Fauvette acharnée",
        "Connaisseur d’ailes", "Dompteur d’oiseaux",
    ]:
        require(title in data_fr, f"FR7.22+ missing current FR Birding title: {title}")
    require((ROOT / "tools/test_persistence.lua").exists(),
            "FR7.22+ persistence regression test is missing")

if fr_revision >= 23:
    require('import "Dusk.BirdingLog.BL_Deeds"' in main,
            "FR7.23+ main must load the deed-progress window")
    require('listzones="Prouesses"' in window and "BL_OpenDeeds" in window,
            "FR7.23+ main window lost the Prouesses button")
    require('if args=="deeds" then' in runtime716 and
            'args:match("^deed%s+(.+)$")' in runtime716,
            "FR7.23+ runtime lost the deed commands")
    require("function BL_DeedsWindow:ShowSummary()" in deeds and
            "function BL_DeedsWindow:ShowZone(code)" in deeds and
            "BL_DeedsZoneProgress" in deeds,
            "FR7.23+ deed progress UI is incomplete")
    require("BL_DeedsReward" in deeds and "reward.ln or reward.n" in deeds,
            "FR7.23+ deed detail must expose known zone rewards")

if fr_revision >= 24:
    require('import "Dusk.Common.noAccent"' in runtime716,
            "FR7.24+ runtime must normalize learned area names safely")
    require('"BL_AreaAliases"' in runtime716 and "BL716_AreaAliases" in runtime716,
            "FR7.24+ learned sub-area persistence is missing")
    require("function BL_LearnCurrentArea(code)" in runtime716 and
            'type(BL_LearnCurrentArea)=="function"' in window,
            "FR7.24+ manual sub-area teaching is missing")
    require("BL716_LearnAreaFromBird" in runtime716 and
            "BL716_ZoneMatchesRegion" in runtime716 and "BL716_AreaKey" in runtime716,
            "FR7.24+ automatic/region-scoped sub-area learning is missing")
    require("Lieu non reconnu pour l’instant." in runtime716,
            "FR7.24+ unknown-area guidance is missing")
    require("Zone introuvable." not in runtime716,
            "FR7.24+ must not show the obsolete hard failure for unknown sub-areas")

if fr_revision >= 25:
    require('import "Dusk.BirdingLog.BL_AreaResolver"' in runtime716,
            "FR7.25+ runtime must use the isolated area resolver")
    for needle in [
        "function R.New(", "function R.Buffer(", "function R.AddEvidence(",
        "function R.Remember(", "function R.ForgetCurrent(", "function R.GetTeachable(",
    ]:
        require(needle in area_resolver, f"FR7.25+ area resolver missing {needle}")
    require("BL716_AreaTTL=300" in runtime716 and "Turbine.Engine.GetGameTime" in runtime716,
            "FR7.25+ area learning must expire using game time")
    require("BL716_FlushBufferedSightings" in runtime716 and
            "BL_AreaResolver.Buffer" in runtime716,
            "FR7.25+ must buffer and flush unknown-area sightings")
    require("function BL_ForgetCurrentArea()" in runtime716 and
            'if args=="area forget" then' in runtime716,
            "FR7.25+ learned aliases must be forgettable")
    require("S.Integer(fp,0,200)" in runtime716 and "n>=current" in runtime716,
            "FR7.25+ Birding proficiency parsing must be bounded and non-decreasing")
    require("not (BL_Options and BL_Options.esc)" in deeds,
            "FR7.25+ deeds window must respect Ignore Esc")
    require("Non renseignée dans BirdingLog" in deeds,
            "FR7.25+ deeds UI must not claim an undocumented reward does not exist")
    require((ROOT / "tools/test_area_resolver.lua").exists(),
            "FR7.25+ area resolver regression test is missing")
    require("lua5.1 tools/test_area_resolver.lua" in workflow,
            "FR7.25+ CI must execute area resolver regression tests")

if fr_revision >= 26:
    require('Dusk.Common.Options_Init(BL_Print,BL_Options,BL_window,"BL_Options")' in main,
            "FR7.26+ Prouesses must stay independent from main-window scaling")
    require('Dusk.Common.Options_Init(BL_Print,BL_Options,BL_window,"BL_Options",BL_deedsWindow)' not in main,
            "FR7.26+ must not route Prouesses through Window2 scaling")
    require("BL_deedsWindow:SetScale" not in deeds and "BL_Options.pos2" not in deeds,
            "FR7.26+ Prouesses must use the proven autonomous FR7.24 opening path")
    require("BL_Options.pos2" not in runtime716,
            "FR7.26+ runtime must not persist the retired Prouesses pos2 state")
    require("pcall(BL_OpenDeeds)" in window and
            'BL_Command:Execute("bl","zones")' in window,
            "FR7.26+ Prouesses button must have a safe chat fallback")

if fr_revision >= 27:
    active_runtime = main + "\n" + window + "\n" + runtime716
    require("BL_TrackHover" not in active_runtime,
            "FR7.27+ must not restore hover-based unknown-item tracking")
    require('if name:sub(-5)=="Frame" then return end' not in runtime716,
            "FR7.27+ must not special-case English Frame loot")
    require("BL_TrackUnknown or BL_TrackHover" not in legacy_loader,
            "FR7.27+ legacy loader must not restore hover-based unknown-item tracking")
    require('if BL_TrackUnknown then' in runtime716,
            "FR7.27+ unknown-item diagnostics must be gated only by /bl track")
    require('"Objet inconnu : "' in runtime716 and '"Unknown item: "' in runtime716,
            "FR7.27+ diagnostic output must identify unknown loot as items")
    require('track = "Toggle unknown-item diagnostic tracking."' in main and
            'track = "Activer/désactiver le diagnostic des objets inconnus."' in main,
            "FR7.27+ help text must describe /bl track as unknown-item diagnostics")

# Security regression guard: PluginData decoding must never execute save text.
for lua_path in ROOT.rglob("*.lua"):
    text = lua_path.read_text(encoding="utf-8")
    require("loadstring(" not in text,
            f"unsafe loadstring() returned in {lua_path.relative_to(ROOT)}")

zone_re = re.compile(r"\['([^']+)'\]\s*=\s*\{z\s*=")
bird_re = re.compile(r'\["([0-9A-F]{5})"\]\s*=\s*\{n\s*=.*?f\s*=\s*\{([^}]*)\}', re.S)
gid_section_re = re.compile(r"BL_GID\s*=\s*\{(.*?)\n\s*\}\s*\n\s*BL_ID\s*=", re.S)
gid_id_re = re.compile(r'\["([0-9A-F]{5})"\]\s*=\s*\{n\s*=')
quoted_re = re.compile(r"['\"]([^'\"]+)['\"]")


zone_geometry_re = re.compile(
    r"\['([^']+)'\]\s*=\s*\{z\s*=\s*\"([^\"]+)\",\s*r\s*=\s*([0-9]+),"
    r"\s*n\s*=\s*(-?[0-9.]+),\s*s\s*=\s*(-?[0-9.]+),"
    r"\s*e\s*=\s*(-?[0-9.]+),\s*w\s*=\s*(-?[0-9.]+)"
)
gid_row_re = re.compile(
    r'\["([0-9A-F]{5})"\]\s*=\s*\{n\s*=\s*"[^"]*",z\s*=\s*"([^"]*)"\}'
)


def parse_zones(text: str):
    return set(zone_re.findall(text))


def parse_zone_geometry(text: str):
    out = {}
    for code, name, region, north, south, east, west in zone_geometry_re.findall(text):
        out[code] = (int(region), float(north), float(south), float(east), float(west))
    return out


def parse_zone_names(text: str):
    return {name for _, name, *_ in zone_geometry_re.findall(text)}


def parse_gid_rows(text: str):
    match = gid_section_re.search(text)
    if not match:
        return []
    return gid_row_re.findall(match.group(1))


def parse_birds(text: str):
    birds = {}
    for bird_id, refs_text in bird_re.findall(text):
        refs = quoted_re.findall(refs_text)
        if bird_id in birds:
            errors.append(f"duplicate bird ID {bird_id}")
        birds[bird_id] = refs
    return birds


def parse_gids(text: str):
    match = gid_section_re.search(text)
    if not match:
        errors.append("could not parse BL_GID section")
        return set()
    return set(gid_id_re.findall(match.group(1)))


zones_en = parse_zones(data_en)
zones_de = parse_zones(data_de)
geometry_en = parse_zone_geometry(data_en)
geometry_de = parse_zone_geometry(data_de)
birds_en = parse_birds(data_en)
birds_de = parse_birds(data_de)
gids_en = parse_gids(data_en)
gids_de = parse_gids(data_de)

require(bool(zones_en), "no EN zones parsed")
require(bool(birds_en), "no EN bird IDs parsed")
require(bool(gids_en), "no EN GID IDs parsed")
require(zones_en == zones_de,
        f"EN/DE zone-code sets differ: EN-only={sorted(zones_en-zones_de)}, DE-only={sorted(zones_de-zones_en)}")
require(geometry_en == geometry_de,
        "EN/DE zone geometry differs; runtime patches must not be required")
for lang, text in [("EN", data_en), ("DE", data_de)]:
    zone_names = parse_zone_names(text)
    for gid, zone_name in parse_gid_rows(text):
        if zone_name:
            require(zone_name in zone_names,
                    f"{lang} GID {gid} references non-canonical zone name {zone_name!r}")
require(set(birds_en) == set(birds_de),
        f"EN/DE bird-ID sets differ: EN-only={sorted(set(birds_en)-set(birds_de))}, DE-only={sorted(set(birds_de)-set(birds_en))}")
require(gids_en == gids_de,
        f"EN/DE GID sets differ: EN-only={sorted(gids_en-gids_de)}, DE-only={sorted(gids_de-gids_en)}")

for lang, birds, zones in [("EN", birds_en, zones_en), ("DE", birds_de, zones_de)]:
    zone_bird_counts = {zone: 0 for zone in zones}
    for bird_id, refs in birds.items():
        for zone in refs:
            require(zone in zones, f"{lang} bird {bird_id} references missing zone {zone}")
        for zone in set(refs):
            if zone in zone_bird_counts:
                zone_bird_counts[zone] += 1
    for zone, count in sorted(zone_bird_counts.items()):
        require(count == 16, f"{lang} zone {zone} has {count} birds instead of 16")

# Every current bird must have an embedded official FR name. This intentionally
# fails when SSG adds a bird until the FR table is updated, instead of silently
# shipping a partially translated database.
fr_ids = set(re.findall(r'\["([0-9A-F]{5})"\]\s*=\s*"', data_fr))
missing_fr = sorted(set(birds_en) - fr_ids)
require(not missing_fr, f"missing embedded FR bird names: {missing_fr}")
missing_fr_gids = sorted(gids_en - fr_ids)
require(not missing_fr_gids, f"missing embedded FR hobby/reward names: {missing_fr_gids}")
require("6B900" in fr_ids, "Birder's Hat FR name 6B900 is missing")

zone_fr_match = re.search(r"local\s+ZoneFR\s*=\s*\{(.*?)\n\}", data_fr, re.S)
fr_zone_codes = set(re.findall(r"\b([A-Za-z][A-Za-z])\s*=", zone_fr_match.group(1))) if zone_fr_match else set()
require(zones_en <= fr_zone_codes,
        f"missing FR zone labels: {sorted(zones_en-fr_zone_codes)}")

if errors:
    print("BirdingLog audit FAILED:")
    for err in errors:
        print(f" - {err}")
    sys.exit(1)

print(f"BirdingLog audit OK — {version}")
print(
    f"Zones: {len(zones_en)} | Birds: {len(birds_en)} | "
    f"Source GIDs: {len(gids_en)} | Embedded FR IDs: {len(fr_ids)}"
)
