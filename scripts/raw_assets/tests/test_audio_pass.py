"""The audio pass takes sounds only as spectral references.

Operator, 2026-09-30: "добавь из 99 репо 299 звуков которые нам подходят
по трем параметрам. гит проходом."  CLAUDE.md TABOO 0.35 rule 8 keeps
every such sound a reference (envelope, T60, IR), never a sample, so
these tests guard the three parameters, the exclusions, determinism,
the diversity caps, the output schema and that no audio file is ever
written inside the repository.
"""

import json
import math
import random
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import audio_pass as ap  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
SR = 44100


def cand(repo, path, slot, right=8, meaning=8, acoustics=8):
    """A pool member as run_pass() builds it, without the profile."""
    return {'repo': repo, 'path': path, 'slot': slot,
            'scores': {'right': right, 'meaning': meaning,
                       'acoustics': acoustics}}


def decaying_noise(t60, seconds=2.0, sr=SR, seed=7):
    """White noise with an exponential decay of a known T60."""
    rng = np.random.default_rng(seed)
    t = np.arange(int(seconds * sr)) / sr
    # Amplitude falls 60 dB in t60 seconds.
    env = 10 ** (-3.0 * t / t60)
    return 0.5 * rng.standard_normal(len(t)) * env


class ExclusionTest(unittest.TestCase):
    def test_sacred_sound_never_enters(self):
        for path in ('sounds/church_bell.ogg', 'audio/choir_amen.ogg',
                     'sfx/chant_loop.wav', 'music/organ.ogg',
                     'sounds/prayer.ogg', 'sounds/holy_light.ogg',
                     'Magic/Cults/ClockCult/steam.ogg',
                     'sounds/gong_big.ogg', 'sounds/doorbell.ogg',
                     'sounds/spell_heal.ogg', 'Misc/narsie_rises.ogg'):
            self.assertIn(ap.refusal(path),
                          ('sacred-never-raw', 'sacred-sound',
                           'dogma-stop-list', 'music'), path)

    def test_dogma_stop_list(self):
        self.assertEqual(ap.refusal('fx/pentagram_glow.ogg'),
                         'dogma-stop-list')

    def test_music_voice_reward_combat(self):
        self.assertEqual(ap.refusal('data/music/theme.ogg'), 'music')
        self.assertEqual(ap.refusal('sounds/menu_song.ogg'), 'music')
        self.assertEqual(ap.refusal('sounds/coin_pickup.wav'),
                         'reward-ding')
        self.assertEqual(ap.refusal('sounds/levelup.ogg'), 'reward-ding')
        self.assertEqual(ap.refusal('Voice/Human/scream1.ogg'), 'voice')
        self.assertEqual(ap.refusal('Weapons/Guns/fire.ogg'), 'combat')
        self.assertEqual(ap.refusal('sounds/tankshot.mp3'), 'combat')
        self.assertEqual(ap.refusal('sounds/Cards/cardFan1.wav'),
                         'chance-or-card-game')

    def test_neutral_matter_passes(self):
        for path in ('sounds/water1.ogg', 'Effects/Footsteps/grass2.ogg',
                     'data/sound/woodcutting/woodcutting.ogg',
                     'sounds/wind.ogg', 'sounds/sawmill.ogg'):
            self.assertIsNone(ap.refusal(path), path)

    def test_attack_with_a_miss_is_combat(self):
        siblings = {'torch', 'torch-miss', 'campfire'}
        self.assertTrue(ap.attack_with_miss('s/torch.ogg', siblings))
        self.assertFalse(ap.attack_with_miss('s/campfire.ogg', siblings))


