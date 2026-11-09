"""Release evidence must never be fabricated just to turn CI green."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("release_gate",ROOT/"tools/check_release_gate.py")
assert spec and spec.loader
gate=importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class ReleaseGateTests(unittest.TestCase):
    def test_all_required_host_and_qa_cases_are_explicitly_tracked(self):
        evidence=json.loads(gate.EVIDENCE.read_text(encoding="utf-8"))
        self.assertEqual(set(evidence["host"]),
            {f"HOST-{n:02}" for n in range(1,11)})
        self.assertEqual(set(evidence["qa"]),
            {f"QA-{n:02}" for n in range(1,61)})

    def test_green_unit_tests_are_not_a_production_release_claim(self):
        evidence=json.loads(gate.EVIDENCE.read_text(encoding="utf-8"))
        blockers=gate.evaluate(evidence)
        self.assertTrue(blockers)
        self.assertIn("HOST-01 has no positive Resolve 20 evidence",blockers)
        self.assertIn("QA-01 has no positive Resolve 20 evidence",blockers)

    def test_fake_host_pass_without_evidence_is_rejected(self):
        evidence=json.loads(gate.EVIDENCE.read_text(encoding="utf-8"))
        for row in evidence["host"].values():
            row["status"]="PASS"
            row["host_evidence"]=None
        blockers=gate.evaluate(evidence)
        self.assertIn("HOST-01 has no positive Resolve 20 evidence",blockers)

    def test_missing_motion_feature_always_blocks_1_0(self):
        evidence=json.loads(gate.EVIDENCE.read_text(encoding="utf-8"))
        evidence["features"].pop("MO-RTE-03")
        self.assertTrue(any("MO-RTE-03" in x for x in gate.evaluate(evidence)))


if __name__=="__main__":
    unittest.main()
