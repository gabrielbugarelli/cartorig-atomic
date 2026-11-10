"""Guard CartoRig Scene's native Fusion tab navigation and object authority.

This is a static architectural test, not a DaVinci Resolve UI screenshot test.
"""
from __future__ import annotations

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "fusion/CartoRig Scene.lua"

PAGES = ("Objects", "Find", "Routes", "Camera", "Groups")
PAGE_IDS = {
    "Objects": ("Objects", "Reveal", "Rename", "MoveUp", "MoveDown",
                "Show", "Hide", "Lock", "Unlock", "Delete"),
    "Find": ("Search", "SearchResults", "LocationFilter", "AddFoundRegion",
             "AddFoundMarker", "AddFoundLabel", "Marker", "Label"),
    "Routes": ("RouteStyle", "CreateRoute", "UseRouteFrom",
               "UseRouteState", "UseRouteArrival", "FollowerMarker"),
    "Camera": ("SelectBase", "SelectCamera", "DisplayMode", "SetMode",
               "SetFlyTarget", "SetFitTarget", "Zoom", "Focus"),
    "Groups": ("StageGroup", "ClearGroupStage", "Group", "Ungroup",
               "ExistingGroups"),
}


class FusionSceneNavigationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.code = SCRIPT.read_text(encoding="utf-8")
        cls.ui = cls.code.split("local window = dispatcher:AddWindow(", 1)[1].split(
            "\nif not window then", 1
        )[0]

    def test_five_focused_native_tabs(self):
        self.assertIn('ui:TabBar{ ID = "SceneTabs"', self.ui)
        self.assertIn('ui:Stack{\n        ID = "ScenePages"', self.ui)
        for page in PAGES:
            self.assertIn(f'ID = "ScenePage{page}"', self.ui)
            self.assertIn(f'items.SceneTabs:AddTab(label)', self.code)
        self.assertIn(
            '{ "Objects", "Find", "Routes", "Camera", "Groups" }', self.code
        )
        self.assertIn('window.On.SceneTabs.CurrentChanged(ev)', self.code)
        self.assertIn('items.ScenePages.CurrentIndex = index', self.code)

    def test_all_widget_ids_unique_and_existing_events_connected(self):
        ids = re.findall(r'\bID\s*=\s*"([^"]+)"', self.ui)
        self.assertEqual(len(ids), len(set(ids)), "Widget IDs must be unique")
        present = set(ids)
        for page in PAGES:
            for required_id in PAGE_IDS[page]:
                self.assertIn(required_id, present)
        actions = set(
            re.findall(r'function window\.On\.([A-Za-z0-9]+)\.Clicked\(', self.code)
        )
        self.assertFalse(actions - present, f"Orphan button events: {actions - present}")

    def test_each_control_is_in_its_own_section(self):
        for i, page in enumerate(PAGES):
            start = self.ui.index(f'ID = "ScenePage{page}"')
            end = (self.ui.index(f'ID = "ScenePage{PAGES[i+1]}"')
                   if i+1 < len(PAGES) else self.ui.index('ID = "Feedback"'))
            section = self.ui[start:end]
            for widget in PAGE_IDS[page]:
                self.assertIn(f'ID = "{widget}"', section,
                              f"{widget} belongs on {page}")
        self.assertLess(
            self.ui.index('ID = "SceneTabs"'),
            self.ui.index('ID = "ScenePages"')
        )
        self.assertGreater(self.ui.index('ID = "Feedback"'),
                           self.ui.index('ID = "ScenePageGroups"'))

    def test_object_combobox_selects_real_host_tool_and_handles_foreign_node(self):
        self.assertIn('window.On.Objects.CurrentIndexChanged(_)', self.code)
        self.assertIn('pcall(Runtime.select, current, id)', self.code)
        self.assertIn('pcall(Runtime.active_selection, current)', self.code)
        self.assertIn('selectionStatus = "OBJECT"', self.code)
        self.assertIn('selectionStatus == "NON_CARTORIG"', self.code)
        self.assertIn('items.Objects.CurrentIndex = -1', self.code)
        self.assertIn('updatingScene = false', self.code)
        self.assertIn('if updatingScene then return end', self.code)
        self.assertIn('NON_CARTORIG_SELECTION:', self.code)

    def test_new_objects_reveal_in_fusion_without_selecting_group_as_tool(self):
        self.assertIn('if object.id == result then', self.code)
        self.assertIn('local chosen = pcall(Runtime.select, current, result)', self.code)
        self.assertIn('selectedObjectId = result', self.code)
        self.assertIn('pendingDelete = nil', self.code)

    def test_scene_does_not_provide_duplicate_timeline_or_motion_editor(self):
        self.assertNotIn('ID = "StartFrame"', self.ui)
        self.assertNotIn('ID = "Duration"', self.ui)
        self.assertNotIn('ID = "FakeSpline"', self.ui)
        self.assertIn('Reveal in Fusion Inspector', self.ui)


if __name__ == "__main__":
    unittest.main()
