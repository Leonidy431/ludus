"""Twelve ready sets for one scene (TABOO 0.032, docs/tech/MULTI_ENV_SETS_
2026-10-03.md).

One base scene is described by a spec (room, surfaces, items, light
classes).  The generator shakes it at BUILD time, keeps only what the
chorus and the geometry audit accept, and bakes exactly twelve sets into
JSON: the hour and its light, the camera, and where every item stands.
The game and the video renderer only read the JSON; nothing is random
at run time.

Randomness is a seed, never the clock: the same spec and seed give the
same twelve sets, byte for byte.  It touches looks only; the heart of
the place, the exits, the clues and every holy thing stay where the spec
puts them.

Geometry audit (our engine has no physics, TABOO 0.016 item 3):
    1. no rigid bodies: only axis-aligned boxes and scalars;
    2. absolute gravity: each item's lowest face is set on the highest
       surface under its centre (a vertical scan over boxes, not a
       physics ray), and an item that overhangs its surface or crosses a
       wall, a passage or the heart's free circle is thrown out;
    3. no run-time randomness.

Usage:
    python3 scripts/scenes/multi_env_sets.py \\
        --spec scripts/scenes/env_specs/evening_cell_sample.json \\
        --out godot/data/scene-sets.json
"""

import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path

SETS = 12
DRAWS = 60
GAP_MM = 5.0
# Named periods of the day: sun elevation (degrees), the sun's colour
# temperature, and how much light reaches the room (0..1).  Human fire
# stays 1900..2500 K and the instrument 6500 K whatever the hour; the
# lampada's 1800 K belongs to the holy and is never generated here
# (TABOO 0.038 item 1 of the style bible).
PERIODS = [
    ("dawn_blue", -4.0, 7500, 0.18), ("sunrise", 3.0, 3200, 0.45),
    ("morning", 25.0, 5000, 0.80), ("noon", 60.0, 5600, 1.00),
    ("afternoon", 35.0, 4800, 0.85), ("golden", 8.0, 3000, 0.55),
    ("dusk", -3.0, 5500, 0.20), ("night", -30.0, 4100, 0.06),
]
HEARTH_K = (1900, 2500)
INSTRUMENT_K = 6500
ECHO_SCALE = (0.40, 0.70)
PLAIN_SCALE = (0.92, 1.08)
LAMP_BOOST = 0.55
LAMP_REACH_M = 1.3
NOISE_FLOOR = 0.03
MIN_CONTRAST = 0.22
MAX_HORIZON_TILT = 8.0


def kelvin_rgb(kelvin):
    """Approximate a black body's colour as 0..1 RGB (Tanner Helland)."""
    t = kelvin / 100.0
    if t <= 66:
        r = 255.0
        g = 99.4708025861 * math.log(t) - 161.1195681661
    else:
        r = 329.698727446 * (t - 60) ** -0.1332047592
        g = 288.1221695283 * (t - 60) ** -0.0755148492
    if t >= 66:
        b = 255.0
    elif t <= 19:
        b = 0.0
    else:
        b = 138.5177312231 * math.log(t - 10) - 305.0447927307
    return [round(min(max(v, 0.0), 255.0) / 255.0, 3) for v in (r, g, b)]


def luminance(rgb):
    """Relative luminance of a linear-ish RGB triple."""
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def make_rng(*parts):
    """A seeded generator: the seed is a hash of its parts, not a clock."""
    digest = hashlib.sha256("|".join(map(str, parts)).encode()).digest()
    return random.Random(int.from_bytes(digest[:8], "big"))


def surface_by_id(spec, sid):
    """The surface record called `sid`, or None (a wall, for instance)."""
    for s in spec["surfaces"]:
        if s["id"] == sid:
            return s
    return None


def item_box(item, pos, yaw, scale):
    """Axis-aligned box (min, max) of an item turned by `yaw` degrees.

    `pos` is the middle of the item's bottom face.  The footprint of a
    turned box is widened to its bounding rectangle, which is the AABB
    the audit works with.
    """
    sx, sy, sz = (v * scale for v in item["size"])
    a = math.radians(yaw)
    w = abs(math.cos(a)) * sx + abs(math.sin(a)) * sz
    d = abs(math.sin(a)) * sx + abs(math.cos(a)) * sz
    lo = [pos[0] - w / 2, pos[1], pos[2] - d / 2]
    hi = [pos[0] + w / 2, pos[1] + sy, pos[2] + d / 2]
    return lo, hi


