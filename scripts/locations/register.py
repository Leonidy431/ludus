"""The register behind the 99 locations: real things and real places.

Data only; the selection lives in locations_99.py (CLAUDE.md TABOO
0.07 and 0.013).  Nothing here is invented to fill a number: every
place is one where a plot of ours happens (a campaign mission, a node
of the Water Atlas or of Kiberslav, a dive task, a threshold, a
passion's meeting, a witness scene), and every thing is a real object
of the 14th-century lake, the caravan road, the 2026 expedition or the
dream of Kiberslav.

OBJECTS: key -> (ru, (w, h, d) metres, material, source, en keywords,
holy).  source is where the volume comes from:
  obj:<id>    a proxy in public/vr/models/obj (our SVG or prompt);
  lake:<id>   a lake object (public/vr/models/lake, godot/models/lake);
  atlas:<id>  a trace of the Water Atlas (models/atlas);
  own         our own drawing, still to be made;
  raw         the props store of the 99 cloned repos (TABOO 0.012),
              into a scene only through the pipeline of TABOO 0.1.
en keywords search the index of the 99 repos (whole words; a tuple
means all words).  holy is None, or how the holy thing stands: 'flat'
(a board or a relief card) or 'vessel'; a holy thing is never raw.

PLACES: one call of place() per candidate.  Plot ids: M<n> campaign
mission, A<n> Atlas node, K<n> Kiberslav node, KM the dream branch,
D:<task> dive task, T:<gate> threshold, P:<passion> meeting on the
road, W:<sacrament> witness scene.  Hearts reuse the game's cores:
  rule:<practice>        RuleCore.PRACTICES
  deed:<practice>        MissionCore.PRACTICE_RU (a mission's deed)
  talk:<npc>/<node>      a node of data/dialogue-trees.json
  find:<lake id>         a MissionCore find of data/lake-objects-99
  dive:<task>            DiveCore.TASKS
  trace:<id>, atlas:chronicle, atlas:scribe   AtlasTraces
  trial:<gate>           TrialCore (data/gate-trials.json)
  passion:<id>           PassionCore (data/passions.json)
  witness:<sacrament>    WitnessCore.ORDER
  typikon:hear           TypikonCore (the bells by clock and rule)
  listen:<id>            stand still and listen; nothing is counted,
                         paid or written (Kiberslav node 76)
  new:<id>               a new small action, NEW_ACTIONS below.
"""

OBJECTS = {}


def obj(key, ru, size, material, src, en=(), holy=None):
    """Add one real thing to the catalogue."""
    assert key not in OBJECTS, key
    OBJECTS[key] = {'ru': ru, 'size_m': list(size), 'material': material,
                    'source': src, 'en': list(en), 'holy': holy}


# --- The road and trade ------------------------------------------------
obj('scales', 'Весы торговца', (0.5, 0.45, 0.25), 'латунь, дуб',
    'obj:obj-vesy', ['scales', 'balance'])
obj('weights', 'Эталонные гири', (0.25, 0.12, 0.15), 'бронза',
    'obj:obj-etalon-giri', ['weights'])
obj('money-scales', 'Весы менялы с бронзовыми гирями', (0.45, 0.4, 0.25),
    'бронза, дуб', 'obj:p0158-vesy-menyaly-s-bronzovymi-giryami',
    ['scales'])
obj('ledger', 'Приходная книга', (0.3, 0.05, 0.22), 'кожа, бумага',
    'obj:obj-uchetnaya-kniga', ['ledger', 'book'])
obj('inkwell', 'Чернильница и перо', (0.1, 0.12, 0.1), 'керамика',
    'obj:obj-chernilnitsa', ['inkwell', 'quill'])
obj('silk-bale', 'Тюк шёлка', (0.6, 0.4, 0.4), 'шёлк, холст',
    'obj:obj-tyuk-shelka', ['bale', 'silk'])
obj('spice-sack', 'Мешок пряностей', (0.4, 0.5, 0.35), 'холст',
    'obj:obj-meshok-pryanostey', ['sack', 'spice'])
obj('silver-ingot', 'Слиток серебра', (0.15, 0.04, 0.06), 'серебро',
    'obj:obj-slitok-serebra', ['ingot'])
obj('grain-sack', 'Мешок зерна', (0.4, 0.6, 0.3), 'холст',
    'obj:obj-meshok-zerna', ['sack', 'grain'])
obj('grain-pit', 'Зерновая яма, обмазанная глиной', (1.0, 0.3, 1.0),
    'обожжённая глина', 'obj:obj-zernovaya-yama', ['granary'])
obj('store-key', 'Ключ от склада', (0.04, 0.18, 0.02), 'железо',
    'obj:obj-klyuch-sklada', ['key'])
obj('archive-chest', 'Сундук архива', (0.8, 0.5, 0.45), 'дуб, железо',
    'obj:obj-sunduk-arkhiva', ['chest'])
obj('treasury-chest', 'Сундук казны вдов и сирот', (0.7, 0.45, 0.4),
    'дуб, железо', 'obj:obj-sunduk-kazny', ['chest', 'coffer'])
obj('casket', 'Ларец каравана', (0.35, 0.25, 0.25), 'дуб, медь',
    'obj:obj-larets', ['casket'])
obj('camel-saddle', 'Верблюжье седло', (0.8, 0.5, 0.6), 'дерево, войлок',
    'obj:obj-verblyuzhye-sedlo', ['saddle', 'camel'])
obj('caravan-bells', 'Бубенцы каравана', (0.3, 0.3, 0.1), 'медь, кожа',
    'obj:obj-bubentsy-karavana', ['jingle'])
obj('water-skin', 'Бурдюк для воды', (0.3, 0.5, 0.2), 'кожа',
    'obj:p0169-burdyuk-dlya-vody', ['waterskin', 'flask'])
obj('caravan-lantern', 'Фонарь караванщика', (0.2, 0.35, 0.2),
    'медь, слюда', 'obj:p0168-fonar-karavanshchika', ['lantern'])
obj('route-map', 'Карта караванных путей', (0.6, 0.6, 0.03), 'береста',
    'obj:obj-karta-putey', ['map'])
obj('tamga', 'Тамга хана', (0.3, 0.3, 0.03), 'бронза',
    'obj:obj-tamga-khana', ['seal', 'stamp'])
obj('yarlyk', 'Ярлык хана на красном воске', (0.6, 0.6, 0.03),
    'бумага, воск', 'obj:obj-yarlyk-khana', ['scroll', 'decree'])
obj('paiza', 'Пайцза для возов', (0.08, 0.25, 0.01), 'серебро',
    'obj:obj-paiza', ['tablet'])
obj('duty-decree', 'Доска с пошлиной', (0.6, 0.6, 0.03), 'дерево',
    'obj:obj-ukaz-poshliny', ['decree'])
obj('receipt', 'Расписка', (0.6, 0.6, 0.02), 'бумага',
    'obj:obj-raspiska', ['receipt'])
obj('tally-stick', 'Долговая бирка с зарубками', (0.03, 0.3, 0.02),
    'дерево', 'obj:p0163-dolgovaya-birka-zarubka', ['stick'])
obj('abacus', 'Счёты купца', (0.3, 0.2, 0.05), 'дерево',
    'obj:p0173-schety-abak-kupecheskie', ['abacus'])
obj('coin-purse', 'Кошель дирхемов', (0.6, 0.6, 0.03), 'кожа',
    'obj:obj-koshel-dirhemov', ['purse', 'coin'])
obj('touchstone', 'Пробирный камень', (0.1, 0.03, 0.06), 'сланец',
    'obj:p0176-otsenochnyy-kamen-probirnik', ['touchstone'])
obj('measuring-ell', 'Мерный локоть торговца тканью', (0.05, 0.6, 0.02),
    'дерево', 'obj:p0172-mernyy-lokot-torgovtsa-tkanyu', ['ruler'])
obj('fruit-crate', 'Лар с сушёным урюком', (0.4, 0.3, 0.3), 'дерево',
    'obj:p0174-bakaleynyy-lar-s-sushenymi-abrikosami', ['crate'])
obj('awning', 'Навес лавки базара', (2.0, 2.2, 1.5), 'холст, жерди',
    'obj:p0177-naves-lavki-bazara-barskhana', ['awning', 'stall'])
obj('fish-basket', 'Корзина торговца рыбой', (0.5, 0.3, 0.4), 'ивняк',
    'obj:p0178-korzina-torgovtsa-ryboy', ['basket'])
obj('salt-sack', 'Мешок соли из Кочкора', (0.35, 0.45, 0.3), 'холст',
    'obj:p0185-meshok-soli-iz-kochkora', ['sack', 'salt'])
obj('caravan-staff', 'Посох караван-баши', (0.05, 1.6, 0.05), 'дерево',
    'obj:p0184-posokh-karavan-bashi', ['staff'])
obj('girth-strap', 'Подпруга верблюда', (0.4, 0.1, 0.3), 'кожа',
    'obj:p0183-remen-podpruga-verblyuda', ['strap'])
obj('trade-contract', 'Торговый договор на бересте', (0.3, 0.02, 0.2),
    'береста', 'obj:p0175-torgovyy-dogovor-na-bereste', ['contract'])
obj('paper-bale', 'Кипа самаркандской бумаги', (0.35, 0.25, 0.3),
    'хлопковая бумага', 'obj:p0180-kipa-khlopkovoy-bumagi-samarkanda',
    ['paper'])
obj('ransom-charter', 'Выкупная грамота пленника', (0.3, 0.02, 0.2),
    'бумага', 'obj:p0228-vykupnaya-gramota-plennika', ['scroll'])
obj('caravel', 'Гравюра каравеллы', (0.6, 0.6, 0.03), 'бумага',
    'obj:obj-karavella-gravura', ['ship', 'caravel'])
obj('refugee-cart', 'Телега уходящих', (0.6, 0.6, 0.04), 'дерево',
    'obj:obj-telega-bezhentsev', ['cart', 'wagon'])
obj('shackles', 'Кандалы', (0.6, 0.6, 0.03), 'железо',
    'obj:obj-kandaly', ['shackles', 'chains'])
obj('khadak', 'Шарф приветствия', (0.1, 0.02, 0.8), 'шёлк',
    'obj:p0230-khadak-sharf-privetstviya', ['scarf'])
obj('credentials', 'Верительная дощечка посла', (0.2, 0.3, 0.02),
    'дерево', 'obj:p0222-posolskaya-veritelnaya-doshchechka', ['tablet'])
obj('nomad-map', 'Карта кочевий', (0.5, 0.02, 0.4), 'кожа',
    'obj:p0232-karta-kocheviy', ['map'])
obj('tent-parley', 'Шатёр переговоров', (3.0, 2.5, 3.0), 'войлок',
    'obj:p0226-shater-peregovorov', ['tent'])

# --- Hearth and household -------------------------------------------------
obj('campfire', 'Костёр стоянки', (1.0, 0.5, 1.0), 'камень, дрова',
    'obj:obj-koster-stoyanki', ['campfire'])
obj('yard-fire', 'Костёр двора', (1.0, 0.6, 1.0), 'камень, дрова',
    'obj:obj-koster-dvora', ['campfire', 'bonfire'])
obj('cauldron-camp', 'Походный котёл', (0.5, 0.4, 0.5), 'медь',
    'obj:obj-kotel-pokhodnyi', ['cauldron'])
obj('cauldron-common', 'Медный котёл общей трапезы', (0.6, 0.45, 0.6),
    'медь', 'obj:p0182-mednyy-kotel-obshchey-trapezy', ['cauldron'])
obj('bread-loaf', 'Хлеб-каравай', (0.6, 0.6, 0.03), 'хлеб',
    'obj:obj-khleb-karavay', ['bread'])
obj('bread-table', 'Трапезный хлеб', (0.6, 0.6, 0.03), 'хлеб',
    'obj:obj-trapeznyi-khleb', ['bread'])
obj('water-jug', 'Кувшин воды', (0.6, 0.6, 0.03), 'керамика',
    'obj:obj-kuvshin-vody', ['jug', 'pitcher'])
obj('karas', 'Армянский карас', (0.6, 0.6, 0.04), 'керамика',
    'obj:obj-karas-kuvshin', ['jar'])
obj('tonir', 'Тонир (тандыр)', (0.9, 0.9, 0.9), 'глина',
    'obj:p0265-tandyr', ['oven', 'tandoor'])
obj('firewood', 'Вязанка дров', (0.6, 0.6, 0.04), 'дерево',
    'obj:obj-vyazanka-drov', ['firewood'])
obj('felt', 'Войлочная кошма', (1.2, 0.02, 1.6), 'войлок',
    'obj:p0252-voylochnaya-koshma', ['rug', 'carpet'])
obj('mortar', 'Ступка', (0.6, 0.6, 0.03), 'камень',
    'obj:obj-stupka', ['mortar'])
obj('hand-mill', 'Ручная мельница-жернов', (0.7, 0.2, 0.7), 'камень',
    'obj:p0259-ruchnaya-melnitsa-zhernov', ['millstone', 'quern'])
obj('mill-wheel', 'Мельничное колесо', (0.6, 0.6, 0.04), 'дерево',
    'obj:obj-melnichnoe-koleso', [('water', 'wheel'), 'watermill'])
obj('kumys-skin', 'Кожаная кумысница', (0.2, 0.45, 0.2), 'кожа',
    'obj:p0221-kumysnitsa-kozhanaya', ['flask'])
obj('foot-basin', 'Таз для омовения ног путнику', (0.6, 0.6, 0.03),
    'медь', 'obj:obj-chasha-dlya-omoveniya-nog', ['basin'])
obj('clay-lamp', 'Глиняная лампа для чтения', (0.12, 0.06, 0.08),
    'глина', 'own', ['lamp', 'oillamp'])
obj('well-bucket', 'Кожаное ведро колодца', (0.3, 0.3, 0.3), 'кожа',
    'obj:p0132-vedro-kozhanoe-dlya-kolodtsa-obiteli', ['bucket'])
obj('hourglass', 'Песочные часы', (0.09, 0.16, 0.09), 'стекло, дерево',
    'obj:p0143-pesochnye-chasy-molitvy', ['hourglass'])
obj('spade', 'Деревянная лопата', (0.25, 1.2, 0.05), 'дерево, железо',
    'raw', ['shovel', 'spade'])
obj('stone-pile', 'Груда камня для кладки', (1.0, 0.5, 0.8), 'камень',
    'raw', ['rubble', 'stones'])
obj('rope-coil', 'Бухта льняной верёвки', (0.4, 0.15, 0.4), 'лён',
    'raw', ['rope'])
obj('barrel', 'Бочка', (0.5, 0.7, 0.5), 'дуб', 'raw', ['barrel'])
obj('basket', 'Плетёная корзина', (0.45, 0.35, 0.35), 'ивняк', 'raw',
    ['basket'])
obj('bench', 'Скамья', (1.2, 0.45, 0.35), 'дуб', 'raw', ['bench'])
obj('herbs', 'Пучки сухих трав', (0.3, 0.4, 0.1), 'травы', 'raw',
    ['herbs', 'herb'])
obj('beehive', 'Борть с дикими пчёлами', (0.5, 0.9, 0.5), 'дерево',
    'obj:p0247-bort-s-dikimi-pchelami', ['beehive', 'hive'])
obj('wax-bar', 'Брусок пчелиного воска', (0.14, 0.07, 0.09), 'воск',
    'obj:p0045-vosk-pchelinyy-brusok', ['wax'])
