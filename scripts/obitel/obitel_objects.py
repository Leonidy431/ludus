"""The obitel's objects: the honest pool of proxies and the K the hub shows.

Operator, 2026-09-30 (TABOO 0.07, docs/APK_PARITY.md): the 1300+ Meta
proxies of the SVG and the prompts are not in the headset and need a
selection.  This script makes that selection for the monastery hub of
the headset (godot/scenes/hub.tscn): the brothers' obitel on the shore
of Issyk-Kul in the story of 1375 and 2026 (TABOO 0.03).

Honest scope first.  Of the proxies in public/vr/models only the things
(kind "obj") can stand in a courtyard: locations are 5 m backdrops,
events and interface panels are not things, people are already the
mentors.  Of the 392 object proxies the register below keeps those that
belong to an obitel -- scriptorium, cell, workshop, refectory, pier,
courtyard -- and names the holy ones with the one place where they may
stand.  Caravan goods, embassy gifts, weapons and the like are not in
the register at all.  Nothing is drawn or invented here: every
candidate is an existing proxy .glb with its json.

The pool is the real combinations proxy x place (a thing may belong to
two places, a thing may have a drawn card and a primitive volume -- its
two "states").  Each candidate is scored on five open criteria, 0-10:
  truth      it is really in a 14th-century Armenian obitel on the lake
             or at the 2026 pier of the ROV (history, the lake, the
             story's own register);
  teaching   it carries FORM -> ACTION -> GOAL (CLAUDE.md, Constitution);
  readable   a player reads it in the headset: computed from the proxy
             (a drawn card reads as a picture; a one-colour primitive
             reads only if its shape is the thing's shape);
  novelty    the hub has nothing like it yet;
  safety     holy things only as flat boards with noInteract/noLoot and
             only in their proper place; without such a place in the
             hub they are not shown (TABOO 0.2, 0.4, 0.32 item 3).
Gates: safety >= 7 and readable >= 4, or the thing is not placed.  The
K are the top scores with at most two candidates per thing and a
minimum per place.  Deterministic: ties break by id, no randomness.

Writes:
  godot/data/obitel-objects.json   the K, with mount, scale and flags
  godot/models/obitel/<id>.glb/.json  copies of the chosen proxies
  docs/OBITEL_OBJECTS_POOL.json    the whole pool with scores
  docs/OBITEL_OBJECTS_SELECTION_2026-09-30.md  the table for the operator
Usage: python3 scripts/obitel/obitel_objects.py [--check]
"""

import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / 'public' / 'vr' / 'models' / 'obj'
OUT_MODELS = ROOT / 'godot' / 'models' / 'obitel'
OUT_DATA = ROOT / 'godot' / 'data' / 'obitel-objects.json'
OUT_POOL = ROOT / 'docs' / 'OBITEL_OBJECTS_POOL.json'
OUT_DOC = ROOT / 'docs' / 'OBITEL_OBJECTS_SELECTION_2026-09-30.md'

K = 32
PER_THING = 2
MIN_PER_PLACE = 4
PLACES = ['scriptorium', 'cell', 'workshop', 'refectory', 'pier',
          'courtyard']
PLACE_RU = {'scriptorium': 'скрипторий', 'cell': 'келья',
            'workshop': 'мастерская', 'refectory': 'трапезная',
            'pier': 'пристань', 'courtyard': 'двор'}
# The Tri budget of a Quest 3 proxy (TABOO 0.32 item 4).
MAX_TRIS = 5000
# A drawn card is hung or stood at this size so it reads at 2 m.
CARD_M = 0.6

# How well a one-colour primitive stands for the real thing once it is
# scaled to the thing's size: the same shape, a near shape, or a cube
# standing for something that is not a cube.
FIT_READ = {'good': 7, 'fair': 5, 'poor': 2}
CARD_READ = 7
SMALL_M = 0.15  # Smaller than this is lost at two metres.

