"""Fail-closed CartoRig 1.0 release acceptance.

GitHub Actions green means the checked source tests passed, not that the product
has been accepted in DaVinci Resolve. The release requires separate proof for
the mandatory product/host/QA/visual/distribution gates in CR-PS-2.0 §18.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
EVIDENCE=ROOT/"docs/qa/CRPS20_EVIDENCE.json"
REQUIRED_OBJECTS=("OBJ-MAP","OBJ-REG","OBJ-RTE","OBJ-MRK","OBJ-CAM","OBJ-LBL","OBJ-GRP")
REQUIRED_MOTION=(
    "MO-REG-01","MO-REG-02","MO-REG-03","MO-REG-04","MO-REG-05","MO-REG-06",
    "MO-RTE-01","MO-RTE-02","MO-RTE-03","MO-MRK-01","MO-MRK-02",
    "MO-CAM-01","MO-CAM-02","MO-CAM-03","MO-LBL-01","MO-MAP-01",
)


def evaluate(data: dict) -> list[str]:
    blockers=[]
    if data.get("contract")!="CR-PS-2.0":
        blockers.append("Master contract is not CR-PS-2.0")
    if data.get("schema")!="cartorig-qa-evidence-v1":
        blockers.append("Unsupported evidence schema")
    for family,max_id,passing in (
        ("HOST",10,"PASS"),
        ("QA",60,"PASS"),
    ):
        records=data.get(family.lower(),{})
        expected={f"{family}-{n:02}" for n in range(1,max_id+1)}
        if set(records)!=expected:
            blockers.append(f"{family} case inventory incomplete")
        for name in sorted(expected):
            record=records.get(name,{})
            if record.get("status")!=passing or not record.get("host_evidence"):
                blockers.append(name+" has no positive Resolve 20 evidence")
    features=data.get("features",{})
    for key in REQUIRED_OBJECTS+REQUIRED_MOTION:
        row=features.get(key,{})
        if row.get("status")!="PASS_HOST_AND_AUTOMATED":
            blockers.append(key+" not fully integrated and certified")
    if not data.get("release_1_0_approved"):
        blockers.append("Product owner has not signed off on the complete release")
    if not data.get("install_and_offline_evidence"):
        blockers.append("Clean-machine offline installer evidence missing")
    if not data.get("spline_mediaout_evidence"):
        blockers.append("Independent native Fusion Spline and MediaOut evidence missing")
    return blockers


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence",type=Path,default=EVIDENCE)
    parser.add_argument("--assert-release-ready",action="store_true")
    args=parser.parse_args()
    evidence=json.loads(args.evidence.read_text(encoding="utf-8"))
    blockers=evaluate(evidence)
    print(f"CR-PS-2.0 release gate: {'PASS' if not blockers else 'BLOCKED'}")
    print(f"Unresolved acceptance items: {len(blockers)}")
    for issue in blockers:
        print(" - "+issue)
    if args.assert_release_ready and blockers:
        raise SystemExit(1)


if __name__=="__main__":
    main()