def overlaps(a, b):
    """Do two axis-aligned boxes cross each other?"""
    return all(a[0][i] < b[1][i] and b[0][i] < a[1][i] for i in range(3))


def inside(box, room):
    """Is the box wholly inside the room's box?"""
    return all(box[0][i] >= room["min"][i] - 1e-9
               and box[1][i] <= room["max"][i] + 1e-9 for i in range(3))


def land(spec, item, pos_xz, yaw, scale):
    """Set an item on the highest surface under its middle.

    Returns the placed record, or None when the item overhangs its
    surface (the vertical scan is a scan over boxes, not a physics ray).
    """
    surf = surface_by_id(spec, item["surface"])
    if surf is None:
        return None
    probe = item_box(item, [pos_xz[0], 0.0, pos_xz[1]], yaw, scale)
    for i, ax in enumerate((0, 2)):
        lo, hi = surf["min"][i], surf["max"][i]
        if probe[0][ax] < lo - 1e-9 or probe[1][ax] > hi + 1e-9:
            return None
    pos = [pos_xz[0], surf["top"], pos_xz[1]]
    return {"pos": [round(v, 3) for v in pos], "yaw": round(yaw, 1),
            "scale": round(scale, 3), "box": item_box(item, pos, yaw, scale)}


def clear_so_far(spec, placed, rec):
    """Does a new item keep clear of the room's walls, the passages,
    the heart's free circle and everything placed before it?"""
    box = rec["box"]
    if not inside(box, spec["room"]):
        return False
    if any(overlaps(box, (z["min"], z["max"])) for z in spec["no_go"]):
        return False
    hx, _, hz = spec["heart"]["at"]
    cx, cz = (box[0][0] + box[1][0]) / 2, (box[0][2] + box[1][2]) / 2
    if math.hypot(cx - hx, cz - hz) < spec["heart"]["clear_m"]:
        return False
    return not any(overlaps(box, other["box"]) for other in placed.values())


def draw_item(spec, rng, item, period):
    """One draw of an item's place, turn and size inside its own slot.

    The middle may only wander where half of the turned box still fits
    on the surface, so nothing overhangs.  Returns the record or None.
    """
    surf = surface_by_id(spec, item["surface"])
    lo, hi = ECHO_SCALE if item.get("echo") else PLAIN_SCALE
    scale = rng.uniform(lo, hi)
    yaw = rng.uniform(-180.0, 180.0)
    probe = item_box(item, [0.0, 0.0, 0.0], yaw, scale)
    hw = (probe[1][0] - probe[0][0]) / 2
    hd = (probe[1][2] - probe[0][2]) / 2
    if surf["min"][0] + hw > surf["max"][0] - hw \
            or surf["min"][1] + hd > surf["max"][1] - hd:
        return None
    x = rng.uniform(surf["min"][0] + hw, surf["max"][0] - hw)
    z = rng.uniform(surf["min"][1] + hd, surf["max"][1] - hd)
    rec = land(spec, item, (x, z), yaw, scale)
    if rec is None:
        return None
    rec["palette"] = rng.randrange(len(item["palettes"]))
    rec["lit"] = bool(item.get("light") == "hearth"
                      and period in item.get("lit_periods", []))
    return rec


def place_items(spec, rng, period):
    """Place every item one after another, each with a few tries.

    The holy comes first and stays as the spec fixed it.  An item that
    finds no clear place in DRAWS tries ends the candidate (None).
    """
    placed = {}
    for item in spec["items"]:
        if item.get("holy"):
            fx = item["fixed"]
            placed[item["id"]] = {
                "pos": fx["pos"], "yaw": fx["yaw"], "scale": fx["scale"],
                "box": item_box(item, fx["pos"], fx["yaw"], fx["scale"]),
                "palette": 0}
    for item in spec["items"]:
        if item.get("holy"):
            continue
        for _ in range(DRAWS):
            rec = draw_item(spec, rng, item, period)
            if rec is not None and clear_so_far(spec, placed, rec):
                placed[item["id"]] = rec
                break
        else:
            return None
    return placed


