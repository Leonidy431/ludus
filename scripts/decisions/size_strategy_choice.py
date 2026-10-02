"""Seven ways to fit the game in the headset, chosen in the open.

Operator, 2026-10-02: «погугли как другие разработчики решают с таким
небольшим объемом памяти поищи 7 вариантов из 999 по параметрам
проекта и зачем шлему OBB».  The pool is every pair of a technique
other developers use (each with its published source) and a kind of
content it applies to; its size is what the catalogue honestly gives,
not 999 (TABOO 0.07 item 2).  Each pair is scored on the 48 parameters
of scripts/decisions/engine-params-48.json: the ones a size technique
touches get a rule from the technique's measured or published traits,
the rest score the same for every pair and say so.  Seven are taken,
the best first, one per technique, so the seven are seven different
answers and not one answer seven times.

    python3 scripts/decisions/size_strategy_choice.py          # report
    python3 scripts/decisions/size_strategy_choice.py --check  # CI

Constitution: ФОРМА (what the headset can carry and what it costs to
carry more) → ДЕЙСТВИЕ (weigh every known way by the project's own
parameters) → ЦЕЛЬ (the teaching's voices and places reach the headset
whole, without stutter and without a network).
"""

import json
import sys
from pathlib import Path

PARAMS = Path(__file__).resolve().parent / 'engine-params-48.json'

# Content of the headset build, as weighed by
# scripts/godot/obb_forecast.py (docs/OBB_FORECAST_2026-10-02.json).
CONTENT = ('engine', 'voices_en', 'voices_ru', 'music_choir', 'models',
           'textures', 'sfx')

