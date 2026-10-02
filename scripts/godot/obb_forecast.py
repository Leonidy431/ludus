"""Forecast of the headset build's weight: when do we need an OBB?

The operator asked (2026-10-02) how much the planned voices, choir and
music would weigh and in which phase the APK meets the store's limit,
so that an OBB (a second data file beside the APK) is planned by
measurement, not by guess.  This script answers with numbers that come
from the repository or from named assumptions, never from the eye:

* what the build holds now: the APK sizes are read from a measured APK
  (--apk) or taken from the CI gate of the last measured build;
* the text the voices would speak: counted in godot/data/
  dialogue-trees.json (every NPC line, Russian and English);
* the music and the choir: the plan of docs/SOUND_DESIGN_SYSTEM.md
  section 9.1 (count and length of each kind of track);
* the models: the .glb files under godot/ measured on disk.

Every assumption (speech rate, bitrate, model size when final) is a
named constant with its reason, and the report prints them, so a
specialist can change one and run it again.

Run: python3 scripts/godot/obb_forecast.py [--apk PATH] [--json OUT]

Constitution: ФОРМА (what the headset can carry: APK, OBB, memory) →
ДЕЙСТВИЕ (weigh the planned voices, choir and models before they are
recorded) → ЦЕЛЬ (the teaching reaches the headset whole, and nothing
is cut late for lack of room).
"""

import argparse
import json
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))

MIB = 1024 ** 2
# The store's limit for one APK and for its one OBB (Meta, "Publish an
# APK": the APK may be up to 1 GB; one expansion file up to 4 GB;
# docs/APK_REQUIREMENTS.md lines 42-43).  "GB" is read as 10^9 bytes,
# the stricter reading.
STORE_APK = 1_000_000_000
STORE_OBB = 4_000_000_000
# The project's own APK budget (scripts/godot/apk-budgets.json, row 1).
OWN_APK = 128 * MIB

# The last APK measured by the CI gate when no --apk is given: job
# android 110851594608, commit 3c85b1f, step "Budgets of the headset
# build (APK)", 2026-10-02.
CI_APK = {
    'source': 'CI android 110851594608 (3c85b1f), check_budgets --apk',
    'apk': 105_071_800,
    'lib_so': 83_393_888,
    'dex': 6_089_556,
    'assets_uncompressed': 17_895_260,
    'assets_compressed': 15_076_439,
}

# Speech: words a second of calm, clear Russian speech for a headset
# (slower than a radio host so a listener can follow in VR), and the
# breath left between two lines.  Assumptions, not measurements: the
# first recorded takes replace them.
WORDS_PER_SEC = 2.2
PAUSE_PER_LINE_SEC = 0.6

# Bitrates in kilobits a second (1 kbit = 1000 bit).  Ogg Vorbis keeps
# its size in the Godot build (it is imported as is and decoded while
# playing).  QOA (Godot's WAV compression since 4.3) is 3.2 bits a
# sample: 141.1 kbit/s a channel at 44.1 kHz.
KBPS = {
    'voice_mono_vorbis': 64,
    'music_stereo_vorbis': 160,
    'choir_stereo_vorbis': 192,
    'sfx_mono_qoa': 3.2 * 44.1,
}

# The plan of docs/SOUND_DESIGN_SYSTEM.md section 9.1: (count, shortest
# and longest minutes).  The plan's own note says the kinds overlap to
# about 40 unique tracks; the list in full is the upper bound.  Bells
# and the ison stay procedural (TABOO 0.35 items 8-10) and weigh 0.
MUSIC_PLAN = {
    'ambient': (12, 3.0, 6.0),
    'npc_themes': (8, 1.5, 3.0),
    'gate_themes': (6, 2.0, 3.0),
    'attribute_themes': (9, 1.5, 2.0),
    'story_moments': (8, 2.0, 4.0),
    'soloist': (8, 2.0, 4.0),
}
CHOIR_PLAN = (12, 2.0, 6.0)
UNIQUE_TRACKS = 40
# Section 9.2: 60 + 30 + 15 sounds; a recorded sound lasts about 2.5 s.
SFX_COUNT = 105
SFX_SEC = 2.5

# A final model (TABOO 0.32 item 2: "lod": "final" replaces the proxy):
# geometry up to 20 000 triangles at about 40 bytes a triangle
# (positions, normals, uv, indices in a .glb), and one 1024 x 1024
# texture set, colour and normal, in ETC2 with mipmaps (1 byte a pixel,
# x 4/3 for the mips, two maps).  Assumptions for a forecast.
FINAL_TRIS = 20_000
BYTES_PER_TRI = 40
TEXTURE_BYTES = int(2 * 1024 * 1024 * 4 / 3)


