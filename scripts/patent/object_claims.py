"""Draft claim sheets for every prompted game object (operator request).

The operator asked for new patent formulas for the created objects.  The
method claims for the raw-material pipeline live in
docs/PATENT_FORMULA_RAW_ASSET_PIPELINE.md; this script drafts one
object-level sheet per prompt in docs/PROMPTS_1070_*.json, in the RU
style "..., отличающийся тем, что ...", so a patent attorney can decide
which objects merit an industrial design filing and which are covered by
copyright alone.

Each sheet binds the object to the constitution (FORM gate -> ACTION ->
GOAL) and to its Meta 3D proxy (TABOO 0.32).  The text is generated
deterministically from the prompt, so rerunning never changes a sheet
unless its prompt changed; nothing here is a filed patent.

Usage: python3 scripts/patent/object_claims.py
"""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROMPTS = ROOT / 'docs' / 'PROMPTS_1070_2026-09-29.json'
MODELS = ROOT / 'public' / 'vr' / 'models'
OUT_MD = ROOT / 'docs' / 'PATENT_CLAIMS_OBJECTS_1070.md'
OUT_JSON = ROOT / 'docs' / 'PATENT_CLAIMS_OBJECTS_1070.json'

KIND = {
    'предмет': 'Игровой предмет', 'NPC': 'Игровой персонаж',
    'локация': 'Игровая локация', 'событие': 'Игровое событие',
    'интерфейс': 'Элемент интерфейса', 'звук': 'Звуковой объект',
}

# Holy objects are never loot or power-ups (TABOO 0.2 item 3); their
# claims say so explicitly, because that restriction is a feature.
SACRED = ('потир', 'дискос', 'кадил', 'крест', 'колокол', 'евангел',
          'икон', 'антиминс', 'мощ', 'кропил', 'лампад', 'чаша')


def model_meta():
    """Map prompt index to its proxy meta-json, if it was generated."""
    found = {}
    for meta in MODELS.rglob('p[0-9][0-9][0-9][0-9]-*.json'):
        found[int(meta.name[1:5]) - 1] = json.loads(meta.read_text('utf-8'))
    return found


def sheet(i, p, meta):
    kind = KIND.get(p['type'], 'Игровой объект')
    sacred = any(s in p['name'].lower() for s in SACRED)
    passion = p.get('passion', 'нет')
    claims = [
        f'1. {kind} «{p["name"]}» для виртуальной среды Meta Quest 3, '
        f'имеющий визуальный образ ({p["visual"]}) и звуковой образ '
        f'({p["sound"]}), **отличающийся тем, что** доступ к нему '
        f'определяется порогом атрибутов игрока «{p["form_gate"]}» '
        f'(ФОРМА), взаимодействие «{p["action"]}» является единственным '
        f'способом его использования (ДЕЙСТВИЕ), а результатом '
        f'взаимодействия служит учительная цель «{p["goal"]}» (ЦЕЛЬ), '
        f'причём награда за взаимодействие детерминирована выбором '
        f'игрока и не содержит случайной составляющей.',
    ]
    if meta:
        claims.append(
            f'2. Объект по п. 1, **отличающийся тем, что** его объёмная '
            f'модель `{meta["kind"]}/{meta["id"]}.glb` имеет форму '
            f'«{meta["shape"]}» размером {meta["size_m"]} м и коллайдер '
            f'«{meta["collider"]}», заданный полем габарита «{p["box"]}».')
    if passion and passion != 'нет':
        claims.append(
            f'{len(claims) + 1}. Объект по п. 1, **отличающийся тем, что** '
            f'взаимодействие с ним испытывает в игроке страсть «{passion}»: '
            f'игрок распознаёт её по признаку, который сообщает наставник, '
            f'и преодолевает трезвением, а не оружием; сам объект '
            f'противником не является.')
    if sacred:
        # Mirrors build.js: holy objects get noLoot; only icons also get
        # noInteract, since other holy objects are handled reverently.
        icon = 'икон' in p['name'].lower()
        flags = 'noInteract и noLoot' if icon else 'noLoot'
        claims.append(
            f'{len(claims) + 1}. Объект по п. 1, **отличающийся тем, что** '
            f'он является святыней, помечен флагом {flags} и не может быть '
            f'добычей, оружием, валютой или множителем.')
    body = '\n'.join(claims)
    return {
        'n': i + 1, 'name': p['name'], 'type': p['type'],
        'storyline': p['storyline'], 'priority': p['priority'],
        'claims': claims,
        'sha256': hashlib.sha256(body.encode('utf-8')).hexdigest()[:16],
    }


def main():
    prompts = json.loads(PROMPTS.read_text('utf-8'))
    metas = model_meta()
    sheets = [sheet(i, p, metas.get(i)) for i, p in enumerate(prompts)]
    OUT_JSON.write_text(json.dumps(sheets, ensure_ascii=False, indent=1)
                        + '\n', 'utf-8')
    lines = [
        '# Формулы на игровые объекты (1070 черновиков)', '',
        '**Статус:** черновики для патентного поверенного. Каждый лист '
        'сгенерирован детерминированно из промта '
        '(`scripts/patent/object_claims.py`). Это не поданные заявки.',
        '', '**Как читать:**',
        '- формула способа переработки сырья лежит отдельно, в '
        '`PATENT_FORMULA_RAW_ASSET_PIPELINE.md`;',
        '- здесь описаны признаки самих объектов (ФОРМА → ДЕЙСТВИЕ → '
        'ЦЕЛЬ, 3D-прокси, страсть, святыня).',
        '', '**Мнение ведущего (не юриста).** Игровой объект сам по себе '
        'чаще охраняется авторским правом или как промышленный образец, '
        'а не как изобретение. Какие листы подавать и в каком виде, решает '
        'юрист.', '',
    ]
    for s in sheets:
        lines += [f'## {s["n"]}. {s["name"]}', '',
                  f'*{s["type"]} · {s["storyline"]} · {s["priority"]} · '
                  f'хеш {s["sha256"]}*', ''] + s['claims'] + ['']
    OUT_MD.write_text('\n'.join(lines), 'utf-8')
    print(f'{len(sheets)} claim sheets, '
          f'{sum(1 for i in range(len(prompts)) if i in metas)} '
          f'bound to 3D proxies -> {OUT_MD.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
