"""Validate the authoritative owner-supplied Fusion product contract.

This is documentary QA, NOT a Fusion host test or product acceptance.
Standard-library only; runs on CI. No source code, assets or algorithms are
copied from previous CartoRig implementations.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "docs/specs/CR-PS-2.0_Fusion_2026-11-08.md"
EXPECTED_SHA256 = "992c1bd04b1ac0442fe73718f37c7ec51c9e130d3cf422f81cd905c4c28fdaa6"
EXPECTED_PRESETS = {
    "MO-REG-01", "MO-REG-02", "MO-REG-03", "MO-REG-04",
    "MO-REG-05", "MO-REG-06",
    "MO-RTE-01", "MO-RTE-02", "MO-RTE-03",
    "MO-MRK-01", "MO-MRK-02",
    "MO-CAM-01", "MO-CAM-02", "MO-CAM-03",
    "MO-LBL-01", "MO-MAP-01",
}


def check_contract(path: Path = SPEC, require_original_hash: bool = True) -> dict[str, object]:
    source_bytes = path.read_bytes()
    digest = hashlib.sha256(source_bytes).hexdigest()
    if require_original_hash and digest != EXPECTED_SHA256:
        raise ValueError("CR-PS-2.0 does not match the owner-provided original SHA256")

    source = source_bytes.decode("utf-8")
    if source.count("\n") != 1426:
        raise ValueError("Master document line count changed unexpectedly")
    if not source.startswith("# CARTORIG — ESPECIFICAÇÃO MESTRA"):
        raise ValueError("Incorrect product specification")
    for phrase in (
        "CR-PS-2.0", "Fusion do DaVinci Resolve Studio",
        "Scene", "Control", "Motion",
        "MANDATE", "BASELINE-PROPOSED", "LATER-PROPOSED",
        "ENGINEERING-VERIFY", "OWNER SIGN-OFF REQUIRED",
        "UI Manager", "BezierSpline", "Transparent Overlay",
    ):
        if phrase not in source:
            raise ValueError(f"Missing normative specification text: {phrase}")

    qa_ids = set(re.findall(r"\bQA-(\d{2})\b", source))
    host_ids = set(re.findall(r"\bHOST-(\d{2})\b", source))
    if qa_ids != {f"{n:02}" for n in range(1, 61)}:
        raise ValueError("QA-01 through QA-60 are not all specified")
    if host_ids != {f"{n:02}" for n in range(1, 11)}:
        raise ValueError("HOST-01 through HOST-10 are not all specified")

    start = source.index("### 11.2. Matriz fechada do catálogo Motion no lançamento")
    end = source.index("### 11.3. Critérios para concluir o R1.0", start)
    launch_matrix = source[start:end]
    found = re.findall(r"^\|\s*(MO-[A-Z]+-\d{2})\s*\|", launch_matrix, re.M)
    if len(found) != 16 or set(found) != EXPECTED_PRESETS:
        raise ValueError("R1.0 Motion matrix must contain exactly 16 defined presets")

    # Do not silently upgrade proposed visual decisions to user-approved scope.
    if "não são apresentados como aprovados pelo proprietário" not in source.replace("**", ""):
        raise ValueError("Product approval guard was lost")
    if "OWNER SIGN-OFF REQUIRED" not in source:
        raise ValueError("Owner homologation must remain explicitly required")

    return {
        "contract": "CR-PS-2.0",
        "sha256": digest,
        "status": "OWNER_SIGN_OFF_REQUIRED",
        "host_tests_specified": len(host_ids),
        "qa_tests_specified": len(qa_ids),
        "motion_presets_proposed": len(found),
        "fusion_host_execution": "NOT_TESTED",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, default=SPEC)
    args = parser.parse_args()
    try:
        summary = check_contract(args.spec)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
    for key, value in summary.items():
        print(f"{key}: {value}")