class LicenceTest(unittest.TestCase):
    def test_no_licence_repo_gives_nothing(self):
        self.assertEqual(ap.right_score(None, False, None, False)[1],
                         'no-licence-repo')

    def test_nc_or_nd_excludes(self):
        self.assertEqual(ap.right_score('MIT', False, 'CC-BY-NC-4.0',
                                        False)[1], 'licence-nc-nd')
        self.assertEqual(ap.right_score('GPL', True, None, True)[1],
                         'licence-nc-nd')

    def test_gpl_text_is_not_non_commercial(self):
        # GPL-3 section 6 says "noncommercially"; that is no CC NC term.
        text = ('GNU GENERAL PUBLIC LICENSE Version 3 ... allowed only '
                'occasionally and noncommercially ...')
        self.assertEqual(ap.classify_long(text), ('GPL', False))
        rotp = ('SOUND/MUSIC Attribution-NonCommercial-NoDerivatives 4.0 '
                'https://creativecommons.org/licenses/by-nc-nd/4.0/')
        self.assertTrue(ap.classify_long(rotp)[1])

    def test_scores_rank_free_terms_first(self):
        cc0 = ap.right_score('GPL', False, 'CC0-1.0', False)[0]
        sa = ap.right_score('GPL', False, 'CC-BY-SA-3.0', False)[0]
        gpl = ap.right_score('GPL', False, None, True)[0]
        mit_code = ap.right_score('MIT', False, None, False)[0]
        self.assertEqual(cc0, 10)
        self.assertGreater(cc0, sa)
        self.assertEqual(gpl, 5)
        # A code licence says nothing sure about sound assets.
        self.assertEqual(mit_code, 7)

    def test_per_file_hint_parsers(self):
        yml = ('- files:\n  - water1.ogg\n  - water2.ogg\n'
               '  license: "CC-BY-SA-3.0"\n\n- files: ["puddle1.ogg"]\n'
               '  license: "CC-BY-NC-4.0"\n')
        got = ap.hints_attributions_yml('Audio/Footsteps', yml)
        self.assertEqual(got['Audio/Footsteps/water1.ogg'], 'CC-BY-SA-3.0')
        self.assertEqual(got['Audio/Footsteps/puddle1.ogg'], 'CC-BY-NC-4.0')
        debian = ('Format: https://x\n\nFiles: *\nLicense: GPL-3+\n\n'
                  'Files: sounds/*\nLicense: public-domain\n\n'
                  'Files: sounds/meteor.wav\nLicense: CC-BY-SA-3.0\n')
        hints = ap.file_hints(['sounds/meteor.wav', 'sounds/wind.wav',
                               'data/x.ogg'], {'copyright': debian})
        self.assertEqual(hints['sounds/meteor.wav'][0], 'CC-BY-SA-3.0')
        self.assertEqual(hints['sounds/wind.wav'][0], 'public-domain')
        # "Files: *" is the whole repository, not a per-file hint.
        self.assertNotIn('data/x.ogg', hints)
        credits = ('==  Sounds: sounds/  ==\n'
                   'Spatial/Game/RocksFalling/\n'
                   '-> RocksFalling*.ogg   Svenskmand   CC-BY-SA 3.0\n')
        hints = ap.file_hints(
            ['sounds/Spatial/Game/RocksFalling/RocksFalling04.ogg'],
            {'CREDITS': credits})
        self.assertEqual(list(hints.values())[0][0], 'CC-BY-SA 3.0')
        csv = ('Date,File,License,Author\n'
               '2023/09/15,data/core/sounds/wind.ogg,CC BY-SA 4.0,x\n')
        self.assertEqual(ap.hints_copyrights_csv(csv),
                         {'data/core/sounds/wind.ogg': 'CC BY-SA 4.0'})


