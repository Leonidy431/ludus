"""99 of an honest pool of branching techniques for episode 1, by 7 marks.

Operator, 2026-10-03 (CLAUDE.md TABOO 0.025): «пиши редакторами эти
варианты для первой серии хором редакторов спецов по играм таким. пусть
берут из лучших игр лучше 99 из 999 по 7 параметрам».

The chorus of game editors (narrative director, branching writer,
consequence designer, endings editor, catechist, Aristotle-sceptic;
the author and the reviewer are different voices, TABOO 0.37) takes
genre techniques of branching and consequence from the best story
games.  A technique is a way of doing, not another game's content: no
name, text or art of another game goes into the game's data (as TABOO
0.024 item 2).  The names of the source games live here and in the
generated document only, as sources.

The pool is generated, not padded (TABOO 0.07 item 2).  A candidate is
a technique placed at one phase of the pilot and driven by one input of
the body:

    technique (TECHNIQUES) x phase (PHASES) x body input (BODIES)
        x pole of the ladder of finales (POLES)

Only the combinations that make sense are generated: a technique lists
the phases and inputs it can live in, and a global table forbids what
the pilot cannot carry (no rope of breaths before the lure, no object
raised to the face under water, nothing at the khachkar at all, TABOO
0.4).  The operator asked for 999; the honest number is printed as it
comes out and is never topped up.

Seven marks of TABOO 0.025 item 4, 0-10 each, written as code in
score(): clarity of the consequence, teaching link (FORM -> ACTION ->
GOAL), bodiliness in VR, replay value, serial hook, theological safety
and cost in the headset (10 = cheapest).  They are design judgements,
not player data: the headset and the operator prove them (TABOO 0.02
item 4).

Selection is deterministic: sort by total, then by id; theological
safety below SAFE_MIN never enters; at most PER_TECH placements of one
technique, PER_GAME of one source game, and at least PER_PHASE in every
phase of the episode.

The selected 99 are written into the "craft" key of
godot/data/pilot-branches.json (ids and Russian titles only, no game
names) and into the chorus document.

    python3 scripts/decisions/branch_craft.py           # write
    python3 scripts/decisions/branch_craft.py --check   # CI

Constitution: ФОРМА (what the best story games learned about choice and
its price) -> ДЕЙСТВИЕ (the chorus takes the technique, not the game,
and fits it to the body and to the pilot's beats) -> ЦЕЛЬ (the player
sees that light and purification follow from his choice, and the door
of repentance stays open).
"""

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DATA = ROOT / 'godot' / 'data' / 'pilot-branches.json'
DOC = ROOT / 'docs' / 'story' / 'BRANCHES_EP1_99_OF_999_2026-10-03.md'

ASKED = 999
WANT = 99
SAFE_MIN = 6
PER_TECH = 3
PER_GAME = 9
PER_PHASE = 8
PER_POLE = 20

MARKS = ('clarity', 'teaching', 'body', 'replay', 'hook', 'safety',
         'cost')
MARKS_RU = {
    'clarity': 'ясность последствия',
    'teaching': 'учительная связь',
    'body': 'телесность в VR',
    'replay': 'переигрываемость',
    'hook': 'смачность (крючок)',
    'safety': 'богословская безопасность',
    'cost': 'цена в шлеме (10 — дёшево)',
}

# The phases of the pilot and the beats of godot/data/pilot-1.json that
# make them.  The khachkar beat is in none: at the holy there is no
# branch, no choice and no technique (TABOO 0.4 item 1, 0.020 item 4).
PHASES = {
    'cold_open': ('холодное начало', ('drop', 'water_rises')),
    'descent': ('спуск', ('immersion', 'hands_on_stick', 'walls')),
    'layer': ('слой', ('thermocline', 'tether_jerk', 'bookmark')),
    'lure': ('приманка', ('lure', 'price_rises', 'choice_echo')),
    'reading': ('чтение', ('diary', 'mark_line')),
    'ascent': ('подъём и обрыв', ('ascent', 'room_drains', 'prior_last',
                                  'title')),
}
# What the phase adds to a technique: a choice near the end is clearer
# and hooks harder; in the cold open the player does not yet know the
# rules, so a consequence there reads worse.
PHASE_MOD = {
    'cold_open': {'clarity': -1, 'hook': 1},
    'descent': {},
    'layer': {'hook': 1},
    'lure': {'clarity': 1, 'teaching': 1, 'hook': 2},
    'reading': {'teaching': 1, 'hook': 1},
    'ascent': {'clarity': 1, 'hook': 2},
}

