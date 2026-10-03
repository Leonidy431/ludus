"""Tests of the twelve-sets generator (TABOO 0.032)."""

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "scenes"))
import multi_env_sets as gen  # noqa: E402

SPEC = json.loads((ROOT / "scripts" / "scenes" / "env_specs"
                   / "evening_cell_sample.json").read_text("utf-8"))


BAKED = ROOT / "scripts" / "scenes" / "baked" / "scene-sets-locations.json"


class LocationsBakeTest(unittest.TestCase):
    """Every place of the game has its sets, and the holy is not shaken."""

    @classmethod
    def setUpClass(cls):
        cls.bake = json.loads(BAKED.read_text("utf-8"))
        cls.places = json.loads((ROOT / "godot" / "data"
                                 / "locations-99.json").read_text("utf-8"))

    def test_all_99_places_are_bound(self):
        self.assertEqual(len(self.bake["envs"]), 99)
        for env in self.bake["envs"].values():
            if env["kind"] == "twelve":
                self.assertEqual(len(env["sets"]), 12)

    def test_holy_places_keep_one_set(self):
        for loc in self.places["locations"]:
            env = self.bake["envs"][loc["id"]]
            if loc.get("holy_place"):
                self.assertEqual(env["kind"], "holy_one_set")
                self.assertEqual(len(env["sets"]), 1)

    def test_every_mission_has_places(self):
        plots = {p for loc in self.places["locations"]
                 for p in loc.get("plots", [])}
        self.assertEqual(set(self.bake["missions"]), plots)

    def test_wall_things_never_move(self):
        for loc in self.places["locations"]:
            env = self.bake["envs"][loc["id"]]
            for k, slot in enumerate(loc["slots"]):
                if slot["mount"] not in gen_free():
                    iid = "%s#%d" % (slot["object"], k)
                    for st in env["sets"]:
                        self.assertEqual(st["items"][iid]["pos"],
                                         [round(v, 2) for v in slot["pos"]])


def gen_free():
    """The mounts whose things stand free and may be shaken."""
    return ("floor", "table", "stand", "seabed")


class MultiEnvSetsTest(unittest.TestCase):
    """The same spec and seed give the same twelve, and they are sound."""

    @classmethod
    def setUpClass(cls):
        cls.a = gen.build(SPEC, "t", 1200)
        cls.b = gen.build(SPEC, "t", 1200)

    def test_twelve_and_deterministic(self):
        self.assertEqual(len(self.a["sets"]), 12)
        self.assertEqual(json.dumps(self.a), json.dumps(self.b))

    def test_every_hour_is_covered(self):
        self.assertEqual(len(self.a["periods_covered"]), len(gen.PERIODS))

    def test_holy_never_moves(self):
        fixed = [i for i in SPEC["items"] if i.get("holy")][0]["fixed"]
        for s in self.a["sets"]:
            rec = s["items"]["icon_board"]
            self.assertEqual(rec["pos"], fixed["pos"])
            self.assertEqual(rec["yaw"], fixed["yaw"])

    def test_gravity_and_clear_heart(self):
        for s in self.a["sets"]:
            for iid, rec in s["items"].items():
                self.assertAlmostEqual(rec["box"][0][1], rec["pos"][1],
                                       delta=gen.GAP_MM / 1000.0)
                if iid == "icon_board":
                    continue
                cx = (rec["box"][0][0] + rec["box"][1][0]) / 2
                cz = (rec["box"][0][2] + rec["box"][1][2]) / 2
                hx, _, hz = SPEC["heart"]["at"]
                self.assertGreaterEqual(
                    ((cx - hx) ** 2 + (cz - hz) ** 2) ** 0.5,
                    SPEC["heart"]["clear_m"])

    def test_light_classes(self):
        for s in self.a["sets"]:
            self.assertTrue(1900 <= s["hearth_kelvin"] <= 2500)
            self.assertEqual(s["instrument_kelvin"], 6500)

    def test_a_bad_layout_is_refused(self):
        spec = json.loads(json.dumps(SPEC))
        spec["items_ids_holy"] = {i["id"]: bool(i.get("holy"))
                                  for i in spec["items"]}
        cand = gen.candidate(spec, "t", 3)
        cand["items"]["codex"]["box"] = [[-9.0, 0.0, 0.0], [-8.0, 1.0, 1.0]]
        self.assertTrue(gen.geometry_audit(spec, cand["items"]))


if __name__ == "__main__":
    unittest.main()
