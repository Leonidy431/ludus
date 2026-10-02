"""The 99 locations keep the standard of the evening-watch cell.

CLAUDE.md TABOO 0.013 (the location standard), 0.07 (an honest pool,
five open criteria, deterministic, diverse), 0.011 (the APK budget),
0.2/0.4/0.26 (holy things and sacraments).  Run from the repository
root: python3 -m unittest discover scripts/locations/tests
"""

import json
import math
import sys
import unittest
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

import locations_99 as L  # noqa: E402
import register as reg  # noqa: E402

INV, CANDS, CHOSEN, LOCS = L.build()


class InventoryTest(unittest.TestCase):
    def test_plots_are_counted_from_their_sources(self):
        c = INV['counts']
        self.assertEqual(c['missions'], 99)
        self.assertEqual(c['acts'], 7)
        self.assertEqual(c['atlas_nodes'], 99)
        self.assertEqual(c['kiberslav_nodes'], 99)
        self.assertEqual(c['dive_tasks'], 8)
        self.assertEqual(c['witness_scenes'], 7)
        self.assertEqual(c['thresholds'], 6)
        self.assertEqual(c['passions'], 8)
        self.assertEqual(c['dream_missions_declared'], 12)
        self.assertEqual(c['dream_missions_written'], 0)

    def test_299_is_answered_honestly(self):
        c = INV['counts']
        self.assertEqual(c['three_lists'], 297)
        self.assertEqual(c['plot_units'], 338)
        self.assertNotEqual(c['plot_units'], 299)


class PoolTest(unittest.TestCase):
    def test_pool_is_the_register_not_padded(self):
        self.assertEqual(len(CANDS), len(reg.PLACES))
        self.assertGreaterEqual(len(CANDS), L.K)
        self.assertEqual(len({c['id'] for c in CANDS}), len(CANDS))

    def test_every_candidate_names_a_plot_of_ours(self):
        for c in CANDS:
            self.assertTrue(c['plots'], c['id'])
            for p in c['plots']:
                self.assertIn(p, INV['plots'], (c['id'], p))

    def test_every_record_is_a_real_proxy(self):
        loc = {f.stem for f in (L.MODELS / 'loc').glob('*.json')}
        for c in CANDS:
            for r in c['records']:
                self.assertIn(r, loc, (c['id'], r))

    def test_sacraments_are_never_performed(self):
        refused = {c['id'] for c in CANDS if 'safety' in c['reasons']}
        for pid in ('first-liturgy-shore', 'confession-stone',
                    'martyrs-1339'):
            self.assertIn(pid, refused)

    def test_rewrite_only_plots_do_not_pass(self):
        sacristy = [c for c in CANDS if c['id'] == 'sacristy'][0]
        self.assertIn('plots-on-rewrite', sacristy['reasons'])


class SelectionTest(unittest.TestCase):
    def test_k_is_99_and_unique(self):
        self.assertEqual(len(LOCS), 99)
        self.assertEqual(len({x['id'] for x in LOCS}), 99)

    def test_deterministic(self):
        again = L.build()
        self.assertEqual(L.data_text(INV, CANDS, LOCS),
                         L.data_text(again[0], again[1], again[3]))

    def test_only_gated_candidates_are_chosen(self):
        for c in CHOSEN:
            self.assertTrue(c['gate'], (c['id'], c['reasons']))
            self.assertGreaterEqual(c['score']['safety'], 7)
            self.assertGreaterEqual(c['score']['readable'], 4)
            self.assertGreaterEqual(c['score']['teaching'], 5)

    def test_diversity(self):
        kinds = Counter(x['kind'] for x in LOCS)
        self.assertLessEqual(max(kinds.values()), L.PER_KIND)
        fam = Counter(f for x in LOCS for f in x['families'])
        for f, n in L.MIN_FAMILY.items():
            self.assertGreaterEqual(fam[f], n, f)

    def test_every_live_mission_has_a_place(self):
        cov = L.coverage(CHOSEN, INV)
        for p, v in cov.items():
            if p.startswith('M') and not INV['plots'][p]['rewrite']:
                self.assertIn(v, ('new', 'built'), p)

    def test_score_is_the_sum_of_five_criteria(self):
        for x in LOCS:
            self.assertEqual(set(x['score']), {'truth', 'teaching',
                                               'readable', 'novelty',
                                               'safety'})
            self.assertEqual(sum(x['score'].values()), x['total'])
            for v in x['score'].values():
                self.assertTrue(0 <= v <= 10)