# Inputs of the body the pilot already reads (pilot_core.gd): head gaze,
# not eye gaze (Quest 3S has no eye tracking); no voice (TABOO 0.26
# item 9).  Bodiliness and cost per input: holding an object up to the
# face needs a model and a close-up, so it costs the most.
BODIES = {
    'gaze_hold': ('задержать взгляд головой', 7, 10),
    'turn_away': ('отвернуться', 8, 10),
    'hand_reach': ('протянуть руку', 9, 8),
    'crouch_lookup': ('присесть или поднять голову', 9, 9),
    'exhale_rope': ('выдох на вервице', 8, 9),
    'raise_to_face': ('поднести вещь к лицу', 9, 6),
    'stand_still': ('замереть', 6, 10),
    'ray_press': ('луч и курок', 4, 10),
}
# Where an input cannot be: the rope of breaths comes with the lure;
# under water the hands drive the vehicle and lift nothing to the face.
BODY_PHASES = {
    'exhale_rope': ('lure', 'reading', 'ascent'),
    'raise_to_face': ('cold_open', 'ascent'),
}

# The pole of the ladder of seven finales a technique serves: the light
# outcome («рай» as image), the middle where the Prior still waits, or
# the path of purification («чистилище» as the heroes' image; the
# mechanic is repentance with the door open, TABOO 0.025 item 5).  A
# technique serves every pole unless POLE_ONLY narrows it.
POLES = {
    'light': 'светлый исход',
    'middle': 'середина: выбор ещё ждёт',
    'purification': 'путь очищения',
}
# What the pole adds: the lower pole hooks harder but asks more care
# (the catechist: a consequence must never read as damnation); the
# middle is the least clear.
POLE_MOD = {
    'light': {},
    'middle': {'clarity': -1, 'hook': -1},
    'purification': {'hook': 1, 'safety': -1},
}
POLE_ONLY = {
    'mercy_route': ('light',),
    'sacrifice_for_stranger': ('light',),
    'betrayal_offer': ('middle', 'purification'),
    'law_crosses_line': ('middle', 'purification'),
    'lesser_evil': ('middle', 'purification'),
    'open_door_return': ('purification',),
    'household_ledger': ('light', 'purification'),
    'save_carryover': ('light', 'middle', 'purification'),
}
# The door technique is the purification pole's own: it does not lose
# safety there, it is what keeps that pole safe.
POLE_KEEPS_SAFE = ('open_door_return',)

ALL_P = tuple(PHASES)
ALL_B = tuple(BODIES)
LATE = ('lure', 'reading', 'ascent')
MID = ('descent', 'layer', 'lure', 'reading')

