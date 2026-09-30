#!/usr/bin/env python3
"""Budget gate for the Meta Quest build (docs/APK_REQUIREMENTS.md).

    python3 scripts/godot/check_budgets.py --tree
    python3 scripts/godot/check_budgets.py \
        --apk build/godot/ludus-dive-quest.apk

--tree checks the source side in godot/ before the build: the triangles
of every .glb (counted in the file itself and compared with the
"triangles"/"tris" field of its .json, the field the GDScript tests
read), the largest single file the export would ship, and the total
bytes of godot/art, godot/models and godot/data.

--apk checks a built APK: its size, the native libraries and their
ABIs, the dex files, the game content under assets/ and its largest
single file.

--pck checks a pack made with `godot --export-pack "Meta Quest"`: the
same content and largest-file budgets as assets/ in the APK, with the
bytes per top folder.  It is how a PR measures its APK delta when the
APK itself cannot be downloaded: export the pack before and after and
compare the --json outputs.

The limits live in scripts/godot/apk-budgets.json, outside godot/, so
that the budget file itself does not ship in the headset build.  Exit
code 0 means every budget holds, 1 means at least one is breached, 2
means the input could not be read.  Messages for people are in Russian
(the project's chat language); the code and its comments are English.
Standard library only, so the gate runs on a bare CI runner.
"""

import argparse
import fnmatch
import json
import os
import re
import struct
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
GODOT = os.path.join(ROOT, 'godot')
BUDGETS = os.path.join(ROOT, 'scripts', 'godot', 'apk-budgets.json')
PRESET = 'Meta Quest'

# Files Godot never packs as resources; they are dropped before the
# "largest file" check so a README or a Python helper does not count.
NOT_RESOURCES = ('.import', '.uid', '.md', '.py', '.txt', '.cfg', '.sh',
                 '.js', '.orig', '.blend1')

GLB_MAGIC = 0x46546C67
GLB_JSON = 0x4E4F534A

# A headroom below this share of the limit is reported as a warning,
# so a budget is seen coming before it breaks the build.
WARN_SHARE = 0.10


class Report:
    """Collects rows of one run and decides the exit code."""

    def __init__(self):
        self.rows = []
        self.breaches = []
        self.notes = []
        self.folders = {}

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


def glb_triangles(path):
    """Triangles a .glb draws, read from its JSON chunk.

    Every node that uses a mesh draws it once more, so a mesh is counted
    per use.  Only triangle modes count; points and lines draw none.
    """
    with open(path, 'rb') as f:
        head = f.read(20)
        magic, _version, _length, clen, ctype = struct.unpack('<IIIII',
                                                              head)
        if magic != GLB_MAGIC or ctype != GLB_JSON:
            raise ValueError('не GLB 2.0: ' + path)
        gltf = json.loads(f.read(clen))
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


def meta_triangles(json_path):
    """The triangle field of a model's .json, or None without one."""
    if not os.path.exists(json_path):
        return None
    with open(json_path, encoding='utf-8') as f:
        meta = json.load(f)
    if not isinstance(meta, dict):
        return None
    value = meta.get('triangles', meta.get('tris'))
    return None if value is None else int(value)


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
            if rel.endswith(NOT_RESOURCES):
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

    worst = (0, '')
    seen_exc = set()
    glbs = [p for p in files if p.endswith('.glb')]
    for rel in glbs:
        path = os.path.join(godot_dir, rel)
        try:
            tris = glb_triangles(path)
        except (OSError, ValueError, KeyError, IndexError) as err:
            rep.breach('%s: модель не читается (%s)' % (rel, err))
            continue
        meta = meta_triangles(path[:-4] + '.json')
        if meta is not None and meta != tris:
            rep.breach('%s: в .json записано %s треугольников, в самой '
                       'модели %s — паспорт модели врёт' % (
                           rel, fmt(meta), fmt(tris)))
        if rel in exceptions:
            seen_exc.add(rel)
            limit = int(exceptions[rel]['limit'])
            if tris > base:
                rep.note('ИСКЛЮЧЕНИЕ %s: %s треугольников при пределе '
                         'ТАБУ 0.32 п. 4 в %s; допущено до %s до решения '
                         'оператора (docs/APK_REQUIREMENTS.md, блокеры)' %
                         (rel, fmt(tris), fmt(base), fmt(limit)))
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
    rep.note('худшая модель: %s; моделей .glb: %d' % (worst[1], len(glbs)))

    biggest = max(((os.path.getsize(os.path.join(godot_dir, p)), p)
                   for p in files), default=(0, ''))
    rep.check('самый большой файл экспорта (исходник)', biggest[0],
              int(tree['largest_resource_bytes']['limit']))
    rep.note('самый большой файл: %s; файлов в экспорте: %d' % (
        biggest[1], len(files)))

    total = 0
    for sub in tree['content_dirs']:
        for dirpath, _dirs, names in os.walk(os.path.join(godot_dir, sub)):
            for name in names:
                total += os.path.getsize(os.path.join(dirpath, name))
    rep.check('godot/%s вместе' % '+'.join(tree['content_dirs']), total,
              int(tree['content_bytes']['limit']))


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
    except (OSError, ValueError) as err:
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
                          'notes': rep.notes, 'folders': rep.folders},
                         ensure_ascii=False))
    if rep.breaches:
        print('ИТОГ: нарушено бюджетов — %d. Сборка остановлена; причина '
              'и путь исправления — docs/APK_REQUIREMENTS.md.' %
              len(rep.breaches))
        for b in rep.breaches:
            print('  ✗ ' + b)
        return 1
    print('ИТОГ: все бюджеты соблюдены.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