class HeartTest(unittest.TestCase):
    def test_one_heart_from_a_real_core(self):
        cores = {'RuleCore', 'MissionCore', 'DiveCore', 'AtlasTraces',
                 'TrialCore', 'PassionCore', 'WitnessCore', 'TypikonCore',
                 'listen', 'new'}
        for x in LOCS:
            self.assertIn(x['heart']['core'], cores, x['id'])

    def test_kitezh_is_listened_to_not_counted(self):
        # Kiberslav node 76: no marker, no reward, no record.  RuleCore's
        # stillness is recorded (and lifts a fall), so it is not the
        # heart of Svetloyar.
        x = next(x for x in LOCS if x['id'] == 'svetloyar')
        self.assertEqual(x['heart']['core'], 'listen')
        self.assertNotIn('слышно', x['lesson'])

    def test_reuse_first(self):
        new = sum(1 for x in LOCS if x['heart']['core'] == 'new')
        self.assertLess(new, len(LOCS) / 3)

    def test_new_actions_carry_the_constitution(self):
        for x in LOCS:
            if x['heart']['core'] == 'new':
                line = x['heart']['constitution']
                for word in ('ФОРМА', 'ДЕЙСТВИЕ', 'ЦЕЛЬ'):
                    self.assertIn(word, line, x['id'])

    def test_witness_hearts_are_only_witness(self):
        for x in LOCS:
            if x['heart']['core'] == 'WitnessCore':
                self.assertEqual(x['heart']['ru'],
                                 'Постоять у черты, склонить голову, уйти')

    def test_heart_resolution_refuses_unknown_ids(self):
        self.assertIsNone(L.heart_of('rule:communion', INV))
        self.assertIsNone(L.heart_of('talk:anahit/no_such_node', INV))
        self.assertIsNone(L.heart_of('dive:fly', INV))
        self.assertIsNotNone(L.heart_of('rule:guard_thoughts', INV))