def geometry_audit(spec, placed):
    """TABOO 1..2: boxes only, walls, passages, heart, no overlaps."""
    boxes = [(i, r["box"]) for i, r in placed.items()]
    for iid, box in boxes:
        if not inside(box, spec["room"]):
            return "wall:" + iid
        for zone in spec["no_go"]:
            if overlaps(box, (zone["min"], zone["max"])):
                return "passage:" + iid
        hx, _, hz = spec["heart"]["at"]
        cx, cz = (box[0][0] + box[1][0]) / 2, (box[0][2] + box[1][2]) / 2
        if not spec["items_ids_holy"].get(iid) and math.hypot(
                cx - hx, cz - hz) < spec["heart"]["clear_m"]:
            return "heart:" + iid
    for k, (ia, a) in enumerate(boxes):
        for ib, b in boxes[k + 1:]:
            if overlaps(a, b):
                return "overlap:%s/%s" % (ia, ib)
    return None


def lit_intensity(placed, iid, period_light):
    """Light reaching an item: the hour's, plus a lit lamp close by."""
    me = placed[iid]["pos"]
    extra = 0.0
    for lid, rec in placed.items():
        if rec.get("lit") and math.hypot(
                rec["pos"][0] - me[0], rec["pos"][2] - me[2]) < LAMP_REACH_M:
            extra = LAMP_BOOST
    return min(period_light + extra, 1.0)


def readable(spec, placed, item, level):
    """Does the item's silhouette read in this light (art director)?"""
    rec = placed[item["id"]]
    rgb = item["palettes"][rec["palette"]]
    inten = lit_intensity(placed, item["id"], level)
    # The item is read against what it stands on, not against a wall.
    back = surface_by_id(spec, item["surface"]) or {}
    wall = luminance(back.get("rgb", spec["wall_rgb"]))
    la, lb = luminance(rgb) * inten, wall * inten
    return abs(la - lb) / (max(la, lb) + NOISE_FLOOR) >= MIN_CONTRAST


def dress(spec, placed, level):
    """Give each item the first palette that reads in this light.

    The chorus judges the whole candidate afterwards; this only spares
    a good layout from being thrown away for one unlucky colour.
    """
    for item in spec["items"]:
        if item.get("holy"):
            continue
        rec = placed[item["id"]]
        for step in range(len(item["palettes"])):
            rec["palette"] = (rec["palette"] + step) % len(item["palettes"])
            if readable(spec, placed, item, level):
                break


def chorus_check(spec, cand):
    """The chorus: four voices judge a candidate; the first no stops it.

    Returns (voice, reason) of the refusal, or None when all agree.
    """
    placed, period_light = cand["items"], cand["light_level"]
    for item in spec["items"]:
        rec = placed[item["id"]]
        # Art director: the silhouette must read in this light.
        # Only what the story needs must read; the rest may sink into
        # the shade, as things do in a dark room.
        if item.get("holy") or not item.get("key"):
            continue
        if not readable(spec, placed, item, period_light):
            return "art_director", "silhouette:" + item["id"]
        # Narrative editor: a lit lamp needs its hours; an echo is small.
        if item.get("light") == "hearth" and (
                rec["lit"] != (cand["period"] in item["lit_periods"])):
            return "narrative_editor", "lamp:" + item["id"]
        if item.get("echo") and not ECHO_SCALE[0] <= rec["scale"] \
                <= ECHO_SCALE[1] + 1e-9:
            return "narrative_editor", "echo:" + item["id"]
    # VR comfort: the horizon stays near level.
    if abs(cand["camera"]["roll"]) > MAX_HORIZON_TILT:
        return "vr_comfort", "horizon"
    # Catechist: the holy is exactly as the spec fixed it.
    for item in spec["items"]:
        if item.get("holy"):
            fx, rec = item["fixed"], placed[item["id"]]
            if rec["pos"] != fx["pos"] or rec["yaw"] != fx["yaw"] \
                    or rec["scale"] != fx["scale"]:
                return "catechist", "holy_moved:" + item["id"]
    return None


def candidate(spec, seed, n):
    """One shaken candidate (a time, a camera, a light, a layout)."""
    rng = make_rng(spec["id"], seed, n)
    pi = rng.randrange(len(PERIODS))
    name, elev, sun_k, level = PERIODS[pi]
    placed = place_items(spec, rng, name)
    if placed is None:
        return None
    level = round(level * rng.uniform(0.85, 1.0), 3)
    dress(spec, placed, level)
    cand = {
        "period": name, "period_index": pi,
        "sun": {"elevation": elev, "kelvin": sun_k,
                "rgb": kelvin_rgb(sun_k)},
        "light_level": level,
        "hearth_kelvin": rng.randrange(HEARTH_K[0], HEARTH_K[1] + 1, 50),
        "instrument_kelvin": INSTRUMENT_K,
        "camera": {"pos": [round(rng.uniform(-1.8, 1.8), 2),
                           round(rng.uniform(1.1, 1.8), 2),
                           round(rng.uniform(-1.4, 1.4), 2)],
                   "yaw": round(rng.uniform(-180.0, 180.0), 1),
                   "pitch": round(rng.uniform(-18.0, 8.0), 1),
                   "roll": round(rng.uniform(-10.0, 10.0), 1),
                   "lens_mm": rng.choice([18, 24, 28, 35, 50])},
        "items": placed,
    }
    cand["hearth_rgb"] = kelvin_rgb(cand["hearth_kelvin"])
    cand["instrument_rgb"] = kelvin_rgb(INSTRUMENT_K)
    return cand


