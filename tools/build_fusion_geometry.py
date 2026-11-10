#!/usr/bin/env python3
"""Produce offline WGS84 polygon geometry (Admin0/Admin1) from Natural Earth.

GeoJSON-interface polygon rings supplied by pyshp distinguish exteriors from
interiors. Each source feature remains ONE authored Region object, regardless
of its multipart outline. Editor does not run Python/network/GIS software.
"""
from __future__ import annotations

import argparse
from hashlib import sha256
import json
from math import isfinite
from pathlib import Path

from build_fusion_catalog import DATASETS, download, open_reader, attr

HEADER = "CARTORIG_ATOMIC_GEOMETRY_V1"
TOLERANCE = {"Country": 0.025, "State": 0.0125}


def orientation(ring: list[tuple[float, float]]) -> float:
    return sum((a[0] * b[1] - b[0] * a[1])
               for a, b in zip(ring, ring[1:] + ring[:1])) / 2.0


def distance_to_segment_sq(point, a, b):
    px, py = point
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    scale = dx*dx + dy*dy
    t = max(0, min(1, ((px-ax)*dx + (py-ay)*dy)/scale)) if scale else 0
    return (px-ax-t*dx)**2 + (py-ay-t*dy)**2


def rdp(points, tolerance):
    if len(points) < 3:
        return points
    a, b = points[0], points[-1]
    index, largest = 0, 0.0
    for i in range(1, len(points)-1):
        distance = distance_to_segment_sq(points[i], a, b)
        if distance > largest:
            index, largest = i, distance
    if largest <= tolerance**2:
        return [a, b]
    left = rdp(points[:index+1], tolerance)
    right = rdp(points[index:], tolerance)
    return left[:-1] + right


def normalize_ring(ring, tolerance):
    original = [(float(x), float(y)) for x, y in ring]
    if original and original[0] == original[-1]:
        original.pop()
    if len(original) < 3:
        raise ValueError("Natural Earth polygon ring has fewer than 3 points")
    if any(not isfinite(x) or not isfinite(y) or
           x < -180 or x > 180 or y < -90 or y > 90
           for x, y in original):
        raise ValueError("Invalid WGS84 polygon ring")
    # Closed-ring RDP starts from a stable extreme, not coincident endpoints.
    anchor = min(range(len(original)), key=lambda i:
                 (original[i][0], original[i][1]))
    cycle = original[anchor:] + original[:anchor]
    mid = len(cycle)//2
    simplified = (rdp(cycle[:mid+1], tolerance)[:-1] +
                  rdp(cycle[mid:]+[cycle[0]], tolerance)[:-1])
    if len(simplified) < 3 or orientation(simplified)*orientation(original) <= 0:
        simplified = original
    # Preserve both the source winding and the exact polygon closure semantics.
    return simplified


def feature_rings(shape, tolerance):
    geo = shape.__geo_interface__
    geometry = geo["type"]
    if geometry == "Polygon":
        polygons = [geo["coordinates"]]
    elif geometry == "MultiPolygon":
        polygons = geo["coordinates"]
    else:
        raise ValueError("Natural Earth country/state is not Polygon/MultiPolygon")
    result = []
    for polygon in polygons:
        for number, ring in enumerate(polygon):
            # 'O' exterior; 'H' hole. Preserve island fragment identities.
            points = normalize_ring(ring, tolerance)
            result.append(("O" if number == 0 else "H", points))
    return result


def encode_rings(rings):
    values = []
    for kind, points in rings:
        vertices = ";".join(f"{x:.6f},{y:.6f}" for x, y in points)
        values.append(f"{kind}:{vertices}")
    return "|".join(values)


def build(output: Path, cache: Path):
    manifest = {"format": HEADER, "provider": "Natural Earth",
                "source_scale": "1:10m", "rows": 0,
                "multipolygons": 0, "holes": 0, "rings": 0,
                "simplification_degrees": TOLERANCE,
                "sources": {},
                "license": "Natural Earth public domain"}
    output.parent.mkdir(parents=True, exist_ok=True)
    places = output.parent / "places.tsv"
    if not places.exists():
        raise ValueError("Build the matching Natural Earth place index first")
    valid_ids = set()
    with places.open("r", encoding="utf-8") as source:
        if source.readline().strip() != "CARTORIG_ATOMIC_PLACES_V1":
            raise ValueError("Unsupported matching place-index version")
        for row in source:
            identity, _, _ = row.partition("\t")
            if identity.startswith(("ne10m:country:", "ne10m:state:")):
                valid_ids.add(identity)
    with output.open("w", encoding="utf-8", newline="\n") as out:
        out.write(HEADER + "\n")
        for kind in ("Country", "State"):
            dataset = DATASETS[kind]
            payload, digest = download(dataset, cache)
            manifest["sources"][kind] = {"dataset": dataset,
                                          "zip_sha256": digest, "features": 0}
            reader = open_reader(payload, dataset)
            fields = [f[0].lower() for f in reader.fields[1:]]
            for index, sr in enumerate(reader.iterShapeRecords()):
                attrs = {name: sr.record[i] for i, name in enumerate(fields)}
                natural_id = attr(attrs, "ne_id") or attr(attrs, "adm1_code",
                                                          "geonameid")
                if not natural_id:
                    raise ValueError(f"{kind} record {index} without source ID")
                try:
                    numeric = float(natural_id)
                    if numeric.is_integer():
                        natural_id = str(int(numeric))
                except ValueError:
                    pass
                identity = f"ne10m:{kind.lower()}:{natural_id}"
                if identity not in valid_ids:
                    continue  # The search pack omits unnamed Natural Earth records.
                rings = feature_rings(sr.shape, TOLERANCE[kind])
                if not rings:
                    raise ValueError(f"Empty geometry: {identity}")
                if len(rings) > 1:
                    manifest["multipolygons"] += 1
                manifest["rings"] += len(rings)
                manifest["holes"] += sum(k == "H" for k, _ in rings)
                out.write(identity + "\t" + str(len(rings)) + "\t" +
                          encode_rings(rings) + "\n")
                manifest["rows"] += 1
                manifest["sources"][kind]["features"] += 1
    manifest["geometry_sha256"] = sha256(output.read_bytes()).hexdigest()
    (output.parent / "cartorig-geometry-manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False)+"\n",
        encoding="utf-8", newline="\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=Path("dist/CartoRigAtomic_Data/geometry.tsv"))
    parser.add_argument("--cache", type=Path, default=Path(".cache/cartorig-ne"))
    args = parser.parse_args()
    print(json.dumps(build(args.output, args.cache), indent=2))


if __name__ == "__main__":
    main()
