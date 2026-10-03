"""What fills the 20 MB the own engine frees: the series pilot first.

Operator, 2026-10-02: «пропиши теперь HLD рассчитав прорывные вещи на
20мб которые мы можем закодить и закачать в шлем», and «игра должна
быть интересной как первая серия смачного сериала» (CLAUDE.md TABOO
0.015).  The own engine template takes libgodot_android.so from about
76.2 MB to 53.3 MB (measured, docs/HLD_ENGINE_BUILD_2026-10-02.md), so
about 20 MB of APK room is planned here, not 22.9: the rest is margin.

The pool is every candidate the project's documents name that can be
coded now, without recordings or purchases (TABOO 0.07: an honest pool,
not padded).  Each gets the five open criteria, 0-10, and its cost in
MB of APK: "measured" when a file of that kind is in the repo, "est"
when it is an estimate with its formula in the note.  Selection is
deterministic: the pilot's own parts first (the operator's priority),
then by score per MB, while the sum fits the budget.

    python3 scripts/decisions/pilot_20mb.py          # table
    python3 scripts/decisions/pilot_20mb.py --check  # CI: fits, honest

Constitution: ФОРМА (20 MB the headset can carry) → ДЕЙСТВИЕ (spend
them on what makes the first fifteen minutes hold, then on what the
pilot promises next) → ЦЕЛЬ (the player stays for the teaching because
the story holds them, not because the menu does).
"""

import sys

BUDGET_MB = 20.0
CRITERIA = ('truth', 'teaching', 'headset', 'novelty', 'safety')

# id, phase, MB, kind, needs, scores (truth, teaching, headset, novelty,
# safety), note.  needs: '' = can be coded now; else what blocks it.
POOL = [
    ('pilot_core', 'P1', 0.02, 'measured', '', (9, 9, 9, 9, 10),
     'pilot_core.gd + pilot-1.json, 10 KB on disk'),
    ('pilot_scene', 'P2', 0.30, 'est', '', (8, 9, 9, 10, 10),
     'scene + script; the room water is one plane and a shader'),
    ('passthrough', 'P3', 0.0, 'est', '', (9, 7, 10, 10, 9),
     'manifest flag and alpha blend; no files'),
    ('hand_mark', 'P3', 0.10, 'est', '', (8, 9, 9, 10, 10),
     'comet decal 256 px ETC2 with mips (~0.09 MB)'),
    ('taboo_body', 'P2', 0.01, 'est', '', (9, 10, 9, 10, 10),
     'head cone, hand distance, breaths into PassionCore'),
    ('diary_lines', 'P4', 0.02, 'est', '', (9, 9, 8, 8, 10),
     'nine diary lines with translation, text only'),
    ('grabar_font', 'P4', 0.12, 'est', '', (10, 8, 8, 9, 10),
     'Noto Serif Armenian subset, OFL; 40 lines of glyphs'),
    ('prior_screen', 'P2', 0.02, 'est', '', (8, 9, 9, 8, 10),
     'messages on the second screen, reuses CockpitScreens'),
    ('title_card', 'P5', 0.05, 'est', '', (7, 6, 9, 8, 10),
     'logo as extruded text mesh, procedural flute'),
    ('comfort_vignette', 'P2', 0.01, 'est', '', (8, 7, 10, 6, 10),
     'vignette and reduced-motion fade for the tether jerk'),
    ('subtitles_en', 'P5', 0.02, 'est', '', (8, 8, 8, 6, 10),
     'English lines of the pilot (DataPacks voices later)'),
    ('ep2_sis_1374', 'P6', 8.00, 'est', '', (8, 10, 7, 10, 9),
     'episode 2: the vault at Sis, 12 proxies x 5000 tris + 4 ETC2 '
     '1024 textures (4 x 1.4 MB) + data'),
    ('shield_final', 'P6', 1.60, 'est', '', (9, 8, 9, 7, 10),
     'final shield model, 5000 tris + one 1024 ETC2 texture'),
    ('caustics', 'P6', 0.35, 'est', '', (9, 5, 8, 6, 10),
     'caustics texture 512 ETC2 with mips'),
    # Not now: blocked by the operator or by people (kept, not dropped).
    ('voices_ru', '-', 35.6, 'est', 'recordings (Д-7)', (9, 9, 9, 8, 10),
     'goes to a DataPacks voice pack, not the APK'),
    ('duduk_theme', '-', 1.2, 'est', 'recording of a live duduk',
     (9, 7, 9, 7, 10), 'node 98; 60 s Vorbis 160 kbps'),
    ('eye_gaze', '-', 0.0, 'est', 'no eye tracking in Quest 3S',
     (5, 7, 0, 8, 9), 'head gaze is used instead'),
    ('voice_taboo', '-', 0.0, 'est', 'voice input off (TABOO 0.26 p.9)',
     (5, 5, 0, 8, 2), 'forbidden words need a microphone'),
    ('passthrough_scare', '-', 0.0, 'est', 'TABOO 0.4 / 0.015 p.5',
     (3, 1, 8, 7, 1), 'a scream into the real room'),
]


def score(row):
    return sum(row[5])


def choose():
    """The pilot's parts first, then the rest by score per MB."""
    free = [r for r in POOL if not r[4]]
    pilot = [r for r in free if r[1] in ('P1', 'P2', 'P3', 'P4', 'P5')]
    rest = sorted((r for r in free if r not in pilot),
                  key=lambda r: (-score(r) / max(r[2], 0.01), r[0]))
    out, used = [], 0.0
    for r in pilot + rest:
        if used + r[2] <= BUDGET_MB:
            out.append(r)
            used += r[2]
    return out, used


def check():
    bad = []
    chosen, used = choose()
    if used > BUDGET_MB:
        bad.append('over budget: %.2f MB' % used)
    for r in chosen:
        if r[5][4] < 8:
            bad.append('%s is not safe enough' % r[0])
        if r[4]:
            bad.append('%s is blocked: %s' % (r[0], r[4]))
    ids = [r[0] for r in POOL]
    if len(ids) != len(set(ids)):
        bad.append('duplicate ids')
    return bad


def main(argv):
    chosen, used = choose()
    if '--check' in argv:
        bad = check()
        for b in bad:
            print('FAIL:', b)
        print('pilot 20 MB: %d of %d chosen, %.2f MB of %.0f' % (
            len(chosen), len(POOL), used, BUDGET_MB))
        return 1 if bad else 0
    print('| id | phase | MB | kind | score | chosen | note |')
    print('|---|---|---|---|---|---|---|')
    for r in POOL:
        mark = 'да' if r in chosen else ('нет: ' + r[4] if r[4] else 'нет')
        print('| %s | %s | %.2f | %s | %d | %s | %s |' % (
            r[0], r[1], r[2], r[3], score(r), mark, r[6]))
    print('\nchosen %.2f MB of %.0f' % (used, BUDGET_MB))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
