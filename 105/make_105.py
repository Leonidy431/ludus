"""Folder 105: every piece of code and every document of the headset build.

Operator, 2026-10-02: «создай папку 105. туда весь код, всю
документацию все мд, и создай yml сборки и подробно сборку для сборщика
и меня и тебя и в документацию гиперссылкой подробно в пеп8».

105 is the headset build line of about 105 MB (headset-latest from main:
105 021 985 bytes, 2026-10-02).  The folder holds no second copy of the
code: a copy kept beside the sources goes stale with the first commit,
and every gate that walks the repository would see each file twice
(TABOO 0.35 item 12: one source).  Instead this program makes, from the
one source:

* 105/INDEX.md -- a hyperlink to every file of code and every document,
  grouped by part of the project, with the line the file describes
  itself with; committed, and kept current by --check in CI;
* with --bundle OUT.zip, the folder 105 itself: every file of code and
  every document under 105/, MANIFEST.json (path, bytes, SHA-256 of
  each) and the guides; the build-105 workflow makes it on every run
  and, on main, puts it beside the APK in the headset-latest release.

    python3 105/make_105.py            # write 105/INDEX.md
    python3 105/make_105.py --check    # CI: fail if INDEX.md is stale
    python3 105/make_105.py --bundle build/ludus-105.zip

Constitution: ФОРМА (the whole build as it is: its code and its word)
→ ДЕЙСТВИЕ (gather it in one place from one source, every file with a
link and a hash) → ЦЕЛЬ (anyone who builds, tests or rules the game
finds every part of it, and the build can be repeated).
"""

import hashlib
import json
import os
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HERE = ROOT / '105'
INDEX = HERE / 'INDEX.md'

# What counts as code and as a document.
CODE = {'.gd', '.gdshader', '.tscn', '.tres', '.py', '.js', '.mjs',
        '.ts', '.cs', '.luau', '.vue', '.scad', '.sh', '.yml', '.yaml',
        '.cfg', '.godot', '.html', '.css', '.gdbuild'}
DOCS = {'.md', '.txt'}
# Third-party code keeps its own licence and home; it is listed by
# folder in the guide, not file by file (TABOO 0.1: the register).
THIRD_PARTY = ('godot/addons/', 'node_modules/', 'public/vr/vendor/',
               'vendor/')
# Generated or bulky trees that are not the project's own writing.
SKIP = ('godot/.godot/', 'build/')

# The parts of the project, in the order a reader meets them.
PARTS = [
    ('105/', 'Папка 105: комплект сборки'),
    ('CLAUDE.md', 'Правила проекта (Конституция и табу)'),
    ('.github/workflows/', 'Сборки и проверки CI (YAML)'),
    ('godot/scripts/', 'Игра для шлема: код (GDScript)'),
    ('godot/scenes/', 'Игра для шлема: сцены'),
    ('godot/tools/', 'Игра для шлема: инструменты замера и кадров'),
    ('godot/tests/', 'Игра для шлема: тесты'),
    ('godot/', 'Игра для шлема: проект и прочее'),
    ('scripts/godot/', 'Сборка шлема: бюджеты, движок, прогноз'),
    ('scripts/decisions/', 'Выборы из честного пула по 48 параметрам'),
    ('scripts/', 'Скрипты проекта: раннер, данные, сюжеты'),
    ('public/ludus/', 'Веб-версия игры'),
    ('public/', 'Веб: прочее'),
    ('functions/', 'Бэкенд (Cloud Functions)'),
    ('tests/', 'Тесты веба (node --test)'),
    ('docs/decisions/', 'Документы решений'),
    ('docs/review/', 'МД-ревью ревизора лимитов APK'),
    ('docs/gost/', 'Документы по ГОСТ'),
    ('docs/', 'Документация проекта'),
    ('', 'Прочее'),
]


def tracked():
    """Files git tracks, as posix paths relative to the root."""
    out = subprocess.run(['git', 'ls-files', '-z'], cwd=ROOT,
                         capture_output=True, check=True).stdout
    return sorted(p for p in out.decode('utf-8').split('\0') if p)


def kind(path):
    """'code', 'doc' or '' for a tracked path."""
    if path.startswith(SKIP) or any(t in path for t in THIRD_PARTY):
        return ''
    ext = os.path.splitext(path)[1].lower()
    if path.endswith('project.godot') or ext in CODE:
        return 'code'
    if ext in DOCS:
        return 'doc'
    return ''


def part_of(path):
    for prefix, title in PARTS:
        if prefix and (path == prefix or path.startswith(prefix)):
            return prefix, title
    return '', PARTS[-1][1]


