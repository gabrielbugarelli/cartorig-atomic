"""Inventory check: all 16 CR-PS-2.0 presets have actual source callbacks.

This static gate is supplemental to the Lua host-double tests. It does NOT
certify native Resolve rendering, real UI or correct spline interpolation.
"""
from __future__ import annotations
import json
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]
EXPECTED={
    "MO-REG-01","MO-REG-02","MO-REG-03","MO-REG-04","MO-REG-05","MO-REG-06",
    "MO-RTE-01","MO-RTE-02","MO-RTE-03",
    "MO-MRK-01","MO-MRK-02",
    "MO-CAM-01","MO-CAM-02","MO-CAM-03",
    "MO-LBL-01","MO-MAP-01",
}
RUNTIME=(ROOT/"fusion/cartorig_scene_runtime.lua").read_text("utf-8")
PLANNER=(ROOT/"fusion/cartorig_motion.lua").read_text("utf-8")
FUSE=(ROOT/"fusion/fuses/CartoRigAtomicLand.fuse").read_text("utf-8")
QA=json.loads((ROOT/"docs/qa/CRPS20_EVIDENCE.json").read_text("utf-8"))


class NativeMotionInventoryTests(unittest.TestCase):
    def test_all_16_release_presets_have_declared_native_execution_sources(self):
        definitions=set(re.findall(r"MO-(?:REG|RTE|MRK|CAM|LBL|MAP)-\d{2}",
                                   RUNTIME+"\n"+FUSE))
        self.assertEqual(definitions,EXPECTED)

    def test_planner_and_product_source_catalog_agree(self):
        planned=set(re.findall(r"MO-(?:REG|RTE|MRK|CAM|LBL|MAP)-\d{2}",
                               PLANNER))
        self.assertEqual(planned,EXPECTED)

    def test_native_callbacks_are_not_ui_manager_only(self):
        self.assertIn("BTNCS_Execute",RUNTIME)
        self.assertIn("BTNCS_Execute",FUSE)
        self.assertIn('"BezierSpline"',RUNTIME)
        self.assertIn('"BezierSpline"',FUSE)
        self.assertIn('GetConnectedOutput()',RUNTIME)
        self.assertIn('host:StartUndo(',RUNTIME)
        self.assertIn('host:EndUndo(',RUNTIME)
        self.assertIn("StepIn=true",RUNTIME)
        self.assertIn("Linear=true",RUNTIME)
        self.assertIn("CartoRigAtomic.MotionFollowerV2",RUNTIME)
        self.assertIn("CartoRigAtomic.MotionFitV2",RUNTIME)

    def test_mock_coverage_does_not_claim_host_certification(self):
        for name in EXPECTED:
            self.assertEqual(QA["features"][name]["status"],
                             "NATIVE_KEYS_UNVERIFIED_IN_HOST")
        self.assertEqual(len(QA["host"]),10)
        self.assertEqual(len(QA["qa"]),60)
        self.assertTrue(all(item["status"]=="NOT_TESTED"
                            for item in QA["host"].values()))
        self.assertFalse(QA["release_1_0_approved"])


if __name__=="__main__":
    unittest.main()
