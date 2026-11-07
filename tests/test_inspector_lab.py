"""Static shape and packaging tests; explicitly not real Resolve host tests."""
from pathlib import Path
import sys
import tempfile
import unittest
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from build_inspector_lab import PACKAGE_ENTRY, SOURCE, build, inspect_source  # noqa: E402


class InspectorLabTests(unittest.TestCase):
    def test_fusion_structure_and_independent_controls(self):
        result = inspect_source(SOURCE.read_text(encoding="utf-8"))
        self.assertEqual(result["published_controls"], 17)
        self.assertEqual(result["color_groups"], [101, 102, 103])
        self.assertEqual(result["internal_nodes"], 10)
        self.assertEqual(result["host_resolve20"], "NOT_TESTED")

    def test_packaging_is_single_self_contained_generator(self):
        with tempfile.TemporaryDirectory() as tmp:
            package = Path(tmp) / "CartoRig-Atomic-Inspector-Lab.drfx"
            result = build(package)
            with ZipFile(package) as archive:
                self.assertEqual(archive.namelist(), [PACKAGE_ENTRY])
                self.assertIsNone(archive.testzip())
                self.assertEqual(archive.read(PACKAGE_ENTRY), SOURCE.read_bytes())
            self.assertEqual(result["host_resolve20"], "NOT_TESTED")

    def test_dangling_node_is_detected(self):
        source = SOURCE.read_text(encoding="utf-8").replace(
            'SourceOp = "Region_A_BG", Source = "Output"',
            'SourceOp = "Missing_Node", Source = "Output"',
            1,
        )
        with self.assertRaisesRegex(ValueError, "Dangling node"):
            inspect_source(source)

    def test_color_group_regression_is_detected(self):
        source = SOURCE.read_text(encoding="utf-8").replace(
            'SourceOp = "Region_B_BG", Source = "TopLeftBlue", Name = "Region B Fill Blue", Page = "Objects", ControlGroup = 103',
            'SourceOp = "Region_B_BG", Source = "TopLeftBlue", Name = "Region B Fill Blue", Page = "Objects", ControlGroup = 999',
        )
        with self.assertRaisesRegex(ValueError, "Missing grouped picker"):
            inspect_source(source)


if __name__ == "__main__":
    unittest.main()
