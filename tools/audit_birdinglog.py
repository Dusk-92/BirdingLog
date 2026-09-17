#!/usr/bin/env python3
"""Static invariants for the Dusk-92 BirdingLog fork.

This intentionally avoids pretending to emulate Turbine/LOTRO. It catches the
repository-level regressions that are deterministic and reviewable in CI.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"ERROR: {message}")
    raise SystemExit(1)


def uncommented(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def section(text: str, start: str, end: str) -> str:
    a = text.find(start)
    b = text.find(end, a + len(start))
    if a < 0 or b < 0:
        fail(f"cannot find section {start!r} .. {end!r}")
    return text[a:b]


def zone_codes(text: str) -> set[str]:
    z = section(text, "BL_Zone = {", "BL_Zname,BL_Zlist")
    return set(re.findall(r"\['([^']+)'\]\s*=\s*\{z=", z))


def bird_ids(text: str) -> set[str]:
    b = section(text, "BL_ID = {", "BL_Bname = {}")
    return set(re.findall(r'\["([0-9A-F]{5})"\]\s*=\s*\{n=', uncommented(b)))


def gid_ids(text: str) -> set[str]:
    g = section(text, "BL_GID = {", "BL_ID = {")
    return set(re.findall(r'\["([0-9A-F]{5})"\]\s*=\s*\{n=', uncommented(g)))


def bird_zone_refs(text: str) -> set[str]:
    b = section(text, "BL_ID = {", "BL_Bname = {}")
    refs: set[str] = set()
    for found in re.findall(r"f=\{([^}]*)\}", uncommented(b)):
        refs.update(re.findall(r"'([^']+)'", found))
    return refs


def fr_ids(text: str) -> set[str]:
    names = section(text, "local NamesFR = {", "for id,name in pairs(NamesFR)")
    return set(re.findall(r'\["([0-9A-F]{5})"\]\s*=', names))


plugin = read("Dusk/BirdingLog.plugin")
readme = read("README.md")
changelog = read("CHANGELOG.md")
updates = read("Dusk/BirdingLog/Updates.txt")
loader = read("Dusk/BirdingLog/BL_Loader716.lua")
data_en = read("Dusk/BirdingLog/BL_Data.lua")
data_de = read("Dusk/BirdingLog/BL_Data_DE.lua")
fr = read("Dusk/BirdingLog/BL_FR.lua")
common_init = read("Dusk/Common/__init__.lua")
common_options = read("Dusk/Common/Options.lua")

m = re.search(r"<Version>([^<]+)</Version>", plugin)
if not m:
    fail("plugin version missing")
version = m.group(1)
if f"Version du fork : **{version}**" not in readme:
    fail("README version does not match plugin")
if f"## {version} —" not in changelog:
    fail("CHANGELOG latest version does not match plugin")
if not updates.startswith(f"09/17/26 {version}\t"):
    fail("Updates.txt first entry does not match plugin")
if "<Package>Dusk.BirdingLog.BL_Loader716</Package>" not in plugin:
    fail("FR7.16 consolidated loader is not the plugin entrypoint")

required_loader_tokens = [
    'import "Dusk.BirdingLog.BL_Main"',
    'BL_PendingShortcuts',
    'BL_FR_OfficialIDs',
    'function BL_IsLocalizationBusy()',
    'BL_SaveRuntimeData=BL716_SaveRuntimeData',
    'Turbine.Shell.RemoveCommand(BL_Command)',
    'return "BL716|"',
]
for token in required_loader_tokens:
    if token not in loader:
        fail(f"consolidated loader invariant missing: {token}")
if 'import "Dusk.BirdingLog.BL_Loader"' in loader or 'import "Dusk.BirdingLog.BL_Loader712"' in loader:
    fail("consolidated loader must not stack legacy compatibility loaders")

zen, zde = zone_codes(data_en), zone_codes(data_de)
ben, bde = bird_ids(data_en), bird_ids(data_de)
gen, gde = gid_ids(data_en), gid_ids(data_de)
if zen != zde:
    fail(f"EN/DE zone-code sets differ: EN-only={sorted(zen-zde)}, DE-only={sorted(zde-zen)}")
if ben != bde:
    fail(f"EN/DE bird-ID sets differ: EN-only={sorted(ben-bde)}, DE-only={sorted(bde-ben)}")
if gen != gde:
    fail(f"EN/DE active GID sets differ: EN-only={sorted(gen-gde)}, DE-only={sorted(gde-gen)}")
if len(ben) != 470:
    fail(f"expected 470 bird IDs, found {len(ben)}")

bad_refs = bird_zone_refs(data_en) - zen
if bad_refs:
    fail(f"bird data references unknown zones: {sorted(bad_refs)}")

fr_known = fr_ids(fr)
missing_fr_birds = ben - fr_known
if missing_fr_birds:
    fail(f"official FR table misses bird IDs: {sorted(missing_fr_birds)}")
missing_fr_objects = gen - fr_known
if missing_fr_objects:
    fail(f"official FR table misses active hobby/reward IDs: {sorted(missing_fr_objects)}")
if "6B900" not in fr_known or 'BL_GID["6B900"]' not in loader:
    fail("Birder's Hat must stay covered by FR data and FR7.16 runtime activation")

if "loadstring(" in common_init or "loadstring(" in loader:
    fail("unsafe loadstring() reintroduced")
if "local function SafeSave" not in common_options or "local function ClampWindow" not in common_options:
    fail("shared options lost safe-save or display-clamp hardening")

print(f"BirdingLog audit OK — {version}, {len(ben)} birds, {len(gen)} active source GIDs + runtime hat")