# Techniques with their published source and traits:
#   apk     0..2  bytes taken out of the APK
#   memory  0..2  bytes taken out of the headset's RAM while playing
#   to_disk True  the bytes only move to the headset's disk
#   network True  needs a network at play or after install
#   parts   0..2  new moving parts (files, steps, tools)
#   ci      0..2  CI minutes it costs
#   risk    0..2  what it could break that the game needs
#   done    True  the build already does it (no new gain)
#   store   True  needs the store's upload settings (the operator's)
TECHNIQUES = {
    'own_engine_template': {
        'ru': 'Свой шаблон движка без неиспользуемых модулей',
        'source': 'docs.godotengine.org «Compiling for Android»; '
                  'godotforums.org/d/21005 (APK ~30 → ~7 МБ)',
        'apk': 2, 'memory': 1, 'to_disk': False, 'network': False,
        'parts': 1, 'ci': 1, 'risk': 1, 'done': False, 'store': False,
        'applies': ('engine',)},
    'thin_lto_size': {
        'ru': 'Оптимизация по размеру и thin LTO',
        'source': 'godotforums.org/d/21005 (use_thinlto)',
        'apk': 1, 'memory': 1, 'to_disk': False, 'network': False,
        'parts': 0, 'ci': 1, 'risk': 0, 'done': False, 'store': False,
        'applies': ('engine',)},
    'one_architecture': {
        'ru': 'Только arm64-v8a',
        'source': 'godotforums.org/d/24453',
        'apk': 2, 'memory': 0, 'to_disk': False, 'network': False,
        'parts': 0, 'ci': 0, 'risk': 0, 'done': True, 'store': False,
        'applies': ('engine',)},
    'compress_native_libs': {
        'ru': 'Сжатые нативные библиотеки в APK',
        'source': 'Godot gradle_build/compress_native_libraries',
        'apk': 2, 'memory': 0, 'to_disk': True, 'network': False,
        'parts': 1, 'ci': 0, 'risk': 0, 'done': False, 'store': False,
        'applies': ('engine',)},
    'obb_expansion': {
        'ru': 'Файл расширения OBB (до 4 ГБ, качается с APK)',
        'source': 'developers.meta.com/horizon/resources/publish-apk; '
                  '…/documentation/native/ps-assets',
        'apk': 2, 'memory': 0, 'to_disk': False, 'network': False,
        'parts': 1, 'ci': 1, 'risk': 1, 'done': False, 'store': False,
        'applies': ('voices_en', 'voices_ru', 'music_choir', 'models')},
    'required_asset_files': {
        'ru': 'Обязательные файлы ресурсов магазина (несколько по 4 ГБ)',
        'source': 'developers.meta.com/horizon/documentation/native/'
                  'ps-assets',
        'apk': 2, 'memory': 0, 'to_disk': False, 'network': False,
        'parts': 2, 'ci': 1, 'risk': 1, 'done': False, 'store': True,
        'applies': ('voices_en', 'voices_ru', 'music_choir', 'models')},
    'dynamic_asset_files': {
        'ru': 'Докачка ресурсов после установки (DLC)',
        'source': 'developers.meta.com/horizon/blog/introducing-multiple-'
                  'expansion-files-for-mobile-rift-and-future-platforms',
        'apk': 2, 'memory': 0, 'to_disk': False, 'network': True,
        'parts': 2, 'ci': 1, 'risk': 2, 'done': False, 'store': True,
        'applies': ('voices_en', 'music_choir', 'models')},
    'godot_resource_packs': {
        'ru': 'Пакеты ресурсов Godot (.pck) через load_resource_pack',
        'source': 'docs.godotengine.org «Exporting packs, patches, and '
                  'mods»',
        'apk': 2, 'memory': 0, 'to_disk': False, 'network': False,
        'parts': 1, 'ci': 1, 'risk': 0, 'done': False, 'store': False,
        'applies': ('voices_en', 'voices_ru', 'music_choir', 'models')},
    'language_pack': {
        'ru': 'Голоса каждого языка — отдельным пакетом',
        'source': 'developers.meta.com …/ps-assets (несколько файлов); '
                  'docs.godotengine.org «Exporting packs»',
        'apk': 2, 'memory': 1, 'to_disk': False, 'network': False,
        'parts': 1, 'ci': 1, 'risk': 0, 'done': False, 'store': False,
        'applies': ('voices_en', 'voices_ru')},
    'gpu_texture_compression': {
        'ru': 'Сжатие текстур на GPU (ETC2/ASTC)',
        'source': 'developers.meta.com/horizon/blog/top-tips-from-arm-'
                  'for-vr-asset-optimization',
        'apk': 1, 'memory': 2, 'to_disk': False, 'network': False,
        'parts': 0, 'ci': 0, 'risk': 0, 'done': True, 'store': False,
        'applies': ('textures', 'models')},
    'supercompressed_download': {
        'ru': 'Crunch/Basis для скачивания',
        'source': 'zilliz.com «compression techniques for VR assets» '
                  '(помогает скачиванию, не памяти)',
        'apk': 1, 'memory': 0, 'to_disk': False, 'network': False,
        'parts': 1, 'ci': 1, 'risk': 1, 'done': False, 'store': False,
        'applies': ('textures',)},
    'vorbis_streaming': {
        'ru': 'Ogg Vorbis с потоковым декодированием',
        'source': 'zilliz.com «compression techniques for VR assets»; '
                  'docs/gost/ОП_OBB_ПАКЕТ_РАСШИРЕНИЯ_ГОСТ_19.402.md',
        'apk': 2, 'memory': 2, 'to_disk': False, 'network': False,
        'parts': 0, 'ci': 0, 'risk': 0, 'done': False, 'store': False,
        'applies': ('voices_en', 'voices_ru', 'music_choir')},
    'procedural_synthesis': {
        'ru': 'Процедурный синтез вместо файлов',
        'source': 'godot/scripts/audio/place_synth.gd; '
                  'scripts/meta3d (проект)',
        'apk': 2, 'memory': 1, 'to_disk': False, 'network': False,
        'parts': 0, 'ci': 0, 'risk': 1, 'done': True, 'store': False,
        'applies': ('sfx', 'music_choir', 'models')},
    'lod_proxies': {
        'ru': 'Прокси вдали, полная модель только вблизи',
        'source': 'ТАБУ №0.32 п. 2; Б-2 (mangustik.glb ближе 2,0 м)',
        'apk': 0, 'memory': 2, 'to_disk': False, 'network': False,
        'parts': 1, 'ci': 0, 'risk': 0, 'done': False, 'store': False,
        'applies': ('models',)},
    'pss_memory_budget': {
        'ru': 'Бюджет памяти по PSS против предела шлема (5,75 ГиБ)',
        'source': 'developers.meta.com/horizon/documentation/native/'
                  'po-memory-ram (Quest 3: 5,75 ГиБ)',
        'apk': 0, 'memory': 2, 'to_disk': False, 'network': False,
        'parts': 0, 'ci': 0, 'risk': 0, 'done': False, 'store': False,
        'applies': ('engine', 'models', 'textures', 'music_choir')},
}