# Each technique: id, source games (the first is the main one), title in
# Russian, our adaptation, phases, inputs, and its own marks for
# clarity, teaching, replay, hook, safety, cost.  Body comes from the
# input.  A technique the Constitution cannot carry keeps a low safety
# and stays in the pool so the reader sees why it was not taken.
TECHNIQUES = (
    ('small_deeds_path', ('The Pandora Directive',),
     'путь из суммы мелких поступков',
     'исход складывается из многих малых выборов телом, а не из '
     'одной развилки',
     ALL_P, ALL_B, (7, 9, 8, 7, 9, 9)),
    ('look_under_over', ('The Pandora Directive',),
     'улика под столом и на потолке',
     'присесть или поднять голову — и найденное меняет, что знает '
     'герой и что он может сказать',
     ('cold_open', 'descent', 'ascent'), ('crouch_lookup', 'gaze_hold'),
     (8, 7, 7, 7, 10, 9)),
    ('hint_rungs', ('The Pandora Directive',),
     'подсказка ступенями',
     'образ → направление → прямо; цена — строка в журнале, а не очки',
     MID, ('gaze_hold', 'stand_still', 'ray_press'),
     (6, 6, 4, 4, 10, 10)),
    ('tone_of_answer', ('The Pandora Directive', 'Firewatch'),
     'тон ответа меняет отношение',
     'не что сказать, а как: мягко, сухо или промолчать — и собеседник '
     'помнит тон',
     ('layer', 'lure', 'ascent'), ('gaze_hold', 'turn_away', 'ray_press'),
     (6, 7, 7, 7, 9, 10)),
    ('ripening_thought', ('Disco Elysium',),
     'созревающий помысел',
     'мысль, впущенная раньше, через время меняет взгляд героя; это '
     'лестница помысла, а не перк',
     ('layer', 'lure', 'reading'), ('gaze_hold', 'stand_still'),
     (6, 10, 7, 8, 9, 10)),
    ('inner_voices', ('Disco Elysium',),
     'спор внутренних голосов',
     'семь атрибутов говорят по очереди, каждый своим ремеслом; '
     'решает человек',
     MID, ('gaze_hold', 'stand_still', 'ray_press'),
     (5, 9, 8, 8, 8, 9)),
    ('failure_forward', ('Disco Elysium', 'Pentiment'),
     'провал ведёт дальше',
     'неудача не тупик: она открывает другую дорогу и свою строку',
     ALL_P, ('hand_reach', 'crouch_lookup', 'gaze_hold'),
     (7, 8, 8, 7, 9, 9)),
    ('stance_accrues', ('Disco Elysium', 'Mass Effect'),
     'позиция копится по репликам',
     'мелкие ответы складываются в направление пути, которое видно '
     'только к финалу',
     ('layer', 'lure', 'ascent'), ('turn_away', 'gaze_hold'),
     (5, 8, 8, 6, 8, 10)),
    ('no_right_answer', ('Pentiment',),
     'нет правильного ответа — есть свидетельство',
     'игра не говорит, кто прав; герой отвечает за то, что видел',
     ('lure', 'reading', 'ascent'), ('hand_reach', 'raise_to_face',
                                     'turn_away'),
     (6, 10, 8, 8, 10, 9)),
    ('limited_time_inquiry', ('Pentiment', 'Pathologic'),
     'времени на всех не хватит',
     'серия идёт по часам: что не осмотрел — осталось неузнанным, без '
     'штрафа',
     ('descent', 'layer', 'reading'), ('gaze_hold', 'crouch_lookup'),
     (7, 7, 9, 8, 9, 10)),
    ('time_skip_shows', ('Pentiment', 'The Witcher 3: Wild Hunt'),
     'прыжок во времени показывает цену',
     'следующая эпоха матрёшки открывается следом выбора прежней',
     ('reading', 'ascent'), ('stand_still', 'gaze_hold', 'raise_to_face'),
     (9, 9, 7, 9, 9, 9)),
    ('what_changes_nature', ('Planescape: Torment',),
     'вопрос серии, на который отвечает игрок',
     'один сквозной вопрос (кто кого читает) получает ответ поступком, '
     'а не словом',
     ('cold_open', 'ascent'), ('stand_still', 'gaze_hold'),
     (6, 10, 7, 9, 9, 10)),
    ('prior_self_journal', ('Planescape: Torment', 'What Remains of '
                            'Edith Finch'),
     'журнал прежнего читателя',
     'герой читает того, кто писал до него, и узнаёт свой выбор в '
     'чужом',
     ('cold_open', 'reading', 'ascent'), ('raise_to_face', 'gaze_hold'),
     (8, 10, 6, 9, 10, 8)),
    ('death_as_return', ('Planescape: Torment', 'The Pandora '
                         'Directive'),
     'гибель как продолжение',
     'гибнет и теряется аппарат, а не человек; тихое возвращение на '
     'стапель',
     ('layer', 'ascent'), ('stand_still', 'hand_reach'),
     (7, 7, 6, 7, 7, 9)),
    ('delayed_echo', ('The Witcher 3: Wild Hunt',),
     'отсроченное эхо выбора',
     'выбор серии 1 отвечает в серии 2 и позже; игрок узнаёт его в '
     'первую минуту',
     ('lure', 'reading', 'ascent'), ALL_B, (8, 9, 9, 10, 9, 10)),
    ('lesser_evil', ('The Witcher 3: Wild Hunt', 'Frostpunk'),
     'меньшее зло',
     'оба исхода с ценой; хор следит, чтобы зло не стало нормой и '
     'дверь покаяния оставалась открытой',
     ('lure', 'ascent'), ('hand_reach', 'turn_away'),
     (7, 6, 8, 9, 6, 10)),
    ('contract_inquiry', ('The Witcher 3: Wild Hunt',),
     'контракт-расследование',
     'улики → знание о существе → исход без оружия: отпустить, '
     'передать или продать',
     ('descent', 'layer'), ('crouch_lookup', 'gaze_hold', 'hand_reach'),
     (8, 8, 7, 7, 9, 7)),
    ('save_carryover', ('Mass Effect', 'The Walking Dead (Telltale)'),
     'выбор переходит в следующую серию',
     'поступки пилота хранятся и задают вариант начала серии 2',
     ('ascent',), ('stand_still', 'gaze_hold', 'ray_press'),
     (9, 8, 9, 9, 10, 10)),
    ('body_interrupt', ('Mass Effect', 'Heavy Rain'),
     'прерывание телом в сцене',
     'в ключевой миг игрок успевает отвернуться или протянуть руку — '
     'без кнопки на экране',
     ('lure', 'ascent'), ('turn_away', 'hand_reach', 'exhale_rope'),
     (8, 8, 7, 9, 9, 9)),
    ('companion_trust', ('Mass Effect', 'Firewatch'),
     'доверие напарника',
     'голос в гарнитуре помнит, сказал ли герой правду; доверие — не '
     'счётчик на экране',
     ('descent', 'layer', 'ascent'), ('gaze_hold', 'turn_away'),
     (6, 8, 7, 8, 9, 10)),
    ('preparation_tally', ('Mass Effect 2',),
     'финал собирается из подготовки',
     'что герой сделал до решающей минуты, то и держит его в ней',
     ('ascent',), ('stand_still', 'hand_reach'),
     (8, 8, 8, 8, 9, 10)),
    ('choose_how_it_was', ('Kentucky Route Zero',),
     'выбрать, каким это было',
     'игрок выбирает не поступок, а как его запомнить; строка журнала '
     'пишется его тоном',
     ('reading', 'ascent'), ('gaze_hold', 'stand_still'),
     (4, 7, 7, 6, 9, 10)),
    ('quiet_scene', ('Kentucky Route Zero', 'Firewatch'),
     'тихая сцена без задачи',
     'место, где можно просто постоять; тишина — тоже ответ',
     ('descent', 'layer', 'reading'), ('stand_still', 'gaze_hold'),
     (4, 8, 5, 5, 10, 10)),
    ('mercy_route', ('Undertale',),
     'путь пощады',
     'пощадить, отпустить, не взять — мир запоминает и отвечает '
     'людьми, а не очками',
     ('descent', 'lure', 'ascent'), ('turn_away', 'hand_reach',
                                     'stand_still'),
     (8, 10, 9, 8, 10, 9)),
    ('world_remembers_replay', ('Undertale',),
     'мир помнит прежний проход',
     'переигровка не стирает прежнего: строка рассказчика замечает '
     'повтор',
     ('cold_open', 'ascent'), ('stand_still', 'gaze_hold'),
     (6, 7, 9, 8, 7, 10)),
    ('kill_counter', ('Undertale',),
     'счётчик убийств',
     'путь меряется числом убитых; в игре боя нет — приём не берётся',
     ('descent', 'layer'), ('hand_reach', 'ray_press'),
     (8, 2, 7, 7, 0, 9)),
    ('daily_rule_price', ('Papers, Please',),
     'будничная процедура с ценой',
     'штамп, журнал, отчёт: обычная работа оператора таит выбор между '
     'правдой и выгодой',
     ('layer', 'lure'), ('hand_reach', 'ray_press', 'gaze_hold'),
     (8, 9, 7, 8, 9, 10)),
    ('household_ledger', ('Papers, Please',),
     'цена видна дома',
     'последствие — в комнате героя: пустой ящик, молчащий телефон',
     ('ascent',), ('gaze_hold', 'raise_to_face', 'crouch_lookup'),
     (9, 9, 7, 8, 9, 9)),
    ('law_crosses_line', ('Frostpunk',),
     'черта, которую пересекают шаг за шагом',
     'каждый шаг вниз мал и оправдан, а черта видна только сзади; это '
     'лестница помысла',
     ('layer', 'lure'), ('gaze_hold', 'hand_reach'),
     (8, 10, 8, 9, 9, 10)),
    ('twin_meters', ('Frostpunk',),
     'два индикатора общества',
     'надежда и недовольство на экране; у нас счётчиков нет — '
     'берётся только как мысль',
     ('layer', 'ascent'), ('ray_press',), (8, 4, 7, 6, 4, 10)),
    ('route_on_map', ('80 Days',),
     'маршрут, видный на карте',
     'путь героя прочерчен на карте сонара; ветка видна как линия',
     ('descent', 'layer', 'ascent'), ('gaze_hold', 'ray_press'),
     (9, 6, 8, 6, 10, 9)),
    ('deduction_book', ('Return of the Obra Dinn',),
     'книга находок с проверкой по трём',
     'игрок сам сводит улики; игра подтверждает, только когда верно '
     'три сразу',
     ('reading', 'ascent'), ('raise_to_face', 'gaze_hold'),
     (8, 8, 7, 8, 10, 8)),
    ('frozen_moment', ('Return of the Obra Dinn',),
     'застывший миг',
     'мгновение события остановлено, по нему ходят и смотрят; у нас — '
     'кадр крушения без тел',
     ('descent', 'reading'), ('gaze_hold', 'crouch_lookup'),
     (7, 7, 6, 8, 6, 6)),
    ('knowledge_is_key', ('Outer Wilds',),
     'ключ — знание, а не вещь',
     'дверь открывает понятое, а не найденное; святое при этом не '
     'ключ',
     MID, ('gaze_hold', 'crouch_lookup', 'stand_still'),
     (7, 10, 8, 8, 9, 10)),
    ('time_loop', ('Outer Wilds',),
     'петля времени',
     'мир перезапускается; у нас один раз жизнь и один выбор — '
     'приём только в устах протокола',
     ('cold_open', 'ascent'), ('stand_still',), (6, 3, 9, 8, 3, 10)),
    ('radio_silence_choice', ('Firewatch',),
     'молчание как реплика',
     'не ответить — тоже ответ; собеседник слышит паузу',
     ('layer', 'lure', 'ascent'), ('stand_still', 'turn_away'),
     (6, 8, 7, 7, 10, 10)),
    ('will_remember', ('The Walking Dead (Telltale)',),
     '«он запомнит это»',
     'тихая строка рассказчика отмечает выбор без цифр и без '
     'награды',
     ('layer', 'lure', 'ascent'), ('turn_away', 'hand_reach',
                                   'gaze_hold'),
     (9, 7, 6, 8, 9, 10)),
    ('crowd_stats', ('The Walking Dead (Telltale)',),
     'проценты выбора других',
     'сравнение с другими игроками требует сети и телеметрии — '
     'против приватности',
     ('ascent',), ('ray_press',), (7, 3, 6, 6, 4, 6)),
    ('characters_can_be_lost', ('Heavy Rain',),
     'потеря продолжает историю',
     'теряется аппарат или канал, история идёт дальше без него',
     ('layer', 'ascent'), ('hand_reach', 'stand_still'),
     (8, 7, 8, 9, 7, 9)),
    ('rewind', ('Life is Strange',),
     'перемотка выбора',
     'отменить поступок и попробовать снова: тот же поступок перестаёт '
     'иметь тот же исход',
     ('lure',), ('ray_press',), (6, 3, 8, 8, 3, 10)),
    ('final_sum_choice', ('Life is Strange', 'Mass Effect 3'),
     'одна развилка в конце отменяет путь',
     'финал решает одна кнопка, а не путь; хор берёт обратное',
     ('ascent',), ('ray_press',), (8, 3, 6, 7, 5, 10)),
    ('second_reading', ('NieR: Automata',),
     'второй проход — другой взгляд',
     'та же серия с другой стороны: писец, а не оператор',
     ('reading', 'ascent'), ('gaze_hold', 'stand_still'),
     (6, 8, 9, 9, 9, 7)),
    ('narrator_to_disobey', ('The Stanley Parable',),
     'рассказчик, которого можно ослушаться',
     'голос третьего лица говорит, что герой сделает; игрок волен '
     'сделать иначе',
     ('descent', 'layer'), ('turn_away', 'stand_still'),
     (6, 6, 9, 8, 7, 10)),
    ('archive_search', ("Her Story",),
     'поиск по архиву',
     'журнал погружения ищется по словам; найденное меняет, что '
     'герой знает',
     ('layer', 'ascent'), ('ray_press', 'gaze_hold'),
     (7, 7, 8, 7, 10, 8)),
    ('room_per_story', ('What Remains of Edith Finch',),
     'у каждой вещи своя история',
     'вещь в руке открывает короткую историю другой эпохи',
     ('cold_open', 'reading', 'ascent'), ('raise_to_face', 'hand_reach'),
     (7, 8, 6, 9, 10, 6)),
    ('walk_and_talk', ('Oxenfree',),
     'разговор на ходу, который можно перебить',
     'реплики идут, пока аппарат идёт; перебить можно телом — '
     'отвернуться',
     ('descent', 'layer'), ('turn_away', 'gaze_hold'),
     (6, 6, 7, 7, 9, 10)),
    ('dying_town_clock', ('Pathologic',),
     'люди уходят, пока ты медлишь',
     'отсрочка стоит чужой жизни; у нас медлят только приборы и вода, '
     'гибели людей нет',
     ('layer',), ('stand_still',), (7, 6, 7, 8, 5, 10)),
    ('sacrifice_for_stranger', ('Mass Effect', 'Pentiment'),
     'жертва ради незнакомого',
     'отдать своё тому, кто не вернёт: заряд, время, место',
     ('lure', 'ascent'), ('hand_reach', 'turn_away'),
     (8, 10, 8, 9, 10, 9)),
    ('betrayal_offer', ('The Pandora Directive', 'The Witcher 3: Wild '
                        'Hunt'),
     'предложение предать',
     'Приор называет цену; цена растёт, пока смотришь — и видна '
     'цена отказа',
     ('lure',), ('gaze_hold', 'hand_reach', 'turn_away', 'exhale_rope'),
     (9, 10, 8, 10, 9, 10)),
    ('open_door_return', ('Planescape: Torment', 'Disco Elysium'),
     'дверь возвращения открыта',
     'и с нижней ветки можно вернуться: признать, вернуть взятое, '
     'попросить прощения',
     ('ascent',), ('hand_reach', 'exhale_rope', 'stand_still'),
     (9, 10, 9, 9, 10, 9)),
)

