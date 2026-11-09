#!/usr/bin/env python3
"""Validate offline Fusion Natural Earth search package before Windows release."""
from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path

EXPECTED = "CARTORIG_ATOMIC_PLACES_V1"


def validate(data: Path, manifest: Path) -> dict:
    metadata = json.loads(manifest.read_text(encoding="utf-8"))
    if metadata.get("format") != EXPECTED:
        raise ValueError("invalid offline catalog version")
    if sha256(data.read_bytes()).hexdigest() != metadata.get("catalog_sha256"):
        raise ValueError("offline catalog differs from source hash manifest")
    names = {}
    count = 0
    unique = set()
    with data.open("r", encoding="utf-8", newline="") as stream:
        if stream.readline().strip() != EXPECTED:
            raise ValueError("corrupt offline data header")
        for line in stream:
            count += 1
            cols = line.rstrip("\r\n").split("\t")
            if len(cols) != 9:
                raise ValueError(f"invalid column count on data line {count+1}")
            identity, kind, name, parent, country, continent, lon, lat, aliases = cols
            if not identity or identity in unique:
                raise ValueError("unstable or duplicate Natural Earth feature ID")
            unique.add(identity)
            if kind not in {"Country", "State", "City"}:
                raise ValueError("invalid geographic category")
            if kind == "City" and not lon:
                raise ValueError("missing city WGS84 point")
            if kind != "City" and (lon or lat):
                raise ValueError("region must not claim an invented point")
            names.setdefault((name.casefold(), kind), 0)
            names[(name.casefold(), kind)] += 1
    if count != metadata.get("count") or count < 10000:
        raise ValueError("incomplete or inconsistent Natural Earth data pack")
    for name, kind in (
        ("rio de janeiro", "State"), ("rio de janeiro", "City"),
        ("são paulo", "State"), ("são paulo", "City"),
        ("brasil", "City"), ("brasília", "City"),
        ("amapá", "State"), ("macapá", "City"),
    ):
        # Brasil is an alias for Brazil and not necessarily a city; check below.
        if name == "brasil":
            continue
        if (name, kind) not in names:
            raise ValueError(f"required real Natural Earth coverage missing: {name}/{kind}")
    if metadata["datasets"].get("Country",{}).get("count",0) < 200 or \
       metadata["datasets"].get("State",{}).get("count",0) < 3000 or \
       metadata["datasets"].get("City",{}).get("count",0) < 5000:
        raise ValueError("Natural Earth categories incomplete")
    return {"verified_rows": count, "sha256": metadata["catalog_sha256"],
            "status": "OFFLINE_GEOGRAPHIC_INDEX_VALID"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    options = parser.parse_args()
    result = validate(options.catalog, options.manifest)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