class MeaningTest(unittest.TestCase):
    def test_slot_by_name_and_folder(self):
        # A strong word in the name weighs 2: int(2 + 3 * 2) = 8.
        self.assertEqual(ap.slot_of('Effects/Footsteps/water1.ogg')[:2],
                         ('lake.water', 8))
        self.assertEqual(ap.slot_of('Effects/Footsteps/grass2.ogg')[0],
                         'road.footsteps')
        self.assertEqual(ap.slot_of('sounds/sonar-ping.ogg')[0],
                         'rov.sonar')

    def test_false_friends_do_not_match(self):
        # "screwdriver" hides a "river", "plankton" a "plank".
        self.assertNotEqual(ap.slot_of('Items/screwdriver.ogg')[0],
                            'lake.water')
        self.assertNotEqual(ap.slot_of('sounds/plankton bite.wav')[0],
                            'workshop.wood')
        # A category folder or a code folder high up names no thing.
        self.assertLess(ap.slot_of('Resources/Audio/Machines/printer.ogg')
                        [1], ap.PASS_SCORE)
        self.assertLess(ap.slot_of('engine/sound/src/test/x.ogg')[1],
                        ap.PASS_SCORE)
        # Words of the repository name are noise.
        noise = ap.tokens('Card-Forge forge')
        self.assertIsNone(ap.slot_of('forge-gui/res/sound/x.mp3',
                                     noise)[0])