# Words that must not reach the game's data: the source games' names
# and their makers (TABOO 0.024 item 2).  Checked on the "craft" key.
FOREIGN = ('Pandora', 'Disco', 'Pentiment', 'Planescape', 'Witcher',
           'Mass Effect', 'Kentucky', 'Undertale', 'Papers', 'Frostpunk',
           '80 Days', 'Obra Dinn', 'Outer Wilds', 'Firewatch', 'Telltale',
           'Heavy Rain', 'Life is Strange', 'NieR', 'Stanley', 'Her Story',
           'Edith Finch', 'Oxenfree', 'Pathologic', 'Walking Dead')

# The chorus's lines, kept with their disagreement (TABOO 0.37).
CHORUS = (
    ('нарративный директор', 'редактор-скептик',
     'чтобы цеплять, ветвей должно быть как можно больше',
     'ветка, которую игрок не узнаёт, не цепляет; семь исходов на одной '
     'лестнице и узнавание в первую минуту серии 2 сильнее сотни '
     'развилок',
     'взяты семь финалов DestinyCore и приёмы «отсроченное эхо» и '
     '«выбор переходит в следующую серию»'),
    ('сценарист ветвлений', 'катехизатор',
     '«чистилище» — просто худшая концовка',
     'Православная Церковь не учит о чистилище как месте '
     'удовлетворения правде Божией (свт. Марк Эфесский, Флорентийский '
     'собор); суд и милость — у Бога (Евр. 9:27)',
     '«рай» и «чистилище» — образы героев; механика — путь покаяния с '
     'открытой дверью; ада и смерти игрока нет'),
    ('дизайнер последствий', 'Аристотель-скептик',
     'перемотка и петля времени дают переигрываемость',
     'если поступок можно отменить, тот же поступок перестаёт давать '
     'тот же исход — это ломает Конституцию',
     'перемотка и петля остаются в пуле с низкой безопасностью и не '
     'проходят порог; переигрываемость даёт новый проход, а не отмена'),
    ('редактор концовок', 'катехизатор',
     'светлый исход надо давать за молитву и веру',
     'награды за веру нет (ТАБУ №0.023 п. 3, №0.35 п. 16); молитва — не '
     'счётчик',
     'светлый исход дают милость, правда и жертва; у святыни ветки нет'),
    ('Аристотель-скептик', 'нарративный директор',
     'баллы 0–10 — это объективная мера',
     'баллы — суждения хора, записанные кодом, а не данные игроков',
     'порядок детерминирован и воспроизводим, а проверку даёт шлем и '
     'оператор (ТАБУ №0.02 п. 4)'),
    ('сценарист ветвлений', 'редактор-скептик',
     'просили 999 — значит, пул должен быть 999',
     'пул не подгоняется (ТАБУ №0.07 п. 2): добивать выдумкой нельзя',
     'пул — то, что дали честные сочетания; число пишется как вышло'),
    ('дизайнер последствий', 'катехизатор',
     'игроку нужен счётчик греха на экране, чтобы видеть путь',
     'счётчик превращает покаяние в торг; путь виден в свете, музыке и '
     'строке рассказчика',
     'чисел пути на экране нет; приём «два индикатора» не взят'),
)