obj('candle-blank', 'Восковая свеча-заготовка', (0.03, 0.32, 0.03),
    'воск', 'obj:p0246-voskovaya-svecha-zagotovka', ['candle'])
obj('hand-candle', 'Свеча в руке паломника', (0.1, 0.2, 0.1), 'воск',
    'obj:p0044-svecha-voskovaya-yaraya', ['candle'])

# --- Water and fishing -----------------------------------------------------
obj('net', 'Сеть рыбака', (0.6, 0.6, 0.03), 'лён',
    'obj:obj-set-rybaka', ['net', 'fishing'])
obj('chebak-net', 'Сеть для чебака', (2.0, 1.0, 0.02), 'лён',
    'obj:p0187-set-dlya-chebaka', ['net'])
obj('float', 'Поплавок из сосновой коры', (0.1, 0.05, 0.1), 'кора',
    'obj:p0188-poplavok-iz-sosnovoy-kory', ['float'])
obj('oar', 'Весло долблёнки', (0.12, 1.8, 0.05), 'дерево',
    'obj:p0189-veslo-grebok-dolblenki', ['oar', 'paddle'])
obj('boat', 'Лодка-плоскодонка', (0.6, 0.6, 0.03), 'дерево',
    'obj:obj-lodka', ['boat', 'rowboat'])
obj('boat-hull', 'Остов рыбацкой лодки', (3.6, 0.8, 1.1), 'дерево',
    'obj:p0257-ostov-rybatskoy-lodki', ['boat', 'hull'])
obj('barge', 'Баржа для спуска аппарата', (0.6, 0.6, 0.03), 'дерево',
    'obj:obj-lodka-barzha', ['barge'])
obj('anchor-stone', 'Каменный якорь', (0.35, 0.25, 0.3), 'камень',
    'obj:p0186-kamennyy-yakor-rybatskoy-lodki', ['anchor'])
obj('sounding-lead', 'Лот с салом', (0.08, 0.14, 0.08), 'свинец',
    'obj:p0190-lot-gruzilo-s-salom', ['plumb'])
obj('knotted-line', 'Мерный линь с узлами', (0.3, 0.12, 0.3), 'лён',
    'obj:p0191-mernyy-lin-s-uzlami', ['rope'])
obj('drying-rack', 'Сушильные рамы для рыбы', (2.0, 1.5, 0.08),
    'дерево', 'obj:p0258-sushilnye-ramy-dlya-ryby', ['rack'])
obj('sinker-basket', 'Корзина камней-грузил', (0.35, 0.3, 0.35),
    'ивняк, камень', 'obj:p0312-korzina-s-kamnyami-gruzilami-dlya-seti',
    ['basket'])
obj('water-gauge', 'Водомерная рейка', (0.1, 2.0, 0.05), 'дерево',
    'obj:p0206-vodomernaya-reyka-beregovaya', ['gauge'])
obj('level-mark', 'Метка уровня воды', (0.6, 0.6, 0.03), 'камень',
    'obj:obj-metka-urovnya', ['marker'])
obj('caulker', 'Лодочный конопатчик', (0.04, 0.25, 0.04), 'железо',
    'obj:p0256-lodochnyy-konopatchik', ['chisel'])
obj('crayfish-trap', 'Ловушка для раков', (0.4, 0.3, 0.4), 'ивняк',
    'obj:p0214-lovushka-dlya-rakov', ['trap'])
obj('spring-flask', 'Фляга с водой горячего ключа', (0.15, 0.3, 0.1),
    'кожа', 'obj:p0208-flyaga-iz-goryachego-istochnika', ['flask'])
obj('sluice', 'Заслонка шлюза', (0.6, 0.6, 0.03), 'дерево',
    'obj:obj-zaslonka-shlyuza', ['sluice'])
obj('measuring-rod', 'Мерная трость', (0.6, 0.6, 0.03), 'дерево',
    'obj:obj-mernaya-trost', ['rod'])
obj('probe-staff', 'Посох промера', (0.6, 0.6, 0.03), 'дерево',
    'obj:obj-posokh-promer', ['staff'])
obj('levels-chronicle', 'Летопись уровней озера', (0.6, 0.6, 0.03),
    'пергамен', 'obj:obj-letopis-urovney', ['chronicle'])
obj('current-map', 'Карта течений озера', (0.5, 0.02, 0.4), 'бумага',
    'obj:p0205-karta-techeniy-ozera', ['map'])
obj('water-sampler', 'Сосуд для отбора воды', (0.09, 0.3, 0.09),
    'керамика', 'obj:p0192-sosud-dlya-otbora-vody', ['bottle'])
obj('reed-bed', 'Тростник у берега', (1.2, 1.6, 0.4), 'тростник',
    'lake:trostnik.shallows.0', ['reeds', 'reed'])

# --- Instruments of 2026 ---------------------------------------------------
obj('rov-card', 'Аппарат на берёзовом стапеле', (0.6, 0.6, 0.03),
    'медь, берёза', 'obj:obj-rov', ['submarine', 'robot'])
obj('sonar', 'Сонар', (0.6, 0.6, 0.03), 'медь, латунь', 'obj:obj-sonar',
    ['sonar'])
obj('depth-gauge', 'Глубиномер', (0.6, 0.6, 0.03), 'латунь',
    'obj:obj-glubinomer', ['gauge'])
obj('thermometer', 'Термометр воды', (0.6, 0.6, 0.03), 'латунь, стекло',
    'obj:obj-termometr-vody', ['thermometer'])
obj('hydrophone', 'Гидрофон', (0.06, 0.2, 0.06), 'медь',
    'obj:p0198-gidrofon', ['microphone'])
obj('rov-tether', 'Трос-кабель аппарата', (0.4, 0.15, 0.4), 'лён, медь',
    'obj:p0196-tros-kabel-rov', ['cable'])
obj('rov-log', 'Журнал наблюдений аппарата', (0.3, 0.05, 0.22),
    'бумага, кожа', 'obj:p0209-zhurnal-nablyudeniy-rov', ['logbook'])
obj('sealed-case', 'Герметичный футляр', (0.6, 0.6, 0.03), 'кожа, воск',
    'obj:obj-germetichny-futlyar', ['case'])
obj('marker-buoy', 'Буй-маркер находки', (0.3, 0.3, 0.3), 'пробка',
    'obj:p0202-buy-marker-nakhodki', ['buoy'])
obj('sample-basket', 'Корзина для образцов со дна', (0.45, 0.3, 0.35),
    'ивняк', 'obj:p0218-korzina-dlya-obraztsov-so-dna', ['basket'])
obj('battery', 'Ящик аккумуляторов экспедиции', (0.45, 0.3, 0.3),
    'металл', 'raw', ['battery'])
obj('field-tent', 'Палатка экспедиции', (2.2, 1.6, 2.2), 'брезент',
    'raw', ['tent'])
obj('server-rack', 'Серверная стойка', (0.6, 2.0, 0.9), 'металл, пластик',
    'raw', ['server'])
obj('screen', 'Экран-панель', (0.8, 0.5, 0.05), 'пластик, LED', 'raw',
    ['monitor', 'screen'])
obj('keyboard', 'Аналоговая клавиатура с тумблерами', (0.45, 0.06, 0.2),
    'латунь, дерево', 'raw', ['keyboard'])
obj('phone', 'Проводной телефон-автомат', (0.3, 0.5, 0.2), 'металл',
    'raw', ['telephone', 'phone'])
obj('antenna-mast', 'Мачта с антенной-решёткой', (0.6, 3.0, 0.6),
    'сталь', 'raw', ['antenna'])
obj('drone-wreck', 'Обломок сбитого дрона', (0.6, 0.2, 0.5),
    'шпон, леска', 'raw', ['drone'])
obj('exoskeleton', 'Старый экзоскелет Ильи', (0.8, 1.8, 0.5),
    'сталь, ясень', 'raw', ['exoskeleton', 'mech'])

# --- Scriptorium and books -------------------------------------------------
obj('wax-tablet', 'Восковая табличка', (0.6, 0.6, 0.03), 'дерево, воск',
    'obj:obj-voskovaya-tablichka', ['tablet'])
obj('scroll-niche', 'Ниша свитков', (0.6, 0.6, 0.03), 'дерево',
    'obj:obj-arkhiv-svitkov', ['scroll', 'scrolls'])
obj('chronicle', 'Раскрытая летопись', (0.6, 0.6, 0.03), 'пергамен',
    'obj:obj-letopis', ['book'])
obj('languages', 'Свиток языков', (0.6, 0.6, 0.03), 'пергамен',
    'obj:obj-svitok-yazykov', ['scroll'])
obj('print-block', 'Печатная доска', (0.6, 0.6, 0.03), 'груша',
    'obj:obj-pechatnaya-doska', ['woodblock'])
obj('binding-press', 'Переплётный пресс', (0.5, 0.6, 0.4), 'дуб',
    'obj:p0248-perepletnyy-press', ['press'])
obj('parchment', 'Выделанный пергамен', (0.8, 1.0, 0.02), 'кожа',
    'obj:p0249-vydelannyy-pergamen', ['parchment'])
obj('glossary', 'Кипчакский словарь', (0.25, 0.06, 0.18), 'бумага',
    'obj:p0234-kipchakskiy-slovar-glossariy', ['book'])
obj('letter', 'Письмо с вестями', (0.6, 0.6, 0.03), 'бумага',
    'obj:obj-pismo-vesti', ['letter'])
obj('birch-bark', 'Берестяная грамота', (0.6, 0.6, 0.03), 'береста',
    'obj:obj-gramota', ['letter'])
obj('portolan', 'Портулан', (0.6, 0.6, 0.03), 'пергамен',
    'obj:obj-portulan', ['map'])
obj('world-map', 'Карта мира странника', (0.6, 0.6, 0.03), 'пергамен',
    'obj:obj-karta-mira-palomnika', ['map'])
obj('mission-map', 'Карта сети обителей', (0.6, 0.6, 0.03), 'пергамен',
    'obj:obj-karta-seti-missiy', ['map'])
obj('order-report', 'Отчёт ордена', (0.6, 0.6, 0.03), 'бумага',
    'obj:obj-otchet-ordena', ['report'])
obj('apprentice-deed', 'Ученический договор', (0.3, 0.02, 0.2), 'бумага',
    'obj:p0266-remeslennyy-uchenicheskiy-dogovor', ['scroll'])
obj('crypt-case', 'Витрина крипты', (0.6, 0.6, 0.05), 'дуб, стекло',
    'obj:obj-vitrina-kripty', ['cabinet'])
obj('bulla', 'Свинцовая булла', (0.6, 0.6, 0.03), 'свинец',
    'obj:obj-bulla', ['seal'])
obj('lectern', 'Низкий дубовый аналой для книги', (0.6, 1.0, 0.45), 'дуб',
    'own', ['lectern'])
obj('ring-table', 'Таблица звонов по уставу', (0.3, 0.4, 0.02), 'дерево',
    'obj:p0157-kolokolnyy-ustav-tablitsa-zvonov', ['table'])

# --- Workshop --------------------------------------------------------------
obj('potter-wheel', 'Гончарный круг', (0.5, 0.8, 0.5), 'дерево, камень',
    'obj:p0237-goncharnyy-krug', [('potter', 'wheel'), 'pottery'])
obj('kiln', 'Печь для обжига', (1.2, 1.4, 1.2), 'глина, кирпич',
    'obj:p0238-pech-dlya-obzhiga', ['kiln'])
obj('potter-stamp', 'Клеймо мастера-гончара', (0.06, 0.1, 0.06),
    'обожжённая глина', 'obj:p0314-kleymo-mastera-gonchara', ['stamp'])
obj('anvil', 'Наковальня', (0.5, 0.45, 0.25), 'железо',
    'obj:p0243-nakovalnya', ['anvil'])
obj('forge', 'Кузнечный горн с мехами', (1.0, 0.9, 0.8), 'кирпич, кожа',
    'obj:p0242-kuznechnyy-gorn-s-mekhami', ['forge', 'bellows'])
obj('tongs', 'Кузнечные клещи', (0.08, 0.5, 0.04), 'железо', 'raw',
    ['tongs'])
obj('crucible', 'Тигель', (0.6, 0.6, 0.03), 'глина',
    'obj:obj-tigel', ['crucible'])
obj('jeweller-crucible', 'Ювелирный тигель', (0.1, 0.1, 0.1), 'глина',
    'obj:p0260-yuvelirnyy-tigel', ['crucible'])
obj('tools', 'Инструмент мастера', (0.6, 0.6, 0.03), 'железо, дуб',
    'obj:obj-instrumenty', ['tools', 'hammer'])
obj('adze', 'Плотницкое тесло', (0.07, 0.4, 0.07), 'железо, дерево',
    'obj:p0244-plotnitskiy-teslo', ['adze', 'axe'])
obj('loom', 'Ткацкий станок', (1.2, 1.4, 0.8), 'дерево',
    'obj:p0239-tkatskiy-stanok', ['loom'])
obj('spindle', 'Прялка-веретено', (0.05, 0.32, 0.05), 'дерево',
    'obj:p0262-pryalka-vereteno', ['spindle'])
obj('dye-vat', 'Красильный чан с мареной', (0.8, 0.7, 0.8), 'дерево',
    'obj:p0263-krasilnyy-chan-s-marenoy', ['vat', 'barrel'])
obj('cloth', 'Отрез ткани', (0.6, 0.6, 0.03), 'лён',
    'obj:obj-tkan-otrez', ['cloth', 'fabric'])
obj('brick-mould', 'Форма для кирпича', (0.6, 0.6, 0.03), 'дерево',
    'obj:obj-kirpich-forma', ['brick'])
obj('spruce-log', 'Бревно тянь-шаньской ели', (0.4, 0.4, 4.0), 'ель',
    'obj:p0245-brevno-tyan-shanskoy-eli', ['log', 'timber'])
obj('marking-cord', 'Разметочная верёвка 3-4-5', (0.6, 0.6, 0.03),
    'лён', 'obj:obj-verevka-kolya', ['rope'])
obj('stakes', 'Колышки разметки', (0.6, 0.6, 0.03), 'дерево',
    'obj:obj-kolyshki-razmetki', ['stake', 'stakes'])
obj('bridge-log', 'Бревно моста', (0.6, 0.6, 0.03), 'дерево',
    'obj:obj-brevno-mosta', ['log', 'plank'])
obj('pile', 'Свая причала', (0.6, 0.6, 0.03), 'дерево',
    'obj:obj-brevno-svaya', ['pile', 'post'])
obj('compass', 'Компас пути', (0.6, 0.6, 0.03), 'латунь',
    'obj:obj-kompas-puti', ['compass'])
obj('star-card', 'Звезда пути', (0.6, 0.6, 0.03), 'пергамен',
    'obj:obj-zvezda-puti', ['star'])
obj('bandage', 'Перевязочное полотно', (0.6, 0.6, 0.03), 'лён',
    'obj:obj-polotno-perevyazki', ['bandage'])
obj('signal-fire', 'Сигнальный костёр', (0.6, 0.6, 0.03), 'камень, дрова',
    'obj:obj-signalnyi-koster', ['beacon', 'bonfire'])
obj('torch', 'Факел дозора', (0.6, 0.6, 0.03), 'дерево, смола',
    'obj:obj-fakel-dozora', ['torch'])
obj('banner', 'Знамя дозора', (0.6, 0.6, 0.03), 'лён',
    'obj:obj-znamya-dozora', ['banner', 'flag'])