# The register.  (thing, places, ru, truth, teaching, novelty, holy
# place or None, proxies, lesson).  A proxy is (id, None) for a drawn
# card or a flat board, or (id, (w, h, d, fit, lay)) for a primitive
# with the thing's real size in metres; lay=True puts it on its side.
# holy: '' for a neutral thing, 'red-corner' for the one holy place the
# hub has (the scriptorium's lampada), 'none' when the hub has no
# proper place for it.
REGISTER = [
    # The scriptorium: the word written by hand (TABOO 0.03 nodes 4, 21).
    ('inkwell', ['scriptorium'], 'Чернильница писца', 10, 8, 8, '',
     [('obj-chernilnitsa', None)],
     'Писец сверяет каждую строку: рука медленнее сканера, но отвечает '
     'за строку (узел 4).'),
    ('wax-tablet', ['scriptorium', 'cell'], 'Восковая табличка', 9, 7, 8,
     '', [('obj-voskovaya-tablichka', None)],
     'Черновик на воске заглаживают и пишут снова: терпение, а не '
     'стирание памяти.'),
    ('archive-chest', ['scriptorium'], 'Сундук архива', 9, 8, 8, '',
     [('obj-sunduk-arkhiva', None)],
     'Память обители хранится рукой; в 2026 её копии поднимают из '
     'резервной копии (узел 21).'),
    ('scroll-niche', ['scriptorium'], 'Ниша свитков', 9, 7, 7, '',
     [('obj-arkhiv-svitkov', None)],
     'Запись находят по нити ярлыков: поиск, который различает монах '
     '(узел 66).'),
    ('chronicle', ['scriptorium'], 'Раскрытая летопись', 9, 8, 7, '',
     [('obj-letopis', None)],
     'Погодные записи: что было, записано один раз.'),
    ('lake-levels', ['scriptorium'], 'Летопись уровней озера', 9, 9, 9,
     '', [('obj-letopis-urovney', None), ('obj-hronika-urovney', None)],
     'Уровень озера записан по годам: вода поднималась и топила посады, '
     'отсюда находки на дне (узел 13).'),
    ('languages', ['scriptorium'], 'Свиток языков', 8, 8, 8, '',
     [('obj-svitok-yazykov', None)],
     'Перевод ложится в словарь писца трудом, не мгновенно (узел 49).'),
    ('translation', ['scriptorium'], 'Тетрадь перевода в два столбца', 8,
     7, 7, '', [('obj-sluzhebnik-perevod', None)],
     'Подлинник слева, перевод справа: строку сверяют, а не пересказывают '
     '(узел 58).'),
    ('print-block', ['scriptorium'], 'Печатная доска', 7, 6, 8, '',
     [('obj-pechatnaya-doska', None)],
     'Оттиск повторяет доску точно; ошибка доски повторится в каждом '
     'листе.'),
    ('account-book', ['scriptorium', 'refectory'], 'Учётная книга', 8, 6,
     7, '', [('obj-uchetnaya-kniga', None)],
     'Приход и расход записаны честно: мера, а не цена.'),
    ('synaxar', ['scriptorium'], 'Тетрадь синаксаря', 8, 8, 8, '',
     [('obj-sinaksar-tetrad', None)],
     'Календарь обители — Синаксарь и седмица, а не звёзды (ТАБУ №0.35 '
     'п. 23).'),
    ('neumes', ['scriptorium'], 'Лист певческих знаков', 5, 6, 8, '',
     [('obj-kryukovaya-notatsiya', None)],
     'Знаки напева без текста: пение а капелла записывают, а не '
     'синтезируют.'),
    ('binding-press', ['scriptorium'], 'Переплётный пресс', 9, 6, 9, '',
     [('p0248-perepletnyy-press', (0.5, 0.6, 0.4, 'fair', False))],
     'Книгу сжимают неделями, чтобы листы легли: спешка портит кодекс.'),
    ('parchment', ['scriptorium', 'workshop'], 'Выделанный пергамен', 10,
     7, 9, '', [('p0249-vydelannyy-pergamen', (0.8, 1.0, 0.02, 'good',
                                               False))],
     'Кожу выделывают неделями: письмо начинается с терпения.'),
    ('paper-bale', ['scriptorium'], 'Кипа самаркандской бумаги', 9, 5, 9,
     '', [('p0180-kipa-khlopkovoy-bumagi-samarkanda',
           (0.35, 0.25, 0.3, 'good', False))],
     'Бумага пришла караваном: обитель на перекрёстке дорог.'),
    ('glossary', ['scriptorium'], 'Кипчакский словарь', 9, 7, 9, '',
     [('p0234-kipchakskiy-slovar-glossariy',
       (0.25, 0.06, 0.18, 'fair', False))],
     'Словарь соседа: слово Евангелия ищет язык кочевника (кодекс '
     'Куманикус, 1303).'),
    ('letter', ['scriptorium'], 'Письмо с вестями', 7, 6, 7, '',
     [('obj-pismo-vesti', None)],
     'Почта сквозь горы: голуби Киликии и радиопакеты (узел 45).'),
    ('charter', ['scriptorium'], 'Берестяная грамота', 5, 6, 6, '',
     [('obj-gramota', None)],
     'Факт процарапан, гипотеза записана углём (ТАБУ №0.38 п. 3).'),
    ('route-map', ['scriptorium'], 'Карта караванных путей', 8, 7, 7, '',
     [('obj-karta-putey', None)],
     'Путь рыцаря к братьям на озере — караванная дорога кампании '
     '(ТАБУ №0.03 п. 2).'),
    ('portolan', ['scriptorium'], 'Портулан', 9, 8, 9, '',
     [('obj-portulan', None)],
     'Каталанский атлас 1375 года — карта этой школы; он и отметил '
     'обитель братьев на озере (ТАБУ №0.03 п. 2).'),
    # The cell: prayer is not shown as a mechanic; the things of a
    # brother's life are.
    ('prostration-mat', ['cell'], 'Поклонный коврик', 8, 7, 9, '',
     [('p0136-poklonnyy-kovrik', (0.6, 0.8, 0.02, 'good', True))],
     'Коврик у стены: поклон виден по стёртому месту, не по счётчику.'),
    ('felt', ['cell'], 'Войлочная кошма', 10, 5, 9, '',
     [('p0252-voylochnaya-koshma', (1.2, 1.6, 0.02, 'good', True))],
     'Кошма кочевника в келье: гость и брат спят на одном войлоке.'),
    ('hourglass', ['cell'], 'Песочные часы', 7, 7, 9, '',
     [('p0143-pesochnye-chasy-molitvy', (0.09, 0.16, 0.09, 'fair',
                                         False))],
     'Песок меряет время, а не молитву: счёт видит только сам брат.'),
    ('isaac-scroll', ['cell'], 'Свиток слов Исаака Сирина', 8, 9, 9, '',
     [('p0102-slova-isaaka-sirina-svitok', (0.07, 0.32, 0.07, 'good',
                                            True))],
     'Пересказ: безмолвие — таинство будущего века (прп. Исаак Сирин; '
     'номер Слова сверить с data/patristic-canon.json).'),
    ('spindle', ['cell', 'workshop'], 'Прялка-веретено', 9, 6, 9, '',
     [('p0262-pryalka-vereteno', (0.05, 0.32, 0.05, 'fair', False))],
     'Нить тянется ровно, пока рука терпелива.'),
    ('bandage', ['cell'], 'Перевязочное полотно', 8, 8, 9, '',
     [('obj-polotno-perevyazki', None)],
     'Рану перевязывает живой человек, а не заговор.'),
    ('firewood', ['courtyard', 'cell'], 'Вязанка дров', 9, 6, 7, '',
     [('obj-vyazanka-drov', None)],
     'Дрова носят на спине: тепло трапезы — чей-то труд.'),
    # The workshop: the hands of the obitel (TABOO 0.38 item 2).
    ('potter-wheel', ['workshop'], 'Гончарный круг', 9, 8, 9, '',
     [('obj-goncharny-krug', None), ('obj-goncharnyi-krug', None),
      ('p0237-goncharnyy-krug', (0.5, 0.8, 0.5, 'good', False))],
     'Глина берёт форму по мере вращения: ФОРМА даётся терпением руки.'),
    ('anvil', ['workshop'], 'Наковальня', 9, 7, 8, '',
     [('obj-nakovalnya', None),
      ('p0243-nakovalnya', (0.5, 0.45, 0.25, 'fair', False))],
     'Стук молота кузницы и пинг эхолота — один ритм (узел 16).'),
    ('forge', ['workshop'], 'Кузнечный горн с мехами', 9, 6, 9, '',
     [('p0242-kuznechnyy-gorn-s-mekhami', (1.0, 0.9, 0.8, 'fair',
                                           False))],
     'Кованый вручную гвоздь заменяет потерянную шайбу (узел 47).'),
    ('crucible', ['workshop'], 'Тигель', 9, 8, 8, '',
     [('obj-tigel', None),
      ('p0260-yuvelirnyy-tigel', (0.1, 0.1, 0.1, 'good', False))],
     'Металл очищается огнём, и не сразу.'),
    ('tools', ['workshop'], 'Плотницкий инструмент', 9, 6, 7, '',
     [('obj-instrumenty', None)],
     'Орудие труда, не оружие: у мастера нет боя.'),
    ('adze', ['workshop'], 'Топор и тесло', 9, 6, 7, '',
     [('obj-topor-teslo', None),
      ('p0244-plotnitskiy-teslo', (0.07, 0.4, 0.07, 'fair', False))],
     'Топор воткнут в бревно, тесло рядом: работа, не бой.'),
    ('loom', ['workshop'], 'Ткацкий станок', 8, 7, 8, '',
     [('obj-tkatskiy-stanok', None),
      ('p0239-tkatskiy-stanok', (1.2, 1.4, 0.8, 'poor', False))],
     'Уток ложится нить за нитью; узор виден только в конце.'),
    ('cloth', ['workshop'], 'Отрез ткани', 8, 5, 7, '',
     [('obj-tkan-otrez', None)],
     'Ткань мерят шнуром, а не на глаз.'),
    ('dye-vat', ['workshop'], 'Красильный чан с мареной', 8, 5, 9, '',
     [('p0263-krasilnyy-chan-s-marenoy', (0.8, 0.7, 0.8, 'good',
                                          False))],
     'Цвет входит в нить медленно, варка за варкой.'),
    ('wax', ['workshop'], 'Брусок пчелиного воска', 9, 6, 8, '',
     [('p0045-vosk-pchelinyy-brusok', (0.14, 0.07, 0.09, 'good', False))],
     'Воск — материал обители: свеча делается руками, не покупается.'),
    ('candle-blank', ['workshop'], 'Восковая свеча-заготовка', 9, 6, 8,
     '', [('p0246-voskovaya-svecha-zagotovka',
           (0.03, 0.32, 0.03, 'fair', False))],
     'Свечу макают в воск слой за слоем.'),
    ('brick-mould', ['workshop', 'courtyard'], 'Форма для кирпича', 9, 7,
     8, '', [('obj-kirpich-forma', None)],
     'Кирпич обители тот же, что лежит глазурованным на дне.'),
    ('bell-mould', ['workshop'], 'Литейная форма для колокола', 8, 8, 9,
     '', [('p0254-liteynaya-forma-dlya-kolokola',
           (0.9, 1.1, 0.9, 'good', False))],
     'Мастера знали акустику: по форме понимают эхо (узел 14). Форма — '
     'не колокол; колокол звучит только по уставу.'),
    ('icon-board', ['workshop'], 'Доска для иконы, ещё без образа', 7, 8,
     9, '', [('p0053-doska-ikonnaya-lipovaya', (0.4, 0.53, 0.02, 'good',
                                                False))],
     'Доска ещё без образа: иконописец начинает с левкаса и поста.'),
    ('gesso', ['workshop'], 'Левкас в горшке', 8, 5, 9, '',
     [('p0054-levkas-v-gorshke', (0.2, 0.2, 0.2, 'good', False))],
     'Левкас кладут слой за слоем, до гладкости.'),
    ('lapis-mortar', ['workshop'], 'Ступа для лазури', 9, 6, 9, '',
     [('p0240-stupa-dlya-rastiraniya-lazuri', (0.25, 0.2, 0.25, 'fair',
                                               False))],
     'Лазурь из Бадахшана растирают часами: синий дорог трудом.'),
    ('scales', ['workshop', 'refectory'], 'Весы и эталонные гири', 9, 8,
     7, '', [('obj-vesy', None), ('obj-etalon-giri', None)],
     'Честная мера: гири сверяют с эталоном.'),
    ('marking-cord', ['courtyard'], 'Разметочная верёвка 3-4-5', 9, 7, 8,
     '', [('obj-verevka-kolya', None), ('obj-kolyshki-razmetki', None)],
     'Прямой угол дают двенадцать равных узлов: знание ремесла, не '
     'тайна.'),
    # The refectory: bread shared at one table (node 38).
    ('bread', ['refectory'], 'Трапезный хлеб', 9, 8, 8, '',
     [('obj-trapeznyi-khleb', None), ('obj-khleb-karavay', None)],
     'Хлеб делят за общим столом (узел 38).'),
    ('water-jug', ['refectory'], 'Кувшин воды', 9, 7, 8, '',
     [('obj-kuvshin-vody', None)],
     'Рыцарь отдал воду раненому: выбор, а не молитва (узел 30).'),
    ('karas', ['refectory'], 'Армянский карас', 10, 5, 9, '',
     [('obj-karas-kuvshin', None)],
     'Карас врыт в землю по плечи: братья принесли его ремесло с '
     'собой из Армении.'),
    ('cauldron', ['refectory'], 'Медный котёл общей трапезы', 9, 7, 9,
     '', [('p0182-mednyy-kotel-obshchey-trapezy',
           (0.6, 0.45, 0.6, 'good', False)),
          ('obj-kotel-pokhodnyi', None)],
     'Один котёл на всю братию: никто не ест отдельно.'),
    ('tonir', ['refectory'], 'Тонир (тандыр)', 10, 6, 9, '',
     [('p0265-tandyr', (0.9, 0.9, 0.9, 'good', False))],
     'Армянский тонир врыт в землю: хлеб печётся жаром стен.'),
    ('peel', ['refectory'], 'Лопата пекаря', 9, 4, 9, '',
     [('p0264-veslo-lopata-pekarya', (0.2, 1.3, 0.04, 'fair', False))],
     'Лопата ставит хлеб в жар и достаёт вовремя.'),
    ('trough', ['refectory'], 'Квашня', 9, 5, 9, '',
     [('p0033-kvashnya-prosfornika', (0.8, 0.3, 0.4, 'fair', False))],
     'Тесто подходит само, в тепле и покое.'),
    ('grain', ['refectory'], 'Мешок зерна', 9, 7, 8, '',
     [('obj-meshok-zerna', None)],
     'Зерно даётся в долг и хранится для всех.'),
    ('flour', ['refectory'], 'Мешок чистой муки', 9, 5, 9, '',
     [('p0034-muka-pshenichnaya-chistaya', (0.4, 0.55, 0.3, 'fair',
                                            False))],
     'Мука чистая: мера и чистота одного труда.'),
    ('grain-pit', ['refectory'], 'Зерновая яма', 9, 6, 8, '',
     [('obj-zernovaya-yama', None)],
     'Яма обмазана обожжённой глиной: запас хранят от сырости и мыши.'),
    ('mortar', ['refectory'], 'Ступка', 8, 4, 7, '',
     [('obj-stupka', None)], 'Толчёт тот, кто ждёт.'),
    ('foot-basin', ['refectory'], 'Таз для омовения ног путнику', 8, 9,
     9, '', [('obj-chasha-dlya-omoveniya-nog', None)],
     'Дьякон сам омывает ноги путнику: служение, а не почёт (Ин. 13:14).'),
    ('salt', ['refectory'], 'Мешок соли', 8, 4, 9, '',
     [('p0185-meshok-soli-iz-kochkora', (0.35, 0.45, 0.3, 'fair',
                                         False))],
     'Соль берегут: её везли горами.'),
    # The pier: the lake and the instrument world of 2026 (TABOO 0.38
    # item 5: the pier with the ROV on its birch stand).
    ('boat', ['pier'], 'Лодка-плоскодонка', 9, 7, 8, '',
     [('obj-lodka', None),
      ('p0257-ostov-rybatskoy-lodki', (3.6, 0.8, 1.1, 'fair', False))],
     'Плыть от террасы к террасе, не спеша.'),
    ('net', ['pier'], 'Сеть рыбака', 10, 7, 7, '',
     [('obj-set-rybaka', None),
      ('p0187-set-dlya-chebaka', (2.0, 1.0, 0.02, 'good', False))],
     'Сеть с поплавками и грузилами: мера улова — мера жизни озера.'),
    ('anchor-stone', ['pier'], 'Каменный якорь', 10, 6, 6, '',
     [('p0186-kamennyy-yakor-rybatskoy-lodki', (0.35, 0.25, 0.3, 'fair',
                                                False))],
     'Такой же якорный камень лежит на дне: вещь, а не символ.'),
    ('oar', ['pier'], 'Весло долблёнки', 9, 5, 9, '',
     [('p0189-veslo-grebok-dolblenki', (0.12, 1.8, 0.05, 'good', False))],
     'Весло ведёт лодку только в руках гребца.'),
    ('sounding-lead', ['pier'], 'Лот с салом', 10, 9, 9, '',
     [('p0190-lot-gruzilo-s-salom', (0.08, 0.14, 0.08, 'good', False))],
     'Дно отвечает песком на сале: промер честный, как у водолаза.'),
    ('knotted-line', ['pier'], 'Мерный линь с узлами', 10, 7, 9, '',
     [('p0191-mernyy-lin-s-uzlami', (0.3, 0.12, 0.3, 'fair', False))],
     'Трос распутывают тем же путём, каким закрутили (узел 2).'),
    ('pile', ['pier'], 'Свая причала', 9, 7, 7, '',
     [('obj-brevno-svaya', None)],
     'Свая держит причал, пока не сгниёт; её остатки ROV находит на дне.'),
    ('water-gauge', ['pier'], 'Водомерная рейка', 10, 8, 9, '',
     [('obj-mernaya-rejka', None),
      ('p0206-vodomernaya-reyka-beregovaya', (0.1, 2.0, 0.05, 'good',
                                              False))],
     'Уровень воды читают по зарубкам: наблюдение, а не догадка.'),
    ('sonar', ['pier'], 'Сонар', 9, 8, 7, '', [('obj-sonar', None)],
     'Сигнал уходит и возвращается эхом: слушать, а не кричать '
     '(узел 18).'),
    ('depth-gauge', ['pier'], 'Глубиномер', 9, 7, 7, '',
     [('obj-glubinomer', None)],
     'Стрелка показывает глубину: медленный спуск, медленное всплытие '
     '(узел 89).'),
    ('thermometer', ['pier'], 'Термометр воды', 10, 9, 8, '',
     [('obj-termometr-vody', None)],
     'Термоклин один, на 50 м: слой скачка температуры (узел 90).'),
    ('sealed-case', ['pier', 'scriptorium'], 'Герметичный футляр', 8, 7,
     8, '', [('obj-germetichny-futlyar', None)],
     'Воск и кожа берегут письмо от воды (узел 37).'),
    ('hydrophone', ['pier'], 'Гидрофон', 10, 9, 6, '',
     [('p0198-gidrofon', (0.06, 0.2, 0.06, 'fair', False))],
     'Уходят из сети, чтобы слышать (узел 18).'),
    ('water-sampler', ['pier'], 'Сосуд для отбора воды', 9, 6, 8, '',
     [('p0192-sosud-dlya-otbora-vody', (0.09, 0.3, 0.09, 'fair', False))],
     'Пробу воды берут с глубины и подписывают: память воды — это ил и '
     'пробы (узел 13).'),
    ('secchi', ['pier'], 'Диск Секки', 10, 8, 9, '',
     [('p0207-prozrachnyy-disk-glubiny-disk-sekki',
       (0.25, 0.02, 0.25, 'good', False))],
     'Прозрачность меряют, пока диск не скроется: терпение глаза '
     '(узел 39).'),
    ('marker-buoy', ['pier'], 'Буй-маркер находки', 9, 6, 8, '',
     [('p0202-buy-marker-nakhodki', (0.3, 0.3, 0.3, 'good', False))],
     'Место находки отмечают, а не берут всё подряд.'),
    ('sonar-beacon', ['pier'], 'Сонарный буй-маяк', 8, 6, 8, '',
     [('p0211-sonarnyy-buy-mayak', (0.3, 0.6, 0.3, 'fair', False))],
     'Маяк зовёт аппарат домой одним и тем же звуком.'),
    ('sample-basket', ['pier'], 'Корзина для образцов со дна', 9, 6, 8,
     '', [('p0218-korzina-dlya-obraztsov-so-dna',
           (0.45, 0.3, 0.35, 'fair', False))],
     'Находки идут писцу в книгу находок, а не на продажу (узел 68).'),
    ('sinker-basket', ['pier'], 'Корзина камней-грузил', 9, 5, 7, '',
     [('p0312-korzina-s-kamnyami-gruzilami-dlya-seti',
       (0.35, 0.3, 0.35, 'fair', False))],
     'Грузила сети: такие же лежат на дне у свай.'),
    ('drying-rack', ['pier'], 'Сушильные рамы для рыбы', 9, 5, 9, '',
     [('p0258-sushilnye-ramy-dlya-ryby', (2.0, 1.5, 0.08, 'fair', False))],
     'Улов сушат на ветру: запас на зиму.'),
    ('sounding-staff', ['pier'], 'Посох промера', 8, 7, 6, '',
     [('obj-posokh-promer', None)],
     'Путник проверяет лёд посохом, прежде чем ступить.'),
    ('rov-log', ['pier'], 'Журнал наблюдений ROV', 9, 8, 8, '',
     [('p0209-zhurnal-nablyudeniy-rov', (0.3, 0.05, 0.22, 'fair', False))],
     'Журнал — свидетельство, а не душа (узел 24).'),
    # The courtyard: the mill, the barn, the well.
    ('millstone', ['courtyard'], 'Жернов', 9, 9, 7, '',
     [('obj-zhernov', None),
      ('p0259-ruchnaya-melnitsa-zhernov', (0.7, 0.2, 0.7, 'good', False))],
     'Жернов — неподвижная точка: калибруют по нему, а не по кресту '
     '(узел 23).'),
    ('water-wheel', ['courtyard'], 'Мельничное колесо', 8, 7, 8, '',
     [('obj-melnichnoe-koleso', None)],
     'Вода, которую никто не заставлял, мелет зерно общины.'),
    ('barn', ['courtyard'], 'Амбар на сваях', 8, 6, 8, '',
     [('obj-ambar', None)],
     'Плоские камни на сваях против мышей: запас берегут умом.'),
    ('spruce-log', ['courtyard', 'workshop'], 'Бревно тянь-шаньской ели',
     10, 5, 9, '', [('p0245-brevno-tyan-shanskoy-eli',
                     (0.4, 4.0, 0.4, 'good', True))],
     'Ель Шренка с гор над озером: сруб обители из своего леса.'),
    ('well-bucket', ['courtyard'], 'Кожаное ведро колодца', 8, 5, 9, '',
     [('p0132-vedro-kozhanoe-dlya-kolodtsa-obiteli',
       (0.3, 0.3, 0.3, 'good', False))],
     'Воду из колодца носят для всех, не для себя.'),
    ('vine', ['courtyard'], 'Виноградная лоза на шпалере', 6, 7, 8, '',
     [('obj-loza', None)],
     'Сухую ветвь отсекают, чтобы лоза принесла плод (Ин. 15:2).'),
    # Holy things.  One place in the hub is proper for a holy image: the
    # scriptorium's red corner under its lampada.  The others have no
    # proper place here yet (no church, no belfry, no altar), so the
    # hub does not show them; see the open questions of the report.
    ('icon', ['scriptorium'], 'Икона в красном углу', 10, 9, 8,
     'red-corner', [('obj-ikona', None)],
     'У святыни интерфейс уходит: без подписи, цифр и подсказки '
     '(ТАБУ №0.38 п. 3).'),
    ('worship-cross', ['pier'], 'Поклонный крест у берега', 10, 9, 9,
     'none', [('obj-poklonnyi-krest', None),
              ('p0065-poklonnyy-krest-u-berega', (0.9, 2.5, 0.12, 'poor',
                                                  False))],
     'Нет прокси формы креста: карточка и куб 2,5 м его не заменяют.'),
    ('bell', ['courtyard'], 'Колокол', 10, 8, 9, 'none',
     [('obj-bell', None)], 'Нет звонницы; колокол — только по уставу.'),
    ('chalice', ['refectory'], 'Потир', 10, 8, 9, 'none',
     [('obj-potir', None)], 'Место потира — алтарь; в хабе его нет.'),
    ('censer', ['scriptorium'], 'Кадило', 10, 8, 9, 'none',
     [('obj-kadilo', None)], 'Место кадила — храм; в хабе его нет.'),
    ('gospel', ['scriptorium'], 'Евангелие напрестольное', 10, 9, 9,
     'none', [('obj-evangelie', None)],
     'Место Евангелия — престол; в хабе его нет.'),
    ('matthew-reliquary', ['scriptorium'], 'Ковчежец апостола Матфея',
     10, 9, 10, 'none', [('obj-kovchezhets-matfeya', None),
                         ('obj-raka-matfeya', None)],
     'Мощи апостола Матфея — сердце обители Каталанского атласа; их '
     'место — храм, которого в хабе ещё нет.'),
    ('prayer-rope', ['cell'], 'Чётки', 9, 8, 2, 'none',
     [('obj-chetki', None)], 'Вервица уже есть в хабе (узлы практики).'),
    ('cell-lampada', ['cell'], 'Лампадка келейная', 9, 8, 8, 'none',
     [('p0144-lampadka-keleynaya-glinyanaya', (0.08, 0.08, 0.08, 'good',
                                               False))],
     'Лампада горит перед образом; в келье хаба образа нет.'),
    ('semantron', ['courtyard'], 'Било деревянное', 9, 8, 9, 'none',
     [('p0081-bilo-derevyannoe', (1.2, 0.2, 0.08, 'poor', False))],
     'Било зовёт на службу по уставу; прокси — куб 1 м.'),
    ('kutya', ['refectory'], 'Кутья', 9, 7, 9, 'none',
     [('obj-kutya', None)], 'Кутью приносят в храм на память усопших.'),
    ('prosphora', ['refectory'], 'Просфора', 10, 8, 9, 'none',
     [('obj-prosfora', None)], 'Просфора — для литургии, не для трапезы.'),
    ('kairak', ['courtyard'], 'Кайрак — надгробный камень с крестом', 10,
     8, 8, 'none', [('obj-kairak', None), ('obj-kayrak', None)],
     'Надгробие — на кладбище, не во дворе; мёртвые не ресурс.'),
    ('ichthys-bowl', ['refectory'], 'Чаша со знаком рыбы', 7, 7, 8,
     'none', [('obj-chasha-ikhtis', None), ('obj-ikhtis-keramika', None)],
     'Знак ИХТИС — имя Христово: не посуда-декор.'),
]