def candidates():
    """Every allowed technique x phase x input, in a fixed order."""
    out = []
    for t in TECHNIQUES:
        tid, games, title, adapt, phases, bodies, marks = t
        for p in phases:
            for b in bodies:
                if p not in BODY_PHASES.get(b, ALL_P):
                    continue
                for q in POLE_ONLY.get(tid, tuple(POLES)):
                    out.append({'id': '%s@%s/%s/%s' % (tid, p, b, q),
                                'technique': tid, 'games': list(games),
                                'title_ru': title, 'adapt_ru': adapt,
                                'phase': p, 'body': b, 'pole': q,
                                'base': marks})
    return out


def score(c):
    clarity, teaching, replay, hook, safety, cost = c['base']
    body_mark, body_cost = BODIES[c['body']][1:]
    s = {'clarity': clarity, 'teaching': teaching, 'body': body_mark,
         'replay': replay, 'hook': hook, 'safety': safety,
         'cost': min(cost, body_cost)}
    for k, v in PHASE_MOD[c['phase']].items():
        s[k] += v
    for k, v in POLE_MOD[c['pole']].items():
        if k == 'safety' and c['technique'] in POLE_KEEPS_SAFE:
            continue
        s[k] += v
    # A choice taken by the whole body teaches more than one clicked:
    # the ladder of the thought is lived (TABOO 0.015 item 4).
    if c['body'] in ('turn_away', 'hand_reach', 'exhale_rope'):
        s['teaching'] += 1
    if c['body'] == 'ray_press':
        s['teaching'] -= 1
    return {k: max(0, min(10, s[k])) for k in MARKS}