obj('horn', 'Рог глашатая', (0.6, 0.6, 0.03), 'рог',
    'obj:obj-rog-glashataya', ['horn'])
obj('dove', 'Почтовый голубь', (0.6, 0.6, 0.03), 'живая птица',
    'obj:obj-golub-mira', ['pigeon', 'dove'])
obj('vine', 'Виноградная лоза на шпалере', (0.6, 0.6, 0.04), 'лоза',
    'obj:obj-loza', ['vine', 'grapevine'])
obj('grapes', 'Гроздь винограда', (0.6, 0.6, 0.05), 'виноград',
    'obj:obj-grozd-vinograda', ['grapes'])
obj('prostration-mat', 'Коврик у стены', (0.6, 0.02, 0.8), 'шерсть',
    'obj:p0136-poklonnyy-kovrik', ['rug'])

# --- Lake and Atlas volumes (procedural, detailed) -------------------------
for _key, _ru in [
        ('ochag.shallows.0', 'Кольцо очага на дне'),
        ('khum.shallows.1', 'Хум наполовину в песке'),
        ('khum.shallows.0', 'Хум — большой глиняный сосуд'),
        ('svaya.shelf.2', 'Ряд свай затопленного посада'),
        ('kirpich.shallows.0', 'Жжёный кирпич'),
        ('zhernov.shallows.1', 'Расколотый жернов'),
        ('zhernov.shallows.0', 'Жернов на шельфе'),
        ('cherepki.shallows.1', 'Россыпь черепков у сваи'),
        ('fundament.shallows.0', 'Прямая линия фундамента'),
        ('fundament.shallows.1', 'Угол каменного фундамента'),
        ('glazur.shallows.1', 'Глазурованный кирпич в кладке'),
        ('balka.shallows.0', 'Деревянная балка'),
        ('kotel.shallows.0', 'Обломок бронзового котла'),
        ('yakor.shallows.0', 'Якорный камень'),
        ('gruzilo.shallows.0', 'Каменное грузило сети'),
        ('spring.shallows.0', 'Струйка подводного источника'),
        ('blacksilt.shallows.0', 'Пятно чёрного железистого ила'),
        ('silt.slope.0', 'Илистая равнина'),
        ('chironomid.shelf.0', 'Трубочки мотыля в иле'),
        ('slope-edge.slope.2', 'Кромка свала: темнота внизу'),
        ('terrace.slope.2', 'Старая береговая линия на склоне'),
        ('boulder.shallows.1', 'Гранитный валун в водорослях'),
        ('chara.shallows.0', 'Густой харовый луг'),
        ('chebachok.shallows.0', 'Стайка иссык-кульского чебачка'),
        ('marinka.shallows.4', 'Маринка в тени камня'),
        ('buoyline.shallows.0', 'Цепь буя станции'),
        ('bubbles.shelf.1', 'Пузырьковый столб в ритме дыхания'),
        ('thermo.slope.0', 'Мерцание термоклина'),
        ('intwave.slope.0', 'Внутренняя волна на слое'),
        ('upwelling.slope.0', 'Подъём глубинной воды у свала'),
        ('snow.shelf.0', 'Взвесь «морского снега»'),
        ('ghostnet.shelf.1', 'Брошенная сеть с рыбой'),
        ('plume.shallows.1', 'Мутный шлейф речной воды')]:
    obj(_key, _ru, (0.0, 0.0, 0.0), 'дно озера', 'lake:' + _key)
obj('atlas-diary', 'Дневник рыцаря в кожаном переплёте', (0.3, 0.05, 0.3),
    'кожа, пергамен', 'atlas:diary', ['book'])
# The key and the model keep the old name 'amphora' so the dive and
# its models still find it; the thing itself is a khum, the clay jar
# raised from Issyk-Kul (historian of the chorus, 2026-10-03).
obj('atlas-amphora', 'Хум со свитком о литье бронзы', (0.3, 0.6, 0.3),
    'керамика', 'atlas:amphora', ['jar', 'jug'])
obj('atlas-astrolabe', 'Астролябия рыцаря', (0.25, 0.25, 0.03),
    'латунь', 'atlas:astrolabe', ['astrolabe'])
obj('atlas-shield', 'Щит рыцаря', (0.9, 0.9, 0.1), 'дерево, железо',
    'atlas:shield', ['shield'])

# --- Holy things: never raw, never loot, never a key -----------------------
obj('icon', 'Образ в красном углу', (0.4, 0.4, 0.003), 'липа, левкас',
    'obj:obj-ikona', holy='flat')
obj('reliquary', 'Ковчежец апостола Матфея', (0.4, 0.4, 0.03), 'серебро',
    'obj:obj-kovchezhets-matfeya', holy='vessel')
obj('kairak', 'Надгробный камень с крестом', (0.4, 0.4, 0.035), 'камень',
    'obj:obj-kairak', holy='flat')
obj('ichthys-pile', 'Знак рыбы, процарапанный на свае', (0.4, 0.4, 0.03),
    'дерево', 'obj:obj-ikhtis-svaya', holy='flat')
obj('ichthys-stone', 'Камень со знаком рыбы', (0.4, 0.4, 0.02), 'камень',
    'obj:obj-kamen-ikhtis', holy='flat')
obj('worship-cross', 'Деревянный поклонный крест', (0.9, 2.5, 0.12),
    'дуб', 'own', holy='flat')
obj('blessing-cross', 'Крест водосвятия', (0.4, 0.4, 0.03), 'медь',
    'obj:obj-krest-vodosvyatny', holy='flat')
obj('bell', 'Колокол на звоннице', (0.4, 0.4, 0.012), 'бронза',
    'obj:obj-bell', holy='flat')
obj('chalice', 'Потир, сделанный для престола', (0.4, 0.4, 0.03),
    'серебро', 'obj:obj-potir', holy='vessel')
obj('khachkar', 'Кайрак — крест-камень братьев', (1.0, 1.6, 0.3),
    'туф', 'atlas:khachkar', holy='flat')

# How the hint at a heart names a mentor whose name carries a church
# title: the interface speaks in images, by the person's deed, and the
# title stays in the person's own speech (TABOO 0.39 item 3).
NPC_HINT_RU = {
    'maximos': 'Максим, что не подписал указ',
    'photius': 'Фотий-книжник у светильника',
    'macrina': 'Макрина с зерном на ладони',
}

# The new small actions, where no core of the game fits.  Each carries
# its Constitution line; its logic is still to be written and tested
# (docs/HLD_LOCATIONS_99_2026-09-30.md, phase L3).
NEW_ACTIONS = {
    'separate-contract': (
        'Вычеркнуть из договора строку о вере и подписать торговые',
        'ФОРМА (Мудрость) → ДЕЙСТВИЕ (отделить путь торговли от '
        'исповедания) → ЦЕЛЬ (путь можно продать, веру — нет)'),
    'lay-a-stone': (
        'Положить на курган один камень и не считать',
        'ФОРМА (Телосложение путника) → ДЕЙСТВИЕ (один камень памяти) → '
        'ЦЕЛЬ (память без счёта и без заслуги)'),
    'read-waterline': (
        'Прочитать старые метки воды и отметить надёжную землю',
        'ФОРМА (Мудрость, Эрудиция) → ДЕЙСТВИЕ (наблюдение по меткам) → '
        'ЦЕЛЬ (не строить там, куда вернётся вода)'),
    'carry-archive-up': (
        'Вынести наверх сначала то, что нельзя написать заново',
        'ФОРМА (Телосложение) → ДЕЙСТВИЕ (порядок выноса) → ЦЕЛЬ '
        '(исход решают порядок и любовь, а не очки)'),
    'test-ice': (
        'Проверить лёд посохом прежде шага',
        'ФОРМА (Мудрость) → ДЕЙСТВИЕ (промер посохом) → ЦЕЛЬ (быстрый '
        'путь не всегда путь)'),
    'share-water': (
        'Открыть заслонку по очереди: верхним и нижним поровну',
        'ФОРМА (Харизма, Мудрость) → ДЕЙСТВИЕ (делить воду мерой) → '
        'ЦЕЛЬ (суд течёт, как вода: Ам 5:24)'),
    'take-core': (
        'Взять один керн ила и подписать его',
        'ФОРМА (Эрудиция) → ДЕЙСТВИЕ (керн, подпись) → ЦЕЛЬ (память '
        'воды — это ил, а не волшебство)'),
    'wait-out-storm': (
        'Остаться у берега, пока держится течение',
        'ФОРМА (Стойкость) → ДЕЙСТВИЕ (не выходить в разрывное '
        'течение) → ЦЕЛЬ (молитва — не выключатель течений)'),
    'find-pole-star': (
        'Найти Полярную звезду и взять пеленг по астролябии',
        'ФОРМА (Мудрость) → ДЕЙСТВИЕ (навигация по звезде) → ЦЕЛЬ '
        '(путь, а не судьба: астрономия, а не астрология)'),
    'forge-nail': (
        'Выковать гвоздь вместо потерянной шайбы',
        'ФОРМА (Ловкость) → ДЕЙСТВИЕ (ковка по слову мастера) → ЦЕЛЬ '
        '(орала, а не мечи: Ис 2:4)'),
    'caulk-seam': (
        'Проконопатить шов лодки льном и смолой',
        'ФОРМА (Ловкость) → ДЕЙСТВИЕ (шов, сделанный честно) → ЦЕЛЬ '
        '(лодка держит воду, пока держит шов)'),
    'prune-vine': (
        'Отсечь сухую ветвь лозы',
        'ФОРМА (Мудрость) → ДЕЙСТВИЕ (обрезка) → ЦЕЛЬ (мера ради плода: '
        'Ин 15:2)'),
    'rope-right-angle': (
        'Выложить прямой угол верёвкой в двенадцать узлов',
        'ФОРМА (Эрудиция) → ДЕЙСТВИЕ (разметка 3-4-5) → ЦЕЛЬ (знание '
        'ремесла, не тайна; стены — защита, не угроза)'),
    'teach-a-letter': (
        'Вывести с ребёнком одну букву на воске',
        'ФОРМА (Харизма) → ДЕЙСТВИЕ (учить, ничего не прося взамен) → '
        'ЦЕЛЬ (вера не покупается хлебом)'),
    'proof-the-block': (
        'Найти ошибку на доске до первого оттиска',
        'ФОРМА (Эрудиция) → ДЕЙСТВИЕ (сверка доски) → ЦЕЛЬ (ошибка '
        'доски повторится в каждом листе)'),
    # Historian of the chorus (2026-10-03): prejudice «the knight tells
    # the cartographer» / counter: the knight never reached Majorca,
    # and the atlas itself writes "it is said" of the apostle's body /
    # why: a merchant or a missionary back from the East before 1375
    # tells what he saw, and the hearsay keeps its honest mark.
    'tell-only-true': (
        'Рассказать картографу виденное, слышанное — «говорят»',
        'ФОРМА (Эрудиция) → ДЕЙСТВИЕ (свидетельство без прикрас) → ЦЕЛЬ '
        '(на карте — то, что видели, и честная пометка «говорят»)'),
    'tell-custom-from-faith': (
        'Отделить обычай от веры: напев и одежду принять, веру не '
        'смешивать',
        'ФОРМА (Мудрость) → ДЕЙСТВИЕ (различение) → ЦЕЛЬ (мир общин без '
        'смешения вер)'),
    'seal-the-chronicle': (
        'Запечатать летопись воском и кожей',
        'ФОРМА (Эрудиция) → ДЕЙСТВИЕ (сберечь запись) → ЦЕЛЬ (память '
        'хранят, а не прячут от правды)'),
    'speak-of-maker': (
        'Говорить о Творце неба, не входя в обряд',
        'ФОРМА (Вера, Харизма) → ДЕЙСТВИЕ (беседа без участия в '
        'камлании) → ЦЕЛЬ (мир без смешения)'),
    'hear-both-sides': (
        'Выслушать обе стороны до конца, прежде чем записать',
        'ФОРМА (Мудрость) → ДЕЙСТВИЕ (суд без лицеприятия) → ЦЕЛЬ '
        '(правда общины решается внутри общины)'),
    'compare-forms': (
        'Сравнить обводы шлема мастера с обводами аппарата',
        'ФОРМА (ремесло) → ДЕЙСТВИЕ (сравнить формы) → ЦЕЛЬ (железо '
        'служит человеку)'),
    'walk-by-compass': (
        'Пройти лес по компасу и эху, без сети',
        'ФОРМА (Мудрость) → ДЕЙСТВИЕ (старая физика) → ЦЕЛЬ (никакого '
        'колдовства: компас, звёзды, эхо)'),
    'show-offline-key': (
        'Предъявить избе ключ, который не знает сети',
        'ФОРМА (Хитрость без меры отвергнута) → ДЕЙСТВИЕ (офлайн-ключ) '
        '→ ЦЕЛЬ (граница живого и машинного)'),
    'tell-bots-from-people': (
        'На вече различить живые голоса и одинаковые громкие',
        'ФОРМА (Мудрость) → ДЕЙСТВИЕ (слушать спектр голосов) → ЦЕЛЬ '
        '(захват вече слышен, если слушать)'),
    'type-by-memory': (
        'Ввести байт за байтом по памяти и назвать себя вслух',
        'ФОРМА (Стойкость) → ДЕЙСТВИЕ (свидетельство открыто) → ЦЕЛЬ '
        '(подвиг — не стереть себя, а стать видимым)'),
    'find-live-mast': (
        'Найти мачту, которая ещё передаёт',
        'ФОРМА (Мудрость) → ДЕЙСТВИЕ (прибор расследования) → ЦЕЛЬ '
        '(крест в стороне ничего не передаёт и не прибор)'),
    'spot-the-haze': (
        'Заметить марево над «пустой» избой',
        'ФОРМА (Мудрость) → ДЕЙСТВИЕ (улика по теплу) → ЦЕЛЬ '
        '(расследование, а не колдовство)'),
    'match-serials': (
        'Сопоставить серийные номера и царапины обломков',
        'ФОРМА (Эрудиция) → ДЕЙСТВИЕ (сверка находок без маркеров) → '
        'ЦЕЛЬ (журнал — свидетельство)'),
    'note-the-wind': (
        'Записать ветер и уровень воды в погодную тетрадь',
        'ФОРМА (Постоянство) → ДЕЙСТВИЕ (запись каждый день) → ЦЕЛЬ '
        '(цикл озера виден в долгих записях)'),
}

PLACES = []


def place(pid, title, kind, shell, size, plots, heart, light, objs,
          lesson, truth, teach, recs=(), sky='day', safety=10, note='',
          exists=''):
    """Add one candidate place of the pool."""
    PLACES.append({
        'id': pid, 'title_ru': title, 'kind': kind, 'shell': shell,
        'size_m': list(size), 'plots': list(plots), 'heart': heart,
        'light': list(light), 'objects': list(objs), 'lesson': lesson,
        'truth': truth, 'teach': teach, 'records': list(recs),
        'sky': sky, 'safety': safety, 'note': note, 'exists': exists})


# Light: (class, kelvin, source).  hearth 1900-2500 K is human work,
# instrument 6500 K is the ROV, the sonar, the network, the world of
# price; lampada 1800 K only where a holy thing stands (TABOO 0.38).
H = 'hearth'
INSTR = 'instrument'
LAMPADA = 'lampada'
ROV_LAMP = (INSTR, 6500, 'прожектор аппарата')

