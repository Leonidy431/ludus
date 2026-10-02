"""One decision for the church-word stop-list, chosen in the open.

Operator, 2026-10-02: «Реши это. Выбери из 999 одно решение по 48
параметрам проекта» -- about the stop-list that lived as three copies
(GDScript, Python, a JS regex over the GDScript source) and matched by
substring, so «помощи» was caught for «мощи» and «Богородицы» was
missed (blind spot 16 of docs/BLINDSPOTS_CODE_BREAKTHROUGH_2026-10-01).

The pool of solutions is the product of explicit design dimensions,
so its size is what the dimensions honestly give, not 999 (TABOO 0.07
item 2).  Hard constraints prune what cannot work in this project; every
remaining variant is scored on the 48 parameters of
scripts/decisions/project-params-48.json by the rules below, one rule
per parameter, 0, 1 or 2 points times the parameter's weight.  Ties are
broken by the order of the dimensions as written, so the run is
deterministic.

    python3 scripts/decisions/stoplist_choice.py          # pool, top 10
    python3 scripts/decisions/stoplist_choice.py --check  # CI

--check fails when the choice differs from the one recorded in
docs/decisions/STOPLIST_SINGLE_SOURCE_2026-10-02.md (CHOSEN below) or
when the files the choice names are missing or their copies differ.

Constitution: ФОРМА (the project's own 48 parameters, written as data)
→ ДЕЙСТВИЕ (every variant scored by the same open rules) → ЦЕЛЬ (one
stop-list keeps the holy off the labels in both versions alike).
"""

import itertools
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PARAMS = Path(__file__).resolve().parent / 'project-params-48.json'

# The design dimensions, in the order that also breaks ties.
DIMS = {
    # Where the master list lives.
    'home': ['godot_data', 'public_data', 'scripts_data', 'gd_const',
             'py_module', 'per_consumer'],
    # How it is written down.
    'format': ['json', 'txt', 'csv', 'yaml', 'code'],
    # How a text is matched against it.
    'match': ['stem_twins_forms', 'word_start_twins', 'word_start',
              'whole_forms', 'regex_entries', 'substring', 'lemmatizer'],
    # Who reads it.
    'consumers': ['godot_js_py', 'godot_js', 'godot'],
    # How the copies are kept the same.
    'sync': ['cmp_copy', 'single_path', 'generated_check',
             'source_regex', 'none'],
    # Where a drift or a wrong verdict is stopped.
    'gate': ['ci_test_job', 'local_only', 'none'],
    # Which side runs the corpus of must-flag and must-pass lines.
    'corpus': ['shared', 'godot', 'js', 'none'],
    # Whether ё is read as е.
    'yo': ['yes', 'no'],
    # How the headset holds the list.
    'load': ['once_cached', 'const', 'each_call'],
}

DATA_HOMES = ('godot_data', 'public_data', 'scripts_data')
CODE_HOMES = ('gd_const', 'py_module', 'per_consumer')
TWIN_MATCH = ('stem_twins_forms', 'word_start_twins', 'regex_entries')

# The variant recorded in the decision document.
CHOSEN = {'home': 'godot_data', 'format': 'json',
          'match': 'stem_twins_forms', 'consumers': 'godot_js_py',
          'sync': 'cmp_copy', 'gate': 'ci_test_job', 'corpus': 'shared',
          'yo': 'yes', 'load': 'once_cached'}

# The files the chosen variant stands on, and its two copies.
CHOSEN_FILES = [
    'godot/data/church-words.json', 'public/ludus/data/church-words.json',
    'godot/scripts/locations_core.gd', 'public/ludus/ludus-church-words.js',
    'scripts/locations/church_words.py',
    'tests/fixtures/church-words-corpus.json',
    'godot/tests/test_church_words.gd', 'tests/church-words.test.js',
    'scripts/locations/tests/test_church_words.py',
]
COPIES = ('godot/data/church-words.json',
          'public/ludus/data/church-words.json')


