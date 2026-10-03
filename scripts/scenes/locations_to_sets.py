"""Bind the twelve-sets technology to every mission's place (TABOO 0.032).

The 99 places of the game (godot/data/locations-99.json) carry the
missions: each place lists its plots.  This script turns every place's
own layout (its shell, its heart, its passage, its slots) into an
environment spec, runs scripts/scenes/multi_env_sets.py on it and bakes
twelve sets per place.  A place with a holy thing at its heart (the
kayrak and its kin) keeps ONE set, the base layout, and nothing about it
is shaken (TABOO 0.4, 0.032 item 4).

What moves is only the looks of the things that stand free (on the
floor, a table, a stand or the seabed): where, how turned, how big
(0.92..1.08, an echo 0.40..0.70) and in which palette; plus the hour, the
light and the camera.  Things on a wall, the heart and the holy stay as
the layout fixed them.  Everything is seeded and made at build time.

The output stays outside the APK (packs, TABOO 0.018): about 0.4 MB for
99 places, compact (centimetres, no boxes).

Usage:
    python3 scripts/scenes/locations_to_sets.py \\
        --out scripts/scenes/baked/scene-sets-locations.json
"""

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import multi_env_sets as gen  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "godot" / "data" / "locations-99.json"
FREE = ("floor", "table", "stand", "seabed")
LAMPS = re.compile(r"lamp|lantern|candle|torch", re.I)
# Eight depths stand in for the hours under water (the sun does not
# reach the same way): elevation 0, a cooler colour, less light.
UNDERWATER = [("d05", 0.0, 7200, 0.90), ("d10", 0.0, 7000, 0.75),
              ("d20", 0.0, 6800, 0.60), ("d30", 0.0, 6500, 0.45),
              ("d40", 0.0, 6300, 0.35), ("d50", 0.0, 6100, 0.25),
              ("d60", 0.0, 6000, 0.18), ("d80", 0.0, 5800, 0.10)]
PALETTES = {
    "дерево": [[0.42, 0.29, 0.17], [0.55, 0.40, 0.25]],
    "камень": [[0.50, 0.50, 0.48], [0.38, 0.38, 0.36]],
    "металл": [[0.62, 0.64, 0.66], [0.45, 0.40, 0.30]],
    "ткань": [[0.62, 0.50, 0.38], [0.45, 0.30, 0.28]],
    "глина": [[0.62, 0.38, 0.25], [0.50, 0.36, 0.28]],
    "кожа": [[0.38, 0.24, 0.16], [0.30, 0.20, 0.14]],
    "бумага": [[0.80, 0.72, 0.56], [0.70, 0.62, 0.48]],
}
NEUTRAL = [[0.55, 0.45, 0.35], [0.40, 0.34, 0.28]]


def palettes_for(material):
    """Two palettes for a thing's material (Russian word in the data)."""
    low = str(material or "").lower()
    for word, pal in PALETTES.items():
        if word in low:
            return pal
    return NEUTRAL