# Things the hub already shows (hub.gd): the chronicle codex on the
# scriptorium table, the prayer rope at its lectern, the ROV.  And
# things the dive already shows (lake-objects-99, atlas traces).
IN_HUB = {'chronicle': 4, 'prayer-rope': 0}
IN_DIVE = {'millstone', 'anchor-stone', 'net', 'pile', 'hydrophone',
           'sinker-basket', 'sounding-staff', 'brick-mould'}
# A thing that has only been a drawing so far gains when it stands as a
# volume (TABOO 0.32: all in volume for Meta).
VOLUME_BONUS = 1
# Where a thing teaches best (explicit, so ties break by what matters).
PLACE_BONUS = {('millstone', 'courtyard'): 2, ('bread', 'refectory'): 1,
               ('inkwell', 'scriptorium'): 1, ('icon', 'scriptorium'): 2,
               ('thermometer', 'pier'): 1, ('lake-levels',
                                            'scriptorium'): 1}
WALL_PLACES = {'scriptorium', 'cell', 'workshop', 'refectory'}
# The pier has a birch crate for the small instruments of the lake.
TABLE_PLACES = {'scriptorium', 'cell', 'workshop', 'refectory', 'pier'}


def proxy_json(pid):
    return json.loads((MODELS / f'{pid}.json').read_text(encoding='utf-8'))