def hard_reason(v):
    """Return why a variant cannot work here, or None when it can."""
    data = v['format'] != 'code'
    if (v['home'] in CODE_HOMES) == data:
        return 'home and format disagree'
    if v['format'] == 'yaml':
        return 'Godot 4 has no YAML parser'
    if v['match'] == 'lemmatizer':
        return 'no MIT morphology for GDScript without growing the APK'
    if v['home'] == 'per_consumer' and v['consumers'] == 'godot':
        return 'one consumer: the same as gd_const'
    if v['home'] in ('public_data', 'scripts_data') and v['sync'] not in (
            'cmp_copy', 'generated_check'):
        return 'the APK reads only godot/: needs a checked copy'
    if v['sync'] == 'source_regex' and (
            v['home'] != 'gd_const' or v['consumers'] == 'godot'):
        return 'source parsing needs a GDScript list and a second reader'
    if v['sync'] == 'cmp_copy' and not data:
        return 'cmp compares a data file'
    if v['sync'] == 'generated_check' and v['home'] not in (
            'scripts_data', 'py_module'):
        return 'a generator needs a generator source'
    if v['sync'] == 'single_path' and v['home'] != 'godot_data':
        return 'one path for all readers is godot/data only'
    if v['consumers'] != 'godot' and v['sync'] == 'none':
        return 'the lists drift (the operator\'s point)'
    if v['load'] == 'const' and data:
        return 'a data file is loaded, not compiled'
    if v['load'] != 'const' and not data:
        return 'a code literal is compiled, not loaded'
    if v['corpus'] in ('js', 'shared') and v['consumers'] == 'godot':
        return 'a JS corpus needs a JS reader'
    return None


def web_copy(v):
    """Whether the web build keeps the same list beside its own code."""
    return (v['home'] == 'public_data' or v['sync'] == 'cmp_copy'
            or v['sync'] == 'generated_check')


def rules(v):
    """Points 0-2 for each of the 48 parameters, by explicit rules."""
    data = v['format'] != 'code'
    js = v['consumers'] in ('godot_js', 'godot_js_py')
    py = v['consumers'] == 'godot_js_py'
    m, s, c = v['match'], v['sync'], v['corpus']
    checked = s in ('cmp_copy', 'generated_check', 'single_path')
    gate = {'ci_test_job': 2, 'local_only': 1, 'none': 0}[v['gate']]
    return {
        'p01': 2 if checked else (1 if s == 'source_regex'
                                  or v['consumers'] == 'godot' else 0),
        'p02': (gate if checked else min(gate, 1) if s == 'source_regex'
                else 1 if v['consumers'] == 'godot' else 0),
        'p03': {'substring': 0, 'word_start': 1, 'word_start_twins': 2,
                'whole_forms': 2, 'stem_twins_forms': 2,
                'regex_entries': 1}[m],
        'p04': {'substring': 1, 'word_start': 1, 'word_start_twins': 1,
                'whole_forms': 0, 'stem_twins_forms': 2,
                'regex_entries': 2}[m],
        'p05': {'shared': 2, 'godot': 1, 'js': 1, 'none': 0}[c],
        'p06': 0 if not js else {'shared': 2, 'godot': 1, 'js': 1,
                                 'none': 0}[c],
        'p07': 2 if not data else 1,
        'p08': 0 if v['load'] == 'each_call' else 2,
        'p09': {'code': 2, 'json': 2, 'txt': 1, 'csv': 1}[v['format']],
        'p10': (0 if not js or s == 'source_regex' else
                {'json': 2, 'txt': 2, 'csv': 1, 'code': 1}[v['format']]),
        'p11': 0 if not py else (2 if data else 1),
        'p12': 2 if py else 0,
        'p13': 2 if js else 0,
        'p14': 2 if web_copy(v) else 0,
        'p15': 0 if s == 'source_regex' else 2,
        'p16': 2 if data else 1,
        'p17': {'stem_twins_forms': 2, 'word_start_twins': 2,
                'regex_entries': 1}.get(m, 0),
        'p18': {'stem_twins_forms': 2, 'whole_forms': 2,
                'regex_entries': 1}.get(m, 0),
        'p19': 2,
        'p20': 2 if v['yo'] == 'yes' else 0,
        'p21': 2,
        'p22': 2,
        'p23': 2,
        'p24': 1 if m == 'substring' else 2,
        'p25': 2,
        'p26': 1 if v['load'] == 'each_call' else 2,
        'p27': 1 if s == 'generated_check' else 2,
        # A master outside both trees needs two copies, two edits.
        'p28': (2 if s in ('single_path', 'source_regex') else
                0 if s == 'cmp_copy' and v['home'] == 'scripts_data' else
                1 if s in ('cmp_copy', 'generated_check') else
                2 if v['consumers'] == 'godot' else 0),
        'p29': 0 if m == 'regex_entries' else 2,
        'p30': 2 if v['format'] == 'json' else 1,
        'p31': 2 if v['format'] in ('json', 'csv') else 1,
        'p32': 2 if not data else 1,
        # The APK comes first (TABOO 0.01): best when the headset reads
        # the master itself, worst when it reads a generator's output.
        'p33': (2 if v['home'] in ('godot_data', 'gd_const') else
                0 if s == 'generated_check' else 1),
        'p34': (2 if web_copy(v) and s in ('cmp_copy', 'generated_check')
                else 1 if s in ('single_path', 'source_regex') else 0),
        'p35': 2 if checked else (1 if s == 'source_regex' else 0),
        'p36': 0 if c == 'none' else gate,
        'p37': (2 if m in TWIN_MATCH and c != 'none' else
                1 if m in TWIN_MATCH else 0),
        'p38': 2,
        'p39': (0 if v['load'] == 'each_call' else
                1 if m == 'regex_entries' else 2),
        'p40': 2 if c in ('godot', 'shared') else 0,
        'p41': 2 if c in ('js', 'shared') else 0,
        'p42': 2 if py else 0,
        'p43': 2,
        'p44': 1 if m == 'whole_forms' else 2,
        'p45': 2,
        'p46': 1 if v['load'] == 'each_call' else 2,
        'p47': 2,
        'p48': 2,
    }