def select(pool):
    order = sorted(pool, key=lambda c: (-c['total'], c['id']))
    chosen, by_tech, by_game, by_phase, by_pole = [], {}, {}, {}, {}

    def fits(c):
        if c['scores']['safety'] < SAFE_MIN:
            return False
        if by_tech.get(c['technique'], 0) >= PER_TECH:
            return False
        if by_game.get(c['games'][0], 0) >= PER_GAME:
            return False
        return c not in chosen

    def take(c):
        chosen.append(c)
        by_tech[c['technique']] = by_tech.get(c['technique'], 0) + 1
        by_game[c['games'][0]] = by_game.get(c['games'][0], 0) + 1
        by_phase[c['phase']] = by_phase.get(c['phase'], 0) + 1
        by_pole[c['pole']] = by_pole.get(c['pole'], 0) + 1

    for q in POLES:
        for c in order:
            if by_pole.get(q, 0) >= PER_POLE:
                break
            if c['pole'] == q and fits(c):
                take(c)
    for p in PHASES:
        for c in order:
            if by_phase.get(p, 0) >= PER_PHASE:
                break
            if c['phase'] == p and fits(c):
                take(c)
    for c in order:
        if len(chosen) >= WANT:
            break
        if fits(c):
            take(c)
    chosen.sort(key=lambda c: (-c['total'], c['id']))
    return chosen


