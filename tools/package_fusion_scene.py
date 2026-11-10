"""Build a single installed Fusion Comp script; editor runs no build tools.

The source engine and UI are kept separate for unit testing.  The distributable
is one self-contained Lua script installed into Fusion/Scripts/Comp.
"""
from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "fusion/cartorig_scene_runtime.lua"
UI = ROOT / "fusion/CartoRig Scene.lua"
GEO = ROOT / "fusion/cartorig_catalog.lua"
GEOMETRY = ROOT / "fusion/cartorig_geometry.lua"
PLACEHOLDER = "@@EMBED_RUNTIME@@"
GEO_PLACEHOLDER = "@@EMBED_CATALOG@@"
GEOMETRY_PLACEHOLDER = "@@EMBED_GEOMETRY@@"


def package(output: Path) -> Path:
    core = ENGINE.read_text(encoding="utf-8")
    scene = UI.read_text(encoding="utf-8")
    catalog = GEO.read_text(encoding="utf-8")
    geometry = GEOMETRY.read_text(encoding="utf-8")
    if not core.rstrip().endswith("return M") or not core.endswith("\n"):
        raise ValueError("Fusion runtime must be a complete, self-contained module")
    if (scene.count(PLACEHOLDER) != 1 or scene.count(GEO_PLACEHOLDER) != 1
            or scene.count(GEOMETRY_PLACEHOLDER) != 1):
        raise ValueError("Scene entry must include one runtime and one catalog placeholder")
    combined = scene.replace(PLACEHOLDER, "(function()\n" + core + "\nend)()")
    combined = combined.replace(GEO_PLACEHOLDER, "(function()\n" + catalog + "\nend)()")
    combined = combined.replace(GEOMETRY_PLACEHOLDER, "(function()\n" + geometry + "\nend)()")
    if PLACEHOLDER in combined or GEO_PLACEHOLDER in combined or GEOMETRY_PLACEHOLDER in combined:
        raise ValueError("Unresolved runtime placeholder in Fusion bundle")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(combined, encoding="utf-8", newline="\n")
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("dist/CartoRig Scene.lua"))
    args = parser.parse_args()
    path = package(args.output)
    print(f"Packaged independent Fusion Scene: {path} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
