#!/usr/bin/env python3
"""Ship the proxies the 99 locations use into the headset build.

The location builder (godot/scripts/location_core.gd) shows every wished
thing of godot/data/locations-99.json by its volume proxy (CLAUDE.md
TABOO 0.32).  Proxies the APK already carries (godot/models/obitel,
lake, atlas) are used where they are; the rest are copied from
public/vr/models/obj into godot/models/locations/, the .glb and its
.json beside it.  Only what the 99 locations use is copied, so the APK
carries nothing a scene does not show (TABOO 0.011).

Things still waiting for the props store (pending-raw) or for our own
drawing (pending-own) have no proxy; they are listed, never faked.

    python3 scripts/locations/ship_models.py          copy and report
    python3 scripts/locations/ship_models.py --check  fail when the
        folder differs from what the data asks (for CI)
"""

import filecmp
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'godot' / 'data' / 'locations-99.json'
SRC = ROOT / 'public' / 'vr' / 'models'
GODOT_MODELS = ROOT / 'godot' / 'models'
OUT = GODOT_MODELS / 'locations'

# Where the APK already carries a proxy of each source kind, as
# LocationsCore.model_path and LocationCore.model_path read it.
IN_APK = {
    'obj': lambda i: GODOT_MODELS / 'obitel' / f'{i}.glb',
    'lake': lambda i: GODOT_MODELS / 'lake' / (
        'lake-' + i.replace('.', '-') + '.glb'),
    'atlas': lambda i: GODOT_MODELS / 'atlas' / f'atlas-{i}.glb',
}
FROM = {
    'obj': lambda i: SRC / 'obj' / f'{i}.glb',
    'lake': lambda i: SRC / 'lake' / ('lake-' + i.replace('.', '-')
                                      + '.glb'),
    'atlas': lambda i: SRC / 'atlas' / f'atlas-{i}.glb',
}


def plan():
    """What must lie in godot/models/locations, and what has no proxy.

    Returns (wanted, pending): wanted maps a file name to its source,
    pending lists the thing keys still waiting for a model."""
    data = json.loads(DATA.read_text(encoding='utf-8'))
    wanted, pending = {}, []
    for key in sorted(data['things']):
        thing = data['things'][key]
        kind, _, ident = thing['source'].partition(':')
        if kind not in IN_APK:
            pending.append(key)
            continue
        if IN_APK[kind](ident).exists():
            continue
        glb = FROM[kind](ident)
        if not glb.exists():
            pending.append(key)
            continue
        wanted[glb.name] = glb
        meta = glb.with_suffix('.json')
        if meta.exists():
            wanted[meta.name] = meta
    return wanted, pending


def check(wanted):
    """Every wanted file is present and equal, and nothing else lies
    there (the .import files Godot writes are its own)."""
    errors = []
    for name, src in sorted(wanted.items()):
        dst = OUT / name
        if not dst.exists():
            errors.append(f'missing {name}')
        elif not filecmp.cmp(src, dst, shallow=False):
            errors.append(f'differs from {src.relative_to(ROOT)}: {name}')
    if OUT.exists():
        for f in sorted(OUT.iterdir()):
            if f.suffix == '.import':
                continue
            if f.name not in wanted:
                errors.append(f'not used by any location: {f.name}')
    return errors


def main(argv):
    wanted, pending = plan()
    if '--check' in argv:
        errors = check(wanted)
        for e in errors:
            print('ship_models:', e)
        if errors:
            return 1
        print('ship_models: godot/models/locations up to date '
              f'({len(wanted)} files)')
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    glbs = 0
    for name, src in sorted(wanted.items()):
        dst = OUT / name
        data = src.read_bytes()
        if not dst.exists() or dst.read_bytes() != data:
            dst.write_bytes(data)
        total += len(data)
        glbs += name.endswith('.glb')
    # A file no location uses goes, and with it the .import Godot wrote.
    for f in sorted(OUT.iterdir()):
        base = f.name[:-len('.import')] if f.suffix == '.import' \
            else f.name
        if base not in wanted:
            f.unlink()
    print(f'ship_models: {glbs} models, {len(wanted)} files, '
          f'{total} bytes in godot/models/locations')
    print(f'ship_models: {len(pending)} things without a proxy yet: '
          + ', '.join(pending))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
