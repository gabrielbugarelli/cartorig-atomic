#!/usr/bin/env python3
"""Prepare licensed Natural Earth catalog data at BUILD TIME (not on editor PCs).

Downloads official Natural Earth shapefiles and writes one UTF-8 offline catalog.
The compiled C++ runtime NEVER accesses the network or uses Python.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import io
import json
from pathlib import Path
import tempfile
import urllib.request
import zipfile

import shapefile  # pyshp; development/CI-only, see tools/requirements-build.txt

SOURCES = {
    "country": ("ne_10m_admin_0_countries", "5.1.1"),
    "state": ("ne_10m_admin_1_states_provinces", "5.1.1"),
    "city": ("ne_10m_populated_places", "5.1.2"),
}
SOURCE_URL = "https://naturalearth.s3.amazonaws.com/10m_cultural/{name}.zip"
MAGIC = "CARTORIG_ATOMIC_GEO_V1"
# Diagnostic LOD: 0.015 degrees. This is NOT high-zoom editorial boundary fidelity.
SIMPLIFY_DEGREES = 0.015
MAX_DOWNLOAD_BYTES = 90 * 1024 * 1024


def read_source(name: str, cache: Path) -> tuple[bytes, str]:
    cache.mkdir(parents=True, exist_ok=True)
    destination = cache / (name + ".zip")
    if destination.exists():
        payload = destination.read_bytes()
    else:
        url = SOURCE_URL.format(name=name)
        request = urllib.request.Request(url, headers={"User-Agent": "CartoRig-Atomic-Builder/0.1"})
        with urllib.request.urlopen(request, timeout=90) as response:
            payload = response.read(MAX_DOWNLOAD_BYTES + 1)
        if len(payload) > MAX_DOWNLOAD_BYTES:
            raise ValueError(f"source download too large: {name}")
        destination.write_bytes(payload)
    if not zipfile.is_zipfile(io.BytesIO(payload)):
        raise ValueError(f"invalid official data archive: {name}")
    return payload, hashlib.sha256(payload).hexdigest()


def load_shapefile(data: bytes, name: str) -> shapefile.Reader:
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        files = {Path(entry).name.lower(): entry for entry in archive.namelist()}
        needed = [name + ext for ext in (".shp", ".shx", ".dbf")]
        for entry in needed:
            if entry.lower() not in files:
                raise ValueError(f"missing {entry} in Natural Earth zip")
        items = [io.BytesIO(archive.read(files[entry.lower()])) for entry in needed]
    return shapefile.Reader(shp=items[0], shx=items[1], dbf=items[2],
                            encoding="utf-8", encodingErrors="replace")


def as_attributes(reader: shapefile.Reader, record) -> dict[str, object]:
    return {str(f[0]).lower(): record[i] for i, f in enumerate(reader.fields[1:])}


def clean(value: object) -> str:
    text = str(value).strip() if value is not None else ""
    if text in ("-99", "-99.0", "None", "nan"): return ""
    return text.replace("\t", " ").replace("\r", " ").replace("\n", " ").replace("|", " ")


def field(attrs: dict, *choices: str) -> str:
    for key in choices:
        value = clean(attrs.get(key))
        if value: return value
    return ""


def stable_id(kind: str, attrs: dict, index: int) -> str:
    value = field(attrs, "ne_id", "adm1_code", "geonamesid", "geonameid", "gn_id")
    if not value: raise ValueError(f"Natural Earth {kind} record {index} has no stable ID")
    try:
        numeric = float(value)
        if numeric.is_integer(): value = str(int(numeric))
    except ValueError:
        pass
    return f"ne:{kind}:{value}"


def sq_distance(point, start, end):
    x, y = point
    sx, sy = start
    ex, ey = end
    dx, dy = ex - sx, ey - sy
    if dx == 0 and dy == 0: return (x-sx)**2 + (y-sy)**2
    t = max(0, min(1, ((x-sx)*dx + (y-sy)*dy) / (dx*dx + dy*dy)))
    return (x-sx-t*dx)**2 + (y-sy-t*dy)**2


def rdp(points, tolerance):
    """Ramer-Douglas-Peucker on a ring's open vertices; preserve closure."""
    if len(points) < 8: return points
    # Iterative to avoid Python recursion limits on complex coastlines.
    keep = {0, len(points)-1}
    pending = [(0, len(points)-1)]
    limit2 = tolerance*tolerance
    while pending:
        start, end = pending.pop()
        best = 0.0
        best_idx = -1
        for i in range(start+1, end):
            d = sq_distance(points[i], points[start], points[end])
            if d > best:
                best, best_idx = d, i
        if best_idx >= 0 and best > limit2:
            keep.add(best_idx)
            pending.append((start,best_idx))
            pending.append((best_idx,end))
    result = [points[i] for i in sorted(keep)]
    if len(result) < 4: return points  # Do not drop valid tiny rings.
    return result


