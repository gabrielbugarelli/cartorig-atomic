#!/usr/bin/env python3
"""Build the CartoRig Fusion search asset from official Natural Earth.

This is CI/developer-only tooling. The installed Fusion runtime reads a local
TSV and never requires Python, pyshp, GIS libraries or network access.
"""
from __future__ import annotations

import argparse
from hashlib import sha256
import io
import json
from pathlib import Path
from urllib.request import Request, urlopen
import zipfile

import shapefile

SOURCE = "https://naturalearth.s3.amazonaws.com/10m_cultural/{name}.zip"
DATASETS = {
    "Country": "ne_10m_admin_0_countries",
    "State": "ne_10m_admin_1_states_provinces",
    "City": "ne_10m_populated_places",
}
VERSION = "CARTORIG_ATOMIC_PLACES_V1"
MAX_ARCHIVE = 100_000_000


def download(name: str, cache: Path) -> tuple[bytes, str]:
    cache.mkdir(parents=True, exist_ok=True)
    saved = cache / f"{name}.zip"
    if saved.exists():
        content = saved.read_bytes()
    else:
        request = Request(SOURCE.format(name=name), headers={
            "User-Agent": "CartoRigAtomic-FusionDataBuilder/0.2"})
        with urlopen(request, timeout=120) as response:
            content = response.read(MAX_ARCHIVE + 1)
        if len(content) > MAX_ARCHIVE:
            raise ValueError("official Natural Earth source exceeded size limit")
        saved.write_bytes(content)
    if len(content) > MAX_ARCHIVE:
        raise ValueError("cached official Natural Earth source exceeded size limit")
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        if archive.testzip() is not None:
            raise ValueError("Natural Earth ZIP CRC failure")
    return content, sha256(content).hexdigest()


def open_reader(content: bytes, dataset: str) -> shapefile.Reader:
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        names = {Path(entry).name.lower(): entry for entry in archive.namelist()}
        components = []
        for extension in (".shp", ".shx", ".dbf"):
            filename = (dataset + extension).lower()
            if filename not in names:
                raise ValueError(f"Natural Earth archive missing {filename}")
            components.append(io.BytesIO(archive.read(names[filename])))
    return shapefile.Reader(shp=components[0], shx=components[1],
                            dbf=components[2], encoding="utf-8",
                            encodingErrors="replace")


def attr(row: dict, *fields: str) -> str:
    for field in fields:
        value = row.get(field.lower())
        if value is None:
            continue
        result = str(value).strip()
        if result and result not in ("-99", "-99.0", "None", "nan"):
            return result
    return ""


def escape(text: str) -> str:
    return str(text).replace("\t", " ").replace("\r", " ").replace(
        "\n", " ").replace(";", ",").strip()