class StandardTest(unittest.TestCase):
    """TABOO 0.013 items 1-6, checked on every chosen location."""

    def test_every_thing_has_its_slot(self):
        for x in LOCS:
            self.assertEqual(x['unplaced'], [], x['id'])
            self.assertEqual(len(x['slots']), len(x['wishlist']), x['id'])

    def test_clear_of_heart_and_passage_and_in_bounds(self):
        for c in CHOSEN:
            plan = L.layout(c)
            w, d = c['size_m'][0], c['size_m'][1]
            hx, hz = plan['heart_at'][0], plan['heart_at'][2]
            pas = plan['passage']
            layers = {}
            for p in plan['placed']:
                r = p['rect']
                self.assertGreaterEqual(r[0], -w / 2 - 1e-6, c['id'])
                self.assertLessEqual(r[2], w / 2 + 1e-6, c['id'])
                self.assertGreaterEqual(r[1], -d / 2 - 1e-6, c['id'])
                self.assertLessEqual(r[3], d / 2 + 1e-6, c['id'])
                if p['mount'] == 'heart':
                    continue
                gap = math.hypot(max(r[0] - hx, 0, hx - r[2]),
                                 max(r[1] - hz, 0, hz - r[3]))
                self.assertGreaterEqual(gap, L.CLEAR_M - 1e-6,
                                        (c['id'], p['object']))
                layer = ('wall' if p['mount'] in ('wall', 'stand') or (
                    p['mount'] == 'holy' and p['pos'][1] > 1.0)
                    else 'top' if p['pos'][1] > 0.3 else 'ground')
                if layer == 'ground':
                    self.assertFalse(L._overlap(r, pas),
                                     (c['id'], p['object']))
                for q in layers.get(layer, []):
                    self.assertFalse(L._overlap(r, q),
                                     (c['id'], p['object']))
                layers.setdefault(layer, []).append(r)

    def test_at_most_two_states_of_one_thing(self):
        for x in LOCS:
            for key, n in Counter(x['wishlist']).items():
                self.assertLessEqual(n, 2, (x['id'], key))

    def test_holy_things_only_in_their_place(self):
        for x in LOCS:
            holy = [k for k in x['wishlist'] if reg.OBJECTS[k]['holy']]
            self.assertLessEqual(len(holy), 1, x['id'])
            for s in x['slots']:
                is_holy = bool(reg.OBJECTS[s['object']]['holy'])
                self.assertEqual(s['mount'] == 'holy', is_holy,
                                 (x['id'], s['object']))
            if holy:
                hp = x['holy_place']
                self.assertTrue(hp['noInteract'] and hp['noLoot'])
                self.assertFalse(hp['tag'])
                self.assertNotEqual(reg.OBJECTS[holy[0]]['source'], 'raw')
                t = L.thing(holy[0])
                # Flat: a board or a relief, never a statue.
                if t['proxy'] and hp['form'] == 'flat' and \
                        t['state'] != 'volume':
                    self.assertLessEqual(t['depth_m'], 0.06, x['id'])
            else:
                self.assertIsNone(x['holy_place'])

    def test_lampada_only_at_a_holy_thing(self):
        for x in LOCS:
            k = x['light']['kelvin']
            lo, hi = L.LIGHT_K[x['light']['class']]
            self.assertTrue(lo <= k <= hi, x['id'])
            if x['light']['class'] == 'lampada':
                self.assertIsNotNone(x['holy_place'], x['id'])

    def test_no_church_word_labels(self):
        for x in LOCS:
            texts = [x['title_ru'], x['heart']['ru']] + [
                reg.OBJECTS[k]['ru'] for k in x['wishlist']
                if not reg.OBJECTS[k]['holy']]
            for text in texts:
                self.assertFalse(L.has_church_word(text), (x['id'], text))

    def test_constitution_line(self):
        for x in LOCS:
            for word in ('ФОРМА', 'ДЕЙСТВИЕ', 'ЦЕЛЬ'):
                self.assertIn(word, x['constitution'], x['id'])

    def test_underwater_holds_volumes(self):
        for x in LOCS:
            if x['shell']['type'] != 'underwater':
                continue
            self.assertEqual(x['light']['class'], 'instrument', x['id'])
            for k in x['wishlist']:
                t = L.thing(k)
                self.assertTrue(t['state'] == 'volume' or t['holy'],
                                (x['id'], k))

    def test_layout_reports_what_does_not_fit(self):
        c = dict(CHOSEN[0], objects=['spruce-log'], shell='room',
                 size_m=[3, 3, 2.6], heart_spec='rule:stillness')
        self.assertEqual(L.layout(c)['unplaced'], ['spruce-log'])


class BudgetTest(unittest.TestCase):
    """TABOO 0.011: measured from the proxy files, not by eye."""

    def test_every_location_fits_once_cards_are_merged(self):
        for x in LOCS:
            b = x['budget']
            self.assertTrue(b['ok'], x['id'])
            self.assertLessEqual(b['draw_calls_merged'], L.MAX_DRAWS)
            self.assertLessEqual(2 * b['tris_worst'], L.MAX_TRIS_TWO_EYES)

    def test_as_is_overs_are_named(self):
        over = [x['id'] for x in LOCS if not x['budget']['ok_as_is']]
        doc = L.OUT_DOC.read_text(encoding='utf-8')
        for pid in over:
            self.assertIn(pid, doc)

    def test_every_proxy_within_the_quest_budget(self):
        for k in {k for x in LOCS for k in x['wishlist']}:
            t = L.thing(k)
            if t['tris'] is not None:
                self.assertLessEqual(t['tris'], L.MAX_TRIS, k)

    def test_data_file_is_small(self):
        self.assertLessEqual(L.OUT_DATA.stat().st_size, L.MAX_FILE_BYTES)


class FilesTest(unittest.TestCase):
    def test_outputs_are_current(self):
        self.assertEqual(L.main(['--check']), 0)

    def test_raw_store_never_holds_a_holy_thing(self):
        hits = L.load_raw_hits()
        for k in hits:
            self.assertFalse(reg.OBJECTS[k]['holy'], k)

    def test_data_names_every_wished_thing_once(self):
        data = json.loads(L.OUT_DATA.read_text(encoding='utf-8'))
        wished = {k for x in data['locations'] for k in x['wishlist']}
        self.assertEqual(set(data['things']), wished)
        self.assertEqual(data['k'], 99)
        self.assertEqual(data['pool_size'], len(CANDS))


if __name__ == '__main__':
    unittest.main()
