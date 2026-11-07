"""Validate and bundle the CartoRig Atomic Inspector Lab Fusion template.

For release engineering/CI only; Resolve users install the output .drfx by double-click.
This is deliberately not a cartographic renderer or location search engine.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
NAME = "CartoRig Atomic - Inspector Lab.setting"
SOURCE = ROOT / "experiments" / "inspector-lab" / NAME
PACKAGE_ENTRY = f"Fusion/Templates/Edit/Generators/CartoRig Atomic/{NAME}"


def _balanced_lua_table(source: str) -> None:
    """Lightweight delimiter check, not a Fusion Lua parser nor host validation."""
    pairs = {")": "(", "]": "[", "}": "{"}
    stack: list[str] = []
    in_string = False
    escaped = False
    for row in source.splitlines():
        # All authored comments are full-line -- comments, never inline.
        if row.lstrip().startswith("--"):
            continue
        for ch in row:
            if in_string:
                if escaped:
                    escaped = False
                elif ch == "\\":
                    escaped = True
                elif ch == '"':
                    in_string = False
                continue
            if ch == '"':
                in_string = True
            elif ch in "([{":
                stack.append(ch)
            elif ch in ")]}":
                if not stack or stack.pop() != pairs[ch]:
                    raise ValueError(f"Unbalanced Lua-like table delimiters near {ch!r}")
    if in_string or stack:
        raise ValueError("Unclosed string or table delimiter")


def inspect_source(source: str) -> dict[str, object]:
    _balanced_lua_table(source)
    if 'ActiveTool = "CRAtomic_InspectorLab"' not in source:
        raise ValueError("Missing active macro identifier")
    if "CRAtomic_InspectorLab = MacroOperator" not in source:
        raise ValueError("Missing Fusion macro container")
    if 'MainOutput1 = InstanceOutput { SourceOp = "Label_Merge", Source = "Output" }' not in source:
        raise ValueError("Missing rendered image output")
    names = re.findall(r"^\s+(\w+) = (?:Background|RectangleMask|Merge|Transform|TextPlus) \{", source, re.M)
    if len(names) != 10 or len(set(names)) != 10:
        raise ValueError(f"Expected 10 distinct schematic Fusion nodes, got {names!r}")
    refs = re.findall(r'SourceOp = "(\w+)"', source)
    if any(ref not in names for ref in refs):
        raise ValueError(f"Dangling node reference: {set(refs) - set(names)}")
    inputs = re.findall(r'^\s+Input(\d+) = InstanceInput \{[^\n]+\},$', source, re.M)
    if inputs != [str(i) for i in range(1, 18)]:
        raise ValueError("Expected exactly 17 ordered published inspector controls")
    for node, group in (("Base_BG", 101), ("Region_A_BG", 102), ("Region_B_BG", 103)):
        for channel in ("Red", "Green", "Blue", "Alpha"):
            pat = fr'SourceOp = "{node}", Source = "TopLeft{channel}"[^\n]*ControlGroup = {group}'
            if not re.search(pat, source):
                raise ValueError(f"Missing grouped picker channel {node}.{channel}")
    for node in ("Layer_A_Merge", "Layer_B_Merge"):
        if not re.search(fr'SourceOp = "{node}", Source = "Blend"', source):
            raise ValueError(f"Missing independent opacity: {node}")
    if 'SourceOp = "Scene_Camera", Source = "Size"' not in source:
        raise ValueError("Missing shared camera zoom control")
    if 'SourceOp = "Probe_Text", Source = "StyledText"' not in source:
        raise ValueError("Missing text-entry-only probe")
    if "NOT GEO SEARCH" not in source or "not a search" not in source:
        raise ValueError("A diagnostic field must never be mistaken for a working search")
    for banned in ("https://", "http://", "ISO3", "gabrielbugarelli/cartorig/", "VES", "GEOlayers"):
        if banned in source:
            raise ValueError(f"Unexpected external source or obsolete product reference: {banned}")
    return {
        "kind": "static-structure-check-only",
        "status": "PASS_LOCAL_STATIC_ONLY",
        "host_resolve20": "NOT_TESTED",
        "published_controls": len(inputs),
        "internal_nodes": len(names),
        "color_groups": [101, 102, 103],
        "sha256": hashlib.sha256(source.encode("utf-8")).hexdigest(),
    }


def build(destination: Path) -> dict[str, object]:
    content = SOURCE.read_text(encoding="utf-8")
    report = inspect_source(content)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(destination, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        archive.writestr(PACKAGE_ENTRY, content.encode("utf-8"))
    with ZipFile(destination) as archive:
        if archive.namelist() != [PACKAGE_ENTRY] or archive.testzip() is not None:
            raise ValueError("Invalid or unexpected DRFX archive layout")
        if archive.read(PACKAGE_ENTRY) != content.encode("utf-8"):
            raise ValueError("DRFX payload differs from validated template")
    report["package"] = str(destination)
    report["package_sha256"] = hashlib.sha256(destination.read_bytes()).hexdigest()
    report["single_click_installation"] = "PROPOSED_NOT_HOST_VERIFIED"
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate template structure only")
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "CartoRig-Atomic-Inspector-Lab.drfx")
    options = parser.parse_args()
    try:
        if options.check:
            report = inspect_source(SOURCE.read_text(encoding="utf-8"))
        else:
            report = build(options.output)
    except (ValueError, OSError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
