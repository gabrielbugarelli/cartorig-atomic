"""Assemble the Windows OpenFX bundle. Build/CI tool, not an editor-side dependency."""
from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path
import shutil
import zipfile

BUNDLE = "CartoRigAtomic.ofx.bundle"


def package(binary: Path, catalog: Path, manifest: Path, destination: Path) -> dict:
    information = json.loads(manifest.read_text(encoding="utf-8"))
    if information.get("format") != "CARTORIG_ATOMIC_GEO_V1":
        raise ValueError("unsupported offline geographic format")
    if information.get("catalog_sha256") != sha256(catalog.read_bytes()).hexdigest():
        raise ValueError("offline catalog SHA256 mismatch")
    if information.get("feature_count", 0) < 10000:
        raise ValueError("Natural Earth catalog incomplete")
    if not binary.is_file() or binary.stat().st_size < 10000:
        raise ValueError("missing or suspiciously small native OpenFX binary")

    contents = destination / BUNDLE / "Contents"
    win64 = contents / "Win64"
    resources = contents / "Resources"
    win64.mkdir(parents=True, exist_ok=True)
    resources.mkdir(parents=True, exist_ok=True)
    shutil.copy2(binary, win64 / "CartoRigAtomic.ofx")
    shutil.copy2(catalog, resources / "cartorig-natural-earth-10m.catalog")
    shutil.copy2(manifest, resources / "natural-earth-manifest.json")

    archive = destination / "CartoRig-Atomic-OFX-Windows-x64.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as target:
        for path in sorted((destination / BUNDLE).rglob("*")):
            if path.is_file():
                target.write(path, path.relative_to(destination).as_posix())
    with zipfile.ZipFile(archive) as check:
        if check.testzip() is not None:
            raise ValueError("damaged OFX archive")
        names = check.namelist()
        for required in (
            f"{BUNDLE}/Contents/Win64/CartoRigAtomic.ofx",
            f"{BUNDLE}/Contents/Resources/cartorig-natural-earth-10m.catalog",
            f"{BUNDLE}/Contents/Resources/natural-earth-manifest.json",
        ):
            if required not in names:
                raise ValueError("missing bundle entry " + required)
    return {
        "bundle_dir": str(destination / BUNDLE),
        "archive": str(archive),
        "archive_sha256": sha256(archive.read_bytes()).hexdigest(),
        "catalog_features": information["feature_count"],
        "installer": "not included — this is the OFX bundle payload",
        "resolve20_host_validation": "NOT_TESTED",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--destination", type=Path, default=Path("dist"))
    options = parser.parse_args()
    print(json.dumps(package(
        options.binary, options.catalog, options.manifest, options.destination
    ), indent=2))


if __name__ == "__main__":
    main()