def spec_of(loc, things):
    """An environment spec from one place's own layout."""
    sh = loc["shell"]
    w, d, h = sh["size_m"]
    room = {"min": [-w / 2, 0.0, -d / 2], "max": [w / 2, max(h, 2.4), d / 2]}
    underwater = sh["type"] == "underwater"
    spec = {"id": loc["id"], "room": room,
            "wall_rgb": [0.55, 0.50, 0.45],
            "heart": {"at": sh["heart_at"], "clear_m": 0.75},
            "no_go": [], "surfaces": [], "items": []}
    if underwater:
        spec["periods"] = UNDERWATER
    px0, pz0, px1, pz1 = sh.get("passage", [0, 0, 0, 0])
    if px1 > px0 and pz1 > pz0:
        spec["no_go"].append({"id": "passage", "min": [px0, 0.0, pz0],
                              "max": [px1, 2.1, pz1]})
    ex, _, ez = sh.get("entrance", [0, 0, 0])
    spec["no_go"].append({"id": "entrance", "min": [ex - 0.8, 0.0, ez - 0.8],
                          "max": [ex + 0.8, 2.1, ez + 0.8]})
    spec["surfaces"].append({
        "id": "floor", "top": 0.0, "min": [room["min"][0], room["min"][2]],
        "max": [room["max"][0], room["max"][2]],
        "rgb": [0.35, 0.33, 0.25] if underwater else [0.30, 0.25, 0.18]})
    tables = [s for s in loc["slots"] if s["mount"] == "table"]
    if tables:
        xs = [s["pos"][0] for s in tables]
        zs = [s["pos"][2] for s in tables]
        ys = sorted(s["pos"][1] for s in tables)
        spec["surfaces"].append({
            "id": "table", "top": ys[len(ys) // 2], "rgb": [0.50, 0.36, 0.24],
            "min": [max(min(xs) - 0.45, room["min"][0]),
                    max(min(zs) - 0.45, room["min"][2])],
            "max": [min(max(xs) + 0.45, room["max"][0]),
                    min(max(zs) + 0.45, room["max"][2])]})
    holy_ids = set()
    for k, slot in enumerate(loc["slots"]):
        thing = things.get(slot["object"], {})
        size = thing.get("size_m", [0.3, 0.3, 0.3])
        holy = slot["mount"] == "holy" or bool(thing.get("holy"))
        item = {"id": "%s#%d" % (slot["object"], k), "size": size,
                "palettes": palettes_for(thing.get("material"))}
        if slot["mount"] in FREE and not holy:
            item["surface"] = "table" if slot["mount"] == "table" \
                else "floor"
            if LAMPS.search(slot["object"]) and not underwater:
                item["light"] = "hearth"
                item["lit_periods"] = ["dawn_blue", "dusk", "night"]
        else:
            item["fixed"] = {"pos": slot["pos"], "yaw": slot.get("yaw", 0),
                             "scale": 1.0}
            item["surface"] = "wall"
            item["holy"] = holy
        if holy:
            holy_ids.add(item["id"])
        spec["items"].append(item)
    return spec, bool(loc.get("holy_place")) or bool(holy_ids)


def base_set(spec):
    """The layout as it is, for a place where nothing may be shaken."""
    items = {}
    for it in spec["items"]:
        fx = it.get("fixed")
        pos = fx["pos"] if fx else [0.0, 0.0, 0.0]
        items[it["id"]] = {"pos": pos, "yaw": fx["yaw"] if fx else 0.0,
                           "scale": 1.0, "palette": 0}
    return {"index": 0, "period": "base", "items": items}


def compact(env):
    """Smaller for a pack: centimetres, no boxes, short keys kept."""
    out = []
    for s in env["sets"]:
        items = {}
        for iid, r in s["items"].items():
            items[iid] = {"pos": [round(v, 2) for v in r["pos"]],
                          "yaw": round(r["yaw"]), "scale": r["scale"],
                          "palette": r.get("palette", 0)}
            if r.get("lit"):
                items[iid]["lit"] = True
        row = {k: v for k, v in s.items() if k != "items"}
        row["items"] = items
        out.append(row)
    return out


def main(argv):
    """Bake every place and write one pack file."""
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", default="ludus-1375")
    ap.add_argument("--tries", type=int, default=1500)
    args = ap.parse_args(argv)
    data = json.loads(DATA.read_text(encoding="utf-8"))
    things = data["things"]
    envs, missions, skipped = {}, {}, {}
    for loc in data["locations"]:
        spec, holy = spec_of(loc, things)
        if holy:
            envs[loc["id"]] = {"kind": "holy_one_set",
                               "sets": [base_set(spec)]}
        else:
            try:
                built = gen.build(spec, args.seed, args.tries)
            except SystemExit as err:
                skipped[loc["id"]] = str(err)
                envs[loc["id"]] = {"kind": "base_only",
                                   "sets": [base_set(spec)]}
                continue
            envs[loc["id"]] = {"kind": "twelve", "accepted": built[
                "accepted"], "refused": built["refused"],
                "sets": compact(built)}
        for plot in loc.get("plots", []):
            missions.setdefault(plot, []).append(loc["id"])
    out = {"version": 1, "note": "Twelve sets per place, bound to every "
           "mission by its places (TABOO 0.032). Outside the APK.",
           "seed": args.seed, "missions": missions, "skipped": skipped,
           "envs": envs}
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(
        out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    kinds = {}
    for e in envs.values():
        kinds[e["kind"]] = kinds.get(e["kind"], 0) + 1
    print("places %d, missions %d, kinds %s, skipped %d"
          % (len(envs), len(missions), kinds, len(skipped)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
