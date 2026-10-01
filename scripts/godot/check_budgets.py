#!/usr/bin/env python3
"""Budget gate for the Meta Quest build (docs/APK_REQUIREMENTS.md).

    python3 scripts/godot/check_budgets.py --tree
    python3 scripts/godot/check_budgets.py \
        --apk build/godot/ludus-dive-quest.apk
    python3 scripts/godot/check_budgets.py \
        --pck build/godot/web/index.pck

--tree checks the source side in godot/ before the build: the triangles
of every .glb and .gltf (counted in the file itself and compared with
the "triangles"/"tris" field of its .json, the field the GDScript tests
read), mesh files in formats the gate cannot count, the largest single
file the export would ship, and the total bytes of every file the
export would ship.

--apk checks a built APK: its size, the native libraries and their
ABIs, the dex files, the game content under assets/ and its largest
single file.

--pck checks a pack made with `godot --export-pack "Meta Quest"` (or
the Web pack, which uses the same filters): the same content and
largest-file budgets as assets/ in the APK, with the bytes per top
folder.  It is how a PR measures its APK delta when the APK itself
cannot be downloaded: export the pack before and after and compare the
--json outputs.

Every mode also has floors: a gate that finds no models, no exported
files, an empty pack or an APK without assets/ has measured nothing,
and that is reported as a breach, not as a pass.

The limits live in scripts/godot/apk-budgets.json, outside godot/, so
that the budget file itself does not ship in the headset build.  Exit
code 0 means every budget holds, 1 means at least one is breached, 2
means the input or the budgets file could not be read or is not
usable.  Messages for people are in Russian (the project's chat
language); the code and its comments are English.  Standard library
only, so the gate runs on a bare CI runner.
"""

import argparse
import fnmatch
import json
import numbers
import os
import re
import struct
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
GODOT = os.path.join(ROOT, 'godot')
BUDGETS = os.path.join(ROOT, 'scripts', 'godot', 'apk-budgets.json')
# CLAUDE.md TABOO 0.011 once named this path for the budgets.  The gate
# does not read it, and anything in godot/data/*.json ships in the APK,
# so a file there would drift from the real limits unseen.
STRAY_BUDGETS = os.path.join('data', 'apk-budgets.json')
PRESET = 'Meta Quest'

# Files Godot never packs as resources; they are dropped before the
# "largest file" check so a README or a Python helper does not count.
# Compared in lower case.
NOT_RESOURCES = ('.import', '.uid', '.md', '.py', '.txt', '.cfg', '.sh',
                 '.js', '.orig', '.blend1')

# Mesh formats: the gate counts triangles in glTF (binary and text);
# the others Godot can import too, but the gate cannot read them, so a
# model in one of them would ship unchecked.
MODELS_COUNTED = ('.glb', '.gltf')
MODELS_NOT_COUNTED = ('.obj', '.fbx', '.dae', '.blend')

GLB_MAGIC = 0x46546C67
GLB_JSON = 0x4E4F534A

# A headroom below this share of the limit is reported as a warning,
# so a budget is seen coming before it breaks the build.
WARN_SHARE = 0.10


class BudgetsError(Exception):
    """The budgets file is readable but not usable."""