def format_ring(points) -> str:
    source = [(float(p[0]), float(p[1])) for p in points]
    if not source: return ""
    if source[0] != source[-1]: source.append(source[0])
    vertices = rdp(source, SIMPLIFY_DEGREES)
    if vertices[0] != vertices[-1]: vertices.append(vertices[0])
    if len(vertices) < 4: return ""
    for lon, lat in vertices:
        if not (-180 <= lon <= 180 and -90 <= lat <= 90):
            raise ValueError(f"out-of-range official geometry: {(lon,lat)}")
    return ";".join(f"{lon:.5f},{lat:.5f}" for lon, lat in vertices)


def geometry_string(geo: dict, kind: str) -> tuple[str, str, str]:
    if kind == "city":
        if geo["type"] != "Point":
            raise ValueError("populated place is not a point")
        lon,lat = geo["coordinates"][:2]
        if not (-180 <= lon <= 180 and -90 <= lat <= 90):
            raise ValueError("invalid city coordinates")
        return f"{lon:.6f}", f"{lat:.6f}", ""
    if geo["type"] == "Polygon":
        polygons = [geo["coordinates"]]
    elif geo["type"] == "MultiPolygon":
        polygons = geo["coordinates"]
    else:
        return ".", ".", ""
    encoded = []
    for polygon in polygons:
        rings = [format_ring(ring) for ring in polygon]
        rings = [ring for ring in rings if ring]
        if rings: encoded.append("~".join(rings))
    return ".", ".", "|".join(encoded)


def row(reader, record, shape, kind: str, index: int) -> str | None:
    attrs = as_attributes(reader, record)
    if kind == "country":
        name = field(attrs, "admin", "name_en", "name", "name_long")
        parent = ""
        country = name
    elif kind == "state":
        name = field(attrs, "name", "name_en", "name_local")
        parent = field(attrs, "admin", "geonunit", "adm0_name")
        country = parent
    else:
        name = field(attrs, "name", "nameascii", "name_en")
        parent = field(attrs, "adm1name")
        country = field(attrs, "adm0name")
    if not name: return None
    candidate_aliases = [
        field(attrs, "name_en"), field(attrs, "name_local"),
        field(attrs, "nameascii"), field(attrs, "name_alt"),
        field(attrs, "namealt"), field(attrs, "name_long"), field(attrs, "name_pt"),
    ]
    aliases: list[str] = []
    for candidate in candidate_aliases:
        for alias in candidate.replace("|", ";").split(";"):
            alias = clean(alias).replace(";", " ")
            if alias and alias.casefold() != name.casefold() and alias not in aliases:
                aliases.append(alias)
    if kind == "country" and name == "Brazil": aliases.append("Brasil")
    lon, lat, geometry = geometry_string(shape.__geo_interface__,kind)
    if kind != "city" and not geometry: return None
    fields = [stable_id(kind,attrs,index), kind, clean(name), clean(parent),
              clean(country), ";".join(aliases[:12]), lon, lat, geometry]
    if any("\t" in f or "\r" in f or "\n" in f for f in fields):
        raise ValueError("invalid TSV field from Natural Earth")
    return "\t".join(fields)


def build(destination: Path, cache: Path) -> dict:
    destination.parent.mkdir(parents=True, exist_ok=True)
    manifest = {
        "format": MAGIC,
        "cartographic_simplification_degrees": SIMPLIFY_DEGREES,
        "source": "Natural Earth public domain vector datasets",
        "source_url": "https://www.naturalearthdata.com/downloads/10m-cultural-vectors/",
        "types": {},
    }
    seen: set[str] = set()
    with destination.open("w", encoding="utf-8", newline="\n") as out:
        out.write(MAGIC + "\n")
        for kind, (name, version) in SOURCES.items():
            payload, archive_sha = read_source(name, cache)
            reader = load_shapefile(payload,name)
            count = 0
            for i, entry in enumerate(reader.iterShapeRecords()):
                current = row(reader,entry.record,entry.shape,kind,i)
                if not current: continue
                feature_id = current.split("\t",1)[0]
                if feature_id in seen:
                    raise ValueError("duplicate Natural Earth ID: "+feature_id)
                seen.add(feature_id)
                out.write(current + "\n")
                count += 1
            manifest["types"][kind] = {
                "dataset": name,
                "advertised_version": version,
                "archive_sha256": archive_sha,
                "feature_count": count,
            }
    manifest["catalog_sha256"] = hashlib.sha256(destination.read_bytes()).hexdigest()
    manifest["feature_count"] = len(seen)
    (destination.parent / "natural-earth-manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False)+"\n",encoding="utf-8")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,default=Path("dist/data/cartorig-natural-earth-10m.catalog"))
    parser.add_argument("--cache",type=Path,default=Path(".cache/natural-earth"))
    args = parser.parse_args()
    manifest = build(args.output,args.cache)
    print(json.dumps(manifest,ensure_ascii=False,indent=2))


if __name__ == "__main__":
    main()