def readable(meta, fit):
    """The headset criterion, computed from the proxy itself."""
    if fit is None:
        return CARD_READ
    w, h, d, cls, _lay = fit
    score = FIT_READ[cls]
    if max(w, h, d) < SMALL_M:
        score -= 2
    return score


def safety(holy, meta):
    if holy == 'none':
        return 0
    if holy == 'red-corner':
        # Only as a flat board with both flags (TABOO 0.32 item 3).
        ok = (meta.get('method') == 'flat-board'
              and meta.get('noInteract') and meta.get('noLoot'))
        return 9 if ok else 0
    return 10


def mount(place, fit, holy):
    if holy == 'red-corner':
        return 'red-corner'
    if fit is None:
        return 'wall' if place in WALL_PLACES else 'stand'
    w, h, d, _cls, lay = fit
    foot = max(w, d, h if lay else 0)
    if place in TABLE_PLACES and foot <= 0.45 and h <= 0.6:
        return 'table'
    return 'floor'


def scale(meta, fit):
    """Per-axis scale from the proxy's bbox to the thing's size."""
    bx, by, bz = meta['bbox_m']
    if fit is None:
        s = CARD_M / max(bx, by)
        return [round(s, 4)] * 3
    w, h, d = fit[:3]
    return [round(w / bx, 4), round(h / by, 4), round(d / bz, 4)]


