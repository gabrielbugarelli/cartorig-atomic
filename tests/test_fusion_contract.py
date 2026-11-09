"""Greenfield specification/host-probe smoke checks.

These checks cannot certify Fusion UIManager, Inspector or Spline behavior:
that requires the owner to run the probe in Resolve Studio 20.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / "experiments/fusion-host/CartoRig Scene - ReadOnly Host Probe.lua"

module_spec = importlib.util.spec_from_file_location(
    "check_fusion_contract", ROOT / "tools/check_fusion_contract.py"
)
assert module_spec and module_spec.loader
checker = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(checker)


class FusionContractTests(unittest.TestCase):
    def test_document_is_exact_owner_supplied_spec(self):
        result = checker.check_contract()
        self.assertEqual(result["status"], "OWNER_SIGN_OFF_REQUIRED")
        self.assertEqual(result["motion_presets_proposed"], 16)
        self.assertEqual(result["qa_tests_specified"], 60)
        self.assertEqual(result["host_tests_specified"], 10)

    def test_signature_integrity_detects_change(self):
        import tempfile
        with tempfile.TemporaryDirectory() as temp:
            tampered = Path(temp) / "fake.md"
            tampered.write_bytes(checker.SPEC.read_bytes() + b"\n")
            with self.assertRaisesRegex(ValueError, "SHA256"):
                checker.check_contract(tampered)

    def test_scene_host_probe_has_no_graph_or_keyframe_mutation(self):
        source = PROBE.read_text(encoding="utf-8")
        code = "\n".join(
            row for row in source.splitlines() if not row.lstrip().startswith("--")
        )
        for mutator in (
            "AddTool(", "DeleteTool(", "SetAttrs(",
            "StartUndo(", "EndUndo(", "BezierSpline(",
            "SetInput(", "ConnectInput(", "Save(", "Load("
        ):
            self.assertNotIn(mutator, code, f"Host probe must be read-only: {mutator}")

    def test_scene_host_probe_uses_native_fusion_ui(self):
        source = PROBE.read_text(encoding="utf-8")
        self.assertIn("fusionApp.UIManager", source)
        self.assertIn("bmdApi.UIDispatcher", source)
        self.assertIn("dispatcher:AddWindow", source)
        self.assertIn("dispatcher:RunLoop", source)
        self.assertIn("dispatcher:ExitLoop", source)
        self.assertIn("window:GetItems()", source)

    def test_comp_is_rechecked_on_refresh_not_cached_as_authority(self):
        source = PROBE.read_text(encoding="utf-8")
        self.assertRegex(source, r"local function refresh\(\)")
        self.assertIn("local active, verified = currentComposition()", source)
        self.assertIn('WRONG_CONTEXT — Active composition changed', source)
        self.assertIn('NO_COMP — No Fusion composition selected', source)
        self.assertIn("Selected Fusion tool: invalidated", source)
        self.assertIn("CONTEXT_UNVERIFIED — CurrentComp API unavailable", source)
        self.assertIn("if not lookupOk then", source)

    def test_no_offline_search_or_motion_features_are_falsely_advertised(self):
        source = PROBE.read_text(encoding="utf-8")
        self.assertIn("read-only", source.lower())
        self.assertIn("NOT TESTED", source)
        self.assertNotIn("Add Region", source)
        self.assertNotIn("Apply Motion", source)
        self.assertNotIn("Macapá", source)
        self.assertNotIn("https://", source)


if __name__ == "__main__":
    unittest.main()