# === Prologue and Act I: the caravan road ================================
place('road-well', 'Колодец на привале', 'well', 'open', (12, 12, 0),
      ['M1', 'M3', 'M12'], 'talk:anahit/a_well',
      (H, 2100, 'костёр привала'),
      ['well-bucket', 'water-skin', 'camel-saddle', 'campfire',
       'caravan-staff'],
      'Дом изнашивается там, где касается чужих: у колодца путник '
      'учится зависеть от гостеприимства (Лествица, ст. 3).', 9, 8,
      recs=['loc-kolodets-na-puti', 'p0500-stepnoy-kolodets'], sky='dusk')
place('prologue-ford', 'Отмель у брода', 'ford', 'shore', (14, 10, 0),
      ['M1', 'M3'], 'find:yakor.shallows.0',
      (H, 2200, 'фонарь караванщика'),
      ['anchor-stone', 'caravan-lantern', 'oar', 'sinker-basket',
       'water-skin'],
      'Находку отдают писцу: вещь рассказывает, а не принадлежит.', 9, 7,
      sky='dusk')
place('obitel-caravanserai', 'Двор странноприимства у озера',
      'caravanserai', 'yard', (14, 14, 2.4),
      ['M1', 'M25', 'M26', 'M53', 'M54'], 'talk:anahit/a_first_night',
      (H, 2200, 'фонарь над воротами'),
      ['camel-saddle', 'caravan-bells', 'casket', 'tonir', 'water-jug',
       'felt'],
      'Первая ночь даром, соль и вода даром: доверие — плод служения, '
      'а не цель (Мф 25:35).', 9, 9,
      recs=['loc-karavansaray', 'loc-issyk-kul'], sky='dusk')
place('caravanserai-empty', 'Опустевший двор, откуда ушли караваны',
      'caravanserai', 'yard', (14, 14, 2.4), ['M94', 'P:sadness'],
      'talk:anahit/a_empty', (H, 2000, 'одна лучина у холодного тонира'),
      ['caravel', 'felt', 'tonir', 'caravan-lantern'],
      'Честная печаль метёт двор, а вторая садится у холодного тонира: '
      'признак — тоска по вчерашнему, ответ — дело сегодняшнее.', 9, 9,
      recs=['loc-karavan-saray-pustoy', 'p0581-razorennyy-karavan-saray'],
      sky='dusk')
place('tash-rabat', 'Каменный сарай в горной долине', 'rabat', 'room',
      (10, 10, 5), ['M12', 'M94'], 'talk:sargis/guesthouse',
      (H, 2100, 'очаг под куполом'),
      ['camel-saddle', 'firewood', 'cauldron-camp', 'felt',
       'caravan-lantern'],
      'Чужак у колодца — долг, который дорога даёт взаймы: каменный дом '
      'на перевале — для всех, кто дойдёт (Евр 13:2).', 8, 8,
      recs=['p0293-karavan-saray-tash-rabat', 'p0521-tashrabat'],
      note='Таш-Рабат обычно датируют XV в.; для 1375 г. — тип '
           'горного рабата, а не сама постройка (историку).')
place('barskoon-rabat', 'Караван-сарай у Барскоона', 'rabat', 'yard',
      (14, 12, 2.4), ['M6', 'M12'], 'talk:sargis/overload',
      (H, 2100, 'костёр у стойл'),
      ['camel-saddle', 'girth-strap', 'grain-sack', 'water-skin'],
      'Верблюд доносит лишний тюк до перевала и ложится: серебро лёгкое '
      'в уме и тяжёлое для колен.', 9, 7,
      recs=['p0473-karavan-saray-barskoon'], sky='dusk')
place('granary', 'Амбар обители в голодную зиму', 'granary', 'room',
      (8, 6, 3.2), ['M5', 'M75', 'P:avarice'], 'passion:avarice',
      (H, 2000, 'фонарь келаря'),
      ['grain-sack', 'grain-pit', 'tally-stick', 'weights', 'salt-sack'],
      'Зерно в голодный год — долг перед городом; скупость говорит о '
      'длинных зимах, признак — страх за завтрашний день.', 9, 9,
      recs=['loc-ambar-obiteli'])
place('storehouse', 'Склад, где не сходится столбец', 'storehouse',
      'room', (8, 6, 3.2), ['M11'], 'talk:vardan/v_mercy',
      (H, 1950, 'лучина кладовщика'),
      ['ledger', 'grain-sack', 'silk-bale', 'store-key', 'abacus'],
      'Честный учёт находит причину, милость — человека: послушник отдал '
      'зерно голодным и постыдился записать.', 9, 9,
      recs=['loc-sklad-obiteli', 'p0592-torgovyy-sklad-shelka'])
place('factory', 'Лавка-склад армянской фактории', 'trading-house',
      'room', (8, 6, 3.2), ['M2'], 'talk:melik/m_prayer_silver',
      (H, 2100, 'масляная лампа конторки'),
      ['ledger', 'inkwell', 'silk-bale', 'spice-sack', 'silver-ingot',
       'scales'],
      'Молитву не продают за десятую долю серебра: имение вверено, а не '
      'своё (свт. Иоанн Златоуст, Слова о Лазаре, 2).', 9, 9,
      recs=['loc-faktoriya', 'loc-gerat',
            'p0535-vkhod-v-dom-kuptsa-armyanina'])
place('court-yard', 'Двор, где рассуждают тяжбу о шёлке', 'court',
      'yard', (10, 10, 2.4), ['M3'], 'talk:vardan/v_crooked',
      (H, 2200, 'светильник у скамьи'),
      ['silk-bale', 'ledger', 'scales', 'receipt', 'measuring-ell',
       'bench'],
      'Счёт помягче для купца — счёт пожёстче для того, кто покупает '
      'хлеб: судят без лицеприятия.', 8, 8,
      recs=['loc-sudnyi-dvor-obiteli'], sky='day')
place('khan-camp', 'Ставка хана улуса', 'khan-camp', 'room', (8, 8, 4),
      ['M4', 'M46', 'A10'], 'talk:khan/k_yasa',
      (H, 2200, 'очаг юрты'),
      ['felt', 'kumys-skin', 'tamga', 'yarlyk', 'paiza', 'cauldron-camp'],
      'Слово у очага — тамга на сердце: мир держат словом, взвешенным '
      'прежде, чем сказано (Рим 12:18).', 10, 8,
      recs=['loc-khan-yurt', 'p0484-stavka-khana-v-urochishche-san-tash'])
place('winter-hut', 'Зимовье на перевале', 'winter-hut', 'room',
      (5, 5, 2.6), ['M6'], 'deed:alms', (H, 2000, 'печь-каменка'),
      ['firewood', 'grain-sack', 'felt', 'caravan-lantern', 'water-skin'],
      'Дрова и хлеб оставляют для того, кто придёт в буран: запас — для '
      'чужого.', 9, 8,
      recs=['loc-pereval-zima', 'p0501-zimove-pastukhov-v-karkyre'],
      sky='night')
place('tana-port', 'Причал генуэзцев в Тане', 'sea-port', 'shore',
      (16, 10, 0), ['M7'], 'new:separate-contract',
      (H, 2200, 'портовый фонарь'),
      ['trade-contract', 'silk-bale', 'barrel', 'scales', 'rope-coil'],
      'Торговый договор отделяют от веры: путь продают, исповедание — '
      'нет.', 9, 7, recs=['loc-port-tana'])
place('chu-ford', 'Брод на Чу у общего костра', 'ford', 'shore',
      (14, 10, 0), ['M8', 'M50'], 'deed:forgive',
      (H, 2100, 'общий костёр'),
      ['campfire', 'felt', 'cauldron-camp', 'water-skin', 'caravan-staff'],
      'Мирят у одного огня: обиду кладут, как тюк у колодца.', 9, 9,
      recs=['loc-brod-chu', 'loc-steppe'], sky='dusk')
place('poor-suburb', 'Бедное предместье Алмалыка', 'suburb', 'yard',
      (12, 10, 2.4), ['M9'], 'deed:secret_deed',
      (H, 1950, 'лучина в окне'),
      ['bread-loaf', 'cloth', 'grain-sack', 'water-jug', 'basket'],
      'Хлеб оставляют у двери так, чтобы левая рука не знала (Мф 6:3–4): '
      'тайное не считается.', 9, 10,
      recs=['loc-predmestye-almalyk'], sky='dusk')
place('sarai-hall', 'Приёмная ханской канцелярии в Сарае', 'chancery',
      'room', (10, 8, 4), ['M10'], 'talk:khan/k_price',
      (H, 2200, 'светильники приёмной'),
      ['yarlyk', 'paiza', 'duty-decree', 'inkwell', 'felt'],
      'Кто продаст свою молитву, продаст и хана: ярлык — ответственность '
      'перед бедными, а не право обогатиться.', 9, 8, recs=['loc-saray'])
place('merchants-hall', 'Длинный стол схода купцов', 'refectory', 'room',
      (10, 6, 3.4), ['M13', 'M61'], 'talk:abba_moses/silent_council',
      (H, 2200, 'светильники над столом'),
      ['bread-table', 'water-jug', 'weights', 'ledger', 'cauldron-common'],
      'Старец промолчал, когда его испытывали: мир за столом хранят, не '
      'становясь ничьей партией.', 9, 8,
      recs=['loc-trapeznaya', 'loc-trapeza'], exists='hub-refectory')
place('fair', 'Ярмарка за оградой', 'market', 'open', (14, 12, 0),
      ['M8', 'M14', 'M44', 'M56'], 'talk:melik/m_weights',
      (H, 2300, 'жаровня торговца'),
      ['awning', 'scales', 'weights', 'spice-sack', 'fruit-crate',
       'fish-basket'],
      'Фальшивая гиря выигрывает крошку в день и теряет рынок за год: '
      'неверные весы — мерзость пред Господом (Притч 11:1).', 9, 9,
      recs=['loc-agora', 'p0557-yarmarka-u-kochkorki',
            'p0303-bazar-v-balasagune', 'p0497-bazar-suyaba'])
place('caravaners-yard', 'Двор возчиков с общей кассой', 'guild-yard',
      'yard', (12, 10, 2.4), ['M15'], 'talk:sargis/open_hand',
      (H, 2200, 'фонарь у коновязи'),
      ['camel-saddle', 'girth-strap', 'casket', 'ledger', 'water-skin'],
      'Рука, что держит весы, должна уметь раскрыться: общая касса вдов '
      'и проводник для бедного паломника.', 8, 8,
      recs=['loc-dvor-karavanshchikov'])
place('money-changer', 'Меняльная лавка', 'money-changer', 'room',
      (5, 4, 2.8), ['M8', 'P:avarice'], 'talk:sargis/false_weights',
      (H, 2100, 'лампа менялы'),
      ['money-scales', 'touchstone', 'coin-purse', 'abacus',
       'silver-ingot'],
      'Все на дороге сбривают зерно с гири: глаз писца видит, какой '
      'камень легче.', 9, 7, recs=['p0594-menyalnaya-lavka'])
place('debt-pit', 'Долговая яма у базара', 'debt-pit', 'room',
      (5, 5, 3.0), ['M5', 'P:avarice'], 'deed:alms',
      (H, 1950, 'свет из решётки'),
      ['tally-stick', 'receipt', 'ransom-charter', 'coin-purse'],
      'Должника выкупают, а не ждут высокой цены: так и господин простил '
      'долг рабу (Мф 18:27).', 8, 9, recs=['p0593-dolgovaya-yama-kuptsa'])
place('customs-post', 'Застава на ущелье', 'customs', 'yard',
      (10, 8, 2.4), ['M65', 'P:anger'], 'talk:strazhnik/why_no_blade',
      (H, 2200, 'костёр заставы'),
      ['duty-decree', 'scales', 'torch', 'water-skin'],
      'Человек без клинка ночью — либо глупец, либо верит чужой тетиве: '
      'заставу проходят кротко и платят честно (Мф 22:21).', 9, 7,
      recs=['p0564-zastava-tamozhni', 'p0489-boomskoe-ushchele'],
      sky='night')
place('feast-bek', 'Пир у бека', 'feast-hall', 'room', (10, 8, 4),
      ['P:gluttony'], 'passion:gluttony', (H, 2300, 'светильники пира'),
      ['cauldron-common', 'bread-loaf', 'kumys-skin', 'felt', 'karas'],
      'Чревоугодие начинает с заботы о здоровье: признак распознают до '
      'второй чаши.', 8, 9, recs=['p0595-pir-u-beka'], sky='night')
place('bedel-pass', 'Узкий перевал Бедель', 'pass', 'open', (12, 10, 0),
      ['M12', 'P:acedia'], 'passion:acedia',
      (H, 2000, 'костёр в затишье'),
      ['camel-saddle', 'water-skin', 'caravan-staff', 'felt'],
      'Узок путь (Мф 7:14): уныние говорит, что день не кончится, '
      'признак — «смысла нет».', 9, 8, recs=['p0300-pereval-bedel'])
place('arabel-syrts', 'Сырты Арабеля', 'high-plateau', 'open',
      (14, 12, 0), ['M6'], 'deed:fast', (H, 2000, 'костёр кизяка'),
      ['camel-saddle', 'bread-loaf', 'felt', 'water-skin'],
      'На высокогорье хлеб делят поровну, а свой пост держат молча.', 9,
      7, recs=['p0474-syrty-arabel'])
place('north-shore', 'Северный берег, где высаживается караван',
      'shore', 'shore', (14, 10, 0), ['M1', 'A9'],
      'talk:rybak_issyk_kul/call', (H, 2200, 'костёр рыбаков'),
      ['boat-hull', 'net', 'drying-rack', 'camel-saddle', 'campfire'],
      'Сеть у рыбака не отняли, ему дали море шире: путь начинается с '
      'отречения (Лествица, ст. 1).', 9, 8,
      recs=['p0467-severnyy-bereg-u-cholpon-aty'], sky='dusk')
place('karakol-bay', 'Пристань купцов и послов в бухте', 'pier-old',
      'shore', (14, 10, 0), ['M36'], 'talk:melik/m_pier',
      (H, 2200, 'фонарь на свае'),
      ['boat', 'net', 'duty-decree', 'scales', 'fish-basket'],
      'Пошлина не больше, чем написано на доске: так Предтеча говорил '
      'мытарям (Лк 3:13).', 9, 8, recs=['p0480-bukhta-karakol'])
place('chon-kemin', 'Долина, где собирают травы', 'meadow', 'open',
      (12, 12, 0), ['M76'], 'talk:tabib/cosmas',
      (H, 2300, 'костёр сборщиков'),
      ['herbs', 'basket', 'mortar', 'water-skin'],
      'Косма и Дамиан не брали монеты с больных: траву собирают для '
      'всех.', 8, 7, recs=['p0508-dolina-chon-kemin'])

# === Act II: signs in clay and stone =====================================
place('ichthys-pier', 'Причал со знаком рыбы на сваях', 'pier-old',
      'shore', (12, 10, 0), ['M16'], 'talk:rybak_issyk_kul/ichthys',
      (H, 2200, 'фонарь на свае'),
      ['ichthys-pile', 'net', 'boat', 'water-jug', 'float'],
      'Пять букв — исповедание, а не оберег: знак читают, не трогая, а '
      'узлы проверяют сами.', 8, 9, recs=['loc-issyk-kul'], sky='dawn',
      safety=9)