def pool():
    out = []
    for (thing, places, ru, truth, teach, nov, holy, proxies,
         lesson) in REGISTER:
        for pid, fit in proxies:
            meta = proxy_json(pid)
            for place in places:
                novelty = nov
                if thing in IN_HUB:
                    novelty = IN_HUB[thing]
                elif thing in IN_DIVE:
                    novelty -= 1
                if fit is not None:
                    novelty = min(10, novelty + VOLUME_BONUS)
                score = {'truth': truth, 'teaching': teach,
                         'readable': readable(meta, fit),
                         'novelty': novelty,
                         'safety': safety(holy, meta)}
                total = sum(score.values()) + PLACE_BONUS.get(
                    (thing, place), 0)
                holy_thing = holy != ''
                out.append({
                    'id': f'{pid}@{place}', 'proxy': pid, 'thing': thing,
                    'place': place, 'ru': ru, 'lesson': lesson,
                    'state': ('board' if meta['method'] == 'flat-board'
                              else 'card' if fit is None else 'volume'),
                    'mount': mount(place, fit, holy),
                    'lay': bool(fit and fit[4]),
                    'size_m': list(fit[:3]) if fit else [CARD_M] * 2,
                    'scale': scale(meta, fit), 'tris': meta['tris'],
                    'source': meta['source'], 'method': meta['method'],
                    'score': score, 'total': total,
                    'gate': (score['safety'] >= 7
                             and score['readable'] >= 4),
                    'flags': {
                        'holy': holy_thing,
                        'noInteract': bool(holy_thing
                                           or meta.get('noInteract')),
                        'noLoot': bool(holy_thing or meta.get('noLoot')),
                    },
                })
    return out


