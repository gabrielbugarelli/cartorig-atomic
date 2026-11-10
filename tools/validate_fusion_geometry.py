#!/usr/bin/env python3
"""Check all shipped Natural Earth multipolygons, ring topology and manifest."""
from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path


def check(geometry: Path, manifest: Path, places: Path) -> dict:
    metadata=json.loads(manifest.read_text(encoding="utf-8"))
    if metadata.get("format")!="CARTORIG_ATOMIC_GEOMETRY_V1":
        raise ValueError("Wrong geometry pack version")
    if metadata.get("geometry_sha256") != sha256(geometry.read_bytes()).hexdigest():
        raise ValueError("Offline geometry SHA-256 mismatch")
    identifiers=set()
    with places.open("r",encoding="utf-8") as source:
        if source.readline().strip()!="CARTORIG_ATOMIC_PLACES_V1":
            raise ValueError("Place index is corrupt")
        for line in source:
            identifiers.add(line.partition("\t")[0])
    count=0
    kinds={"country":0,"state":0}
    holes=0
    multiparts=0
    with geometry.open("r",encoding="utf-8") as source:
        if source.readline().strip()!="CARTORIG_ATOMIC_GEOMETRY_V1":
            raise ValueError("Geometry index header is corrupt")
        for line in source:
            count+=1
            cells=line.rstrip("\n\r").split("\t",2)
            if len(cells)!=3:
                raise ValueError(f"Bad ring record #{count}")
            identity,ringCount,encoded=cells
            if identity not in identifiers:
                raise ValueError("Geometry without matching typed place identity: "+identity)
            kind=identity.split(":",2)[1]
            if kind not in kinds:
                raise ValueError("Geometry contains non-polygon feature: "+identity)
            kinds[kind]+=1
            if not ringCount.isdigit() or int(ringCount)<1:
                raise ValueError("Bad multipolygon ring count")
            rings=encoded.split("|")
            if len(rings)!=int(ringCount):
                raise ValueError("Ring count mismatch: "+identity)
            if len(rings)>1:
                multiparts+=1
            if not rings[0].startswith("O:"):
                raise ValueError("Polygon must begin with exterior ring")
            for ring in rings:
                role,sep,points=ring.partition(":")
                if not sep or role not in ("O","H"):
                    raise ValueError("Unrecognized polygon ring role")
                if role=="H": holes+=1
                pairs=points.split(";")
                if len(pairs)<3:
                    raise ValueError("Polygon has fewer than 3 points")
                for item in pairs:
                    split=item.split(",")
                    if len(split)!=2:
                        raise ValueError("Malformed lon/lat pair")
                    lon,lat=float(split[0]),float(split[1])
                    if not (-180<=lon<=180 and -90<=lat<=90):
                        raise ValueError("Out-of-range WGS84 vertex")
    if count!=metadata.get("rows") or count<4000:
        raise ValueError("Incomplete geometry pack")
    if any(kinds[k]!=metadata["sources"][k.title()]["features"] for k in kinds):
        raise ValueError("Natural Earth polygon category mismatch")
    if holes != metadata.get("holes") or multiparts != metadata.get("multipolygons"):
        raise ValueError("Data origin or multipart topology was lost")
    return {"features":count,"country":kinds["country"],"state":kinds["state"],
            "hole_rings":holes,"multipart_features":multiparts,
            "sha256":metadata["geometry_sha256"],"status":"VALID"}


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--geometry",required=True,type=Path)
    parser.add_argument("--manifest",required=True,type=Path)
    parser.add_argument("--places",required=True,type=Path)
    options=parser.parse_args()
    print(json.dumps(check(options.geometry,options.manifest,options.places),indent=2))