place('kairak-valley', 'Надгробный камень в Чуйской долине', 'cemetery',
      'open', (12, 10, 0), ['M17', 'M39'], 'talk:tabib/theotokos',
      (H, 2000, 'фонарь лекаря'),
      ['kairak', 'herbs', 'water-jug', 'felt'],
      'Умершего почитают и надпись читают вслух; исповедание о '
      'Богородице свидетельствуют без вражды.', 10, 9,
      recs=['loc-chuiskaya-dolina-kairaki',
            'p0483-kladbishche-s-siriyskimi-nadgrobiyami',
            'p0531-mogily-1338-goda'], sky='dusk', safety=9,
      note='Сирийские надгробия Чуйской долины XIII–XIV вв. и записи о '
           'море 1338–1339 гг. — реальные; сверить надпись для кадра.')
place('naos', 'Под сводом, где хранят ковчежец', 'church-naos', 'room',
      (10, 12, 6), ['M18', 'M19', 'M20', 'M21', 'M60', 'M89'],
      'rule:prostrations', (LAMPADA, 1800, 'лампада у образа'),
      ['icon', 'prostration-mat'],
      'У святыни интерфейс уходит: поклон виден по стёртому месту, а '
      'счёт — только самому брату.', 9, 8, recs=['loc-hram-naos'],
      sky='indoor', safety=8,
      note='Четыре из шести миссий здесь на переписке хора (реликвии, '
           'обращение); место держится на М21 и М60.')
place('island-prison', 'Островная крепость, где держат пленных',
      'prison', 'yard', (12, 10, 3.0), ['M24', 'M51', 'A62'],
      'talk:abba_moses/robber_road', (H, 1950, 'факел у решётки'),
      ['shackles', 'bread-loaf', 'water-jug', 'ransom-charter'],
      'Бывший разбойник учит милости к узникам: хлеб и воду приносят, не '
      'превращая обитель в тюрьму (Мф 25:36).', 7, 9,
      recs=['loc-ostrov-krepost', 'loc-zamok-ostrov'], sky='dusk',
      note='Островная тюрьма Тимура на Иссык-Куле — предание, не факт.')
place('deacon-cell', 'Келья, где пишут правду о братии', 'cell', 'room',
      (4, 4, 2.8), ['M22', 'M58'], 'talk:vardan/v_legend',
      (H, 1900, 'глиняная лампа'),
      ['wax-tablet', 'inkwell', 'chronicle', 'felt'],
      'Плащ, отданный в мороз, записывают с пометкой «предание», а '
      '«заплакавшую икону» не выдумывают.', 8, 9, recs=['loc-kelia'],
      sky='indoor', exists='hub-cell')
place('santash-pass', 'Перевал Санташ, где кладут камень', 'pass',
      'open', (12, 12, 0), ['M23'], 'new:lay-a-stone',
      (H, 2100, 'костёр путников'),
      ['worship-cross', 'stone-pile', 'caravan-staff', 'water-skin'],
      'Камень кладут один и не считают; крест на перевале — место '
      'молитвы, а не знамя.', 9, 8,
      recs=['loc-pereval-santash', 'loc-nebo-stepi',
            'p0485-kurgan-san-tash-schet-kamney'], safety=9,
      note='Предание о кургане Сан-Таш (камни воинов) — легенда; '
           'крест на перевале — рисунок свой, из сырья не берётся.')
place('gate-night', 'Сторожка у ворот в бурную ночь', 'gate', 'yard',
      (10, 8, 2.4), ['M25', 'M63', 'T:foundational'],
      'trial:foundational', (H, 2100, 'фонарь сторожки'),
      ['stone-pile', 'spade', 'caravan-lantern', 'water-jug'],
      'Кто роет до скалы, строит низко и медленно: основание — слышать и '
      'делать слово (Мф 7:24–27).', 8, 10,
      recs=['loc-vorota-obiteli-noch'], sky='night')
place('gate-crowd', 'Ворота перед толпой', 'gate', 'yard', (10, 8, 2.4),
      ['M98', 'P:anger'], 'passion:anger', (H, 2300, 'факелы у ворот'),
      ['torch', 'water-jug', 'bench'],
      'Гнев говорит: ответь сейчас, пока огонь горяч; дьякон не поднимает '
      'оружия и стоит за правду и мир.', 8, 9, recs=['loc-vorota-obiteli'],
      sky='dusk')
place('feast-yard', 'Двор в праздник, где учат общий голос', 'feast-yard',
      'yard', (12, 12, 2.4), ['M27', 'T:liturgical'], 'trial:liturgical',
      (H, 2200, 'светильники двора'),
      ['bench', 'bread-table', 'grapes', 'water-jug'],
      'Нижние держат одну ноту, напев идёт над ними: кто поёт громче '
      'всех, тот поёт один.', 8, 10,
      recs=['loc-dvor-obiteli-prazdnik', 'p0590-khor-na-skale-a-cappella'],
      sky='dusk')
place('sunken-chapel', 'Затопленная часовня на террасе', 'sunken-chapel',
      'underwater', (14, 14, 8), ['M28', 'A5', 'A15'], 'dive:hover',
      ROV_LAMP,
      ['ichthys-stone', 'fundament.shallows.1', 'glazur.shallows.1',
       'cherepki.shallows.1', 'chara.shallows.0'],
      'Зависнуть у стены и ничего не взять: пульт гаснет у святыни сам '
      '(узел 5).', 8, 9, recs=['loc-zatoplennaya-chasovnya'],
      sky='underwater', safety=9)
place('bishop-stone', 'Камень епископа Иоанна на берегу', 'grave-shore',
      'shore', (12, 10, 0), ['M29'], 'talk:macrina/seed',
      (H, 1900, 'свеча в фонаре'), ['kairak', 'hand-candle', 'felt'],
      'Одна печаль плачет над могилой, другая — над бороздой: зерно '
      'уходит в землю и выходит колосом.', 7, 9, recs=['loc-kamen-ioanna'],
      sky='dusk', safety=9,
      note='Епископ Иоанн — фигура кампании; реальность проверить.')
place('obitel-shore', 'Берег под обителью', 'shore', 'shore',
      (16, 10, 0), ['M30', 'M87', 'M99'], 'talk:abba_moses/cell_teaches',
      (H, 2100, 'костёр на берегу'),
      ['boat', 'net', 'oar', 'reed-bed', 'campfire'],
      'Келья научит всему: святых далёких земель почитают, не переселяя '
      'их чудеса в свой пейзаж.', 9, 8, recs=['loc-issyk-kul'],
      sky='dusk')
place('baptism-ford', 'Брод, куда входят оглашенные', 'ford-witness',
      'shore', (12, 10, 0), ['M43', 'W:baptism'], 'witness:baptism',
      (H, 2100, 'свечи в руках'),
      ['blessing-cross', 'cloth', 'water-jug'],
      'Игрок стоит у черты: вода освящается Богом, а не игрой (ТАБУ '
      '№0.26 п. 10).', 8, 8,
      recs=['p0542-krestilnyy-brod', 'p0476-ushchele-barskoon-s-vodopadom'],
      sky='dawn', safety=7, exists='witness')
place('belfry', 'Звонница у скита', 'belfry', 'yard', (8, 8, 3.0),
      ['A91'], 'typikon:hear', (H, 2000, 'фонарь звонаря'),
      ['bell', 'ring-table', 'rope-coil'],
      'Звон идёт по уставу и часам: благовест зовёт, перебор скорбит; '
      'звонарь слушает, а не нажимает.', 8, 7,
      recs=['p0524-kolokolnya-zvonnitsa-u-skita'], sky='dusk', safety=8,
      note='Колокол — только по kolokol и Типикону; игрок не звонит.')
place('rock-island', 'Остров-скала посреди залива', 'rock-island',
      'open', (8, 8, 0), ['A18', 'K70'], 'rule:vigil',
      (H, 1900, 'лучина в каменной нише'),
      ['felt', 'water-jug', 'hourglass', 'boat'],
      'Кто уходит из сети, тот слышит (узел 18): ночное бдение не '
      'считается заслугой.', 7, 8,
      recs=['p0492-ostrov-skala-posredi-zaliva'], sky='night')

# === Act III: the rising water ============================================
place('terrace-regression', 'Обнажившаяся терраса', 'terrace-shore',
      'shore', (14, 10, 0), ['M31', 'A29'], 'new:read-waterline',
      (H, 2200, 'костёр разметчиков'),
      ['water-gauge', 'stakes', 'marking-cord', 'level-mark', 'spade'],
      'Надёжную землю отличают по старым меткам воды: наблюдение, а не '
      'догадка.', 9, 8, recs=['loc-terrasa-regressiya'])
place('flooded-lower', 'Нижняя обитель, куда пришла вода',
      'flood-obitel', 'yard', (12, 12, 2.4), ['M32', 'M35', 'M90'],
      'new:carry-archive-up', (H, 2000, 'фонари в руках'),
      ['archive-chest', 'sealed-case', 'levels-chronicle', 'grain-sack',
       'water-gauge'],
      'Исход решают порядок и любовь: сначала несут то, что нельзя '
      'написать заново.', 9, 9, recs=['loc-zatoplenie-obiteli'],
      sky='dusk')
place('upper-terrace', 'Верхняя терраса, куда переносят кельи',
      'upper-terrace', 'open', (14, 12, 0), ['M35', 'M90'],
      'deed:obedience', (H, 2200, 'костёр стройки'),
      ['spruce-log', 'adze', 'marking-cord', 'brick-mould', 'stakes'],
      'Переносят по слову старших, не споря: ход идёт вверх медленно.', 9,
      8, recs=['loc-verhnyaya-terrasa', 'loc-verkhnyaya-terrasa'])
place('drowned-posad', 'Затопленный посад: улицы и очаги',
      'sunken-settlement', 'underwater', (16, 16, 8),
      ['M34', 'M40', 'A13', 'A52', 'D:finds'], 'dive:finds', ROV_LAMP,
      ['ochag.shallows.0', 'khum.shallows.1', 'svaya.shelf.2',
       'kirpich.shallows.0', 'zhernov.shallows.1'],
      'Находки идут писцу по одной: посад открывается как книга, а не '
      'как клад.', 10, 9,
      recs=['loc-gorod-na-dne', 'p0478-zatoplennoe-poselenie-sary-bulun',
            'loc-issyk-kul-underwater'], sky='underwater', exists='dive')
place('brothers-walls', 'Стены обители братьев на дне',
      'sunken-monastery', 'underwater', (16, 16, 8),
      ['M96', 'M99', 'A19', 'A76'], 'find:fundament.shallows.1', ROV_LAMP,
      ['fundament.shallows.1', 'glazur.shallows.1', 'balka.shallows.0',
       'kirpich.shallows.0', 'chara.shallows.0'],
      'Правильный угол стены выдаёт руку человека среди камней: так '
      'отличают фундамент от скалы (узел 19).', 7, 9,
      recs=['p0469-zatoplennyy-armyanskiy-monastyr-koysary',
            'p0298-zatoplennye-ruiny-u-koysary'], sky='underwater',
      note='Место обители Каталанского атласа неизвестно; Койсары — '
           'гипотеза, её так и называть.')
place('chigu', 'Городище под водой у восточного берега', 'sunken-city',
      'underwater', (16, 16, 8), ['M40', 'A19'],
      'find:fundament.shallows.0', ROV_LAMP,
      ['fundament.shallows.0', 'kotel.shallows.0', 'cherepki.shallows.1',
       'boulder.shallows.1'],
      'Прямая линия под илом — след стены: находку сверяют с записью, '
      'а не с молвой.', 6, 7, recs=['p0479-gorodishche-chigu-podvodnoe'],
      sky='underwater',
      note='Чигу (столица усуней) на дне — гипотеза исследователей.')
place('ice-bay', 'Лёд мелкого залива', 'ice', 'open', (14, 10, 0),
      ['M37'], 'new:test-ice', (H, 2100, 'фонарь каравана'),
      ['probe-staff', 'camel-saddle', 'rope-coil', 'sounding-lead'],
      'Лёд проверяют посохом прежде шага: быстрый путь не всегда путь.',
      9, 9, recs=['loc-led-zaliva', 'p0578-zimniy-led-u-rybachego'],
      note='Иссык-Куль не замерзает; лёд бывает в мелких заливах — так '
           'и показывать.')
place('dam', 'Запруда на стоке', 'dam', 'shore', (12, 10, 0), ['M38'],
      'new:share-water', (H, 2200, 'костёр у запруды'),
      ['sluice', 'measuring-rod', 'spade', 'water-gauge'],
      'Воду делят по очереди: богатый город не спасают за счёт низовых '
      'сёл.', 8, 9, recs=['loc-plotina', 'p0600-irrigatsionnyy-aryk'])
place('crypt-museum', 'Крипта, где хранят находки разных вер', 'crypt',
      'room', (8, 6, 3.0), ['M39'], 'find:bulla.shallows.0',
      (H, 1950, 'фонарь хранителя'),
      ['crypt-case', 'bulla', 'sealed-case', 'ledger'],
      'Чужие святыни хранят бережно и не выставляют как трофей.', 8, 8,
      recs=['loc-kripta-muzei'], sky='indoor')
place('washed-road', 'Размытая горная дорога', 'washed-road', 'open',
      (12, 10, 0), ['M41'], 'talk:sargis/overload',
      (H, 2100, 'костёр застрявшего каравана'),
      ['camel-saddle', 'grain-sack', 'rope-coil', 'stone-pile'],
      'Застрявший караван учит мере груза: лишний тюк ложится на колени '
      'верблюда.', 9, 7,
      recs=['loc-razmytaya-doroga', 'p0516-razliv-vesenniy-zatoplennaya-'
            'tropa'])
place('mountain-bridge', 'Мост через горную речку', 'bridge', 'open',
      (12, 8, 0), ['M41', 'M73'], 'rule:handiwork',
      (H, 2200, 'костёр артели'),
      ['bridge-log', 'adze', 'rope-coil', 'stakes'],
      'Мост ставят для чужих паломников: руки заняты, язык молчит (Лк '
      '10).', 9, 8,
      recs=['loc-gornaya-reka-most', 'p0520-most-cherez-naryn'])
place('terrace-gardens', 'Сады на низких террасах', 'orchard', 'open',
      (14, 12, 0), ['M42', 'A29'], 'rule:thanksgiving',
      (H, 2300, 'костёр сборщиков'),
      ['vine', 'grapes', 'basket', 'spade'],
      'Сажают, зная, что вода придёт: урожай — дар, а не собственность.',
      8, 8, recs=['loc-terrasy-sady'])
place('weather-post', 'Погодная точка на мысу', 'weather-post', 'open',
      (8, 8, 0), ['M33'], 'new:note-the-wind', (H, 2100, 'фонарь поста'),
      ['water-gauge', 'levels-chronicle', 'measuring-rod', 'bench'],
      'Цикл озера виден только в долгих записях: записывают каждый день.',
      8, 7,
      recs=['p0602-meteotochka-na-myse',
            'p0601-burovaya-tochka-zamerov-glubiny'])
place('sub-spring', 'Выход подводного источника', 'underwater-spring',
      'underwater', (12, 12, 8), ['A42', 'M45'], 'find:spring.shallows.0',
      ROV_LAMP,
      ['spring.shallows.0', 'blacksilt.shallows.0', 'marinka.shallows.4',
       'boulder.shallows.1'],
      'Источник находят по холоду воды: муть у линзы — от ключа, а не от '
      'проклятия (узел 42).', 9, 8, recs=['p0548-podvodnyy-istochnik'],
      sky='underwater')