def apk_now(path):
    """Sizes of the build now: from an APK on disk, or the CI gate."""
    if not path:
        return dict(CI_APK)
    out = {'source': path, 'apk': os.path.getsize(path), 'lib_so': 0,
           'dex': 0, 'assets_uncompressed': 0, 'assets_compressed': 0}
    with zipfile.ZipFile(path) as z:
        for i in z.infolist():
            if i.filename.startswith('lib/') and i.filename.endswith('.so'):
                out['lib_so'] += i.file_size
            elif i.filename.startswith('classes') and \
                    i.filename.endswith('.dex'):
                out['dex'] += i.file_size
            elif i.filename.startswith('assets/'):
                out['assets_uncompressed'] += i.file_size
                out['assets_compressed'] += i.compress_size
    return out


def dialogue_text():
    """Words and lines of the NPC lines, Russian and English."""
    path = os.path.join(ROOT, 'godot', 'data', 'dialogue-trees.json')
    with open(path, encoding='utf-8') as f:
        trees = json.load(f)['trees']
    lines = ru = en = 0
    for tree in trees.values():
        for node in tree['nodes']:
            lines += 1
            ru += len((node.get('text_ru') or '').split())
            en += len((node.get('text') or '').split())
    return {'trees': len(trees), 'lines': lines, 'words_ru': ru,
            'words_en': en}


def models_now():
    """The .glb files the headset project holds, measured on disk."""
    count = size = 0
    base = os.path.join(ROOT, 'godot')
    for dirpath, dirnames, files in os.walk(base):
        if '.godot' in dirpath.split(os.sep):
            continue
        for name in files:
            if name.endswith('.glb'):
                count += 1
                size += os.path.getsize(os.path.join(dirpath, name))
    return {'count': count, 'bytes': size}


def kbps_bytes(kbps, seconds):
    return int(kbps * 1000 / 8 * seconds)


def speech_seconds(words, lines):
    return words / WORDS_PER_SEC + lines * PAUSE_PER_LINE_SEC


def forecast(apk_path):
    apk = apk_now(apk_path)
    text = dialogue_text()
    models = models_now()

    voice_sec = speech_seconds(text['words_ru'], text['lines'])
    voice = kbps_bytes(KBPS['voice_mono_vorbis'], voice_sec)
    voice_en = kbps_bytes(KBPS['voice_mono_vorbis'],
                          speech_seconds(text['words_en'], text['lines']))

    music = {}
    for k, (n, lo, hi) in MUSIC_PLAN.items():
        music[k] = {
            'count': n,
            'min_minutes': n * lo, 'max_minutes': n * hi,
            'min_bytes': kbps_bytes(KBPS['music_stereo_vorbis'],
                                    n * lo * 60),
            'max_bytes': kbps_bytes(KBPS['music_stereo_vorbis'],
                                    n * hi * 60)}
    n, lo, hi = CHOIR_PLAN
    choir = {'count': n, 'min_minutes': n * lo, 'max_minutes': n * hi,
             'min_bytes': kbps_bytes(KBPS['choir_stereo_vorbis'],
                                     n * lo * 60),
             'max_bytes': kbps_bytes(KBPS['choir_stereo_vorbis'],
                                     n * hi * 60)}
    music_min = sum(v['min_bytes'] for v in music.values())
    music_max = sum(v['max_bytes'] for v in music.values())
    listed = sum(v['count'] for v in music.values()) + n
    # The plan's ~40 unique tracks: the full list scaled down.
    unique_share = UNIQUE_TRACKS / listed
    sfx = kbps_bytes(KBPS['sfx_mono_qoa'], SFX_COUNT * SFX_SEC)

    final_one = FINAL_TRIS * BYTES_PER_TRI + TEXTURE_BYTES
    final_models = models['count'] * final_one

    audio_min = int((music_min + choir['min_bytes']) * unique_share) \
        + voice + sfx
    audio_max = music_max + choir['max_bytes'] + voice + voice_en + sfx

    def total(extra):
        return apk['apk'] + extra

    phases = [
        ('now', 'APK today', 0),
        ('voices_ru', '+ Russian voices of the 34 trees', voice),
        ('sound_min', '+ sound plan, low (40 unique, short, RU voice)',
         audio_min),
        ('sound_max', '+ sound plan, high (full list, long, RU+EN voice)',
         audio_max),
        ('models_final', '+ final models in place of proxies',
         audio_max + final_models - models['bytes']),
    ]
    rows = []
    for key, label, extra in phases:
        t = total(extra)
        rows.append({'phase': key, 'label': label, 'added': extra,
                     'apk_if_one_file': t,
                     'own_budget_share': t / OWN_APK,
                     'store_share': t / STORE_APK,
                     'over_own': t > OWN_APK, 'over_store': t > STORE_APK})

    # How much room is left before each limit, in minutes of each kind.
    room_own = OWN_APK - apk['apk']
    room_store = STORE_APK - apk['apk']

    def minutes(room, kbps):
        return room / (kbps * 1000 / 8) / 60

    room = {k: {'own_budget_min': minutes(room_own, v),
                'store_min': minutes(room_store, v)}
            for k, v in KBPS.items()}

    return {
        'apk_now': apk, 'dialogue': text, 'models_now': models,
        'assumptions': {
            'words_per_sec': WORDS_PER_SEC,
            'pause_per_line_sec': PAUSE_PER_LINE_SEC, 'kbps': KBPS,
            'unique_tracks': UNIQUE_TRACKS, 'listed_tracks': listed,
            'sfx_count': SFX_COUNT, 'sfx_sec': SFX_SEC,
            'final_tris': FINAL_TRIS, 'bytes_per_tri': BYTES_PER_TRI,
            'texture_bytes': TEXTURE_BYTES},
        'limits': {'store_apk': STORE_APK, 'store_obb': STORE_OBB,
                   'own_apk': OWN_APK},
        'voice': {'seconds_ru': voice_sec, 'bytes_ru': voice,
                  'bytes_en': voice_en},
        'music': music, 'choir': choir, 'sfx_bytes': sfx,
        'final_model_bytes_each': final_one,
        'final_models_bytes': final_models,
        'phases': rows, 'room_minutes': room,
    }