def load_params():
    """The 48 parameters with their weights, checked for shape."""
    with open(PARAMS, encoding='utf-8') as f:
        params = json.load(f)['params']
    ids = [p['id'] for p in params]
    assert len(params) == 48 and len(set(ids)) == 48, 'need 48 params'
    return params


def run():
    """Enumerate, prune, score and rank; return the facts of the run."""
    params = load_params()
    weight = {p['id']: p['weight'] for p in params}
    names = list(DIMS)
    pool = list(itertools.product(*DIMS.values()))
    pruned = Counter()
    scored = []
    for order, values in enumerate(pool):
        v = dict(zip(names, values))
        why = hard_reason(v)
        if why:
            pruned[why] += 1
            continue
        pts = rules(v)
        assert set(pts) == set(weight), 'a rule per parameter'
        total = sum(weight[k] * pts[k] for k in pts)
        scored.append((-total, order, v, pts))
    scored.sort(key=lambda x: (x[0], x[1]))
    best = 2 * sum(weight.values())
    return {'pool': len(pool), 'pruned': pruned, 'scored': scored,
            'max': best, 'params': params}


def short(v):
    """A variant as one line of its dimension values."""
    return ' / '.join(v[k] for k in DIMS)


def report(facts, top=10):
    """Print the pool size, the pruning and the top of the ranking."""
    n, kept = facts['pool'], len(facts['scored'])
    print('pool N = %d (product of %s)' % (n, ' x '.join(
        str(len(x)) for x in DIMS.values())))
    print('pruned by hard constraints: %d; scored: %d' % (n - kept, kept))
    for why, k in sorted(facts['pruned'].items(), key=lambda x: -x[1]):
        print('  %6d  %s' % (k, why))
    print('max score %d; top %d:' % (facts['max'], top))
    print('  dims: ' + ' / '.join(DIMS))
    for rank, (neg, _o, v, _p) in enumerate(facts['scored'][:top], 1):
        print('%3d  %d  %s' % (rank, -neg, short(v)))
    chosen = facts['scored'][0][2]
    print('chosen: ' + short(chosen))
    return chosen


def check(chosen):
    """Fail when the choice or its files differ from the record."""
    errors = []
    if chosen != CHOSEN:
        errors.append('the choice is not the recorded one')
    for f in CHOSEN_FILES:
        if not (ROOT / f).is_file():
            errors.append('missing ' + f)
    a, b = (ROOT / p for p in COPIES)
    if a.is_file() and b.is_file() and a.read_bytes() != b.read_bytes():
        errors.append('the two copies of the list differ')
    for e in errors:
        print('ERROR: ' + e)
    return not errors


def main(argv):
    chosen = report(run())
    if '--check' in argv:
        return 0 if check(chosen) else 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