place('silt-core', 'Слой ила — архив времени', 'silt-floor',
      'underwater', (12, 12, 8), ['A13', 'M45'], 'new:take-core',
      ROV_LAMP,
      ['silt.slope.0', 'chironomid.shelf.0', 'water-sampler',
       'sample-basket'],
      'Память воды — это ил: один керн, подписанный рукой (узел 13).',
      10, 9, recs=['p0547-sloy-ila-70-m-arkhiv-vremeni'],
      sky='underwater')
place('sunken-barque', 'Затонувший караванный барк', 'sunken-boat',
      'underwater', (14, 14, 8), ['A28', 'A40', 'A82', 'M78'],
      'trace:astrolabe', ROV_LAMP,
      ['atlas-astrolabe', 'balka.shallows.0', 'khum.shallows.0',
       'kotel.shallows.0'],
      'Вещь лежит там, куда её сдвинула ошибка на полградуса: ошибка '
      'прощается, знание остаётся.', 7, 9,
      recs=['p0549-zatonuvshiy-karavan-bark'], sky='underwater',
      exists='dive-trace')
place('sunken-pier', 'Затопленная пристань XIV века', 'sunken-pier',
      'underwater', (14, 14, 8), ['M16', 'M40'], 'find:yakor.shallows.0',
      ROV_LAMP,
      ['yakor.shallows.0', 'svaya.shelf.2', 'gruzilo.shallows.0',
       'cherepki.shallows.1'],
      'Якорный камень лежит у свай: вещь, а не символ; её отмечают для '
      'писца (Евр 6:19 — образ, а не находка).', 9, 7,
      recs=['p0505-zatoplennaya-pristan-xiv-v'], sky='underwater')
place('canyon', 'Подводный каньон реки', 'underwater-canyon',
      'underwater', (12, 16, 10), ['A2', 'A81', 'D:tether'],
      'dive:tether', ROV_LAMP,
      ['boulder.shallows.1', 'slope-edge.slope.2', 'plume.shallows.1'],
      'Трос распутывают тем же путём, каким закрутили (узел 2).', 7, 9,
      recs=['p0504-podvodnyy-kanon-reki-dzhergalan'], sky='underwater')
place('slope-niche', 'Ниша в скале на свале', 'underwater-cave',
      'underwater', (12, 14, 8), ['A26', 'A27'], 'atlas:chronicle',
      ROV_LAMP,
      ['slope-edge.slope.2', 'boulder.shallows.1', 'terrace.slope.2'],
      'Проход цел или лежит завалом — по записи летописи: след выбора '
      'виден, милость не награждается.', 7, 9,
      recs=['p0544-podvodnyy-vkhod-v-peshcheru-u-korumdu'],
      sky='underwater', exists='dive-trace')
place('rip-current', 'Разрывное течение на свале', 'current',
      'underwater', (12, 16, 10), ['A48', 'A69', 'D:slope'], 'dive:slope',
      ROV_LAMP,
      ['slope-edge.slope.2', 'upwelling.slope.0', 'silt.slope.0'],
      'Спускаются по тросу против течения и не лезут в разрыв (узел 48).',
      8, 8, recs=['p0550-zona-techeniya-golfstrim-ozera'],
      sky='underwater', exists='dive')
place('chara-meadow', 'Харовый луг, где держится стайка', 'underwater-meadow',
      'underwater', (14, 14, 6), ['A41', 'A84'],
      'find:chebachok.shallows.0', ROV_LAMP,
      ['chara.shallows.0', 'chebachok.shallows.0', 'marinka.shallows.4',
       'boulder.shallows.1'],
      'Стайку эндемика отмечают, а не ловят: рыбу отпускают (узел 41).',
      10, 7, recs=['p0503-podvodnye-sady-kharovykh-vodorosley'],
      sky='underwater')
place('millstone-shelf', 'Жернов на шельфе — неподвижная точка',
      'underwater-shelf', 'underwater', (14, 14, 8),
      ['A22', 'A23', 'A36', 'D:heading'], 'dive:heading', ROV_LAMP,
      ['zhernov.shallows.0', 'kotel.shallows.0', 'boulder.shallows.1'],
      'Сталь на дне сбивает компас: калибруют по жернову, а не по кресту '
      '(узел 23).', 9, 9, sky='underwater', exists='dive')
place('thermocline', 'Слой скачка на пятидесяти метрах', 'thermocline',
      'underwater', (14, 14, 10), ['A6', 'A90', 'D:thermocline'],
      'dive:thermocline', ROV_LAMP,
      ['thermo.slope.0', 'intwave.slope.0', 'snow.shelf.0'],
      'Термоклин один, на 50 м: машинный шум стихает, звук меняется '
      '(узел 90).', 10, 8, recs=['p0470-termoklin-na-40-m'],
      sky='underwater', exists='dive',
      note='В промте термоклин на 40 м; по ТАБУ №0.03 п. 6 — 50 м.')
place('deep-shield', 'Самая глубокая точка: щит в свете лампы',
      'deep-floor', 'underwater', (12, 12, 8),
      ['A92', 'A83', 'A41', 'D:silence'], 'trace:shield', ROV_LAMP,
      ['atlas-shield', 'silt.slope.0', 'snow.shelf.0'],
      'Касание вещи, а не вызов мёртвого: дойти до глубины и вернуться '
      'медленно.', 8, 10,
      recs=['p0471-glubokovodnaya-vpadina-668-m'], sky='underwater',
      exists='dive-trace')
place('ledge-70', 'Уступ на семидесяти метрах', 'underwater-ledge',
      'underwater', (12, 12, 8), ['A5', 'A15', 'A86'], 'dive:hover',
      ROV_LAMP, ['khachkar', 'slope-edge.slope.2', 'snow.shelf.0'],
      'Протокол отвечает «тип не определён», пульт гаснет: святое — не '
      'ключ и не находка.', 8, 9, sky='underwater', safety=9,
      exists='dive-trace')
place('ascent-line', 'Буйреп медленного всплытия', 'ascent-line',
      'underwater', (8, 8, 14), ['A89', 'D:slowrise'], 'dive:slowrise',
      ROV_LAMP, ['buoyline.shallows.0', 'bubbles.shelf.1', 'rov-tether'],
      'Всплывают не быстрее 10 м/мин: возвращение к людям медленно '
      '(узел 89).', 10, 8, sky='underwater', exists='dive')
place('diary-shelf', 'Шельф, где лежит дневник', 'underwater-shelf',
      'underwater', (14, 14, 8), ['A4', 'A77', 'A96', 'M86'],
      'trace:diary', ROV_LAMP,
      ['atlas-diary', 'svaya.shelf.2', 'chironomid.shelf.0'],
      'Дневник поднимают и отдают писцу: сканер читает буквы, а смысл — '
      'человек.', 8, 10, sky='underwater', exists='dive-trace')
place('amphora-slope', 'Склон с хумом о литье', 'underwater-slope',
      'underwater', (12, 12, 8), ['A14'], 'trace:amphora', ROV_LAMP,
      ['atlas-amphora', 'terrace.slope.2', 'cherepki.shallows.1'],
      'Свиток о литье бронзы и о голосе била идёт звонарю: мастера '
      'знали, как звенит металл.', 8, 8, sky='underwater',
      exists='dive-trace',
      note='Хум, а не амфора: амфора — тара Средиземноморья. Свиток — '
           'вымысел серии (узел 14).')
place('hot-spring', 'Горячий ключ, где омывают больных', 'hot-spring',
      'open', (10, 10, 0), ['M76'], 'talk:tabib/wound_wash',
      (H, 2100, 'костёр у ключа'),
      ['spring-flask', 'bandage', 'water-jug', 'felt'],
      'Рану промывают, прежде чем перевязать: омывает живой человек.', 9,
      8, recs=['p0491-goryachie-istochniki-altyn-arashan',
               'p0299-goryachie-istochniki-dzhety-oguz'])
place('red-rocks', 'Красные скалы у долины', 'red-rocks', 'open',
      (12, 12, 0), ['P:anger'], 'passion:anger',
      (H, 2300, 'костёр под скалой'), ['felt', 'water-skin', 'campfire'],
      'Гнев просит ответить сейчас; красный камень остывает к ночи.', 10,
      7, recs=['p0475-dolina-dzhety-oguz',
               'p0543-smotrovaya-skala-sem-bykov-izdali'])
place('storm-bay', 'Штормовой залив', 'storm-bay', 'shore', (14, 10, 0),
      ['A48'], 'new:wait-out-storm', (H, 2000, 'фонарь под навесом'),
      ['boat-hull', 'oar', 'rope-coil', 'anchor-stone'],
      'В шторм ждут на берегу: молитва — не выключатель течений (узел '
      '48).', 9, 9, recs=['p0532-shtormovoy-zaliv',
                          'p0603-shtil-posle-buri'], sky='dusk')
place('star-shore', 'Ночной берег: путь по звёздам', 'night-shore',
      'shore', (14, 10, 0), ['M78', 'A40', 'A57'], 'new:find-pole-star',
      (H, 1900, 'угли костра'),
      ['atlas-astrolabe', 'compass', 'star-card', 'route-map'],
      'По звезде находят путь, а не судьбу: навигация — не астрология.',
      9, 9, recs=['loc-bereg-noch', 'p0584-nochnaya-step-pod-zvezdami',
                  'p0571-syrtovaya-observatoriya-pastukha'], sky='night')
place('mirror-pool', 'Зеркальная заводь', 'still-pool', 'shore',
      (10, 8, 0), ['P:vainglory'], 'passion:vainglory',
      (H, 2200, 'закатный костёр'), ['reed-bed', 'water-jug', 'boat'],
      'Тщеславие просит смотреться в воду и рассказывать о себе: '
      'признак — чужой взгляд дороже дела.', 8, 8,
      recs=['p0598-zerkalnaya-zavod'], sky='dusk')
place('dry-bed', 'Сухое русло в засуху', 'dry-bed', 'open', (12, 10, 0),
      ['P:sadness'], 'passion:sadness', (H, 2300, 'костёр путника'),
      ['water-skin', 'stone-pile', 'caravan-staff'],
      'Печаль говорит, что всё хорошее ушло; воду ищут, а не оплакивают '
      '(Пс 62).', 8, 7, recs=['p0599-sukhoe-ruslo-zasukha'])
place('spawning-creek', 'Нерестовая речка', 'creek', 'shore', (10, 8, 0),
      ['P:gluttony'], 'passion:gluttony', (H, 2200, 'костёр рыбака'),
      ['net', 'fish-basket', 'reed-bed'],
      'В нерест не ловят (Втор 22:6): чревоугодие говорит «только раз».',
      9, 8, recs=['p0605-nerestovaya-rechka'])
place('fishers-camp', 'Ночной костёр рыбаков', 'fishers-camp', 'shore',
      (12, 10, 0), ['M88', 'A33'], 'talk:rybak_issyk_kul/mending',
      (H, 2100, 'костёр'),
      ['net', 'drying-rack', 'boat-hull', 'campfire', 'float'],
      'Починка раньше улова: предание отличают от погони за сокровищем, '
      'пока чинят сеть.', 9, 8,
      recs=['p0486-rybatskiy-stan-v-ananevo',
            'p0302-rybatskoe-stoybishche-na-yuzhnom-beregu',
            'p0576-khizhina-starogo-rybaka'], sky='night')

# === Act IV: khans and envoys =============================================
place('chancery', 'Канцелярия наместника: сверка грамоты', 'chancery',
      'room', (8, 6, 3.2), ['M47'], 'talk:vardan/v_receipt',
      (H, 2100, 'лампа писца'),
      ['yarlyk', 'inkwell', 'ledger', 'paiza', 'receipt'],
      'Пергамент помнит нож: выскобленную дату видно под свежими '
      'чернилами.', 9, 8, recs=['loc-kantselyariya'])
place('divan-darugi', 'Диван даругачи', 'divan', 'room', (10, 8, 4),
      ['M48'], 'talk:khan/k_flatter', (H, 2200, 'светильники дивана'),
      ['felt', 'tamga', 'ledger', 'water-jug'],
      'Мёд на языке, а язык голоден: дело общины излагают прямо, как '
      'тетива.', 9, 7,
      recs=['loc-divan-darugi', 'p0301-stavka-darugi-u-chu'])
place('divan-governor', 'Диван наместника в Алмалыке', 'divan', 'room',
      (10, 8, 4), ['M65'], 'talk:melik/m_yarlyk',
      (H, 2200, 'светильники дивана'),
      ['yarlyk', 'duty-decree', 'ledger', 'felt'],
      'Печать помнит то, что забывает рука: подать берут через старост, '
      'а не через откупщиков.', 9, 7,
      recs=['loc-divan-namestnika', 'p0513-dvorets-namestnika-v-almalyke'])
place('porch-court', 'Притвор, где судят единоверцев', 'court', 'room',
      (8, 6, 3.4), ['M49'], 'new:hear-both-sides',
      (H, 2000, 'светильник притвора'),
      ['bench', 'ledger', 'receipt', 'inkwell'],
      'Выслушать обе стороны до конца, прежде чем записать: суд без '
      'лицеприятия.', 8, 8, recs=['loc-pritvor-sud', 'p0554-sud-biya'],
      sky='indoor')
place('sacristy', 'Ризница с протоколом', 'sacristy', 'room', (6, 5, 3),
      ['M52'], 'rule:stillness', (LAMPADA, 1800, 'лампада у ковчежца'),
      ['reliquary', 'ledger'],
      'Святыню не взвешивают протоколом выгод.', 9, 5,
      recs=['loc-riznitsa'], sky='indoor', safety=8,
      note='Миссия 52 на переписке хора (реликвия как предмет торга).')
place('kam-yurt', 'Юрта кама под небом степи', 'yurt-kam', 'room',
      (6, 6, 3.2), ['M55'], 'new:speak-of-maker', (H, 2100, 'очаг юрты'),
      ['felt', 'kumys-skin', 'cauldron-camp'],
      'О Творце неба говорят, не входя в камлание: мир без смешения.', 9,
      7, recs=['loc-yurta-kama'], safety=7,
      note='Бубен кама не ставится: чужой обряд не награждается и не '
           'истинен (ТАБУ №0.4 п. 6).')
place('archive-crypt', 'Подземная крипта архива', 'archive-crypt',
      'room', (6, 6, 2.8), ['M57', 'A21', 'A32'], 'new:seal-the-chronicle',
      (H, 1950, 'фонарь хранителя'),
      ['sealed-case', 'archive-chest', 'chronicle', 'wax-bar'],
      'Летопись запечатывают воском и кожей: память берегут, а не прячут '
      'от правды.', 8, 8, recs=['loc-kripta-arhiva'], sky='indoor')
place('chu-community', 'Двор общины Мар-Авы в долине', 'valley-community',
      'yard', (12, 10, 2.4), ['M59'], 'deed:forgive',
      (H, 2200, 'очаг двора'),
      ['bench', 'water-jug', 'bread-loaf', 'herbs'],
      'Спор о пастве решают миром: обиду кладут, а не делят общину.', 9,
      8, recs=['loc-chuiskaya-dolina',
               'p0482-nestarianskaya-chasovnya-v-issyk-ata'])
