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

    def test_magic_words_by_another_name(self):
        # A Magic: The Gathering client, a sylph's water orb, a wesnoth
        # campaign skill, an inquisitor's heresy cue.
        for path in ('Mage.Client/sounds/OnNextPage.wav',
                     'campaigns/X/sounds/sylph-orb-water.wav',
                     'campaigns/X/sounds/skill-blizzard.wav',
                     'sounds/remove_heresy.ogg'):
            self.assertEqual(ap.refusal(path), 'sacred-sound', path)
        self.assertIsNone(ap.refusal('sounds/image.ogg'))

    def test_things_not_in_the_world_of_the_game(self):
        for path in ('Machines/machine_vend.ogg', 'Fluids/flush.ogg',
                     'Footsteps/borgwalk1.ogg', 'movement/walkerStep.ogg',
                     'Footsteps/asteroid2.ogg', 'Weather/space_wind.ogg',
                     'Animals/penguin_squawk.ogg',
                     'Animals/parrot_raught.ogg',
                     'Animals/raccoon_chatter.ogg',
                     'Footsteps/heelsclack2.ogg',
                     'Machines/airlock_deny.ogg',
                     'Machines/airlock_electrify_on.ogg',
                     'Objects/circular_saw.ogg',
                     'loops/loopMineBeam.ogg'):
            self.assertEqual(ap.refusal(path), 'not-real-thing', path)
        # A space bar is a key, not space.
        self.assertIsNone(ap.refusal('ui/spacebar.ogg'))

    def test_credit_line_role(self):
        melee = ("[wpn 1 generic](https://x) By SlavicMagic as 'metalhit' "
                 'for metal melee sounds (CC0)')
        self.assertEqual(ap.credit_refusal({'credit': melee}),
                         'credit-combat')
        heresy = ("FireBurning_v2.wav by pcaeldries for 'remove heresy' "
                  'action of inquisitor (CC BY 4.0)')
        self.assertEqual(ap.credit_refusal({'credit': heresy}),
                         'credit-sacred-role')
        grinder = '"01-1 Angle Grinder.wav" by domiscz of Freesound.org'
        self.assertEqual(ap.credit_refusal({'credit': grinder}),
                         'credit-not-real-thing')
        # An author's name is not a role: "el_boss" is no boss.
        self.assertIsNone(ap.credit_refusal(
            {'credit': 'Made by el_boss, edited by mirrorcult'}))

    def test_review_drops_carry_their_source_role(self):
        for key in (('yairm210__Unciv', 'android/assets/sounds/fire.mp3'),
                    ('yairm210__Unciv',
                     'android/assets/sounds/metalhit.mp3'),
                    ('yairm210__Unciv', 'android/assets/sounds/horse.mp3'),
                    ('00-Evan__shattered-pixel-dungeon',
                     'core/src/main/assets/sounds/chains.mp3')):
            self.assertIn(key, ap.REVIEW_DROPS)
        self.assertIn('Heresy', ap.REVIEW_DROPS[
            ('yairm210__Unciv', 'android/assets/sounds/fire.mp3')])

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

    def test_readme_default_with_declared_nc_waits_for_the_lawyer(self):
        readme = ('Most assets are licensed under [CC-BY-SA 3.0](https://'
                  'creativecommons.org/licenses/by-sa/3.0/) unless stated '
                  'otherwise.\n> Some assets are licensed under the '
                  'non-commercial [CC-BY-NC-SA 3.0](https://x) and will '
                  'need to be removed.')
        default, nc = ap.readme_asset_licence(readme)
        self.assertEqual(default, 'CC-BY-SA 3.0')
        self.assertTrue(nc)
        score, reason, cls = ap.right_score('MIT', False, None, False,
                                            default, nc)
        self.assertEqual((score, reason, cls),
                         (None, 'licence-nc-unknown', 'CC-BY-SA'))
        # Without the NC warning the README default is the licence.
        self.assertEqual(ap.right_score('MIT', False, None, False,
                                        default, False)[:2], (5, None))
        # "Some assets are released under various licenses" names none.
        self.assertEqual(ap.readme_asset_licence(
            'GPL v2+. Some assets are released under various Creative '
            'Commons licenses.')[0], None)

    def test_register_unknown_or_ambiguous_is_held_out(self):
        self.assertEqual(ap.right_score('GPL', False, 'UNKNOWN', True)[1],
                         'licence-unknown')
        self.assertEqual(ap.right_score('GPL', False, 'CC-3', True)[1],
                         'licence-ambiguous')
        self.assertEqual(ap.right_score('GPL', False, 'CC0-1.0', True)[0],
                         10)

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
        self.assertEqual(got['Audio/Footsteps/water1.ogg']['licence'],
                         'CC-BY-SA-3.0')
        self.assertEqual(got['Audio/Footsteps/puddle1.ogg']['licence'],
                         'CC-BY-NC-4.0')
        # A single-quoted YAML value keeps its inner double quotes.
        yml = ("- files: [saw.ogg]\n  copyright: '\"01-1 Angle Grinder"
               ".wav\" by domiscz'\n  license: CC0-1.0\n")
        got = ap.hints_attributions_yml('', yml)['saw.ogg']
        self.assertEqual(got['author'], '"01-1 Angle Grinder.wav" by domiscz')
        debian = ('Format: https://x\n\nFiles: *\nLicense: GPL-3+\n\n'
                  'Files: sounds/*\nLicense: public-domain\n\n'
                  'Files: sounds/meteor.wav\nLicense: CC-BY-SA-3.0\n')
        hints = ap.file_hints(['sounds/meteor.wav', 'sounds/wind.wav',
                               'data/x.ogg'], {'copyright': debian})
        self.assertEqual(hints['sounds/meteor.wav']['licence'],
                         'CC-BY-SA-3.0')
        self.assertEqual(hints['sounds/wind.wav']['licence'],
                         'public-domain')
        # "Files: *" is the whole repository, not a per-file hint.
        self.assertNotIn('data/x.ogg', hints)
        credits = ('==  Sounds: sounds/  ==\n'
                   'Spatial/Game/RocksFalling/\n'
                   '-> RocksFalling*.ogg   Svenskmand   CC-BY-SA 3.0\n')
        hints = ap.file_hints(
            ['sounds/Spatial/Game/RocksFalling/RocksFalling04.ogg'],
            {'CREDITS': credits})
        self.assertEqual(list(hints.values())[0]['licence'],
                         'CC-BY-SA 3.0')
        csv = ('Date,File,License,Author\n'
               '2023/09/15,data/core/sounds/wind.ogg,CC BY-SA 4.0,x\n')
        got = ap.hints_copyrights_csv(csv)['data/core/sounds/wind.ogg']
        self.assertEqual((got['licence'], got['author']),
                         ('CC BY-SA 4.0', 'x'))

    def test_sources_txt_line_names_its_own_licence(self):
        # SS14 Footsteps/sources.txt: the author's "by" is no licence,
        # and the next line's licence belongs to other files.
        text = ('grass1.ogg and grass2.ogg are taken from https://x/ by '
                'D001447733 licensed under CC BY-3.0 and split\n'
                'grass3.ogg and grass4.ogg are taken from https://y/ by '
                'jevans27 licensed under CC-0 and split\n')
        paths = ['F/grass1.ogg', 'F/grass3.ogg']
        hints = ap.file_hints(paths, {'F/sources.txt': text})
        self.assertEqual(hints['F/grass1.ogg']['licence'], 'CC BY-3.0')
        self.assertEqual(hints['F/grass3.ogg']['licence'], 'CC-0')
        self.assertEqual(ap.classify_short('CC-0'), 'PD')
        self.assertTrue(ap.HINT_NAME.search('Audio/Footsteps/sources.txt'))

    def test_widelands_sound_register(self):
        text = ('Title,,,\n\nFile Name,Format,Location,Usage,Author,'
                'License,reworked,Original File Name,Source\n'
                'ironping.ogg,22050,sound/metal,smelting,timgormly,CC-3,'
                'yes,metal-ping1.aiff,http://f/170964/\n'
                'wolf_01.ogg,22050,data/sound/animals,,UNKNOWN,,,'
                'Howl-4.wav,UNKNOWN\n'
                'moose_01.ogg,22050,data/sound/animals,,fws.gov,PD,yes,'
                'Elk.wav,http://s/246\n')
        self.assertTrue(ap.HINT_NAME.search('data/sound/wl-sound-docu.csv'))
        paths = ['data/sound/metal/ironping.ogg',
                 'data/sound/animals/wolf_01.ogg',
                 'data/sound/animals/moose_01.ogg']
        hints = ap.file_hints(paths, {'data/sound/wl-sound-docu.csv': text})
        self.assertEqual(hints[paths[0]]['licence'], 'CC-3')
        self.assertEqual(hints[paths[0]]['author'], 'timgormly')
        self.assertEqual(hints[paths[1]]['licence'], 'UNKNOWN')
        self.assertEqual(hints[paths[2]]['licence'], 'public domain')
        self.assertEqual(hints[paths[2]]['source'], 'sound-register')

    def test_credits_page_names_sounds_by_stem(self):
        text = ('## Sound credits\n'
                "- [Pencil1](https://f/43673/) By stijn as 'paper' for "
                'opening the tech picker (CC0)\n'
                "- [Chain Snare](https://f/1/) By lovesbody as 'fortify' "
                '(CC BY 4.0)\n')
        paths = ['android/assets/sounds/paper.mp3',
                 'android/assets/sounds/fortify.mp3']
        hints = ap.file_hints(paths, {'docs/Credits.md': text})
        self.assertEqual(hints[paths[0]]['licence'], 'CC0')
        self.assertEqual(hints[paths[0]]['author'], 'stijn')
        self.assertEqual(hints[paths[1]]['licence'], 'CC BY 4.0')
        self.assertEqual(hints[paths[1]]['source'], 'credits-page')


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

    def test_weak_words_alone_do_not_pass(self):
        # "ship move" in a movement/ folder: weak twice, still no step.
        self.assertLess(ap.slot_of('sounds/movement/shipMoveBig.ogg')[1],
                        ap.PASS_SCORE)

    def test_slot_words_name_real_things_only(self):
        # Modern hand tools are no smithy, a UI whoosh is no wind, a
        # scanner is no sonar, a rubber stamp is no quill, a buckle is
        # no linen, and a footstep on a hull is no hull creak.
        self.assertNotEqual(ap.slot_of('Items/toolbox_close.ogg')[0],
                            'workshop.forge')
        self.assertNotEqual(ap.slot_of('Items/welder.ogg')[0],
                            'workshop.forge')
        self.assertIsNone(ap.slot_of('sounds/whoosh.mp3')[0])
        self.assertLess(ap.slot_of('Machines/scan_loop.ogg')[1],
                        ap.PASS_SCORE)
        self.assertIsNone(ap.slot_of('Items/Stamp/thick_stamp.ogg')[0])
        self.assertNotEqual(ap.slot_of('Effects/buckle.ogg')[0],
                            'workshop.cloth')
        self.assertNotEqual(ap.slot_of('Effects/Footsteps/hull4.ogg')[0],
                            'rov.hull')
        self.assertNotEqual(ap.slot_of('Effects/glass_step.ogg')[0],
                            'road.footsteps')
        self.assertEqual(ap.slot_of('sounds/anvil_01.ogg')[0],
                         'workshop.forge')


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

    def test_centroid_does_not_depend_on_framing(self):
        # A 50 ms click of 2 kHz, alone or in 1.5 s of silence: one
        # whole-file spectrum weighs it the same either way.
        n = int(0.05 * SR)
        burst = np.sin(2 * math.pi * 2000 * np.arange(n) / SR) \
            * np.hanning(n)
        short = ap.measure(np.concatenate([burst, np.zeros(n)]), SR)
        long = ap.measure(np.concatenate([burst, np.zeros(30 * n)]), SR)
        self.assertAlmostEqual(short['centroid_hz'], 2000, delta=60)
        self.assertAlmostEqual(short['centroid_hz'], long['centroid_hz'],
                               delta=20)

    def test_drift_and_steps_below_20_hz_are_ignored(self):
        # A keyboard or step file with a drifting offset: the 1 kHz tone
        # is what the ear hears, and the envelope stays the tone's.
        t = np.arange(2 * SR) / SR
        tone = 0.3 * np.sin(2 * math.pi * 1000 * t)
        clean = ap.measure(tone, SR)
        ramp = ap.measure(tone + 0.4 * t, SR)
        step = ap.measure(tone + np.where(t < 1.0, 0.0, 0.3), SR)
        for prof in (ramp, step):
            self.assertAlmostEqual(prof['centroid_hz'], 1000, delta=30)
        for a, b in zip(clean['envelope_db'], ramp['envelope_db']):
            self.assertAlmostEqual(a, b, delta=0.5)
        # The step leaves one short transient, not a new envelope: its
        # peak lowers every point by the same amount, and only the two
        # points around the step keep a different shape.
        diffs = [a - b for a, b in zip(step['envelope_db'],
                                       clean['envelope_db'])]
        common = float(np.median(diffs))
        self.assertLessEqual(sum(abs(d - common) > 0.5 for d in diffs), 2)
        # The filter: -3 dB at 20 Hz, flat above 100 Hz, nothing at DC.
        x = np.sin(2 * math.pi * 20 * t) + np.sin(2 * math.pi * 200 * t)
        y = ap.highpass(np.ones(len(t)), SR)
        self.assertLess(float(np.abs(y).max()), 1e-6)
        spec = np.abs(np.fft.rfft(ap.highpass(x, SR)))
        f = np.fft.rfftfreq(len(x), 1 / SR)
        g20 = spec[np.argmin(abs(f - 20))] / (len(x) / 2)
        g200 = spec[np.argmin(abs(f - 200))] / (len(x) / 2)
        self.assertAlmostEqual(g20, 1 / math.sqrt(2), delta=0.02)
        self.assertAlmostEqual(g200, 1.0, delta=0.01)

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
        self.assertEqual(blow['onsets'], 1)
        self.assertTrue(ap.is_impulsive(blow))
        rng = np.random.default_rng(1)
        wind = 0.3 * rng.standard_normal(3 * SR)
        wind[-SR // 2:] *= np.linspace(1, 0, SR // 2)
        self.assertFalse(ap.is_impulsive(ap.measure(wind, SR)))
        self.assertTrue(ap.is_steady(ap.measure(wind, SR)))

    def test_a_train_of_blows_is_not_one_blow(self):
        # Four hammer blows, 0.4 s apart, each dying away: its "T60" is
        # no decay of one thing (widelands hammering_01).
        blow = decaying_noise(0.2, seconds=0.4)
        train = np.concatenate([blow, blow, blow, blow])
        prof = ap.measure(train, SR)
        self.assertEqual(prof['onsets'], 4)
        self.assertFalse(ap.is_impulsive(prof))

    def test_a_noisy_sustained_file_is_not_a_blow(self):
        # Five seconds of fire-like noise whose level wanders by 12 dB
        # and fades at the end (SS14 burning.ogg).
        rng = np.random.default_rng(5)
        t = np.arange(5 * SR) / SR
        level = 10 ** ((-6 + 6 * np.sin(2 * math.pi * 0.7 * t)) / 20)
        fire = 0.3 * rng.standard_normal(len(t)) * level
        fire[-SR:] *= np.linspace(1, 0, SR)
        prof = ap.measure(fire, SR)
        self.assertFalse(ap.is_impulsive(prof))
        # Its score gets no bonus for a T60 it does not have.
        blow_score = ap.acoustic_score(ap.measure(decaying_noise(0.8),
                                                  SR))[0]
        self.assertLess(ap.acoustic_score(prof)[0], blow_score)

    def test_onsets_ignore_noise_in_the_tail(self):
        env = [-120.0, 0.0, -6.0, -15.0, -30.0, -45.0, -38.0, -50.0]
        self.assertEqual(ap.count_onsets(env), 1)
        env = [0.0, -13.0, -3.0, -25.0, -14.0, -40.0]
        # A rise of 10 dB back near the top, then a return above -15 dB
        # after a fall below -20 dB: three blows.
        self.assertEqual(ap.count_onsets(env), 3)

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
        self.assertNotEqual(ap.thing_of('x/impactWood_light_002.ogg'),
                            ap.thing_of('x/impactPlank_light_002.ogg'))

    def test_actions_and_fused_states_are_one_thing(self):
        def one(*names):
            return {ap.thing_of('Items/' + n) for n in names}
        # The families the first run counted as several things.
        self.assertEqual(len(one('toolbox_close.ogg', 'toolbox_open.ogg',
                                 'toolbox_remove.ogg',
                                 'toolbox_insert.ogg',
                                 'toolbox_drop.ogg')), 1)
        self.assertEqual(len(one('screwdriver.ogg', 'screwdriver2.ogg',
                                 'screwdriver_drop.ogg',
                                 'screwdriverclose.ogg',
                                 'screwdriveropen.ogg')), 1)
        self.assertEqual(len(one('airlock_electrify_on.ogg',
                                 'airlock_electrify_off.ogg',
                                 'airlock_ext_close.ogg', 'airlock_open.ogg',
                                 'airlock_creaking.ogg',
                                 'airlock_deny.ogg')), 1)
        self.assertEqual(len(one('cat_meow.ogg', 'cat_meow2.ogg',
                                 'cat_hiss.ogg')), 1)
        self.assertEqual(len(one('woodenclosetopen.ogg',
                                 'woodenclosetclose.ogg')), 1)
        # A word that only ends like a state keeps its letters.
        self.assertEqual(ap.thing_of('x/closet.ogg')[1], 'closet')
        self.assertEqual(ap.thing_of('x/button.ogg')[1], 'button')

    def test_slot_minimum_comes_before_the_folder_cap(self):
        # One folder serves two slots; the second slot must still get
        # its minimum although the first filled the folder cap.
        pool = [cand('a', f'Items/anvil{i}_x.ogg', 'workshop.forge')
                for i in range(3)]
        pool += [cand('a', f'Items/linen{i}_y.ogg', 'workshop.cloth',
                      acoustics=6) for i in range(3)]
        chosen, _ = ap.select(pool, k=100, tiers=((3, 40),), thing_cap=5)
        self.assertEqual(sum(c['slot'] == 'workshop.cloth'
                             for c in chosen), 3)

    def test_second_tier_needs_the_thing_in_the_name(self):
        pool = [cand('a', f'Animals/a{i}/x.ogg', 'road.animals', meaning=5)
                for i in range(6)]
        pool += [cand('a', f'Animals/b{i}/horse.ogg', 'road.animals')
                 for i in range(6)]
        # Tier 1 may take three from the repository; tier 2 goes on.
        chosen, stats = ap.select(pool, k=100,
                                  tiers=((10 ** 6, 3), (10 ** 6, 10 ** 6)))
        tier2 = [c for c in chosen if c['tier'] == 2]
        self.assertTrue(tier2)
        self.assertTrue(all(c['scores']['meaning'] >= ap.TIER2_MEANING
                            for c in tier2))
        self.assertEqual(stats['not-chosen'], len(pool) - len(chosen))


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
                          'vid', 'deficit_id', 'keywords', 'pass_id',
                          'sha1', 'bytes'})
        self.assertEqual(ap.props_row(c)['kind'], 'audio')
        self.assertEqual(ap.props_row(c)['vid'], 'game')
        self.assertEqual(ap.props_row(c)['deficit_id'], 'DEF-027')

    def test_props_vid(self):
        self.assertEqual(ap.vid_of('fyrox-sound/examples/data/door.wav'),
                         'example')
        self.assertEqual(ap.vid_of('Tests/Assets/Audio/rock.wav'), 'test')
        self.assertEqual(ap.vid_of('engine/sound/src/test/door.wav'),
                         'test')
        self.assertEqual(ap.vid_of('editor/sounds/click.ogg'), 'editor')
        self.assertEqual(ap.vid_of('Resources/Audio/Items/Tools/x.ogg'),
                         'game')

    def test_godot_copy_holds_medians_only(self):
        c = dict(cand('r', 'a/b.ogg', 'rov.hull'),
                 profile=ap.measure(decaying_noise(0.5), SR))
        data = ap.godot_references([c, c, c])
        text = json.dumps(data)
        self.assertNotIn('a/b.ogg', text)
        hull = data['slots']['rov.hull']
        self.assertEqual(hull['t60_n'], 3)
        self.assertAlmostEqual(hull['t60_median_s'], 0.5, delta=0.05)
        # Below three single blows no median is published.
        self.assertIsNone(ap.godot_references([c])['slots']['rov.hull']
                          ['t60_median_s'])

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
            # No row rests on a licence the lawyer has to decide.
            self.assertNotIn(r['licence_source'], ('readme-nc',))
            self.assertNotEqual(r['licence_class'], 'UNKNOWN', r['path'])
        props = json.loads(ap.OUT_PROPS.read_text('utf-8'))
        for row in props:
            self.assertEqual(row['kind'], 'audio')
            self.assertIn(row['vid'], ('game', 'example', 'test', 'editor',
                                       'doc'))
            self.assertIsNone(ap.refusal(row['path']), row['path'])
        if ap.OUT_GODOT.exists():
            godot = json.loads(ap.OUT_GODOT.read_text('utf-8'))
            self.assertEqual(set(godot['slots']), set(ap.SLOTS))
            for slot in godot['slots'].values():
                self.assertNotIn('path', slot)
                if slot['t60_median_s'] is not None:
                    self.assertGreaterEqual(slot['t60_n'],
                                            ap.SLOT_T60_MIN)


if __name__ == '__main__':
    unittest.main()