def feature(cand):
    """A short vector that says how a candidate differs from others."""
    moved = [v["pos"][0] for k, v in cand["items"].items()
             if not k.startswith("icon")]
    return [cand["period_index"] / 7.0, cand["camera"]["yaw"] / 180.0,
            cand["camera"]["pitch"] / 20.0,
            sum(moved) / (2.5 * max(len(moved), 1))]


def pick_twelve(cands):
    """Twelve far-apart candidates, chosen the same way every time."""
    feats = [feature(c) for c in cands]
    # First one set for every hour of the day that was accepted, so the
    # walk passes through the whole day; then the farthest candidates.
    chosen = []
    for name, _, _, _ in PERIODS:
        pool = [i for i in range(len(cands)) if cands[i]["period"] == name]
        if pool and len(chosen) < SETS:
            chosen.append(min(pool, key=lambda i: json.dumps(feats[i])))
    while len(chosen) < SETS:
        best, best_d = None, -1.0
        for i in range(len(cands)):
            if i in chosen:
                continue
            d = min(math.dist(feats[i], feats[j]) for j in chosen)
            if d > best_d:
                best, best_d = i, d
        chosen.append(best)
    return [cands[i] for i in chosen]


def build(spec, seed, tries):
    """Shake, audit, judge and bake the twelve sets of one environment."""
    spec = dict(spec)
    spec["items_ids_holy"] = {i["id"]: bool(i.get("holy"))
                              for i in spec["items"]}
    accepted, refused = [], {}
    for n in range(tries):
        cand = candidate(spec, seed, n)
        if cand is None:
            refused["overhang"] = refused.get("overhang", 0) + 1
            continue
        why = geometry_audit(spec, cand["items"])
        if why:
            key = "geometry:" + why.split(":")[0]
            refused[key] = refused.get(key, 0) + 1
            continue
        verdict = chorus_check(spec, cand)
        if verdict:
            key = "chorus:%s:%s" % (verdict[0], verdict[1].split(":")[0])
            refused[key] = refused.get(key, 0) + 1
            continue
        accepted.append(cand)
    if len(accepted) < SETS:
        raise SystemExit("only %d candidates passed; need %d"
                         % (len(accepted), SETS))
    sets = pick_twelve(accepted)
    for i, s in enumerate(sets):
        s["index"] = i
        for rec in s["items"].values():
            rec["box"] = [[round(v, 3) for v in rec["box"][0]],
                          [round(v, 3) for v in rec["box"][1]]]
    return {"env": spec["id"], "seed": seed, "generator":
            "scripts/scenes/multi_env_sets.py", "tries": tries,
            "accepted": len(accepted), "refused": refused,
            "periods_covered": sorted({s["period"] for s in sets}),
            "sets": sets}


def main(argv):
    """Read the spec, bake the sets, write the JSON."""
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--spec", required=True)
    ap.add_argument("--seed", default="ludus-1375")
    ap.add_argument("--tries", type=int, default=3000)
    ap.add_argument("--out", required=True)
    args = ap.parse_args(argv)
    spec = json.loads(Path(args.spec).read_text(encoding="utf-8"))
    out = Path(args.out)
    envs = {}
    if out.exists():
        envs = json.loads(out.read_text(encoding="utf-8")).get("envs", {})
    envs[spec["id"]] = build(spec, args.seed, args.tries)
    out.write_text(json.dumps({"version": 1, "envs": envs},
                              ensure_ascii=False, separators=(",", ":")),
                   encoding="utf-8")
    e = envs[spec["id"]]
    print("%s: %d accepted of %d, refused %s, periods %s"
          % (spec["id"], e["accepted"], e["tries"], e["refused"],
             e["periods_covered"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