place('hidden-library', 'Скрытая библиотека униторов', 'hidden-library',
      'room', (6, 6, 2.8), ['M64', 'A31'], 'talk:photius/creed_margin',
      (H, 1950, 'светильник чтеца'),
      ['order-report', 'scroll-niche', 'inkwell', 'archive-chest'],
      'Символ переписывают, но не дополняют: чужие отчёты читают, различая '
      'веру, и не жгут.', 8, 8, recs=['loc-tainaya-biblioteka'],
      sky='indoor')
place('papal-camp', 'Лагерь посольства с Запада', 'envoy-tent', 'room',
      (8, 8, 3.5), ['M54', 'M21'], 'talk:maximos/two_signatures',
      (H, 2200, 'светильник шатра'),
      ['letter', 'credentials', 'felt', 'inkwell'],
      'Указ с двумя подписями — подделка дважды: поддержку не покупают '
      'подписью против сердца.', 9, 9,
      recs=['p0562-lager-posolstva-papy-1338'],
      note='Посольство Мариньолли через Алмалык (1338–1339) — реальное; '
           'святые латинян не выводятся (ТАБУ №0.2 п. 1).')
place('horde-tent', 'Шатёр посла Золотой Орды', 'envoy-tent', 'room',
      (8, 8, 3.5), ['M46'], 'talk:khan/k_peace',
      (H, 2200, 'очаг шатра'), ['felt', 'khadak', 'credentials', 'paiza'],
      'В бою конь не пасётся: мир и тихая жизнь нужнее побед.', 9, 8,
      recs=['p0553-shater-posla-zolotoy-ordy'])
place('translators', 'Стол уйгурских толмачей', 'translators-camp',
      'room', (6, 6, 3.0), ['M18', 'A49', 'A58'],
      'talk:photius/slavic_mission', (H, 2100, 'лампа толмача'),
      ['languages', 'glossary', 'inkwell', 'paper-bale'],
      'Евангелию не нужна чужая азбука: перевод ложится в словарь трудом, '
      'а не мгновенно (узел 49).', 9, 8,
      recs=['p0556-lager-uygurskikh-perevodchikov', 'p0559-dom-tolmacha'])
place('khan-garden', 'Сад хана', 'palace-garden', 'open', (12, 12, 0),
      ['P:lust'], 'passion:lust', (H, 2300, 'фонари сада'),
      ['vine', 'water-jug', 'bench'],
      'Только взглянуть — ничего не стоит, говорит помысл: взгляд '
      'отводят вовремя.', 8, 8, recs=['p0560-sad-khana'], sky='dusk',
      safety=8)
place('burnt-mission', 'Пустырь сожжённой миссии', 'burnt-ruin', 'open',
      (12, 10, 0), ['P:anger', 'M98'], 'deed:forgive',
      (H, 2000, 'угли пожарища'), ['stone-pile', 'water-jug', 'spade'],
      'Простить, а не мстить (Лк 23:34): обиду кладут, как тюк у '
      'колодца.', 8, 9, recs=['p0575-pustyr-sozhzhennoy-missii'])

# === Act V: the workshop of the obitel ====================================
place('forge', 'Кузня обители', 'forge', 'room', (8, 6, 3.5),
      ['M66', 'A16', 'A43', 'A47', 'A54'], 'new:forge-nail',
      (H, 2500, 'горн'),
      ['anvil', 'forge', 'tongs', 'crucible', 'tools'],
      'Куют орала, а не мечи (Ис 2:4): гвоздь, кованный рукой, заменит '
      'потерянную шайбу (узел 47).', 9, 9,
      recs=['loc-kuznya-obiteli', 'p0296-kuznechnyy-dvor',
            'p0494-kuznya-u-kyzyl-suu'], sky='indoor')
place('pottery', 'Гончарный двор', 'pottery', 'yard', (10, 8, 2.4),
      ['M67'], 'rule:handiwork', (H, 2400, 'печь для обжига'),
      ['potter-wheel', 'kiln', 'potter-stamp', 'karas', 'water-jug'],
      'Глина берёт форму по мере вращения; знак рыбы на посуде '
      'свидетельствует, а не поднимает цену.', 9, 9,
      recs=['loc-goncharnyi-dvor', 'p0295-goncharnyy-kvartal',
            'p0493-masterskaya-goncharov-ton'])
place('shipyard', 'Верфь на Светлом мысу', 'shipyard', 'shore',
      (16, 10, 0), ['M68'], 'new:caulk-seam', (H, 2200, 'смоляной котёл'),
      ['boat-hull', 'caulker', 'spruce-log', 'adze', 'oar'],
      'Шов конопатят льном и смолой: лодка держит воду, пока держит '
      'шов.', 9, 8,
      recs=['loc-verf-svetlyi-mys', 'p0297-lodochnaya-verf-u-tyupa',
            'p0495-lodochnaya-verf-v-tamge', 'p0506-bukhta-svetlyy-mys'])
place('weaving', 'Ткацкая: одна прядь до вечера', 'weaving', 'room',
      (8, 6, 3.2), ['M69', 'T:ascetic'], 'trial:ascetic',
      (H, 2200, 'окно и светильник'),
      ['loom', 'spindle', 'dye-vat', 'cloth'],
      'Одну прядь до вечера, пока другие едят: пост держится в тишине, а '
      'не в словах.', 9, 10,
      recs=['loc-tkatskaya-masterskaya',
            'p0567-tkatskaya-masterskaya-oblacheniy',
            'p0502-yuzhnyy-bereg-kyzyl-tuu'])
place('vineyard', 'Виноградник на нижней террасе', 'vineyard', 'open',
      (12, 10, 0), ['M70'], 'new:prune-vine', (H, 2300, 'костёр сборщиков'),
      ['vine', 'grapes', 'karas', 'basket'],
      'Сухую ветвь отсекают, чтобы лоза принесла плод (Ин 15:2): мера, а '
      'не запас.', 8, 9, recs=['loc-sad-vinogradnik'],
      note='Виноградарство у озера в XIV в. — сверить (историку).')
place('brickyard', 'Кирпичный двор у стройки', 'brickyard', 'yard',
      (12, 10, 2.4), ['M71', 'A19'], 'deed:obedience',
      (H, 2400, 'печь для обжига'),
      ['brick-mould', 'kiln', 'stone-pile', 'spade'],
      'Зодчий учит обжигу и кладке: заимствуют технику, а смысл остаётся '
      'свой.', 9, 8, recs=['loc-kirpichnyi-dvor'])
place('survey-hill', 'Холм, где размечают двор верёвкой', 'survey-hill',
      'open', (12, 12, 0), ['M72', 'A19'], 'new:rope-right-angle',
      (H, 2300, 'костёр разметчиков'),
      ['marking-cord', 'stakes', 'compass', 'route-map'],
      'Прямой угол дают двенадцать равных узлов: знание ремесла, не '
      'тайна.', 9, 9, recs=['loc-plan-obiteli', 'loc-skit'])
place('crafts-school', 'Навес, где учат детей ремеслу', 'school', 'yard',
      (10, 8, 2.4), ['M74'], 'new:teach-a-letter',
      (H, 2300, 'солнце под навесом и очаг'),
      ['wax-tablet', 'potter-wheel', 'apprentice-deed', 'bread-loaf',
       'bench'],
      'Учат лепить, ковать и выводить буквы, не требуя веры в обмен на '
      'хлеб.', 8, 9, recs=['loc-shkola-remesel'])
place('infirmary', 'Лечебница у ворот', 'infirmary', 'room', (8, 6, 3.2),
      ['M76'], 'talk:tabib/bandage', (H, 2100, 'лампа лекаря'),
      ['bandage', 'mortar', 'herbs', 'water-jug', 'felt'],
      'Туго, чтобы держало, свободно, чтобы шла кровь: ревность без меры '
      '— тоже вред.', 9, 9, recs=['loc-lechebnitsa'], sky='indoor')
place('print-shop', 'Печатня с доской для оттиска', 'print-shop', 'room',
      (8, 6, 3.2), ['M79'], 'new:proof-the-block',
      (H, 2100, 'лампа печатника'),
      ['print-block', 'paper-bale', 'inkwell', 'binding-press'],
      'Ошибку доски ищут до оттиска: она повторится в каждом листе.', 6,
      8, recs=['loc-tipografiya'], sky='indoor',
      note='Ксилография уйгуров известна (Турфан); «типография» обители '
           '— поздняя линия кампании, анахронизм пометить.')
place('treasury-crypt', 'Подклеть с казной вдов и сирот',
      'treasury-crypt', 'room', (6, 5, 2.6), ['M80', 'P:avarice'],
      'deed:secret_deed', (H, 1950, 'фонарь казначея'),
      ['treasury-chest', 'coin-purse', 'ledger', 'tally-stick'],
      'Казна — долг перед бедными, а не сокровище: доброе делают тайно.',
      8, 9, recs=['loc-kripta-kazny'], sky='indoor')
place('silversmith', 'Мастерская серебряника', 'jeweller', 'room',
      (6, 5, 3.0), ['M81', 'P:avarice'], 'talk:melik/m_no_one',
      (H, 2300, 'горелка и окно'),
      ['chalice', 'jeweller-crucible', 'silver-ingot', 'touchstone',
       'tools'],
      '«Никому не нужно знать» — голос, что приходит с серебром: потир не '
      'переливают в украшение.', 9, 9,
      recs=['loc-yuvelirnaya', 'p0570-yuvelirnaya-masterskaya'],
      sky='indoor', safety=8,
      note='Потир на столе мастера — сделан для престола, noInteract; '
           'хору: достаточно ли этого места.')
place('water-mill', 'Водяная мельница на ручье', 'mill', 'shore',
      (10, 8, 0), ['M82', 'A23'], 'deed:alms', (H, 2200, 'фонарь мельника'),
      ['mill-wheel', 'hand-mill', 'grain-sack', 'bread-loaf'],
      'Вода, которую никто не заставлял, мелет муку для бедных.', 9, 8,
      recs=['loc-vodyanaya-melnitsa', 'p0568-melnitsa-na-karakolke'])
place('field-kitchen', 'Походная кухня на стоянке', 'field-kitchen',
      'open', (12, 10, 0), ['M83'], 'rule:fast',
      (H, 2200, 'костёр под котлом'),
      ['cauldron-camp', 'campfire', 'bread-loaf', 'water-skin',
       'camel-saddle'],
      'В постный день кормят и строгих, и голодных, никого не осуждая; '
      'свой пост держат молча.', 9, 9,
      recs=['loc-karavannaya-stoyanka'], sky='dusk')
place('signal-tower', 'Сигнальная башня на холме', 'watchtower', 'open',
      (8, 8, 0), ['M84', 'A45'], 'rule:guard_thoughts',
      (H, 2300, 'сигнальный костёр'),
      ['signal-fire', 'torch', 'banner', 'horn', 'dove'],
      'Сторож не воюет, он не спит: так обходят прожитый день в сумерки.',
      9, 10, recs=['loc-signalnaya-bashnya',
                   'p0536-storozhevaya-bashnya-na-beregu'], sky='night')
place('archaeology-hq', 'Штаб подводной археологии', 'field-lab-2026',
      'room', (8, 6, 3.0), ['M85', 'M93', 'A37', 'A64', 'A68', 'A96'],
      'atlas:scribe', (INSTR, 6500, 'лампа стола и экраны'),
      ['rov-log', 'sample-basket', 'sealed-case', 'marker-buoy',
       'depth-gauge'],
      'Находки идут писцу в книгу находок, а не в оплату (узел 68): '
      'журнал — свидетельство.', 9, 9, recs=['loc-shtab-arkheologii'],
      sky='indoor')
place('apiary', 'Пасека за стеной ульев', 'apiary', 'open', (10, 8, 0),
      ['T:mystical'], 'trial:mystical', (H, 2000, 'дымарь пасечника'),
      ['beehive', 'wax-bar', 'candle-blank', 'cloth'],
      'Свечу не зажигают сами: свет приходит сам, а яркий сон — не знак.',
      8, 10, recs=['p0525-paseka-u-ushchelya-grigorevskoe',
                   'p0566-svechnaya-masterskaya'], sky='dusk')
place('elder-spring', 'Родник у скита, где стоит мутный кувшин',
      'spring', 'open', (8, 8, 0), ['T:contemplative'],
      'trial:contemplative', (H, 2100, 'костерок у родника'),
      ['water-jug', 'well-bucket', 'knotted-line', 'felt'],
      'Мутная вода светлеет, если её не трясти: старец молчит и вяжет '
      'узел.', 8, 10,
      recs=['p0589-rodnik-u-skita', 'p0472-skit-na-myse-u-tamgi'],
      sky='dusk')
place('lampless-cell', 'Келья без лампы', 'hermit-cave', 'cave',
      (4, 5, 2.4), ['T:apophatic', 'A18'], 'trial:apophatic',
      (H, 1900, 'отсвет заката во входе, лампы нет'),
      ['felt', 'water-jug', 'reed-bed'],
      'Без лампы и без слов: слышно дыхание и далёкий тростник.', 8, 10,
      recs=['loc-peshchera-isikhasta',
            'p0487-peshchera-otshelnika-nad-kara-oy',
            'p0541-keli-molchalnikov',
            'p0587-skit-na-severnom-sklone-kungey'], sky='dusk')
place('abandoned-skete', 'Брошенный скит', 'skete-ruin', 'yard',
      (10, 10, 2.4), ['P:acedia'], 'passion:acedia',
      (H, 2000, 'лучина в уцелевшей келье'),
      ['stone-pile', 'spade', 'water-jug', 'firewood'],
      'Уныние говорит, что работа бессмысленна; остаться и поправить одну '
      'дверь.', 7, 9, recs=['p0597-broshennyy-skit-akediya'])

# === Finale: the stone under the water ====================================
place('map-workshop', 'Мастерская картографа на Майорке', 'map-workshop',
      'room', (8, 6, 3.4), ['M87', 'A76'], 'new:tell-only-true',
      (H, 2200, 'окно и лампа'),
      ['portolan', 'inkwell', 'compass', 'parchment', 'world-map'],
      'Купец с Востока до 1375 г. говорит картографу только виденное; '
      'слышанное — с пометкой «говорят».', 10, 9, sky='indoor',
      note='Мастерская Крескесов (Авраам и его сын Иегуда), Пальма, '
           'Каталанский атлас 1375 г.; о мощах Матфея атлас пишет '
           '«говорят». Рассказчик — купец или миссионер до 1375 г., не '
           'рыцарь.')
place('council-hall', 'Совет обителей перед картой', 'council-hall',
      'room', (10, 8, 4), ['M91', 'A65'], 'talk:macrina/teaching',
      (H, 2200, 'светильники совета'),
      ['mission-map', 'bench', 'ledger', 'water-jug'],
      'Псалом на каждый час, как хлеб к трапезе: каждая обитель даёт своё, '
      'как члены одного тела.', 7, 8, recs=['loc-sovet-obiteley'])
place('farewell-road', 'Дорога, по которой уходит община', 'road',
      'open', (14, 8, 0), ['M95'], 'talk:anahit/a_farewell',
      (H, 2100, 'утренний костёр'),
      ['refugee-cart', 'water-skin', 'bread-loaf', 'camel-saddle'],
      'Дом жив, пока в нём кто-то печёт для чужого: уходящих '
      'благословляют, вещи остаются свидетелями.', 9, 9, sky='dawn')