def encode_record(kind: str, attrs: dict, shape, index: int,
                  country_continents: dict[str, str]) -> str | None:
    if kind == "Country":
        name = attr(attrs, "admin", "name_en", "name")
        parent, country = "", name
        continent = attr(attrs, "continent")
    elif kind == "State":
        name = attr(attrs, "name", "name_en")
        country = attr(attrs, "admin", "adm0_name", "geonunit")
        parent = country
        continent = country_continents.get(country.casefold(), "")
    else:
        name = attr(attrs, "name", "nameascii")
        country = attr(attrs, "adm0name", "sov0name")
        parent = attr(attrs, "adm1name")
        continent = country_continents.get(country.casefold(), "")
    if not name:
        return None

    natural_id = attr(attrs, "ne_id")
    if not natural_id:
        natural_id = attr(attrs, "adm1_code", "geonameid", "geonamesid")
    if not natural_id:
        raise ValueError(f"Natural Earth {kind} record #{index} lacks feature ID")
    try:
        numeric_id = float(natural_id)
        if numeric_id.is_integer():
            natural_id = str(int(numeric_id))
    except ValueError:
        pass
    identity = f"ne10m:{kind.lower()}:{natural_id}"

    lon = lat = ""
    if kind == "City":
        if shape.shapeType not in (shapefile.POINT, shapefile.POINTM,
                                   shapefile.POINTZ) or not shape.points:
            raise ValueError(f"Natural Earth populated place {identity} lacks point")
        x, y = shape.points[0][:2]
        if not (-180 <= x <= 180 and -90 <= y <= 90):
            raise ValueError(f"Invalid Natural Earth WGS84 point: {identity}")
        lon, lat = f"{x:.7f}", f"{y:.7f}"

    candidates = [
        attr(attrs, "name_en"), attr(attrs, "name_local"),
        attr(attrs, "nameascii"), attr(attrs, "name_alt"),
        attr(attrs, "namealt"), attr(attrs, "name_long"),
        attr(attrs, "name_pt"),
    ]
    if kind == "Country" and name == "Brazil":
        candidates.append("Brasil")
    aliases, seen = [], {name.casefold()}
    for candidate in candidates:
        for alternative in candidate.split("|"):
            alias = escape(alternative)
            if alias and alias.casefold() not in seen:
                seen.add(alias.casefold())
                aliases.append(alias)

    values = [
        identity, kind, name, parent, country, continent, lon, lat,
        ";".join(aliases[:16]),
    ]
    safe_fields = [escape(value) for value in values[:-1]]
    safe_aliases = values[-1].replace("\t", " ").replace("\r", " ").replace("\n", " ")
    return "\t".join(safe_fields + [safe_aliases])


def build(output: Path, cache: Path) -> dict:
    manifest = {
        "format": VERSION,
        "provider": "Natural Earth",
        "scale": "1:10m",
        "source_url_pattern": SOURCE,
        "provenance": "Official Natural Earth cultural shapefiles. Public domain.",
        "datasets": {},
    }
    cache.mkdir(parents=True, exist_ok=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    raw_sources = {}
    for kind, dataset in DATASETS.items():
        content, archive_hash = download(dataset, cache)
        raw_sources[kind] = open_reader(content, dataset)
        manifest["datasets"][kind] = {
            "name": dataset, "source_zip_sha256": archive_hash, "count": 0,
        }

    country_continents = {}
    country_reader = raw_sources["Country"]
    for item in country_reader.iterRecords():
        row = {f[0].lower(): item[i] for i, f in
               enumerate(country_reader.fields[1:])}
        key = attr(row, "admin", "name_en", "name")
        if key:
            country_continents[key.casefold()] = attr(row, "continent")

    identities = set()
    lines = [VERSION]
    for kind, reader in raw_sources.items():
        keys = [f[0].lower() for f in reader.fields[1:]]
        for index, sr in enumerate(reader.iterShapeRecords()):
            fields = {key: sr.record[i] for i, key in enumerate(keys)}
            line = encode_record(kind, fields, sr.shape, index, country_continents)
            if not line:
                continue
            identity = line.split("\t", 1)[0]
            if identity in identities:
                raise ValueError("Natural Earth feature ID collision: " + identity)
            identities.add(identity)
            if line.count("\t") != 8:
                raise ValueError("Catalog TSV contract violated")
            lines.append(line)
            manifest["datasets"][kind]["count"] += 1

    if len(lines) < 10000:
        raise ValueError("Official Natural Earth coverage incomplete")
    output.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    manifest["count"] = len(lines) - 1
    manifest["catalog_sha256"] = sha256(output.read_bytes()).hexdigest()
    manifest["conversion_tool"] = "cartorig-atomic-fusion-places-v1"
    (output.parent / "cartorig-data-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8", newline="\n")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=Path("dist/CartoRigAtomic_Data/places.tsv"))
    parser.add_argument("--cache", type=Path, default=Path(".cache/cartorig-ne"))
    args = parser.parse_args()
    print(json.dumps(build(args.output, args.cache),
                     ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