class Report:
    """Collects rows of one run and decides the exit code."""

    def __init__(self):
        self.rows = []
        self.breaches = []
        self.notes = []
        self.folders = {}
        self.exceptions = []

    def check(self, name, value, limit, unit='Б', record=True):
        """Record one metric against its limit; value > limit breaches.

        record=False shows the row without adding a breach, for a
        summary row whose breaches were already named one by one.
        """
        headroom = (limit - value) / limit if limit else 0.0
        if value > limit:
            status = 'НАРУШЕНО'
            if record:
                self.breaches.append('%s: %s %s больше предела %s %s' % (
                    name, fmt(value), unit, fmt(limit), unit))
        elif headroom < WARN_SHARE:
            status = 'мало запаса'
        else:
            status = 'ок'
        self._row(name, value, limit, unit, headroom, status)

    def floor(self, name, value, least, unit='шт.'):
        """Record a floor: value < least means nothing was measured."""
        margin = (value - least) / least if least else 0.0
        if value < least:
            status = 'НАРУШЕНО'
            self.breaches.append(
                '%s: %s %s меньше нижней границы %s %s — ворота почти '
                'ничего не измерили' % (
                    name, fmt(value), unit, fmt(least), unit))
        else:
            status = 'ок'
        self._row(name + ' (не меньше)', value, least, unit, margin, status)

    def _row(self, name, value, limit, unit, headroom, status):
        self.rows.append({'metric': name, 'value': value, 'limit': limit,
                          'unit': unit, 'headroom_pct': round(
                              headroom * 100.0, 1), 'status': status})

    def breach(self, text):
        self.breaches.append(text)

    def note(self, text):
        self.notes.append(text)

    def print_table(self, title):
        print(title)
        print('  %-44s %14s %14s %8s  %s' % (
            'метрика', 'сейчас', 'предел', 'запас', 'итог'))
        for r in self.rows:
            print('  %-44s %14s %14s %7.1f%%  %s' % (
                r['metric'][:44], fmt(r['value']), fmt(r['limit']),
                r['headroom_pct'], r['status']))


def fmt(n):
    """Group digits with spaces, as Russian text does: 93 396 704."""
    if isinstance(n, float):
        return ('%.2f' % n).replace('.', ',')
    return '{:,}'.format(n).replace(',', ' ')


