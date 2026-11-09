"""Packaging QA for standalone Fusion runtime installed by Windows GUI."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "cartorig_package_fusion", ROOT / "tools/package_fusion_scene.py")
assert spec and spec.loader
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)


class FusionPackageTests(unittest.TestCase):
    def test_source_embeds_once_without_editor_dependencies(self):
        with tempfile.TemporaryDirectory() as directory:
            compiled = Path(directory) / "CartoRig Scene.lua"
            packager.package(compiled)
            content = compiled.read_text(encoding="utf-8")
            self.assertEqual(content.count("local Runtime = (function()"), 1)
            self.assertNotIn("@@EMBED_RUNTIME@@", content)
            self.assertIn('function M.add_marker(comp, name, lon, lat)', content)
            self.assertIn('function M.add_label(comp, name, lon, lat)', content)
            self.assertIn('function M.fade_in(comp, objectId, firstFrame, duration)', content)
            self.assertIn('function window.On.Create.Clicked(_)', content)
            self.assertIn('function window.On.Reveal.Clicked(_)', content)
            self.assertIn('dispatcher:RunLoop()', content)
            self.assertNotIn('os.execute(', content)
            self.assertNotIn('require("socket")', content)

    def test_packaging_is_reproducible(self):
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "one.lua"
            second = Path(directory) / "two.lua"
            packager.package(first)
            packager.package(second)
            self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_original_source_preserves_scene_without_auto_creation(self):
        source = packager.UI.read_text(encoding="utf-8")
        self.assertEqual(source.count("Runtime.create("), 1)
        self.assertIn("function window.On.Create.Clicked(_)", source)
        # Scene should not be created during UI startup.
        after_functions = source[source.index("sync()\nwindow:Show()"):]
        self.assertNotIn("Runtime.create(", after_functions)

    def test_installer_is_user_scope(self):
        script = (ROOT / "install/CartoRigAtomicFusionScene.iss").read_text("utf-8")
        self.assertIn("PrivilegesRequired=lowest", script)
        self.assertIn(r"Fusion\Scripts\Comp", script)
        self.assertIn("CartoRig Scene.lua", script)
        self.assertNotIn("PowerShell", script)
        self.assertNotIn("python", script.lower())


if __name__ == "__main__":
    unittest.main()