def select(cands, k=K):
    ranked = sorted((c for c in cands if c['gate']),
                    key=lambda c: (-c['total'], c['id']))
    chosen, per, ids = [], {}, set()

    def take(c):
        chosen.append(c)
        ids.add(c['id'])
        per[c['thing']] = per.get(c['thing'], 0) + 1

    def ok(c):
        # One proxy is shown once, whatever the place.
        return (c['id'] not in ids and per.get(c['thing'], 0) < PER_THING
                and all(x['proxy'] != c['proxy'] for x in chosen))

    # The holy image first: its place is fixed and it is one.
    for c in ranked:
        if c['flags']['holy'] and ok(c):
            take(c)
    # A minimum per place, each place's best, a new thing first.
    for place in PLACES:
        n = sum(1 for c in chosen if c['place'] == place)
        for c in ranked:
            if n >= MIN_PER_PLACE:
                break
            if c['place'] == place and c['thing'] not in per and ok(c):
                take(c)
                n += 1
    # The rest by score, a new thing before a second state of one.
    for c in ranked:
        if len(chosen) >= k:
            break
        if c['thing'] not in per and ok(c):
            take(c)
    for c in ranked:
        if len(chosen) >= k:
            break
        if ok(c):
            take(c)
    return sorted(chosen, key=lambda c: (PLACES.index(c['place']),
                                         c['mount'], c['proxy']))