def describe(path):
    """The line a file describes itself with, if it has one."""
    p = ROOT / path
    try:
        lines = p.read_text(encoding='utf-8').splitlines()[:40]
    except (UnicodeDecodeError, OSError):
        return ''
    ext = p.suffix.lower()
    for line in lines:
        s = line.strip()
        if not s:
            continue
        if ext in ('.md', '.txt'):
            if s.startswith('#'):
                return s.lstrip('#').strip()
            continue
        if ext in ('.gd', '.gdshader') and s.startswith('##'):
            return s.lstrip('#').strip()
        if ext == '.py' and s.startswith(('"""', "'''")):
            s = s.strip('"\'').strip()
            return s or (lines[lines.index(line) + 1].strip()
                         if lines.index(line) + 1 < len(lines) else '')
        if ext in ('.js', '.mjs', '.ts', '.cs', '.css') and \
                s.startswith(('//', '/*', '*')):
            s = s.lstrip('/*').strip()
            if s and not s.startswith(("'use strict'", 'eslint')):
                return s
        if ext in ('.yml', '.yaml', '.sh', '.cfg') and s.startswith('#') \
                and not s.startswith('#!'):
            return s.lstrip('#').strip()
    return ''


def md_link(path):
    """A link from 105/INDEX.md to a file at the root of the repo."""
    target = '../' + path
    return '[%s](%s)' % (path, target.replace(' ', '%20'))


def build_index(files):
    rows = {}
    counts = {'code': 0, 'doc': 0}
    for f in files:
        k = kind(f)
        if not k:
            continue
        counts[k] += 1
        prefix, title = part_of(f)
        rows.setdefault((prefix, title), []).append((f, k))
    out = ['# Папка 105 — указатель кода и документации', '',
           'Создан `python3 105/make_105.py`; проверяется в CI '
           '(`--check`). Каждая строка — ссылка на файл в репозитории '
           'и строка, которой файл описывает себя сам. Полную папку '
           'с копиями файлов и SHA-256 даёт сборка '
           '[build-105](../.github/workflows/build-105.yml) '
           '(см. [СБОРКА.md](СБОРКА.md)).', '',
           '- файлов кода: %d' % counts['code'],
           '- документов: %d' % counts['doc'],
           '- сторонний код (свои лицензии) перечислен по папкам в '
           '[СБОРКА.md](СБОРКА.md), не по файлам.', '']
    order = [t for _, t in PARTS]
    for (prefix, title) in sorted(rows, key=lambda k: order.index(k[1])):
        items = rows[(prefix, title)]
        out += ['## %s (%d)' % (title, len(items)), '']
        for f, k in items:
            d = describe(f)
            mark = '' if k == 'code' else ' 📄'
            d = d.replace('|', '/')[:160]
            out.append('- %s%s%s' % (md_link(f), mark,
                                     ' — ' + d if d else ''))
        out.append('')
    return '\n'.join(out).rstrip('\n') + '\n', counts


def manifest(files):
    out = []
    for f in files:
        k = kind(f)
        if not k:
            continue
        data = (ROOT / f).read_bytes()
        out.append({'path': f, 'kind': k, 'bytes': len(data),
                    'sha256': hashlib.sha256(data).hexdigest()})
    return out


def bundle(dest, files):
    """The folder 105 as a zip: every file of code and every document,
    MANIFEST.json and the guides, under 105/."""
    m = manifest(files)
    head = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT,
                          capture_output=True, text=True).stdout.strip()
    meta = {'commit': head, 'files': len(m),
            'bytes': sum(x['bytes'] for x in m), 'manifest': m}
    Path(dest).parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(dest, 'w', zipfile.ZIP_DEFLATED) as z:
        for x in m:
            z.write(ROOT / x['path'], '105/' + x['path'])
        z.writestr('105/MANIFEST.json',
                   json.dumps(meta, ensure_ascii=False, indent=1) + '\n')
    return meta


def main(argv):
    files = tracked()
    text, counts = build_index(files)
    if '--check' in argv:
        old = INDEX.read_text(encoding='utf-8') if INDEX.exists() else ''
        if old != text:
            print('105/INDEX.md is stale: run python3 105/make_105.py')
            return 1
        print('105/INDEX.md current: %d code, %d docs' % (
            counts['code'], counts['doc']))
        return 0
    if '--bundle' in argv:
        dest = argv[argv.index('--bundle') + 1]
        meta = bundle(dest, files)
        print('bundle %s: %d files, %d bytes, commit %s' % (
            dest, meta['files'], meta['bytes'], meta['commit'][:12]))
        return 0
    INDEX.write_text(text, encoding='utf-8')
    print('wrote 105/INDEX.md: %d code, %d docs' % (
        counts['code'], counts['doc']))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