class AcousticsTest(unittest.TestCase):
    def test_t60_of_a_known_decay(self):
        prof = ap.measure(decaying_noise(0.5), SR)
        self.assertIn(prof['t60_method'], ('T20', 'T30'))
        self.assertAlmostEqual(prof['t60_s'], 0.5, delta=0.05)
        self.assertGreater(prof['t60_r2'], 0.95)

    def test_centroid_of_a_sine_and_dc_is_ignored(self):
        t = np.arange(SR) / SR
        sine = 0.5 * np.sin(2 * math.pi * 1000 * t) + 0.2
        prof = ap.measure(sine, SR)
        self.assertAlmostEqual(prof['centroid_hz'], 1000, delta=30)

    def test_hard_failures(self):
        tone = 0.5 * np.sin(2 * math.pi * 440 * np.arange(16000) / 16000)
        self.assertEqual(ap.acoustic_score(ap.measure(tone, 16000))[1],
                         'sample-rate')
        clipped = np.clip(3 * decaying_noise(1.0), -1, 1)
        self.assertEqual(ap.acoustic_score(ap.measure(clipped, SR))[1],
                         'clipping')
        short = decaying_noise(0.01, seconds=0.02)
        self.assertEqual(ap.acoustic_score(ap.measure(short, SR))[1],
                         'duration')

    def test_t60_of_a_sustained_sound_is_marked_as_file_fade(self):
        blow = ap.measure(decaying_noise(0.3), SR)
        self.assertTrue(ap.is_impulsive(blow))
        rng = np.random.default_rng(1)
        wind = 0.3 * rng.standard_normal(3 * SR)
        wind[-SR // 2:] *= np.linspace(1, 0, SR // 2)
        self.assertFalse(ap.is_impulsive(ap.measure(wind, SR)))

    def test_a_clean_decay_scores_high(self):
        score, reason = ap.acoustic_score(ap.measure(decaying_noise(0.8),
                                                     SR))
        self.assertIsNone(reason)
        self.assertGreaterEqual(score, 8)


class SelectionTest(unittest.TestCase):
    def pool(self):
        pool = []
        for i in range(12):
            pool.append(cand('a', f'Footsteps/grass{i}.ogg',
                             'road.footsteps'))
            pool.append(cand('a', f'Footsteps/surface{i}_step.ogg',
                             'road.footsteps', acoustics=7))
            pool.append(cand('b', f'water/w{i}/drip.ogg', 'lake.water',
                             right=6))
        pool.append(cand('c', 'wind/wind.ogg', 'lake.wind', 5, 5, 5))
        return pool

    def test_deterministic_whatever_the_input_order(self):
        pool = self.pool()
        first = [c['path'] for c in ap.select(pool, k=20)[0]]
        random.Random(3).shuffle(pool)
        again = [c['path'] for c in ap.select(pool, k=20)[0]]
        self.assertEqual(first, again)

    def test_caps_and_slot_minimum(self):
        chosen, _ = ap.select(self.pool(), k=100,
                              tiers=((3, 40),))
        folders = {}
        for c in chosen:
            key = (c['repo'], str(Path(c['path']).parent))
            folders[key] = folders.get(key, 0) + 1
        self.assertLessEqual(max(folders.values()), 3)
        # grass0..grass11 are one thing in twelve takes: two at most.
        grass = [c for c in chosen if 'grass' in c['path']]
        self.assertLessEqual(len(grass), ap.THING_CAP)
        # The weakest slot still gets its place.
        self.assertIn('lake.wind', {c['slot'] for c in chosen})

    def test_second_tier_keeps_two_states_per_thing(self):
        chosen, _ = ap.select(self.pool(), k=100)
        grass = [c for c in chosen if 'grass' in c['path']]
        self.assertLessEqual(len(grass), ap.THING_CAP)
        self.assertEqual({c['tier'] for c in chosen}, {1, 2})

    def test_states_of_one_thing(self):
        self.assertEqual(ap.thing_of('x/door_open.ogg'),
                         ap.thing_of('x/door_close.ogg'))
        self.assertEqual(ap.thing_of('x/impactWood_light_002.ogg'),
                         ap.thing_of('x/impactWood_heavy_000.ogg'))
        self.assertNotEqual(ap.thing_of('x/grass1.ogg'),
                            ap.thing_of('x/snowstep1.ogg'))


class OutputTest(unittest.TestCase):
    def test_no_audio_inside_the_repository(self):
        with self.assertRaises(ValueError):
            ap.cache_path(REPO, 'r', 'a.ogg')
        with self.assertRaises(ValueError):
            ap.cache_path(REPO / 'build' / 'audio', 'r', 'a.ogg')
        for out in ap.OUTPUTS:
            self.assertNotIn(out.suffix.lower(), ap.AUDIO_EXT, out)
        for folder in ('docs', 'godot/data', 'public/ludus/data'):
            found = [p for p in (REPO / folder).rglob('*')
                     if p.suffix.lower() in ap.AUDIO_EXT]
            self.assertEqual(found, [], folder)

    def test_props_row_schema(self):
        c = dict(cand('r', 'a/b.ogg', 'lake.water'), url='https://x/r',
                 revision='abc', licence='CC0-1.0', keywords=['water'],
                 sha1='0' * 40, bytes=10)
        self.assertEqual(set(ap.props_row(c)),
                         {'repo', 'revision', 'path', 'licence', 'kind',
                          'deficit_id', 'keywords', 'pass_id', 'sha1',
                          'bytes'})
        self.assertEqual(ap.props_row(c)['kind'], 'audio')
        self.assertEqual(ap.props_row(c)['deficit_id'], 'DEF-027')

    def test_committed_references_are_clean(self):
        """If the pass wrote its data, every row obeys the rules."""
        if not ap.OUT_REFS.exists():
            self.skipTest('no references written yet')
        refs = json.loads(ap.OUT_REFS.read_text('utf-8'))
        rows = refs['references']
        self.assertLessEqual(len(rows), ap.K)
        for r in rows:
            self.assertIsNone(ap.refusal(r['path']), r['path'])
            self.assertIsNone(ap.NC_ND.search(r['licence']), r['path'])
            self.assertIn(r['slot'], ap.SLOTS)
            self.assertIn(r['tier'], (1, 2))
            self.assertTrue(all(r['scores'][k] >= ap.PASS_SCORE
                                for k in ('right', 'meaning',
                                          'acoustics')), r['path'])
            for key in ('envelope_db', 't60_s', 'centroid_hz', 'edc_db',
                        'attack_ms', 'bands_db', 'impulsive'):
                self.assertIn(key, r['profile'])
            self.assertNotIn((r['repo'].split('github.com/')[-1]
                              .replace('/', '__'), r['path']),
                             ap.EYE_CHECK_DROPS)
        props = json.loads(ap.OUT_PROPS.read_text('utf-8'))
        for row in props:
            self.assertEqual(row['kind'], 'audio')
            self.assertIsNone(ap.refusal(row['path']), row['path'])


if __name__ == '__main__':
    unittest.main()