def load_budgets(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def _get(budgets, dotted):
    """The value at a dotted path, or raise BudgetsError naming it."""
    node = budgets
    for part in dotted.split('.'):
        if not isinstance(node, dict) or part not in node:
            raise BudgetsError('нет ключа %s' % dotted)
        node = node[part]
    return node


def _positive(budgets, dotted, integer=True):
    value = _get(budgets, dotted)
    kind = numbers.Integral if integer else numbers.Real
    if isinstance(value, bool) or not isinstance(value, kind) \
            or value <= 0:
        raise BudgetsError('%s должен быть %s больше нуля, а не %r' % (
            dotted, 'целым числом' if integer else 'числом', value))
    return value


def _check_exceptions(budgets, dotted, base):
    """Every exception names its reason, approval and blocker, and
    stays within exception_policy.max_factor of its base limit."""
    required = _get(budgets, 'exception_policy.required')
    factor = _positive(budgets, 'exception_policy.max_factor', False)
    if not isinstance(required, list) or 'limit' not in required:
        raise BudgetsError('exception_policy.required должен быть списком '
                           'полей, и limit в нём обязателен')
    try:
        exceptions = _get(budgets, dotted)
    except BudgetsError:
        return
    if not isinstance(exceptions, dict):
        raise BudgetsError('%s должен быть объектом' % dotted)
    for key, exc in exceptions.items():
        where = '%s["%s"]' % (dotted, key)
        if not isinstance(exc, dict):
            raise BudgetsError('%s должен быть объектом' % where)
        for field in required:
            if field not in exc or exc[field] in ('', None):
                raise BudgetsError('%s: нет поля %s' % (where, field))
        limit = exc['limit']
        if isinstance(limit, bool) or not isinstance(limit, numbers.Real) \
                or limit <= 0:
            raise BudgetsError('%s.limit должен быть числом больше нуля'
                               % where)
        if limit > factor * base:
            raise BudgetsError(
                '%s.limit %s больше %s — это %s базы %s; исключение выше '
                'этого — уже другой бюджет, его меняют строкой хора '
                '(docs/APK_REQUIREMENTS.md, п. (d) 4)' % (
                    where, fmt(limit), fmt(factor * base),
                    'x%s' % fmt(factor), fmt(base)))


def validate_budgets(budgets):
    """Raise BudgetsError when the file cannot drive the gate.

    Every limit either gate reads is checked here, the scene section of
    godot/tools/measure_budgets.gd included, so a broken budgets file
    turns the source step red before any scene is measured.
    """
    if not isinstance(budgets, dict):
        raise BudgetsError('ожидался объект JSON, а не %s' %
                           type(budgets).__name__)
    for dotted in ('apk.total_bytes.limit', 'apk.native_libs_bytes.limit',
                   'apk.dex_bytes.limit', 'apk.assets_bytes.limit',
                   'apk.largest_asset_bytes.limit',
                   'apk.min_assets_entries.limit', 'pck.min_files.limit',
                   'tree.content_bytes.limit',
                   'tree.largest_resource_bytes.limit',
                   'tree.model_triangles.limit', 'tree.min_models.limit',
                   'tree.min_exported_files.limit',
                   'scene.draw_calls_frame.limit',
                   'scene.primitives_two_eyes_est.limit',
                   'scene.static_memory_delta_bytes.limit',
                   'scene.texture_memory_over_empty_bytes.limit',
                   'scene.subviewport_bytes.limit',
                   'scene.audio_generators.limit',
                   'audio.pcm_clips_bytes.limit',
                   'audio.place_players.limit',
                   'audio.place_pcm_bytes.limit'):
        _positive(budgets, dotted)
    for dotted in ('scene.script_ms_mean_host.limit',
                   'scene.script_ms_max_host.limit',
                   'scene.script_host_max_load_per_core.limit',
                   'audio.synth_ms_per_second_host.limit'):
        _positive(budgets, dotted, integer=False)
    for dotted in ('apk.abis', 'apk.required_entries'):
        value = _get(budgets, dotted)
        if not isinstance(value, list) or not value or not all(
                isinstance(v, str) and v for v in value):
            raise BudgetsError('%s должен быть непустым списком строк'
                               % dotted)
    _check_exceptions(budgets, 'tree.model_triangles.exceptions',
                      _get(budgets, 'tree.model_triangles.limit'))
    for key, entry in _get(budgets, 'scene').items():
        if isinstance(entry, dict) and 'exceptions' in entry:
            _check_exceptions(budgets, 'scene.%s.exceptions' % key,
                              _positive(budgets, 'scene.%s.limit' % key,
                                        False))


def _gltf_triangles(gltf):
    """Triangles a parsed glTF draws.

    Every node that uses a mesh draws it once more, so a mesh is counted
    per use.  Only triangle modes count; points and lines draw none.
    """
    accessors = gltf.get('accessors', [])
    per_mesh = []
    for mesh in gltf.get('meshes', []):
        tris = 0
        for prim in mesh.get('primitives', []):
            mode = prim.get('mode', 4)
            if 'indices' in prim:
                count = accessors[prim['indices']]['count']
            else:
                count = accessors[prim['attributes']['POSITION']]['count']
            if mode == 4:
                tris += count // 3
            elif mode in (5, 6):
                tris += max(count - 2, 0)
        per_mesh.append(tris)
    uses = [n['mesh'] for n in gltf.get('nodes', []) if 'mesh' in n]
    if not uses:
        return sum(per_mesh)
    return sum(per_mesh[m] for m in uses)


def model_triangles(path):
    """Triangles of a .glb (its JSON chunk) or a .gltf (the file)."""
    if path.lower().endswith('.gltf'):
        with open(path, encoding='utf-8') as f:
            return _gltf_triangles(json.load(f))
    with open(path, 'rb') as f:
        head = f.read(20)
        if len(head) < 20:
            raise ValueError('файл короче заголовка GLB (%d Б)' % len(head))
        magic, _version, _length, clen, ctype = struct.unpack('<IIIII',
                                                              head)
        if magic != GLB_MAGIC or ctype != GLB_JSON:
            raise ValueError('не GLB 2.0')
        chunk = f.read(clen)
        if len(chunk) < clen:
            raise ValueError('JSON-блок GLB обрезан')
    return _gltf_triangles(json.loads(chunk))


def meta_triangles(json_path):
    """The triangle field of a model's .json: (value, problem).

    (None, '') without a passport or without the field; a field that is
    there but not a whole number is a problem, not a missing passport.
    """
    if not os.path.exists(json_path):
        return None, ''
    try:
        with open(json_path, encoding='utf-8') as f:
            meta = json.load(f)
    except (OSError, ValueError) as err:
        return None, 'паспорт не читается (%s)' % err
    if not isinstance(meta, dict):
        return None, ''
    key = 'triangles' if 'triangles' in meta else 'tris'
    if key not in meta:
        return None, ''
    value = meta[key]
    try:
        whole = not isinstance(value, bool) and isinstance(
            value, numbers.Real) and value == int(value) and value >= 0
    except (ValueError, OverflowError):
        whole = False
    if not whole:
        return None, 'поле %s = %r — не целое число' % (key, value)
    return int(value), ''


def export_excludes(godot_dir):
    """exclude_filter of the Meta Quest preset in export_presets.cfg.

    Read from the file itself, so the gate follows the export when a
    folder is added to or removed from the filter.
    """
    path = os.path.join(godot_dir, 'export_presets.cfg')
    name = None
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith('name='):
                name = line.split('=', 1)[1].strip('"')
            elif line.startswith('exclude_filter=') and name == PRESET:
                raw = line.split('=', 1)[1].strip('"')
                return [p.strip() for p in raw.split(',') if p.strip()]
    return []


def exported_files(godot_dir):
    """Paths (relative to godot/) the Android export would pack.

    all_resources packs every resource outside exclude_filter; hidden
    files, .godot/ and folders with a .gdignore are invisible to Godot.
    """
    excludes = export_excludes(godot_dir)
    out = []
    for dirpath, dirnames, filenames in os.walk(godot_dir):
        rel_dir = os.path.relpath(dirpath, godot_dir)
        if '.gdignore' in filenames:
            dirnames[:] = []
            continue
        dirnames[:] = sorted(d for d in dirnames if not d.startswith('.'))
        for name in sorted(filenames):
            if name.startswith('.'):
                continue
            rel = name if rel_dir == '.' else os.path.join(rel_dir, name)
            rel = rel.replace(os.sep, '/')
            if rel in ('project.godot', 'export_presets.cfg'):
                continue
            if rel.lower().endswith(NOT_RESOURCES):
                continue
            if any(fnmatch.fnmatch(rel, pat) for pat in excludes):
                continue
            out.append(rel)
    return out


def check_tree(budgets, godot_dir, rep):
    tree = budgets['tree']
    tri = tree['model_triangles']
    base = int(tri['limit'])
    exceptions = tri.get('exceptions', {})
    files = exported_files(godot_dir)

    if os.path.exists(os.path.join(godot_dir, STRAY_BUDGETS)):
        rep.breach('godot/%s существует, но ворота читают %s; файл в '
                   'godot/data ещё и уходит в APK. Удалить его; путь в '
                   'CLAUDE.md правит лид' % (
                       STRAY_BUDGETS, os.path.relpath(BUDGETS, ROOT)))

    worst = (0, '')
    seen_exc = set()
    models = [p for p in files if p.lower().endswith(MODELS_COUNTED)]
    for rel in files:
        if rel.lower().endswith(MODELS_NOT_COUNTED):
            rep.breach('%s: модель в формате %s не считается воротами '
                       '(считаются только %s); перевести в .glb' % (
                           rel, os.path.splitext(rel)[1],
                           ', '.join(MODELS_COUNTED)))
    for rel in models:
        path = os.path.join(godot_dir, rel)
        try:
            tris = model_triangles(path)
        except (OSError, ValueError, KeyError, IndexError, TypeError,
                struct.error) as err:
            rep.breach('%s: модель не читается (%s)' % (rel, err))
            continue
        meta, problem = meta_triangles(os.path.splitext(path)[0] + '.json')
        if problem:
            rep.breach('%s: %s' % (os.path.splitext(rel)[0] + '.json',
                                   problem))
        elif meta is not None and meta != tris:
            rep.breach('%s: в .json записано %s треугольников, в самой '
                       'модели %s — паспорт модели врёт' % (
                           rel, fmt(meta), fmt(tris)))
        if rel in exceptions:
            seen_exc.add(rel)
            exc = exceptions[rel]
            limit = int(exc['limit'])
            if tris > base:
                rep.exceptions.append({'what': rel, 'value': tris,
                                       'base': base, 'limit': limit,
                                       'blocker': exc['blocker'],
                                       'approval': exc['approval']})
                rep.note('ИСКЛЮЧЕНИЕ %s: %s треугольников при пределе '
                         'ТАБУ 0.32 п. 4 в %s; допущено до %s (%s, %s)' %
                         (rel, fmt(tris), fmt(base), fmt(limit),
                          exc['blocker'], exc['approval']))
            if tris > limit:
                rep.breach('%s: %s треугольников больше предела '
                           'исключения %s' % (rel, fmt(tris), fmt(limit)))
            continue
        if tris > base:
            rep.breach('%s: %s треугольников больше предела %s '
                       '(ТАБУ 0.32 п. 4, прокси для Quest 3)' % (
                           rel, fmt(tris), fmt(base)))
        worst = max(worst, (tris, rel))
    for rel in sorted(set(exceptions) - seen_exc):
        rep.note('исключение %s больше не нужно: файла нет в экспорте' %
                 rel)
    rep.check('треугольники: худшая модель вне исключений', worst[0],
              base, 'тр.', record=False)
    rep.floor('моделей .glb/.gltf', len(models),
              int(tree['min_models']['limit']))
    rep.note('худшая модель: %s; моделей .glb/.gltf: %d' % (
        worst[1], len(models)))

    biggest = max(((os.path.getsize(os.path.join(godot_dir, p)), p)
                   for p in files), default=(0, ''))
    rep.check('самый большой файл экспорта (исходник)', biggest[0],
              int(tree['largest_resource_bytes']['limit']))
    rep.floor('файлов в экспорте', len(files),
              int(tree['min_exported_files']['limit']))
    rep.note('самый большой файл: %s; файлов в экспорте: %d' % (
        biggest[1], len(files)))

    by_top = {}
    for rel in files:
        top = rel.split('/', 1)[0] if '/' in rel else '.'
        by_top[top] = by_top.get(top, 0) + os.path.getsize(
            os.path.join(godot_dir, rel))
    rep.check('файлы экспорта вместе (исходники)', sum(by_top.values()),
              int(tree['content_bytes']['limit']))
    for top, size in sorted(by_top.items(), key=lambda x: -x[1]):
        rep.note('  godot/%-33s %14s Б' % (top, fmt(size)))


def read_pck(path):
    """[(path, size, folder)] of a Godot 4 PCK (format 3 and later).

    Layout of Godot 4.4+: magic "GDPC", five uint32 (format, major,
    minor, patch, flags), uint64 file base, uint64 directory offset;
    the directory is a count, then per file: uint32 path length, the
    path, uint64 offset, uint64 size, 16 bytes of MD5, uint32 flags.
    Flag 2 means offsets count from the file base.

    Imported files sit in .godot/imported/ under hashed names; the
    .import or .remap file that points at one tells which source folder
    it came from, so the breakdown reads "art/derived/DEF-057", not a
    hash.
    """
    with open(path, 'rb') as f:
        data = f.read()
    if data[:4] != b'GDPC':
        raise ValueError('не PCK Godot: ' + path)
    fmt_ver, _ma, _mi, _pa, flags = struct.unpack_from('<5I', data, 4)
    if fmt_ver < 3:
        raise ValueError('формат PCK %d не поддержан (нужен 3+)' % fmt_ver)
    if flags & 1:
        raise ValueError('каталог PCK зашифрован: ' + path)
    base, pos = struct.unpack_from('<QQ', data, 24)
    if not flags & 2:
        base = 0
    count, = struct.unpack_from('<I', data, pos)
    pos += 4
    entries = []
    for _ in range(count):
        plen, = struct.unpack_from('<I', data, pos)
        pos += 4
        name = data[pos:pos + plen].rstrip(b'\0').decode('utf-8')
        pos += plen
        off, size = struct.unpack_from('<QQ', data, pos)
        pos += 16 + 16 + 4
        entries.append((name, base + off, size))
    owner = {}
    for name, off, size in entries:
        if name.endswith(('.import', '.remap')):
            text = data[off:off + size].decode('utf-8', 'replace')
            for target in re.findall(r'res://([^"\n]+)', text):
                owner[target] = os.path.dirname(name) or '.'
    out = []
    for name, _off, size in entries:
        folder = owner.get(name, os.path.dirname(name) or '.')
        out.append((name, size, folder))
    return out


def check_pck(budgets, pck_path, rep):
    apk = budgets['apk']
    files = read_pck(pck_path)
    rep.floor('файлов в PCK', len(files),
              int(budgets['pck']['min_files']['limit']))
    rep.check('контент PCK (без сжатия)', sum(f[1] for f in files),
              int(apk['assets_bytes']['limit']))
    big = max(files, key=lambda f: f[1], default=('', 0, ''))
    rep.check('самый большой файл в PCK', big[1],
              int(apk['largest_asset_bytes']['limit']))
    rep.note('PCK %s: %s Б, файлов %d; самый большой: %s' % (
        pck_path, fmt(os.path.getsize(pck_path)), len(files), big[0]))
    by_dir = {}
    for _name, size, folder in files:
        by_dir[folder] = by_dir.get(folder, 0) + size
    for key, size in sorted(by_dir.items(), key=lambda x: -x[1])[:12]:
        rep.note('  %-40s %14s Б' % (key, fmt(size)))
    rep.folders = by_dir


def check_apk(budgets, apk_path, rep):
    apk = budgets['apk']
    rep.check('APK целиком', os.path.getsize(apk_path),
              int(apk['total_bytes']['limit']))
    with zipfile.ZipFile(apk_path) as z:
        entries = z.infolist()
    names = [e.filename for e in entries]
    for need in apk['required_entries']:
        if need.endswith('/'):
            found = any(n.startswith(need) for n in names)
        else:
            found = need in names
        if not found:
            rep.breach('в APK нет %s — сборка потеряла %s' % (
                need, 'контент игры' if need.endswith('/') else 'код'))
    libs = [e for e in entries
            if e.filename.startswith('lib/') and e.filename.endswith('.so')]
    abis = sorted({e.filename.split('/')[1] for e in libs})
    extra = sorted(set(abis) - set(apk['abis']))
    missing = sorted(set(apk['abis']) - set(abis))
    if extra:
        rep.breach('лишняя архитектура в APK: %s (разрешено только %s); '
                   'вторая архитектура удваивает движок' % (
                       ', '.join(extra), ', '.join(apk['abis'])))
    if missing:
        rep.breach('в APK нет архитектуры %s из бюджета (Quest 3 '
                   'запускает только arm64-v8a)' %
                   ', '.join(missing))
    rep.check('нативные библиотеки lib/*.so',
              sum(e.file_size for e in libs),
              int(apk['native_libs_bytes']['limit']))
    dex = [e for e in entries
           if '/' not in e.filename and e.filename.endswith('.dex')]
    rep.check('classes*.dex', sum(e.file_size for e in dex),
              int(apk['dex_bytes']['limit']))
    assets = [e for e in entries if e.filename.startswith('assets/')]
    rep.floor('файлов в assets/', len(assets),
              int(apk['min_assets_entries']['limit']))
    rep.check('контент assets/ (без сжатия)',
              sum(e.file_size for e in assets),
              int(apk['assets_bytes']['limit']))
    big = max(assets, key=lambda e: e.file_size, default=None)
    rep.check('самый большой файл в assets/',
              big.file_size if big else 0,
              int(apk['largest_asset_bytes']['limit']))
    if big:
        rep.note('самый большой файл в APK: %s' % big.filename)
    rep.note('записей в APK: %d; ABI: %s; контент в сжатом виде: %s Б' % (
        len(entries), ', '.join(abis),
        fmt(sum(e.compress_size for e in assets))))


def summary(rep):
    """The last line: breaches, or a pass that names its exceptions."""
    if rep.breaches:
        print('ИТОГ: нарушено бюджетов — %d. Сборка остановлена; причина '
              'и путь исправления — docs/APK_REQUIREMENTS.md.' %
              len(rep.breaches))
        for b in rep.breaches:
            print('  ✗ ' + b)
        return 1
    if rep.exceptions:
        waiting = [e['blocker'] + (', ждёт оператора'
                                   if str(e['approval']).startswith(
                                       'pending') else '')
                   for e in rep.exceptions]
        print('ИТОГ: бюджеты соблюдены; действуют исключения: %d (%s) — '
              'выше базового предела, docs/APK_REQUIREMENTS.md.' % (
                  len(rep.exceptions), '; '.join(waiting)))
        return 0
    print('ИТОГ: все бюджеты соблюдены.')
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(
        description='Бюджеты APK для шлема (docs/APK_REQUIREMENTS.md).')
    ap.add_argument('--tree', action='store_true',
                    help='проверить исходники в godot/')
    ap.add_argument('--apk', metavar='PATH',
                    help='проверить собранный APK')
    ap.add_argument('--pck', metavar='PATH',
                    help='проверить PCK из --export-pack "Meta Quest"')
    ap.add_argument('--budgets', default=BUDGETS,
                    help='файл бюджетов (по умолчанию %(default)s)')
    ap.add_argument('--godot', default=GODOT,
                    help='каталог проекта Godot (по умолчанию %(default)s)')
    ap.add_argument('--json', action='store_true',
                    help='напечатать итог ещё и как JSON (для ревизора)')
    args = ap.parse_args(argv)
    if not (args.tree or args.apk or args.pck):
        ap.error('нужен хотя бы один из --tree, --apk PATH, --pck PATH')
    try:
        budgets = load_budgets(args.budgets)
        validate_budgets(budgets)
    except (OSError, ValueError, BudgetsError) as err:
        print('Не читается файл бюджетов %s: %s' % (args.budgets, err))
        return 2

    rep = Report()
    try:
        if args.tree:
            check_tree(budgets, args.godot, rep)
        if args.apk:
            check_apk(budgets, args.apk, rep)
        if args.pck:
            check_pck(budgets, args.pck, rep)
    except (OSError, ValueError, struct.error, zipfile.BadZipFile) as err:
        print('Вход не читается: %s' % err)
        return 2

    what = ' и '.join(w for w, on in (('исходники godot/', args.tree),
                                      ('APK ' + str(args.apk), args.apk),
                                      ('PCK ' + str(args.pck), args.pck))
                      if on)
    rep.print_table('Бюджеты: %s (пределы: %s)' % (
        what, os.path.relpath(args.budgets, ROOT)))
    for n in rep.notes:
        print('  · ' + n)
    if args.json:
        print(json.dumps({'rows': rep.rows, 'breaches': rep.breaches,
                          'notes': rep.notes, 'folders': rep.folders,
                          'exceptions': rep.exceptions},
                         ensure_ascii=False))
    return summary(rep)


if __name__ == '__main__':
    sys.exit(main())