def mb(n):
    return '%.1f' % (n / MIB)


def report(f):
    a = f['apk_now']
    print('APK now (%s): %s MiB; lib/*.so %s MiB; assets %s MiB '
          'uncompressed' % (a['source'], mb(a['apk']), mb(a['lib_so']),
                            mb(a['assets_uncompressed'])))
    d = f['dialogue']
    print('Dialogue: %d trees, %d lines, %d words RU, %d words EN' % (
        d['trees'], d['lines'], d['words_ru'], d['words_en']))
    v = f['voice']
    print('Voice RU: %.1f min, %s MiB (Vorbis mono %d kbit/s); EN %s MiB'
          % (v['seconds_ru'] / 60, mb(v['bytes_ru']),
             f['assumptions']['kbps']['voice_mono_vorbis'],
             mb(v['bytes_en'])))
    for k, m in f['music'].items():
        print('Music %-17s %2d tracks %5.1f-%5.1f min  %s-%s MiB' % (
            k, m['count'], m['min_minutes'], m['max_minutes'],
            mb(m['min_bytes']), mb(m['max_bytes'])))
    c = f['choir']
    print('Choir             %2d pieces %5.1f-%5.1f min  %s-%s MiB' % (
        c['count'], c['min_minutes'], c['max_minutes'],
        mb(c['min_bytes']), mb(c['max_bytes'])))
    print('SFX: %s MiB' % mb(f['sfx_bytes']))
    m = f['models_now']
    print('Models: %d .glb, %s MiB now; final %s MiB each, %s MiB all' % (
        m['count'], mb(m['bytes']), mb(f['final_model_bytes_each']),
        mb(f['final_models_bytes'])))
    print('Phase                      APK if one file   own 128 MiB  '
          'store 1 GB')
    for r in f['phases']:
        print('%-26s %10s MiB   %6.0f %%   %6.1f %%' % (
            r['phase'], mb(r['apk_if_one_file']),
            100 * r['own_budget_share'], 100 * r['store_share']))
    print('Room left, minutes of each kind:')
    for k, r in f['room_minutes'].items():
        print('  %-22s own budget %7.0f   store %8.0f' % (
            k, r['own_budget_min'], r['store_min']))


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('--apk', help='measure this APK instead of the CI '
                                 'numbers of the last build')
    p.add_argument('--json', help='write the forecast as JSON here')
    args = p.parse_args()
    f = forecast(args.apk)
    report(f)
    if args.json:
        with open(args.json, 'w', encoding='utf-8') as out:
            json.dump(f, out, ensure_ascii=False, indent=1)
            out.write('\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
