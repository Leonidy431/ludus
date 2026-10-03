"""The 144 insight variants of episode 1 as branches of the game's
development (CLAUDE.md TABOO 0.021, 0.025, 0.37).

The operator (2026-10-03): «задачу по 144 вариантам преобразуй в
разные ветки развития игры. как сделаешь эти 144 ролики к ним допиши
текст и комить видео».

A branch here is not a new plot.  Each insight has twelve variants, one
per hour of the day (godot/data/pilot-insight-variants.json, made by
scripts/prerender/insight_variants.py and rendered by
scripts/prerender/render_insights.py).  The game picks the variant
deterministically by the hour of the player's own device clock when the
insight comes (no randomness, nothing sent anywhere, TABOO 0.35 p. 15,
21); the branch is what that hour leaves in the world: a line in the
journal, a memory of one character, and one dialogue answer in the
next beat that can add +1 to one of the seven attributes (a choice in a
dialogue, never the watching or the skipping of the insight: TABOO
0.021 p. 3).  All twelve branches of an insight converge into the same
next beat of godot/data/pilot-1.json (the insight's bridge_to): the
bottleneck that keeps the tree from exploding.

    python3 scripts/story/insight_branches.py     # write JSON and .md
    python3 scripts/story/check_branches.py       # the chorus's checks

Writes godot/data/pilot-insight-branches.json and
docs/story/chorus-ep1/INSIGHT_BRANCHES_144_2026-10-03.md.

Constitution: ФОРМА (the hour of the player and his seven attributes)
→ ДЕЙСТВИЕ (the memory comes in that hour's light and leaves one trace
that a later answer can take up) → ЦЕЛЬ (the same law of the world in
every hour; the paths part for a beat and meet again).
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VARIANTS = ROOT / 'godot' / 'data' / 'pilot-insight-variants.json'
INSIGHTS = ROOT / 'godot' / 'data' / 'pilot-insights.json'
BEATS = ROOT / 'godot' / 'data' / 'pilot-1.json'
RENDERS = ROOT / 'build' / 'insight_variants'
OUT = ROOT / 'godot' / 'data' / 'pilot-insight-branches.json'
DOC = ROOT / 'docs' / 'story' / 'chorus-ep1' / \
    'INSIGHT_BRANCHES_144_2026-10-03.md'
COMMIT = 'feat(story): add narrative branch %s and video assets'

# The attribute an answer in the converging beat may raise, by hour.
# Never Faith (no reward for faith, TABOO 0.023 p. 3) and never Cunning
# (it opens no gate and is not rewarded, TABOO 0.35 p. 14).
SLOT_ATTR = {
    'blue_hour': 'constitution', 'dawn': 'wisdom', 'sunrise': 'erudition',
    'morning': 'dexterity', 'late_morning': 'erudition', 'noon': 'wisdom',
    'afternoon': 'charisma', 'golden': 'wisdom', 'sunset': 'constitution',
    'dusk': 'charisma', 'moon_night': 'erudition',
    'deep_night': 'constitution',
}
ATTR_RU = {
    'wisdom': 'Мудрость', 'erudition': 'Книжность',
    'constitution': 'Стойкость', 'dexterity': 'Ловкость',
    'charisma': 'Слово',
}
SLOT_EN = {
    'blue_hour': ('pre-dawn blue hour', 'no direct sun; sky 10000-12000 K '
                  'blue ambient; the only warm source is human fire'),
    'dawn': ('dawn', 'sun just below the horizon; pink-violet sky glow, '
             'soft shadowless light'),
    'sunrise': ('sunrise', 'sun 2 deg above the horizon at about 2500 K, '
                'long raking shadows'),
    'morning': ('morning', 'sun 15-20 deg at about 4100 K, modelled '
                'shadows'),
    'late_morning': ('late morning', 'high sun about 5000 K, even working '
                     'light'),
    'noon': ('solar noon', 'sun at its highest for the date, about '
             '5600 K, short hard shadows'),
    'afternoon': ('afternoon', 'sun from the other side at about 5200 K'),
    'golden': ('golden hour', 'sun 8-10 deg at about 3100 K, warm grazing '
               'light across textures'),
    'sunset': ('sunset', 'sun on the horizon at about 2400 K, warm '
               'backlight'),
    'dusk': ('dusk', 'sun gone 5 deg below; blue air, first human fire'),
    'moon_night': ('night with moon', 'moon 30 deg high rendered at '
                   '7500 K by film convention; warm human fire as a '
                   'small pool'),
    'deep_night': ('deep night', 'no sun, no moon; stars only, and human '
                   'fire or an instrument screen'),
}

# Per insight: the theme of its branches, who keeps the memory, the
# journal line it leaves, the converging beat's reading, what the frame
# shows (for the video prompt, physics and geometry only) and a tail
# line for the voice-over that points to the converging beat.
THEMES = {
    'ink_first_line': dict(
        theme='рука передаёт руке', keeper='переписчик обители',
        subject='A copyist cell of lime plaster, a walnut desk, an open '
        'parchment codex with brown ink lines, a reed pen with a wet nib '
        'on the right leaf, a clay inkpot, a small clay oil lamp, a '
        'window opening in the left wall onto a grey winter lake and '
        'white mountains. No person in frame.',
        action='the oil-lamp flame flickers at 2-3 Hz; the wet ink on the '
        'last line catches a specular glint; faint dust drifts in the '
        'window light',
        tail='Под водой рукоять возьмёт другая рука.'),
    'bazaar_jug': dict(
        theme='копия указывает на подлинник', keeper='Клауд',
        subject='A market stall in Karakol: a poplar table under a faded '
        'cotton awning, a turquoise crackle-glazed jug 28 cm tall with a '
        'thumb dent low on its side, eight smaller jugs behind it, '
        'neighbouring stalls and adobe walls in warm dust. No person in '
        'frame.',
        action='awning valance strips sway 1-2 cm in a light wind; dust '
        'hangs in the air; the hero jug stays still',
        tail='Вода в комнате уже поднимается.'),
    'tape_at_night': dict(
        theme='память, которой не верят сети', keeper='Клауд',
        subject='Under a birch desk: a black USB drive taped to the '
        'underside of the board with two parallel strips of paper tape, '
        'one strip end curling loose; an orange ROV tether coiled on a '
        'wall hook; a crate with a turned-away alarm clock. No person in '
        'frame.',
        action='the loose tape end trembles slightly; the laptop screen '
        'light from above is steady; no motion otherwise',
        tail='Вода в комнате уже поднимается.'),
    'ford_of_cold': dict(
        theme='порог холода', keeper='писец обители',
        subject='A cold mountain ford: wet dark river stones with torn '
        'foam on their downstream side, rimed stones on the near bank, '
        'hoof prints filled with water and a dropped leather glove on '
        'the far gravel bank, a snow range across a lake behind. No '
        'person or horse in frame.',
        action='the river runs left to right at about 1 m/s; foam drifts '
        'and breaks; a thin mist lies 30 cm over the water',
        tail='Внизу трос дёрнется, как тот порог.'),
    'hands_of_masons': dict(
        theme='шнур держат свои', keeper='писец обители',
        subject='A monastery wall under construction by a lake: three '
        'courses of split granite and sandstone, a linen string taut 5 '
        'mm above the top course between two ash stakes, a tripod with '
        'a lead plumb bob, a mallet, a trowel, a wicker basket of '
        'mortar, bare footprints in the dust. No person in frame.',
        action='the plumb bob hangs perfectly still; the string does not '
        'move; dust settles',
        tail='Внизу трос дёрнется — с ближнего конца.'),
    'harbor_of_ayas': dict(
        theme='швартов отдают свои', keeper='писец обители',
        subject='A medieval stone quay at Ayas: courses of dressed '
        'limestone, the lowest wet and dark, an oak bollard with iron '
        'bands, a laid hemp mooring rope running over the edge into the '
        'sea, a canvas sack, a small horn lantern on a post, a dark cog '
        'with a furled sail on the horizon. No person in frame.',
        action='small swell laps the wet course; the rope end sways in '
        'the water; the cog moves slowly away along the horizon',
        tail='Внизу его уже ждёт приманка.'),
    'purse_at_the_gate': dict(
        theme='тёплое серебро', keeper='писец обители',
        subject='A stone window sill in a gate tower of Sis, 1374: a '
        'leather purse, seven silver drams with a mounted king spilt '
        'from it, an iron gate key lying untouched, a tallow candle '
        'stub; light enters through a 3 cm arrow slit as a thin stripe. '
        'No person in frame.',
        action='the candle flame flickers at 2-3 Hz; the light stripe is '
        'still; dust drifts through the stripe',
        tail='А цена тем временем растёт.'),
    'gate_opened_inside': dict(
        theme='засов скрипнул один раз', keeper='писец обители',
        subject='The inner side of the city gate of Sis: two oak leaves, '
        'one ajar by 12 degrees, empty iron staples where the bar lay, '
        'the oak bar leaned on the wall, silver coins spilt along a '
        'wedge of light on the flagstones, an empty purse, a torch in an '
        'iron bracket. No person in frame.',
        action='the torch flame of three tongues flickers; the wedge of '
        'light through the gap is still; smoke rises slowly',
        tail='Его выбор отзовётся эхом в следующем выборе.'),
    'bread_in_siege': dict(
        theme='хлеб соседу', keeper='писец обители',
        subject='On a city wall of Sis in siege: a grey wool cloth on '
        'stone, one round flat loaf torn 60/40 with the larger part '
        'pushed toward an empty place, crumbs, two clay cups (one '
        'overturned), a wooden spoon, a brazier; through the crenel far '
        'below a gate yard with a torch and a faint glint of silver. No '
        'person in frame.',
        action='the brazier embers pulse; the torch far below flickers; '
        'crumbs and bread stay still',
        tail='Его выбор отзовётся эхом в следующем выборе.'),
    'scribe_lifts_eyes': dict(
        theme='недописанное — дверь', keeper='Клауд',
        subject='A copyist cell with an open window onto Issyk-Kul: an '
        'empty stool, a desk with an open codex whose last line breaks '
        'off mid-word with a tiny blot, a dry reed pen across the lip of '
        'a clay inkpot, beyond the window a spring meadow, the lake and '
        'a snow range mirrored in still water. No person in frame.',
        action='the lake surface shimmers faintly; no wind in the cell; '
        'the pen lies still',
        tail='Он сам проведёт черту на своей странице.'),
    'same_comet': dict(
        theme='знак идёт строкой', keeper='Клауд',
        subject='Macro of a parchment page: dense brown script with '
        'margin notes everywhere except beside a small inked comet sign '
        '(a round head ringed by eight short ticks and three thin '
        'strands of tail). Never a star of rays. No hand in frame.',
        action='the light moves imperceptibly across the parchment fibres '
        'as the push-in advances; nothing else moves',
        tail='Пора подниматься к людям.'),
    'error_of_a_finger': dict(
        theme='ошибка стала картой', keeper='писец обители',
        subject='Inside a tarred wooden boat on Issyk-Kul: a brass '
        'astrolabe hanging by its ring on a leather thong from the '
        'thole, a coil of hemp rope, a small brass oil lamp, black water '
        'beyond the gunwale, a dark mountain ridge with one small warm '
        'window light at its foot. No person in frame.',
        action='the astrolabe swings gently, about 9 deg, with the swell; '
        'the lamp flame flickers; the water surface moves slowly',
        tail='Комната уходит под воду; он запомнит этот берег.'),
}


def load(p):
    return json.loads(Path(p).read_text(encoding='utf-8'))


def render_info(iid, v):
    f = RENDERS / iid / ('v%02d.json' % v)
    return load(f) if f.exists() else None


def verdict(iid, var, info, picks, notes):
    """The chorus's remark on one frame: one weakness and two strengths
    («на каждый негатив два позитива», the operator), from what was
    seen on the contact sheet (notes) or, where the sheet raised
    nothing, from the measured frame."""
    key = '%s/v%02d' % (iid, var['v'])
    if key in notes:
        return notes[key]
    lt, cam = var['light'], var['cam']
    minus = 'кадр ровный, но час читается только по свету, не по событию'
    if info and abs(info['meter_mean'] - lt['exposure_target']) > 0.05:
        minus = 'экспонометр не дошёл до цели (%.2f против %.2f)' % (
            info['meter_mean'], lt['exposure_target'])
    elif cam['lens_mm'] >= 100:
        minus = 'длинный фокус %g мм сжимает план, место теряется' % (
            cam['lens_mm'])
    elif cam['roll']:
        minus = 'наклон %+g° заметен; в шлеме — на грани' % cam['roll']
    plus1 = 'свет класса часа честный: %s' % (
        ('огонь %d K, не 1800 K' % lt['fire_k']) if lt['fire_k']
        else 'экран прибора 6500 K')
    plus2 = 'вещь, которую называет рассказчик, в центре внимания'
    if picks.get(iid) == var['v']:
        plus2 = 'выбор хора: смысл строки и свет совпали'
    return '− %s / + %s / + %s' % (minus, plus1, plus2)


def voice_lines(text, limit=140):
    """Split a voice-over into subtitle lines of at most limit
    characters, at sentence ends (TABOO 0.020 p. 1)."""
    out, cur = [], ''
    for s in text.replace('… ', '…\n').replace('. ', '.\n').split('\n'):
        s = s.strip()
        if not s:
            continue
        if cur and len(cur) + 1 + len(s) > limit:
            out.append(cur)
            cur = s
        else:
            cur = (cur + ' ' + s).strip()
    if cur:
        out.append(cur)
    return out


def prompt(iid, var):
    t = THEMES[iid]
    slot_en, light_en = SLOT_EN[var['slot']]
    c, lt = var['cam'], var['light']
    fire = ('human fire %d K (inside the 1900-2200 K band)' % lt['fire_k']
            if lt['fire_k'] else 'no fire; instrument screen 6500 K')
    tilt = ('%+.0f deg tilt' % c['orbit_pitch']) if c['orbit_pitch'] \
        else 'level'
    return ('%s Time: %s, solar %s, sun elevation %+.0f deg. Lighting: '
            '%s; %s; never 1800 K. Camera: %g mm lens, orbit %+.0f deg '
            'around the subject from the reference view, %s, roll %g '
            'deg, locked off with a 6%% slow push-in. In frame, physics '
            'only: %s. Exclude: any human face, any saint\'s face, halo, '
            'blood, text overlays, carved cross-stones; nothing holy '
            'used as a lure.' % (
                t['subject'], slot_en, var['solar_time'],
                var['sun_elev'], light_en, fire, c['lens_mm'],
                c['orbit_yaw'], tilt, c['roll'], t['action']))


def build():
    variants = load(VARIANTS)
    insights = {i['id']: i for i in load(INSIGHTS)['insights']}
    beats = {b['id']: b for b in load(BEATS)['beats']}
    picks = variants.get('picks', {})
    notes = variants.get('notes', {})
    nodes = []
    for iid, vs in variants['variants'].items():
        ins = insights[iid]
        t = THEMES[iid]
        conv = ins['bridge_to']
        assert conv in beats, conv
        for var in vs:
            attr = SLOT_ATTR[var['slot']]
            nid = 'v_%s_%02d' % (iid, var['v'])
            voice = '%s %s' % (var['narration_ru'], t['tail'])
            logic = (
                'Инсайт пришёл в час «%s» (часы устройства игрока, без '
                'случайности): в журнал ложится строка «%s, %s», а %s '
                'запоминает этот час. Просмотр и пропуск ничего не дают '
                'и не отнимают; в сходящемся бите `%s` один ответ в '
                'диалоге, который вспоминает этот час, может дать +1 к '
                'атрибуту «%s». Все 12 вариантов сходятся в `%s` '
                '(узкое горло сюжета), денег и инвентаря цены нет.' % (
                    var['time_of_day'], ins['id'], var['time_of_day'],
                    t['keeper'], conv, ATTR_RU[attr], conv))
            nodes.append({
                'node_id': nid,
                'insight': iid,
                'v': var['v'],
                'slot': var['slot'],
                'branch_ru': '%s — %s' % (var['time_of_day'].capitalize(),
                                          t['theme']),
                'logic_ru': logic,
                'world': {
                    'journal': 'journal:%s_v%02d' % (iid, var['v']),
                    'memory': {'keeper': t['keeper'],
                               'key': 'insight_hour.%s' % iid,
                               'value': var['slot']},
                    'dialogue_bonus': {'beat': conv, 'attribute': attr,
                                       'amount': 1,
                                       'by': 'dialogue_answer'},
                    'inventory': [],
                },
                'converges_to': conv,
                'frame': 'build/insight_variants/%s/v%02d.jpg' % (
                    iid, var['v']),
                'video_prompt': prompt(iid, var),
                'voiceover_ru': voice,
                'subtitles_ru': voice_lines(voice),
                'chorus': verdict(iid, var, render_info(iid, var['v']),
                                  picks, notes),
                'git_commit_msg': COMMIT % iid,
                'status': 'ready_for_render',
            })
    return {
        'episode': 1,
        'doc': 'docs/story/chorus-ep1/INSIGHT_BRANCHES_144_2026-10-03.md',
        'tech': 'docs/TECH_INSIGHT_RENDER_144_2026-10-03.md',
        'select': 'the hour of the player\'s device clock when the insight '
                  'comes picks the variant: the twelve slots of '
                  'pilot-insight-variants.json by their solar hour; '
                  'nothing random, nothing sent',
        'rule': 'a branch leaves a journal line and one memory; an answer '
                'in the converging beat may add +1 to one attribute; '
                'watching or skipping the insight gives nothing; every '
                'branch of an insight converges into its bridge_to beat',
        'picks': picks,
        'nodes': nodes,
    }


def doc(data):
    out = ['# Инсайты серии 1: 144 варианта как ветки развития игры',
           '',
           'Оператор (2026-10-03, дословно): «задачу по 144 вариантам '
           'преобразуй в разные ветки развития игры. как сделаешь эти 144 '
           'ролики к ним допиши текст и комить видео»; «на каждый негатив '
           'два позитива».',
           '',
           'Данные — `godot/data/pilot-insight-branches.json`, генератор — '
           '`scripts/story/insight_branches.py`, проверка хора — '
           '`scripts/story/check_branches.py` (тест '
           '`scripts/tests/test_insight_branches.py`), технология — '
           '`docs/TECH_INSIGHT_RENDER_144_2026-10-03.md`, кадры и хор '
           'вариантов — `INSIGHT_VARIANTS_144_2026-10-03.md`.',
           '',
           '**Как выбирается ветка.** Вариант выбирают часы устройства '
           'игрока в миг, когда приходит инсайт: двенадцать часов дня — '
           'двенадцать вариантов. Без случайности, ничего не уходит в '
           'сеть. Просмотр и пропуск не награждаются и не наказываются '
           '(ТАБУ №0.021 п. 3). След ветки — строка журнала, память '
           'одного героя и один ответ в диалоге сходящегося бита, '
           'который может дать +1 к одному из семи атрибутов (никогда '
           'к Вере — без наград за веру, ТАБУ №0.023; никогда к Хитрости).',
           '',
           '**Узкое горло.** Все 12 веток инсайта сходятся в его бит '
           '`bridge_to` из `godot/data/pilot-1.json`, поэтому дерево не '
           'взрывается: 144 ветки — 9 сходящихся битов. Вариантов у '
           'святыни (кайрак, id `khachkar`) нет: у неё инсайтов нет '
           '(ТАБУ №0.021 п. 6, №0.027).',
           '',
           '**Хор.** Шоураннер, сценарист ветвлений, дизайнер последствий '
           '(авторы); катехизатор, историк, оператор-постановщик, '
           'Аристотель-скептик (проверяющие). У каждой ветки замечание '
           '«− / + / +»: на каждый негатив два позитива.',
           '',
           'Предубеждение: «144 ветки — это 144 сюжета» / контраргумент '
           '(скептик, дизайнер последствий): комбинаторный взрыв не '
           'делается и не проверяется; ветка — час и его след, а сюжет '
           'сходится в следующий бит / почему: слово оператора о ветках '
           'исполнено без разрыва ритма сериала (ТАБУ №0.015 п. 2).',
           '']
    for n in data['nodes']:
        meta = {k: n[k] for k in ('node_id', 'video_prompt',
                                  'voiceover_ru', 'git_commit_msg',
                                  'status')}
        out += [
            '### Вариант ID: %s/v%02d — %s' % (
                n['insight'], n['v'], n['branch_ru']),
            '',
            '**1. Логика ветки (Игровой Импакт):** %s' % n['logic_ru'],
            '',
            '**2. Режиссура видео (Промпт для видео-нейросети):** %s'
            % n['video_prompt'],
            '',
            '**3. Закадровый текст:** %s' % ' / '.join(n['subtitles_ru']),
            '',
            '**4. Метаданные:**',
            '',
            '```json',
            json.dumps(meta, ensure_ascii=False),
            '```',
            '',
            'Хор: %s' % n['chorus'],
            '']
    return '\n'.join(out)


def main():
    data = build()
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n',
                   encoding='utf-8')
    DOC.write_text(doc(data), encoding='utf-8')
    print('wrote', OUT, len(data['nodes']), 'nodes;', DOC)
    return 0


if __name__ == '__main__':
    sys.exit(main())