def build():
    pool = candidates()
    for c in pool:
        c['scores'] = score(c)
        c['total'] = sum(c['scores'].values())
    chosen = select(pool)
    return {'pool': pool, 'chosen': chosen}


def craft(data):
    """The "craft" key of pilot-branches.json: no game names in it."""
    return {
        'about': 'Top-99 branching techniques for episode 1, chosen by '
                 'scripts/decisions/branch_craft.py; do not edit.',
        'doc': str(DOC.relative_to(ROOT)),
        'asked': ASKED,
        'pool': len(data['pool']),
        'marks': list(MARKS),
        'chosen': [{'id': c['id'], 'technique': c['technique'],
                    'title_ru': c['title_ru'], 'phase': c['phase'],
                    'body': c['body'], 'pole': c['pole'],
                    'total': c['total']}
                   for c in data['chosen']],
    }


def data_text(data):
    branches = json.loads(DATA.read_text(encoding='utf-8'))
    branches['craft'] = craft(data)
    return json.dumps(branches, ensure_ascii=False, indent=2) + '\n'


def doc_text(data):
    pool, chosen = data['pool'], data['chosen']
    unsafe = sorted({c['technique'] for c in pool
                     if c['scores']['safety'] < SAFE_MIN})
    games = sorted({g for t in TECHNIQUES for g in t[1]})
    lines = [
        '# Ветки первой серии: 99 приёмов из честного пула — хор '
        'редакторов игр',
        '',
        '**Дата:** 2026-10-03 · **Правило:** ТАБУ №0.025 (CLAUDE.md) · '
        '**Генератор:** `scripts/decisions/branch_craft.py` (документ '
        'собран им, руками не правится; `--check` в CI) · **Ветки:** '
        '`godot/data/pilot-branches.json` · **Финалы:** '
        '`godot/data/destiny.json` (`DestinyCore`) · **Проверка:** '
        '`godot/scripts/branch_core.gd`, `godot/tests/test_branches.gd`',
        '',
        '**Хор редакторов игр:** нарративный директор, сценарист '
        'ветвлений, дизайнер последствий, редактор концовок, '
        'катехизатор, Аристотель-скептик. Автор и проверяющий — разные '
        'голоса (ТАБУ №0.37).',
        '',
        '## Пул',
        '',
        '- Оператор просил **%d**; честный пул — **%d** сочетаний '
        '«приём × фаза серии × ввод телом × полюс лестницы финалов» '
        'из %d приёмов %d игр. '
        'Пул не добивается выдумкой (ТАБУ №0.07 п. 2).' % (
            ASKED, len(pool), len(TECHNIQUES), len(games)),
        '- Фазы: %s. У кайрака ветки нет: бит `khachkar` не входит ни в '
        'одну фазу (ТАБУ №0.4).' % ', '.join(
            '%s (%s)' % (v[0], ', '.join(v[1])) for v in PHASES.values()),
        '- Полюса: %s; у каждого приёма — только те полюса, которым он '
        'служит.' % ', '.join(POLES.values()),
        '- Ввод телом: %s. Голоса нет (ТАБУ №0.26 п. 9), взгляд — '
        'головой.' % ', '.join(v[0] for v in BODIES.values()),
        '- Семь параметров (0–10, баллы в коде `score()`): %s.' % (
            '; '.join('%d) %s' % (i, MARKS_RU[m])
                      for i, m in enumerate(MARKS, 1))),
        '- Отбор: по сумме, затем по id; безопасность < %d не проходит; '
        'не больше %d мест одного приёма и %d одной игры-источника; не '
        'меньше %d в каждой фазе и %d у каждого полюса.' % (
            SAFE_MIN, PER_TECH, PER_GAME, PER_PHASE, PER_POLE),
        '- Не прошли по безопасности (остались в пуле, чтобы было видно '
        'почему): %s.' % ', '.join('`%s`' % u for u in unsafe),
        '- Имена игр — только здесь и в коде как источники. В данные '
        'игры идут id и русские названия приёмов (как ТАБУ №0.024 п. 2).',
        '',
        '## Хор: предубеждение / контраргумент / почему',
        '',
    ]
    for who, against, bias, counter, why in CHORUS:
        lines.append('- **%s ↔ %s.** Предубеждение: «%s». Контраргумент: '
                     '%s. Почему: %s.' % (who, against, bias, counter, why))
    lines += [
        '',
        '## Топ-99',
        '',
        '| # | приём | источник | фаза | тело | полюс | ясн | учит | '
        'тело | перег | крюк | безоп | цена | Σ |',
        '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|',
    ]
    for i, c in enumerate(chosen, 1):
        s = c['scores']
        lines.append('| %d | **%s** — %s | %s | %s | %s | %s | %s | %d |'
                     % (i, c['title_ru'], c['adapt_ru'],
                        ', '.join(c['games']), PHASES[c['phase']][0],
                        BODIES[c['body']][0], POLES[c['pole']],
                        ' | '.join(str(s[m]) for m in MARKS), c['total']))
    lines += [
        '',
        '## Приёмы пула',
        '',
        '| приём | источник | сочетаний в пуле | взято |',
        '|---|---|---|---|',
    ]
    for t in TECHNIQUES:
        n = sum(1 for c in pool if c['technique'] == t[0])
        k = sum(1 for c in chosen if c['technique'] == t[0])
        lines.append('| `%s` %s | %s | %d | %d |' % (
            t[0], t[2], ', '.join(t[1]), n, k))
    lines += [
        '',
        '**Конституция:** ФОРМА (что лучшие сюжетные игры узнали о '
        'выборе и его цене) → ДЕЙСТВИЕ (хор берёт приём, а не игру, и '
        'кладёт его на тело и биты пилота) → ЦЕЛЬ (игрок видит, что '
        'свет и очищение — следствие выбора, а дверь покаяния открыта).',
        '',
    ]
    return '\n'.join(lines)