def constitution(c):
    return (f'ФОРМА: {c["ru"].lower()} ({PLACE_RU[c["place"]]}) → '
            f'ДЕЙСТВИЕ: игрок видит вещь на её месте и её ремесло → '
            f'ЦЕЛЬ: {c["lesson"]}')


def build():
    cands = pool()
    best = select(cands)
    objs = []
    for c in best:
        objs.append({
            'id': c['proxy'], 'thing': c['thing'], 'place': c['place'],
            'ru': c['ru'], 'lesson': c['lesson'],
            'constitution': constitution(c), 'state': c['state'],
            'mount': c['mount'], 'lay': c['lay'], 'size_m': c['size_m'],
            'scale': c['scale'], 'tris': c['tris'],
            'model': f'res://models/obitel/{c["proxy"]}.glb',
            'meta': f'res://models/obitel/{c["proxy"]}.json',
            'source': c['source'], 'score': c['score'],
            'total': c['total'], 'flags': c['flags'],
        })
    return cands, objs


def doc(cands, objs):
    things = len(REGISTER)
    gated = sum(1 for c in cands if c['gate'])
    holy_out = sorted({c['thing'] for c in cands
                       if c['flags']['holy'] and not c['gate']})
    lines = [
        '# Объекты обители в шлеме: из N — K (ТАБУ №0.07)', '',
        'Генератор: `scripts/obitel/obitel_objects.py`. Данные: '
        '`godot/data/obitel-objects.json`. Модели: `godot/models/obitel/`. '
        'Расстановка: `godot/scripts/obitel_layout.gd`. HLD: '
        '`docs/HLD_OBITEL_OBJECTS_2026-09-30.md`.', '',
        '## Пул и его настоящий размер', '',
        f'- Прокси-объектов в `public/vr/models/obj`: '
        f'{len(list(MODELS.glob("*.json")))}. Локации (задники 5 м), '
        'события, интерфейс и люди в пул не входят: это не вещи двора.',
        f'- Реестр обители: **{things} вещей** (скрипторий, келья, '
        'мастерская, трапезная, пристань, двор и святыни с их местом). '
        'Караванные товары, дары посольств, оружие, карты других сюжетов '
        'в реестр не взяты.',
        f'- Честный пул N = **{len(cands)}** сочетаний «прокси × место» '
        '(у вещи бывает карточка-рисунок и объёмный примитив — два её '
        'состояния; некоторые вещи уместны в двух местах). Число не '
        'подгонялось.',
        f'- Проходят ворота (безопасность ≥ 7 и читаемость ≥ 4): '
        f'**{gated}**.',
        f'- Выбрано K = **{len(objs)}** (просили 24–40; взято {K}: по '
        f'{MIN_PER_PLACE} минимум на место, не больше {PER_THING} на '
        'вещь, один прокси — один раз).', '',
        'Критерии 0–10: правда, учительная связь, читаемость в шлеме '
        '(считается по прокси: карточка-рисунок 7; примитив 7/5/2 по '
        'совпадению формы, −2 если вещь меньше 15 см), новизна (−4 если '
        'вещь уже есть в хабе, −1 если есть в погружении, +1 за объём), '
        'безопасность (святое — только плоской доской с noInteract/'
        'noLoot и только на своём месте). Порядок детерминирован.', '',
        '## K: что стоит в хабе', '',
        '| # | Место | Вещь | Прокси | Вид | Крепление | Правда | Учит | '
        'Читаем | Новизна | Безоп. | Итог |',
        '|---|---|---|---|---|---|---|---|---|---|---|---|']
    for i, o in enumerate(objs, 1):
        s = o['score']
        lines.append(
            f'| {i} | {PLACE_RU[o["place"]]} | {o["ru"]} | `{o["id"]}` | '
            f'{o["state"]} | {o["mount"]} | {s["truth"]} | '
            f'{s["teaching"]} | {s["readable"]} | {s["novelty"]} | '
            f'{s["safety"]} | {o["total"]} |')
    lines += [
        '', '## Святое', '',
        '- Икона (`obj-ikona`, flat-board) — единственная святыня в хабе: '
        'плоская доска в красном углу скриптория под лампадой, '
        '`noInteract`/`noLoot`, без подписи и подсказки.',
        f'- Не показаны, потому что в хабе нет их места или нет прокси '
        f'нужной формы: {", ".join(holy_out)}. Причина у каждой — в '
        'реестре генератора.', '',
        '## Что проверить специалисту до релиза', '',
        '- Историк-этнограф Семиречья: армянский карас и тонир у '
        'братьев на Иссык-Куле XIV в.; кипчакский словарь (Codex '
        'Cumanicus, 1303) как вещь скриптория; самаркандская бумага; '
        'лоза на шпалере у озера (правда 6).',
        '- Литургист и иконописец: липовая доска для иконы у армянских '
        'мастеров (обычно иной материал); лист певческих знаков — у '
        'армянских братьев были хазы, а не крюки (правда 5).',
        '- Богослов: икона в красном углу скриптория — достаточно ли '
        'этого места, или образу нужен свой киот; можно ли показать '
        'поклонный коврик без подсказки действия.',
        '- Гидроакустик: сонар, термометр, глубиномер — это карточки '
        '2026 года рядом с ROV; не путает ли игрока их соседство с '
        'вещами XIV в.',
        '- Художник: карточки-рисунки — это рельефы SVG (LOD0 proxy), а '
        'не модели вещей; их заменят модели `lod: final` тем же id.',
        '', '## Открытые вопросы', '',
        '- В хабе нет храма: мощи апостола Матфея, Евангелие, потир, '
        'кадило, колокол и поклонный крест ждут своего места и своей '
        'модели. Хор 12 (ТАБУ №0.37).',
        '- Прокси из промтов одноцветные (дуб): их читаемость держится '
        'только на форме; нужна своя процедурная модель, как у озера.',
        '']
    return '\n'.join(lines)