place('wedding-yard', 'Свадебный двор у обители', 'wedding-yard', 'yard',
      (12, 10, 2.4), ['M97', 'M60'], 'new:tell-custom-from-faith',
      (H, 2300, 'светильники пира'),
      ['bread-loaf', 'karas', 'felt', 'cloth', 'bench'],
      'Язык, напев и одежду можно принять; веру не смешивают.', 8, 9,
      recs=['loc-svadebnyi-dvor'], safety=8)
place('finale-table', 'Стол под лампой: щит и письмо', 'finale-room',
      'room', (5, 5, 2.8), ['A83', 'A92', 'A99', 'M99'], 'rule:stillness',
      (H, 1900, 'настольная лампа'),
      ['atlas-shield', 'letter', 'atlas-diary', 'sealed-case'],
      'Пульт гаснет; остаются вещь и письмо в свете лампы — не призрак '
      '(узел 83).', 8, 10, sky='indoor')
place('dawn-shore', 'Берег на рассвете', 'shore', 'shore', (14, 10, 0),
      ['A99', 'M99'], 'rule:thanksgiving', (H, 2000, 'угли у воды'),
      ['boat', 'oar', 'net', 'reed-bed'],
      'Рассветный свет ложится на руку и на воду — это делает утро, не '
      'машина.', 9, 9, recs=['p0533-utrenniy-tuman-nad-vodoy'],
      sky='dawn')

# === The Water Atlas: Cilicia 1375 and the 2026 expedition ================
place('sis-gate', 'Ворота Сиса под треснувшим сводом', 'city-gate',
      'room', (6, 10, 6), ['A7', 'A10', 'A26', 'A27', 'A38', 'A74'],
      'atlas:chronicle', (H, 2400, 'зарево горящего города'),
      ['atlas-shield', 'bread-loaf', 'water-skin', 'stone-pile'],
      'Пощадить или обрушить свод — записано один раз; след выбора виден '
      'в озере, милость не награждается очками.', 10, 10, sky='night',
      safety=9, note='Сис пал в 1375 г.; боя в игре нет (узел 60).')
place('ayas-harbour', 'Гавань Аяса до 1347 г., где ушёл корабль',
      'sea-port',
      'shore', (16, 10, 0), ['A9'], 'rule:thanksgiving',
      (H, 2200, 'портовый фонарь'),
      ['barrel', 'rope-coil', 'anchor-stone', 'letter'],
      'Корабль молодого рыцаря ушёл, а благодарят за всё: озеро впереди '
      '— архив, а не могила.', 7, 8, sky='dusk',
      note='Аяс разорён мамлюками в 1337 г. и взят в 1347 г.; сцена — '
           'молодость рыцаря до 1347 г. (узел 9).')
place('sis-library', 'Сгоревшая библиотека Сиса', 'library-ruin',
      'room', (8, 8, 4), ['A32'], 'passion:sadness',
      (H, 2000, 'дым и угли'), ['scroll-niche', 'archive-chest', 'stone-pile'],
      'Утрата книг — утрата памяти, не смерть: печаль говорит «всё '
      'погибло», а переписанное живёт в обители.', 8, 7, sky='indoor')
place('mamluk-captivity', 'Двор плена у мамлюков', 'prison', 'yard',
      (10, 8, 3), ['A62'], 'rule:stillness', (H, 2300, 'полуденное пекло'),
      ['shackles', 'water-jug', 'bread-loaf'],
      'Терпение без жестокости на экране: перегрев машины — рифма, не '
      'зрелище пытки.', 8, 7, sky='day')
place('sis-armourer', 'Мастерская оружейника в Сисе', 'armourer', 'room',
      (8, 6, 3.2), ['A3', 'A16', 'A56', 'A63'], 'new:compare-forms',
      (H, 2400, 'горн'), ['anvil', 'tools', 'forge', 'cloth'],
      'Мастер XIV века и инженер 2026 года решали одну задачу потока: '
      'железо служит человеку.', 9, 6, sky='indoor')
place('expedition-camp', 'Лагерь экспедиции на берегу, 2026',
      'camp-2026', 'open', (12, 10, 0), ['A33', 'A38', 'A61', 'A73'],
      'deed:alms', (INSTR, 6500, 'фонарь палатки'),
      ['battery', 'field-tent', 'rov-log', 'hydrophone', 'water-jug'],
      'Заряд батарей делят с соседней экспедицией: человеческий выбор, а '
      'не мистика (узел 38).', 9, 9, sky='night')
place('order-servers', 'Серверная Ордена', 'server-room', 'room',
      (6, 6, 3), ['A7', 'A10', 'A35', 'A44', 'A55', 'A67', 'A86', 'A87',
                  'A97'],
      'passion:pride', (INSTR, 6500, 'ровный свет стоек'),
      ['server-rack', 'screen', 'keyboard', 'sealed-case'],
      'Ложное бессмертие копии: протокол говорит «мир — симуляция», '
      'признак прелести — петля и цена.', 7, 8, sky='indoor', safety=9)

# === Kiberslav: «Сон послушника» (a parable, not a transfer) ==============
place('dream-cell', 'Келья, где начинается долгий сон', 'cell', 'room',
      (4, 4, 2.8), ['KM', 'K70', 'K75'], 'rule:vigil',
      (LAMPADA, 1800, 'лампада у образа, окно в ночь'),
      ['icon', 'felt', 'hydrophone', 'lectern'],
      'Пробуждение возвращает тем же светом лампады: сон — притча, а не '
      '«было на самом деле».', 8, 8, sky='indoor', safety=9,
      exists='hub-cell')
place('svetloyar', 'Берег Светлояра: слышно, не найти', 'kitezh-shore',
      'shore', (14, 10, 0), ['K76', 'KM'], 'listen:kitezh',
      (H, 1900, 'свеча в руках паломника'),
      ['hand-candle', 'reed-bed', 'boat'],
      'Кто стоит неподвижно, тот слушает озеро; город под водой не '
      'находят и не взламывают: ни маркера, ни награды, ни записи.', 7,
      10, sky='night', safety=9)
place('offline-tavern', 'Корчма с одним проводным телефоном', 'tavern',
      'room', (8, 6, 3), ['K84', 'KM'], 'rule:stillness',
      (H, 2100, 'лучина за стойкой'),
      ['phone', 'bench', 'water-jug', 'bread-loaf'],
      'Здесь покупают не чипы, а тишину: час без сети.', 5, 9,
      sky='indoor')
place('ilya-izba', 'Изба Ильи: странники просят воды', 'izba', 'room',
      (6, 5, 2.8), ['K13', 'K22', 'K79', 'K80', 'KM'], 'deed:alms',
      (H, 1900, 'лучина'),
      ['exoskeleton', 'water-jug', 'felt', 'bread-loaf'],
      'Илья встаёт, чтобы послужить незнакомцам: причина подъёма — '
      'служение, патч лишь убрал помеху.', 6, 9, sky='indoor')
place('offline-forest', 'Лес вне покрытия', 'forest', 'open',
      (14, 12, 0), ['K24', 'K50', 'K86', 'KM'], 'new:walk-by-compass',
      (H, 1900, 'костерок'), ['compass', 'firewood', 'spruce-log'],
      'В серой зоне работает старая физика: компас, звёзды, эхо — '
      'никакого колдовства.', 6, 8, sky='night')
place('yaga-hut', 'Изба на опорах, что знает только офлайн-ключ',
      'air-gap-hut', 'yard', (10, 8, 2.4), ['K37', 'K38', 'K88'],
      'new:show-offline-key', (H, 2000, 'лучина в окне'),
      ['mortar', 'water-jug', 'birch-bark'],
      'Яга торгует мёртвым кэшем, а не колдовством: живая и мёртвая вода — '
      'сказочная медтехника.', 5, 6, sky='night')
place('veche', 'Вече, где голоса разнесены по спектру', 'veche', 'open',
      (14, 12, 0), ['K20', 'K66', 'K94'], 'new:tell-bots-from-people',
      (INSTR, 6500, 'экраны площади'), ['screen', 'horn', 'bench'],
      'Боты звучат громче и одинаковее: захват вече слышен, если '
      'слушать.', 5, 8, sky='dusk')
place('zero-board', 'Нулевая плата, где Илья называет себя',
      'server-vault', 'room', (6, 6, 3), ['K6', 'K12', 'K82', 'K91', 'K92'],
      'new:type-by-memory', (INSTR, 6500, 'свет стоек'),
      ['server-rack', 'keyboard', 'birch-bark'],
      'Байт за байтом по памяти, под напев — и назвать себя вслух: '
      'свидетельствовать, а не стереть себя.', 5, 9, sky='indoor')
place('mast-wasteland', 'Пустошь с мачтами', 'wasteland', 'open',
      (14, 12, 0), ['K65'], 'new:find-live-mast',
      (INSTR, 6500, 'огни мачт'),
      ['worship-cross', 'antenna-mast', 'drone-wreck'],
      'Мачты остаются мачтами; деревянный крест в стороне ничего не '
      'передаёт.', 5, 6, sky='dusk', safety=9)
place('reactor-izba', 'Реакторная изба с маревом', 'reactor-izba',
      'yard', (10, 8, 2.4), ['K33', 'K41'], 'new:spot-the-haze',
      (INSTR, 6500, 'дежурный свет'), ['firewood', 'screen', 'spade'],
      'Марево над «пустой» избой выдаёт скрытый узел: улика, а не '
      'колдовство.', 5, 7, sky='night')
place('memory-market', 'Рынок сжатой памяти', 'market-dream', 'open',
      (12, 10, 0), ['K22'], 'passion:avarice',
      (INSTR, 6500, 'вывески'), ['screen', 'awning', 'coin-purse'],
      'Детскую память продают дешевле всего: Илья не продаёт память о '
      'матери.', 5, 8, sky='night', safety=9)
place('iriy', 'Премиум-сад, где всё безупречно', 'prelest-sim', 'open',
      (12, 12, 0), ['K18', 'A97'], 'passion:pride',
      (INSTR, 6500, 'ровный свет без тени'), ['vine', 'bench', 'screen'],
      'Совершенство — и есть улика: признак прелести — цена, счётчик и '
      'петля.', 5, 8, sky='day', safety=7)
place('technoslavie', 'Пустая оболочка культа', 'prelest-shell', 'room',
      (8, 10, 6), ['K9', 'K62'], 'passion:vainglory',
      (INSTR, 6500, 'белый свет в пустых киотах'), ['screen', 'bench'],
      'Машина лик не рендерит: киоты пусты, признак подделки — цена за '
      'вход.', 5, 8, sky='indoor', safety=7)
place('cloud-ancestors', 'Облако слепков', 'cloud-sim', 'room',
      (6, 6, 3), ['K7', 'K74', 'A8'], 'passion:sadness',
      (INSTR, 6500, 'экраны слепков'), ['screen', 'letter', 'bench'],
      'Слепок не отвечает на новое: признак — петля; мёртвые не ресурс.',
      5, 9, sky='indoor', safety=7)
place('dead-cache', 'Кэш мёртвых машин', 'wreck-yard', 'open',
      (12, 10, 0), ['K12', 'K45', 'K74', 'K89'], 'new:match-serials',
      (INSTR, 6500, 'фонарь сканера'),
      ['drone-wreck', 'screen', 'rov-log'],
      'Серийные номера и царапины ведут к первой плате: сверка без '
      'подсказок-маркеров.', 5, 7, sky='dusk')

# Candidates the chorus rules out before any score (TABOO 0.26, 0.2):
# kept in the pool so the refusal and its reason are visible.
place('first-liturgy-shore', 'Первая служба на берегу', 'shore-witness',
      'shore', (14, 10, 0), ['W:eucharist', 'M99'], 'witness:eucharist',
      (H, 2000, 'свечи'), ['water-jug'],
      'Литургия — только событие жизни обители, видимое издали.', 8, 6,
      recs=['p0610-pervaya-liturgiya-na-beregu'], safety=5,
      note='В промте игрок служит (диакон): игра таинств не совершает '
           '(ТАБУ №0.26 п. 8); издали это уже есть на тропе свидетеля.')
place('confession-stone', 'Камень у воды для покаяния', 'stone-witness',
      'open', (8, 8, 0), ['W:confession'], 'witness:confession',
      (H, 2000, 'свеча'), ['felt'],
      'Листок подготовки уже есть в хабе и сгорает.', 7, 5,
      recs=['p0588-mesto-ispovedi-u-kamnya'], safety=4,
      note='Исповедь — не место-награда и не механика (ТАБУ №0.26 п. 3).')
place('martyrs-1339', 'Место гибели миссии 1339 года', 'memorial',
      'open', (10, 10, 0), ['P:anger'], 'deed:forgive',
      (H, 2000, 'свечи'), ['stone-pile'],
      'Молитва, а не мщение.', 10, 7,
      recs=['p0515-mesto-muchenichestva-missionerov-1339'], safety=6,
      note='Погибшие 1339 г. — латинские миссионеры; святыми они в игре '
           'не выводятся (ТАБУ №0.2 п. 1). Хору 12.')
place('harem-wing', 'Закрытое крыло дворца', 'palace-closed', 'room',
      (8, 6, 3), ['P:lust'], 'passion:lust', (H, 2200, 'светильники'),
      ['bench'], 'Отвернуть взгляд и уйти.', 7, 6,
      recs=['p0561-garem-krylo-zakryto-dlya-igroka'], safety=6,
      note='Для шлема и Meta Store место избыточно: хватает сада хана.')

# Places the headset already has (hub, dive, witness path).  They are
# not in the pool: the 99 are new places.  Their plots count as
# covered, so the report says which plots already have a place.
BUILT = {
    'hub-scriptorium': (
        'Скрипторий хаба', ['M45', 'M62', 'M77', 'M86', 'M92', 'A3', 'A49',
                            'A58', 'A64', 'A66', 'A72', 'A76', 'K94']),
    'hub-refectory': ('Трапезная хаба (пост)', ['M13', 'M61']),
    'hub-cell-watch': ('Келья вечернего дозора (эталон)', ['A18']),
    'hub-pier-rov': ('Пристань с аппаратом', ['M33', 'M93', 'A20', 'A25',
                                              'A60', 'A88', 'A93']),
    'hub-stillness': ('Угол безмолвия', ['A18']),
    'hub-ladder': ('Лестница врат (пороги панелями)',
                   ['T:foundational', 'T:liturgical', 'T:ascetic',
                    'T:contemplative', 'T:mystical', 'T:apophatic']),
    'hub-road': ('Калитка на дорогу (страсти)',
                 ['P:gluttony', 'P:lust', 'P:avarice', 'P:sadness',
                  'P:anger', 'P:acedia', 'P:vainglory', 'P:pride']),
    'dive': ('Погружение: пять поясов и задачи',
             ['D:hover', 'D:heading', 'D:tether', 'D:slowrise', 'D:finds',
              'D:slope', 'D:thermocline', 'D:silence', 'A2', 'A6', 'A13',
              'A22', 'A39', 'A48', 'A52', 'A69', 'A80', 'A81', 'A89',
              'A90']),
    'dive-traces': ('Следы рыцаря в погружении',
                    ['A4', 'A14', 'A15', 'A26', 'A27', 'A28', 'A40', 'A41',
                     'A82', 'A92', 'A96']),
    'cockpit': ('Кокпит «Мангустика»', ['A5', 'A17', 'A34', 'A50', 'A60',
                                        'A83', 'A88']),
    'witness': ('Тропа свидетеля', ['W:baptism', 'W:chrismation',
                                    'W:eucharist', 'W:confession',
                                    'W:ordination', 'W:marriage',
                                    'W:unction']),
}