CHOSEN = ['thin_lto_size', 'vorbis_streaming', 'language_pack',
          'own_engine_template', 'pss_memory_budget',
          'godot_resource_packs', 'gpu_texture_compression']


def pool():
    out = []
    for tid, t in TECHNIQUES.items():
        for c in t['applies']:
            out.append((tid, c))
    return out


def rules(tid, content):
    """Points 0..2 per parameter; untouched parameters score 2."""
    t = TECHNIQUES[tid]
    gain = 0 if t['done'] else 1
    real_apk = 0 if t['to_disk'] else t['apk']
    pts = {('e%02d' % i): 2 for i in range(1, 49)}
    pts.update({
        # Lib/*.so room only from techniques on the engine.
        'e01': (2 if content == 'engine' and real_apk and gain else 0),
        'e02': real_apk * gain,
        'e03': 2 - t['risk'] if t['memory'] else 1,
        'e10': 2 - t['risk'],
        'e17': 2 - t['risk'],
        'e18': 2 if real_apk and not t['to_disk'] else 1,
        'e19': 0 if t['to_disk'] else 2,
        'e20': t['memory'] * gain if t['memory'] else 0,
        'e21': 0 if t['to_disk'] else 2,
        'e22': 2 - t['parts'],
        'e24': 2 - t['ci'],
        'e32': 0 if t['network'] else 2,
        'e35': 2 - t['parts'],
        'e40': 2 if t['done'] or t['source'].startswith('developers') or
        'docs.godotengine' in t['source'] else 1,
        'e41': 2 if content == 'engine' else 1,
        'e42': 0 if t['store'] else 2,
        'e46': 0 if t['network'] else 2,
    })
    return pts


def run():
    params = json.loads(PARAMS.read_text(encoding='utf-8'))['params']
    assert len(params) == 48
    weight = {p['id']: p['weight'] for p in params}
    scored = []
    for tid, c in pool():
        pts = rules(tid, c)
        assert set(pts) == set(weight)
        scored.append((sum(weight[k] * pts[k] for k in pts), tid, c))
    order = list(TECHNIQUES)
    scored.sort(key=lambda x: (-x[0], order.index(x[1]),
                               CONTENT.index(x[2])))
    seven, used = [], set()
    for s in scored:
        if s[1] not in used:
            seven.append(s)
            used.add(s[1])
        if len(seven) == 7:
            break
    return {'pool': len(scored), 'scored': scored, 'seven': seven,
            'best': 2 * sum(weight.values())}


def main(argv):
    r = run()
    picked = [t for _, t, _ in r['seven']]
    if '--check' in argv:
        if picked != CHOSEN:
            print('size strategies changed: %s, recorded %s' % (
                picked, CHOSEN))
            return 1
        print('size strategies: %s' % ', '.join(picked))
        return 0
    print('pool %d pairs of %d techniques x %d kinds of content; '
          'best possible %d' % (r['pool'], len(TECHNIQUES), len(CONTENT),
                                r['best']))
    for n, (s, t, c) in enumerate(r['seven'], 1):
        print('%d. %4d  %-26s %-12s %s' % (n, s, t, c,
                                           TECHNIQUES[t]['ru']))
    print('next after the seven:')
    rest = [x for x in r['scored'] if x[1] not in {t for t in picked}]
    for s, t, c in rest[:5]:
        print('   %4d  %-26s %s' % (s, t, c))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