def main():
    cands, objs = build()
    data = json.dumps({
        'note': 'The K objects of the obitel in the hub; generated by '
                'scripts/obitel/obitel_objects.py (TABOO 0.07).',
        'pool_size': len(cands), 'register_things': len(REGISTER),
        'k': len(objs), 'objects': objs}, ensure_ascii=False, indent=1)
    if '--check' in sys.argv:
        same = OUT_DATA.read_text(encoding='utf-8') == data + '\n'
        print('obitel-objects.json', 'up to date' if same else 'STALE')
        return 0 if same else 1
    OUT_DATA.write_text(data + '\n', encoding='utf-8')
    OUT_POOL.write_text(json.dumps(
        {'note': 'Every proxy x place of the obitel register, scored.',
         'size': len(cands),
         'candidates': sorted(cands, key=lambda c: (-c['total'],
                                                    c['id']))},
        ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    OUT_MODELS.mkdir(parents=True, exist_ok=True)
    keep = {o['id'] for o in objs}
    for f in OUT_MODELS.iterdir():
        if f.name.split('.')[0] not in keep:
            f.unlink()
    for o in objs:
        assert o['tris'] <= MAX_TRIS, o['id']
        for ext in ('glb', 'json'):
            shutil.copyfile(MODELS / f'{o["id"]}.{ext}',
                            OUT_MODELS / f'{o["id"]}.{ext}')
    OUT_DOC.write_text(doc(cands, objs), encoding='utf-8')
    per = {}
    for o in objs:
        per[o['place']] = per.get(o['place'], 0) + 1
    mounts = {}
    for o in objs:
        key = (o['place'], o['mount'])
        mounts[key] = mounts.get(key, 0) + 1
    print(f'register {len(REGISTER)}, pool {len(cands)}, gated '
          f'{sum(1 for c in cands if c["gate"])}, chosen {len(objs)}: '
          f'{per}')
    for key in sorted(mounts):
        print(' ', key, mounts[key])
    return 0


if __name__ == '__main__':
    sys.exit(main())