def problems(data):
    bad = []
    if len(data['chosen']) != WANT:
        bad.append('%d chosen, not %d' % (len(data['chosen']), WANT))
    ids = [c['id'] for c in data['pool']]
    if len(set(ids)) != len(ids):
        bad.append('duplicate candidates in the pool')
    for c in data['chosen']:
        if c['scores']['safety'] < SAFE_MIN:
            bad.append('%s: unsafe in the top' % c['id'])
    text = json.dumps(craft(data), ensure_ascii=False)
    for name in FOREIGN:
        if name in text:
            bad.append('a game name in the data: %s' % name)
    for p in PHASES:
        if sum(1 for c in data['chosen'] if c['phase'] == p) < PER_PHASE:
            bad.append('phase %s under %d' % (p, PER_PHASE))
    for q in POLES:
        if sum(1 for c in data['chosen'] if c['pole'] == q) < PER_POLE:
            bad.append('pole %s under %d' % (q, PER_POLE))
    return bad


def main(argv):
    data = build()
    bad = problems(data)
    if '--check' in argv:
        if not DOC.exists() or DOC.read_text(encoding='utf-8') != \
                doc_text(data):
            bad.append('%s is stale' % DOC.relative_to(ROOT))
        if DATA.read_text(encoding='utf-8') != data_text(data):
            bad.append('%s "craft" is stale' % DATA.relative_to(ROOT))
        for b in bad:
            print('FAIL:', b)
        print('branch craft: asked %d, pool %d, chosen %d' % (
            ASKED, len(data['pool']), len(data['chosen'])))
        return 1 if bad else 0
    for b in bad:
        print('FAIL:', b)
    if bad:
        return 1
    DOC.write_text(doc_text(data), encoding='utf-8')
    DATA.write_text(data_text(data), encoding='utf-8')
    print('wrote %s and %s: asked %d, pool %d, chosen %d' % (
        DOC.relative_to(ROOT), DATA.relative_to(ROOT), ASKED,
        len(data['pool']), len(data['chosen'])))
    for i, c in enumerate(data['chosen'][:5], 1):
        print('%d. %s (%s) %d' % (i, c['id'], ', '.join(c['games']),
                                  c['total']))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
