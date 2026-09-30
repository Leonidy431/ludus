"""The lake's objects: a pool of 999 candidates and the best 99 of them.

Operator, 2026-09-30: "work out the 99 best of 999 objects of the lake
and make them".  Honest scope first: Issyk-Kul has about ninety distinct
things a diver or an ROV meets (species, plants, stones, finds of the
drowned settlements, the water's own phenomena).  The pool of 999 is
therefore their plausible combinations -- item x state x depth band --
and the file says so; nothing is invented to reach the number.

Each candidate is scored on five open criteria, 0-10 each:
  truth      it is really in Issyk-Kul (species lists, the known
             drowned settlements, the lake's physics);
  teaching   it carries FORM -> ACTION -> GOAL (a boundary to cross,
             a rhythm to keep, patience at the bottom) - CLAUDE.md §0;
  readable   a player reads it at 2-10 m in the headset;
  novelty    the game has nothing like it yet;
  safety     never holy as a find, never a passion (TABOO 0.35 r.6).
The 99 are the top scores with at most two per item and every category
present, so the lake is not 99 fish.  Deterministic: no randomness.

Writes:
  docs/LAKE_OBJECTS_999.json           the whole pool with scores
  public/ludus/data/lake-objects-99.json  the 99, with 3D parts
  docs/LAKE_OBJECTS_99.md              the table for the operator
Usage: python3 scripts/lake/lake_objects.py
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Depth bands of the view from the ROV, metres.
BANDS = [('shallows', 0, 5), ('shelf', 5, 20), ('slope', 20, 50),
         ('thermocline', 50, 100), ('deep', 100, 300)]

# (id, category, ru, en, depth range m, truth, teaching, readable,
#  novelty, shape, size m, colour, states).  Shapes map to 3D parts.
ITEMS = [
    # Fish: the species of data/issyk-kul-fish.json.
    ('chebak', 'fish', 'Иссык-кульский чебак', 'Issyk-Kul dace', (1, 60),
     10, 6, 8, 5, 'fish', 0.30, '#b9c4c9',
     ['стайка', 'одиночка', 'молодь', 'у дна', 'в тени камня']),
    ('chebachok', 'fish', 'Иссык-кульский чебачок', 'Small dace', (1, 15),
     10, 5, 7, 5, 'fish', 0.14, '#cfd8da',
     ['стайка', 'молодь', 'у берега', 'в траве', 'у поверхности']),
    ('marinka', 'fish', 'Иссык-кульская маринка', 'Marinka', (1, 40),
     10, 6, 8, 6, 'fish', 0.45, '#8f8a6e',
     ['одиночка', 'пара', 'у дна', 'кормится', 'в тени камня']),
    ('osman', 'fish', 'Голый осман', 'Naked osman', (1, 20), 10, 5, 7, 6,
     'fish', 0.35, '#7d7a66', ['одиночка', 'у дна', 'у устья', 'кормится',
                               'в тени камня']),
    ('gubach', 'fish', 'Пятнистый губач', 'Stone loach', (1, 100), 10, 7,
     5, 7, 'fish', 0.12, '#9a8f73', ['под камнем', 'на песке', 'в гальке',
                                     'замер', 'кормится']),
    ('ishkhan', 'fish', 'Севанская форель', 'Sevan trout', (15, 120), 9,
     6, 8, 6, 'fish', 0.55, '#a7a39a', ['одиночка', 'на границе слоя',
                                        'в глубине', 'охотится', 'пара']),
    ('sudak', 'fish', 'Судак', 'Zander', (4, 35), 9, 5, 8, 5, 'fish', 0.60,
     '#9ea58e', ['одиночка', 'в засаде', 'охотится', 'у свай', 'пара']),
    ('leshch', 'fish', 'Лещ', 'Bream', (3, 25), 9, 4, 8, 4, 'fish', 0.40,
     '#b3a67f', ['стайка', 'кормится', 'у дна', 'одиночка', 'пара']),
    ('sazan', 'fish', 'Сазан', 'Wild carp', (1, 15), 9, 4, 8, 4, 'fish',
     0.55, '#a88f55', ['одиночка', 'кормится', 'в траве', 'пара',
                       'у поверхности']),
    ('sig', 'fish', 'Сиг', 'Whitefish', (10, 80), 9, 5, 7, 6, 'fish', 0.40,
     '#c6ccce', ['стайка', 'на границе слоя', 'в глубине', 'одиночка',
                 'пара']),
    # The rest of the species list (docs/ISSYK_KUL_FISH.md): river-mouth
    # natives and the accidental or planned introductions that live on.
    ('osman-scaly', 'fish', 'Чешуйчатый осман', 'Scaly osman', (0, 5), 7,
     5, 7, 8, 'fish', 0.35, '#8a8266', ['у устья', 'одиночка', 'в струе']),
    ('loach-tibet', 'fish', 'Тибетский голец', 'Tibetan stone loach',
     (0, 5), 7, 6, 5, 8, 'fish', 0.11, '#8c8468', ['под камнем', 'у устья',
                                                   'в гальке']),
    ('loach-grey', 'fish', 'Серый голец', 'Grey stone loach', (0, 30), 7,
     6, 5, 8, 'fish', 0.13, '#80806e', ['на песке', 'в траве', 'замер']),
    ('golyan', 'fish', 'Иссык-кульский гольян', 'Issyk-Kul minnow', (0, 3),
     8, 6, 5, 9, 'fish', 0.07, '#9aa08a', ['стайка', 'у ключа', 'у устья']),
    ('raduzhnaya', 'fish', 'Радужная форель', 'Rainbow trout', (2, 40), 8,
     5, 8, 6, 'fish', 0.50, '#b0a0a8', ['одиночка', 'охотится', 'у садка']),
    ('lin', 'fish', 'Линь', 'Tench', (1, 10), 8, 5, 7, 7, 'fish', 0.35,
     '#6a7a3a', ['в траве', 'у дна', 'одиночка']),
    ('karas', 'fish', 'Серебряный карась', 'Prussian carp', (0, 10), 8, 4,
     7, 6, 'fish', 0.25, '#b8b090', ['стайка', 'в траве', 'у берега']),
    ('amur-chebachok', 'fish', 'Амурский чебачок', 'Stone moroko', (0, 5),
     8, 6, 5, 8, 'fish', 0.08, '#b0b4a8', ['стайка', 'у берега',
                                           'в траве']),
    ('amur-white', 'fish', 'Белый амур', 'Grass carp', (0, 8), 6, 4, 8, 7,
     'fish', 0.80, '#9a9a70', ['одиночка', 'в траве', 'кормится']),
    ('tolstolob', 'fish', 'Белый толстолобик', 'Silver carp', (0, 10), 6,
     4, 8, 7, 'fish', 0.70, '#c8ccc8', ['стайка', 'у поверхности',
                                        'одиночка']),
    # Small life of the bottom and the water.
    ('gammarus', 'life', 'Бокоплавы', 'Amphipods', (0, 60), 9, 6, 4, 9,
     'swarm', 0.02, '#c9b28a', ['рой у дна', 'на камне', 'в траве']),
    ('lymnaea', 'life', 'Прудовик на камне', 'Pond snail', (0, 15), 9, 7,
     6, 9, 'shell', 0.04, '#8a7a5a',
     ['на камне', 'на траве', 'пустая раковина']),
    ('chironomid', 'life', 'Трубочки мотыля в иле', 'Midge larva tubes',
     (5, 120), 9, 6, 3, 9, 'tubes', 0.02, '#8a6a50',
     ['в иле', 'на склоне', 'в глубине']),
    ('plankton', 'life', 'Облако рачков-планктона', 'Zooplankton cloud',
     (0, 100), 9, 6, 5, 8, 'cloud', 1.5, '#d6e2e0',
     ['у поверхности', 'на границе слоя', 'ночью поднимается']),
    ('shells', 'life', 'Россыпь пустых раковин', 'Empty shells', (0, 30),
     8, 7, 6, 8, 'shells', 0.3, '#d8d0bc', ['на песке', 'в гальке',
                                            'у кромки']),
    # Plants of the shallows.
    ('chara', 'plant', 'Харовый луг', 'Stonewort meadow', (1, 15), 10, 7,
     8, 9, 'meadow', 1.0, '#5f7a4a', ['густой', 'редкий', 'на склоне']),
    ('rdest', 'plant', 'Рдест', 'Pondweed', (0, 8), 9, 6, 8, 9, 'stems',
     0.8, '#6d8a4c', ['густой', 'редкий', 'колышется']),
    ('trostnik', 'plant', 'Тростник у берега', 'Shore reeds', (0, 1), 9,
     5, 9, 8, 'reeds', 2.0, '#8a8a52', ['стена', 'редкий', 'сломанный']),
    ('nitchatka', 'plant', 'Нитчатка на камнях', 'Filamentous algae',
     (0, 10), 9, 6, 6, 8, 'fuzz', 0.2, '#6a8a3a', ['на камне', 'на свае',
                                                   'на сети']),
    ('urut', 'plant', 'Уруть', 'Water milfoil', (0, 6), 7, 5, 7, 9,
     'stems', 0.7, '#4a6a3a', ['густая', 'редкая', 'колышется']),
    # The shelf itself.
    ('ripples', 'shelf', 'Песчаная рябь', 'Sand ripples', (0, 30), 10, 7,
     8, 6, 'ripples', 3.0, '#c8b890', ['мелкая', 'крупная', 'под течением']),
    ('gravel', 'shelf', 'Галечное поле', 'Gravel field', (0, 25), 10, 5, 7,
     7, 'gravel', 3.0, '#9a8f80', ['мелкая', 'крупная', 'с ракушкой']),
    ('boulder', 'shelf', 'Гранитный валун', 'Granite boulder', (0, 80),
     10, 7, 9, 6, 'boulder', 1.2, '#8a8680', ['одиночный', 'в водорослях',
                                              'поле валунов']),
    ('silt', 'shelf', 'Илистая равнина', 'Silt plain', (20, 300), 10, 7,
     5, 8, 'silt', 3.0, '#6a655a', ['ровная', 'со следами', 'мутная']),
    ('terrace', 'shelf', 'Подводная терраса', 'Drowned shore terrace',
     (15, 60), 10, 8, 8, 9, 'terrace', 4.0, '#9a9078',
     ['ступень', 'обрыв', 'старая береговая линия']),
    ('slope-edge', 'shelf', 'Кромка свала в глубину', 'Edge of the drop',
     (20, 120), 10, 9, 8, 9, 'edge', 4.0, '#5a6a70',
     ['кромка', 'осыпь', 'темнота внизу']),
    ('clay', 'shelf', 'Глинистый выход', 'Clay outcrop', (5, 60), 9, 5, 6,
     8, 'outcrop', 1.5, '#9a7a5a', ['пласт', 'промоина', 'в иле']),
    ('spring', 'shelf', 'Выход подводного источника', 'Spring seep',
     (0, 20), 7, 8, 7, 9, 'seep', 0.6, '#b8c8c0',
     ['струйка', 'мерцание воды', 'ключ в песке']),
    # All the stones: what the shores of Terskey and Kungey shed.
    ('sandstone', 'shelf', 'Красный песчаник', 'Red sandstone', (0, 20), 9,
     6, 9, 8, 'boulder', 0.8, '#a0503a', ['глыба', 'окатыш', 'плита']),
    ('quartz', 'shelf', 'Кварцевая галька', 'Quartz pebbles', (0, 20), 9, 5,
     7, 7, 'gravel', 2.0, '#e0dcd0', ['россыпь', 'у кромки', 'в песке']),
    ('schist', 'shelf', 'Сланцевая плитка', 'Schist flags', (0, 40), 8, 5,
     7, 8, 'slab', 0.6, '#5a5f5a', ['плитка', 'осыпь', 'в иле']),
    ('blacksilt', 'shelf', 'Чёрный железистый ил', 'Black ferrous silt',
     (0, 30), 8, 6, 6, 9, 'silt', 2.0, '#2a2a28', ['пятно', 'у берега',
                                                   'под песком']),
    # Finds of the drowned settlements (neutral things only).
    ('khum', 'find', 'Хум — большой глиняный сосуд', 'Khum, a storage jar',
     (2, 40), 9, 6, 9, 9, 'jar', 0.9, '#9a6a45',
     ['целый', 'наполовину в песке', 'разбитый']),
    ('cherepki', 'find', 'Россыпь черепков', 'Potsherds', (2, 40), 10, 5,
     6, 7, 'sherds', 0.4, '#a06a48', ['россыпь', 'у сваи', 'в гальке']),
    ('zhernov', 'find', 'Жернов', 'Millstone', (2, 35), 9, 7, 9, 9, 'disc',
     0.6, '#7a7670', ['целый', 'расколотый', 'в водорослях']),
    ('kayrak', 'find', 'Кайрак — зернотёрка', 'Grinding stone', (2, 30), 9,
     6, 7, 8, 'slab', 0.5, '#8a8070', ['целый', 'в песке', 'с пестом']),
    ('kirpich', 'find', 'Жжёный кирпич', 'Fired brick', (2, 30), 9, 5, 6,
     7, 'brick', 0.3, '#9a5a3a', ['один', 'кладка', 'россыпь']),
    ('svaya', 'find', 'Свая затопленного посада', 'Pile of a drowned town',
     (3, 40), 9, 7, 9, 8, 'pile', 2.0, '#5a4a38', ['стоит', 'сломана',
                                                   'ряд свай']),
    ('fundament', 'find', 'Линия каменного фундамента', 'Foundation line',
     (3, 30), 9, 8, 8, 9, 'wall', 3.0, '#8a847a', ['прямая', 'угол',
                                                   'в песке']),
    ('ochag', 'find', 'Кольцо очага', 'Hearth ring', (3, 30), 8, 7, 7, 9,
     'ring', 0.8, '#6a5a4a', ['целое', 'в иле', 'с углём']),
    ('kotel', 'find', 'Обломок бронзового котла', 'Bronze cauldron shard',
     (3, 40), 9, 5, 7, 8, 'shard', 0.4, '#6a8a6a', ['обломок', 'ручка',
                                                    'в песке']),
    ('bulla', 'find', 'Свинцовая булла', 'Lead seal', (2, 25), 8, 6, 5, 8,
     'disc', 0.04, '#8a8a8a', ['в песке', 'на камне', 'в черепках']),
    ('gruzilo', 'find', 'Каменное грузило сети', 'Net sinker stone',
     (1, 20), 9, 6, 6, 8, 'sinker', 0.1, '#7a7466', ['одно', 'связка',
                                                     'в гальке']),
    ('yakor', 'find', 'Якорный камень', 'Anchor stone', (2, 40), 8, 7, 8,
     9, 'anchor', 0.5, '#6a6660', ['один', 'с верёвкой', 'в иле']),
    ('balka', 'find', 'Деревянная балка', 'Timber beam', (3, 40), 9, 5, 8,
     7, 'beam', 3.0, '#5a4630', ['целая', 'сгнившая', 'в иле']),
    # Finds named by the underwater expeditions (docs/ISSYK_KUL_FISH.md,
    # section 4): glazed brick, slag, smith's tongs, animal bones.
    ('glazur', 'find', 'Глазурованный кирпич', 'Glazed brick', (2, 30), 9,
     6, 8, 9, 'brick', 0.3, '#3a7a8a', ['один', 'в кладке', 'скол']),
    ('shlak', 'find', 'Металлургический шлак', 'Smelting slag', (2, 30), 9,
     6, 6, 9, 'shard', 0.2, '#3a3430', ['кусок', 'россыпь', 'в иле']),
    ('kleshchi', 'find', 'Кузнечные клещи', "Smith's tongs", (2, 30), 9, 7,
     7, 9, 'shard', 0.4, '#4a4a48', ['в песке', 'у кладки', 'обросшие']),
    ('kosti', 'find', 'Кости животных', 'Animal bones', (2, 30), 9, 6, 6,
     8, 'sherds', 0.4, '#d8d0b8', ['россыпь', 'у очага', 'в иле']),
    # The water's own phenomena.
    ('caustics', 'water', 'Солнечная сетка на дне', 'Sun caustics',
     (0, 8), 10, 7, 9, 7, 'light', 3.0, '#e8f0c8',
     ['полдень', 'рябь', 'утро']),
    ('shafts', 'water', 'Лучи сквозь толщу', 'Light shafts', (0, 25), 10,
     8, 9, 7, 'light', 5.0, '#d8ecf0', ['косые', 'редкие', 'гаснут']),
    ('thermo', 'water', 'Мерцание термоклина', 'Thermocline shimmer',
     (40, 110), 10, 10, 7, 9, 'layer', 6.0, '#a8c8d0',
     ['граница', 'рябь слоя', 'переход']),
    ('snow', 'water', 'Взвесь «морского снега»', 'Marine snow', (5, 300),
     10, 6, 6, 5, 'particles', 3.0, '#e0e8e8', ['редкая', 'густая',
                                                'медленная']),
    ('bubbles', 'water', 'Пузырьковый столб', 'Bubble column', (0, 60), 9,
     9, 9, 8, 'bubbles', 2.0, '#e8f4f8', ['от ROV', 'в ритме дыхания',
                                          'из ключа']),
    ('turbid', 'water', 'Облако мути', 'Turbidity cloud', (0, 60), 9, 6,
     6, 7, 'cloud', 2.0, '#8a8a70', ['после течения', 'у дна',
                                     'оседает']),
    ('seiche', 'water', 'Сейшевое течение', 'Seiche current', (0, 60), 9,
     7, 5, 9, 'current', 4.0, '#9ab8c0', ['слабое', 'сильное', 'разворот']),
    # More of the water's motion, drawn as flow lines like the seiche
    # current (operator, 2026-09-30: "такого больше").
    ('karman', 'water', 'Вихревая дорожка за валуном',
     'Vortex street behind a boulder', (0, 60), 10, 9, 7, 9, 'eddy', 2.5,
     '#a8c8d0', ['за валуном', 'за сваей', 'гаснет']),
    ('intwave', 'water', 'Внутренняя волна на термоклине',
     'Internal wave on the thermocline', (40, 110), 9, 10, 7, 9,
     'intwave', 6.0, '#b8d8e0', ['граница', 'гребень', 'переход']),
    ('plume', 'water', 'Шлейф речной воды у устья', 'River plume',
     (0, 15), 9, 8, 8, 9, 'plume', 4.0, '#b0b098', ['у устья', 'мутный',
                                                    'холодный']),
    ('langmuir', 'water', 'Ленгмюровские полосы под ветром',
     'Langmuir streaks', (0, 6), 9, 7, 7, 9, 'langmuir', 5.0, '#d8ecf0',
     ['полосы', 'под ветром', 'гаснут']),
    ('upwelling', 'water', 'Подъём глубинной воды у свала',
     'Upwelling at the drop', (20, 120), 7, 8, 6, 9, 'upwelling', 4.0,
     '#98b8c8', ['кромка', 'слабый', 'холодный']),
    # People and the lake today.
    ('tether', 'human', 'Трос ROV', 'ROV tether', (0, 300), 10, 7, 8, 5,
     'rope', 3.0, '#e0a040', ['натянут', 'петля', 'у дна']),
    ('ghostnet', 'human', 'Брошенная сеть', 'Ghost net', (2, 40), 9, 8, 8,
     9, 'net', 2.0, '#8a9a8a', ['на камнях', 'с рыбой', 'в траве']),
    ('buoyline', 'human', 'Цепь буя станции', 'Station buoy chain',
     (0, 80), 8, 6, 8, 8, 'chain', 3.0, '#6a6a6a',
     ['натянута', 'ржавая', 'в водорослях']),
    ('bottle', 'human', 'Бутылка на песке', 'A bottle on the sand',
     (0, 30), 9, 7, 7, 7, 'bottle', 0.3, '#7a9a8a', ['целая', 'в песке',
                                                     'разбитая']),
    ('grebe', 'bird', 'Ныряющая поганка', 'Diving grebe', (0, 5), 9, 6, 8,
     9, 'bird', 0.4, '#5a4a3a', ['ныряет', 'всплывает', 'охотится']),
    ('cormorant', 'bird', 'Баклан под водой', 'Cormorant underwater',
     (0, 10), 9, 5, 8, 9, 'bird', 0.8, '#2a2a2a', ['ныряет', 'охотится',
                                                   'всплывает']),
    # Wintering divers of the Issyk-Kul Ramsar site.
    ('lysukha', 'bird', 'Лысуха под водой', 'Coot underwater', (0, 3), 8,
     5, 8, 8, 'bird', 0.4, '#1e1e20', ['ныряет', 'щиплет траву',
                                       'всплывает']),
    ('nyrok', 'bird', 'Красноносый нырок', 'Red-crested pochard', (0, 3),
     8, 5, 8, 8, 'bird', 0.5, '#7a3a2a', ['ныряет', 'щиплет траву',
                                          'всплывает']),
    ('krokhal', 'bird', 'Большой крохаль', 'Goosander', (0, 5), 8, 5, 8,
     8, 'bird', 0.6, '#3a4a40', ['ныряет', 'охотится', 'всплывает']),
]

# What each state and band adds, so ties break by what matters to play.
STATE_BONUS = {'на границе слоя': 3, 'в ритме дыхания': 3, 'граница': 2,
               'кромка': 2, 'старая береговая линия': 2, 'переход': 2,
               'темнота внизу': 2, 'в тени камня': 1, 'у сваи': 1,
               'ряд свай': 1, 'с рыбой': 1, 'стайка': 1}
# Operator, 2026-09-30: "добавь всех рыб все камни и все реальное".  So
# every real thing of the register is shown at least once; the category
# minimums of the first selection are no longer needed.
EVERY_ITEM = True

# Operator, 2026-09-30: "можно брать как добычу".  What may be taken and
# how, one rule per item, deterministic (TABOO 0.35 r.15):
#   keep       taken into the bag (introduced fish, stones, plant samples,
#              litter and the ghost net, whose removal is itself a mercy);
#   release    native and endemic fish: caught, entered in the log and
#              let go -- the lake bans fishing for its endemics and four
#              of them are in the Red Book of Kyrgyzstan;
#   hand-over  finds of the drowned settlements go to the brotherhood's
#              scriptorium, never sold (no SKU, TABOO 0.35 r.16);
#   None       nothing to take: water, light, living birds, the station's
#              gear, and anything that bears a cross (the lead bulla).
NATIVE_FISH = {'chebak', 'chebachok', 'marinka', 'osman', 'gubach',
               'osman-scaly', 'loach-tibet', 'loach-grey', 'golyan'}
NO_LOOT = {'bulla', 'tether', 'buoyline', 'kosti'}


def loot_rule(item, category):
    if item in NO_LOOT or category in ('water', 'bird'):
        return None
    if category == 'fish':
        return 'release' if item in NATIVE_FISH else 'keep'
    if category == 'find':
        return 'hand-over'
    return 'keep'


def pool():
    out = []
    for (iid, cat, ru, en, depth, truth, teach, read, nov, shape, size,
         colour, states) in ITEMS:
        for band, lo, hi in BANDS:
            if hi <= depth[0] or lo >= depth[1]:
                continue
            for state in states:
                score = {'truth': truth, 'teaching': teach,
                         'readable': read, 'novelty': nov, 'safety': 10}
                total = sum(score.values()) + STATE_BONUS.get(state, 0)
                # Deeper bands read worse in the dark.
                total -= BANDS.index((band, lo, hi)) // 2
                out.append({
                    'id': f'{iid}.{band}.{states.index(state)}',
                    'item': iid, 'category': cat, 'ru': f'{ru}: {state}',
                    'en': en, 'band': band, 'depth': [max(lo, depth[0]),
                                                      min(hi, depth[1])],
                    'state': state, 'shape': shape, 'size_m': size,
                    'colour': colour, 'score': score, 'total': total,
                })
    return out


def select(candidates, n=99, per_item=2):
    ranked = sorted(candidates, key=lambda c: (-c['total'], c['id']))
    chosen, per = [], {}
    # Every real thing first, in its best state (EVERY_ITEM); the rest of
    # the places go to the next best states, at most two per thing.
    for c in ranked:
        if EVERY_ITEM and c['item'] not in per:
            chosen.append(c)
            per[c['item']] = 1
    for c in ranked:
        if len(chosen) >= n:
            break
        if c in chosen or per.get(c['item'], 0) >= per_item:
            continue
        chosen.append(c)
        per[c['item']] = per.get(c['item'], 0) + 1
    return sorted(chosen, key=lambda c: (c['category'], c['item'], c['id']))


def parts(c):
    """Primitive parts for the 3D proxy (scripts/meta3d, lod proxy)."""
    s = c['size_m']
    col = c['colour']
    shape = c['shape']
    if shape == 'fish':
        return [{'name': 'body', 'shape': 'box', 'size': [s, s * .3, s * .12],
                 'pos': [0, 0, 0], 'color': col},
                {'name': 'tail', 'shape': 'box', 'size': [s * .25, s * .3,
                                                          s * .04],
                 'pos': [-s * .6, 0, 0], 'color': col}]
    if shape in ('boulder', 'jar', 'disc', 'slab', 'brick', 'sinker',
                 'anchor', 'shard', 'bottle', 'shell', 'outcrop'):
        h = {'jar': 1.1, 'disc': .2, 'slab': .25, 'brick': .5,
             'bottle': 1.2, 'shell': .6, 'outcrop': .5}.get(shape, .7)
        return [{'name': shape, 'shape': 'box', 'size': [s, s * h, s * .8],
                 'pos': [0, s * h / 2, 0], 'color': col}]
    if shape in ('pile', 'stems', 'reeds', 'chain', 'rope'):
        n = {'stems': 5, 'reeds': 7}.get(shape, 1)
        return [{'name': f'{shape}-{i}', 'shape': 'box',
                 'size': [.03 + s * .02, s, .03 + s * .02],
                 'pos': [i * .12 - n * .06, s / 2, (i % 2) * .08],
                 'color': col} for i in range(n)]
    if shape in ('wall', 'beam', 'terrace', 'edge', 'ring'):
        return [{'name': shape, 'shape': 'box', 'size': [s, .25, .4],
                 'pos': [0, .125, 0], 'color': col}]
    # Fields, swarms, light and water: a flat zone the engine fills.
    return [{'name': f'{shape}-zone', 'shape': 'box',
             'size': [s, .02, s], 'pos': [0, .01, 0], 'color': col,
             'flags': {'zone': True}}]


def main():
    cands = pool()
    # 999 exactly: the pool is cut at the lowest scores if larger, and
    # its real size is recorded either way.
    real = len(cands)
    ranked = sorted(cands, key=lambda c: (-c['total'], c['id']))[:999]
    best = select(cands)
    for c in best:
        c['parts'] = parts(c)
        rule = loot_rule(c['item'], c['category'])
        c['flags'] = {'noLoot': rule is None, 'loot': rule}
    (ROOT / 'docs' / 'LAKE_OBJECTS_999.json').write_text(json.dumps(
        {'note': 'Combinations item x state x depth band of eighty '
                 'real things of Issyk-Kul; not 999 distinct things.',
         'real_combinations': real, 'kept': len(ranked),
         'candidates': ranked}, ensure_ascii=False, indent=1) + '\n',
        encoding='utf-8')
    (ROOT / 'public' / 'ludus' / 'data' / 'lake-objects-99.json') \
        .write_text(json.dumps({'objects': best}, ensure_ascii=False,
                               indent=1) + '\n', encoding='utf-8')
    lines = ['# 99 objects of the lake and the pool they came from', '',
             f'Pool: {real} real combinations (item x state x depth band) '
             f'of {len(ITEMS)} things of Issyk-Kul. The operator asked for '
             '999; the lake honestly gives this many, and nothing was '
             'invented to reach the number. Selection: every real thing '
             'at least once in its best state, then the next best states, '
             'at most two per thing. Loot (operator, 2026-09-30): keep, '
             'release (native fish), hand-over (finds) or none (water, '
             'birds, station gear, the bulla with its cross); see '
             'docs/ISSYK_KUL_FISH.md.', '',
             '| # | Category | Object | Band | Depth, m | Score | Loot |',
             '|---|---|---|---|---|---|---|']
    for i, c in enumerate(best, 1):
        lines.append(f'| {i} | {c["category"]} | {c["ru"]} | {c["band"]} '
                     f'| {c["depth"][0]}–{c["depth"][1]} | {c["total"]} '
                     f'| {c["flags"]["loot"] or "—"} |')
    (ROOT / 'docs' / 'LAKE_OBJECTS_99.md').write_text(
        '\n'.join(lines) + '\n', encoding='utf-8')
    cats = {}
    for c in best:
        cats[c['category']] = cats.get(c['category'], 0) + 1
    print(f'items {len(ITEMS)}, combinations {real}, kept {len(ranked)}, '
          f'chosen {len(best)}: {cats}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
