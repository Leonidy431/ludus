# ludus

работать на лудус игрой Путь дьякона". Действуй как Lead Game Designer и Principal Luau Engineer в студии, входящей в топ-10 Roblox и Meta Horizon games по уровню выручки (GaaS, LiveOps). Твоя задача — разработать концепт и архитектурный план для игры «Deacon's Path: Issyk-Kul» (Путь Диакона).
Игра должна приносить сотни миллионов рублей выручки за счет гениальной интеграции механик ежедневного возврата (Daily Ludus / Idle-Strategy) и социальной интриги. Разработай детальный HLD документ по следующим 4 разделам:

Core Loop (Ежедневный Лудус на 15 минут) ## 🥽 Oculus/VR-нативная игра «Рыцари против инопланетян» — новая параллельная IP, изоляция веткой+каталогом, НЕ существующая игра (STANDING RULE, 2026-08-22)
Директива оператора, 2026-08-22 (дословно): «Начни говорю ветку игры Паралельно. Для окулус приложения в дополнение к веб версии более динамичная молодежная смачная» + полный 99-фактный манифест (9 блоков: онтология, глобальная стратегия XCOM-типа, корабль-хаб, VR-тактика, «сеча», Молитва+33 инструмента, миссия «Иссык-Куль», требования Meta Oculus Store, директивы хору Claude). Полный TZ + хор-ревью: docs/ru/ТЗ_OCULUS_РЫЦАРИ_ПРОТИВ_ПРИШЕЛЬЦЕВ_2026-08-22.md.

Это НЕ развитие существующей игры Webtypicon2 (docs/GAME_CONSTITUTION.md, Храм/Агора, functions/src/game/, public/game/, включая её собственный WebXR VR-режим vr.js/vr.html). Другой жанр (sci-fi-хоррор экшен vs. литургически-образовательная игра), другая платформа (нативный Unity/Unreal + Meta XR SDK под Quest/ARM64, а не браузерный WebXR на Firebase-стеке), другой тон, отдельная IP. «В дополнение к веб версии» (дословно оператора) = параллельно, не вместо. Никогда не путать эти два игровых трека друг с другом в документации/коде.
ТАБУ №1 распространяется автоматически и строже — эта игра не имеет вообще никакой связи (даже read-only) с литургическим корпусом; никакого сюжетного/богословского смешения с православным материалом проекта (пришельцы и вымышленный орден остаются полностью вымышленными, без псевдо-богословских утверждений).
Изоляция по прецеденту AppleMed: реальный будущий Unity/Unreal-код живёт в ОТДЕЛЬНОЙ ветке (oculus-knights-vs-aliens) + отдельном каталоге (oculus-knights/), никогда не мержится в main смешанно с остальным кодом, никогда не участвует в стандартном deploy.yml. Открытый вопрос (не решён этим правилом, ждёт оператора): вынести реальную Unity/Unreal- кодовую базу в СОВСЕМ отдельный GitHub-репозиторий (рекомендация продюсерского узла хора — Unity/Unreal генерируют тяжёлые бинарные каталоги, плохо сочетаются с уже большим монорепо литургического корпуса) — см. TZ §7.
CONSTRAINT TRANSPARENCY, постоянно актуально: в песочнице/на текущем self-hosted раннере НЕТ Unity Editor/Unreal Engine/Android SDK — реальный компилируемый Unity C#/Unreal Blueprint код здесь писать и тестировать нельзя. До Фазы 2 (TZ §6) работа — только документация/данные (JSON/YAML)/нарратив, никогда не выдаётся за откомпилированный/ протестированный код.
Фазовый роудмап обязателен (TZ §6) — вертикальный срез (одна миссия «Иссык-Куль»), не весь 99-фактный манифест одновременно; та же дисциплина «module-by-module», что и у VM Migration Protocol/книжного модуля этого файла.
Решения по этой игре — через хор 32 профильных профи по играм (per стоящее правило «🎮 Хор 32 профильных профи по играм»), но с ДРУГИМ, специфичным для VR/native-разработки составом специалистов (не литургическим), зафиксированным per-вопрос в TZ, не всегда идентичным составу для существующей веб-игры.
Формальная Конституция принята (Гуру-проход №2, 2026-08-22): docs/ru/КОНСТИТУЦИЯ_OCULUS_ИГРЫ_2026-08-22.md — Статья 2 закрепляет отдельное, более строгое табу (директива оператора дословно: «Также отдельное табу от богослужебных текстов») — у этой игры НЕТ вообще никакой связи (даже read-only) ни с одним модулем проекта, кроме единственного разрешённого исключения п.8 ниже; Статья 5 фиксирует реальные (WebSearch, 2026-08-22) технические/контентные пределы Meta Quest Store — включая критичную находку: официальная контент-политика Meta прямо запрещает «glorification of gore»/ «dismemberment» для контента общей аудитории, что напрямую конфликтует с манифестом п.48 — решение хора (стилизованное, не реалистичное расчленение) зафиксировано там же как творческое суждение, НЕ гарантия реального прохождения ревью Meta.
Единственная разрешённая точка связи с остальным сайтом (директива оператора: «Связка только с нашей текстово game/vr.html») — исходящая ссылка/кнопка на существующей странице public/game/vr.html (WebXR-режим ОСНОВНОЙ игры), никогда не iframe/общий код/общая аутентификация, никакая другая страница сайта не получает точку связи без отдельного решения оператора. См. Конституция Статья 3. Игрок не должен «гриндить» часами. Он заходит раз в день. Пропиши цикл сессии: Сбор отчетов: Что произошло в офлайне (Набеги Орды, добыча камня, успех экспедиций водолазов). Бросок Судьбы (Гача-механика кубиков): Ежедневная бесплатная и платная (за Robux) генерация пула кубиков, которые игрок распределит по слотам заданий на следующие 24 часа. Асинхронное PvP и Дипломатия: Механика отправки шпионов и заключения торговых договоров с другими игроками на сервере, пока те в офлайне.
Агрессивная и Этичная Монетизация (Robux Economy) Как именно игра войдет в топ по доходности: Пропиши 3 механики монетизации без системы "Pay-to-Win" в чистом виде (например: Time-skips для долгого строительства мегалитов, покупка страховки «Пайцза» от потери ресурсов при набеге, уникальные UGC-предметы для кастомизации архитектуры монастыря). Система VIP-подписки: что дает статус "Патриарх" игроку каждый день.
Программная Архитектура (Roblox Studio / Luau) Набросай структуру серверной логики: Как оптимально использовать DataStoreService и MemoryStoreService для просчета действий Орды и симуляции экономики тысяч игроков, находящихся в офлайне. Как защитить игру от эксплойтов (RemoteEvent security), учитывая, что в игре есть ценный ресурс (Серебро/Реликвии), который можно передавать другим игрокам.
LiveOps: Интеграция 366 миссий Предложи систему, как наши заранее написанные 366 миссий-испытаний (соответствующих сабианским градусам) будут автоматически выдаваться сервером в виде глобальных ежедневных квестов (Daily Quests) и мировых кризисов, заставляя весь сервер объединяться против Орды или сражаться за ресурсы озера. Архитектура цифрового мира во многом подобна архитектуре древних полисов — она требует площадей для торговли, стен для защиты и храмов для надежды. Когда система вознаграждает игрока за ежедневное проявление воли, грань между игрой и второй жизнью стирается. Считаешь ли ты, что введение элементов жестокого предательства и потери ресурсов в офлайне оттолкнет массовую аудиторию Roblox, или именно страх потери станет тем якорем, который заставит их возвращаться каждый день цель: топ-10 ~$65,7 млн, это в среднем по ₽5,5 млрд на каждого. Для топ-100 средняя выплата составила ~₽910 млн, для топ-1000 — ~₽120 млн. давай делать вторую часть - Act as a Principal VR Systems Architect and Senior Gameplay Programmer (Unity/C# or Godot/GDScript). I am setting up a VR Submarine/ROV Simulator for Meta Quest 3, heavily inspired by "Ziggy's Cosmic Adventures" but focused on underwater 6DOF physics, thermocline density mechanics, and acoustic sonar rendering. My workflow: I am a system architect. I will use you (Claude/Aider) to generate 90% of the logic, state machines, and physics math. I will act as the reviewer, integrating your code into the engine and handling CI/CD via GitHub Actions. Our main bottleneck is the VR iteration loop ("headset on/off" fatigue). To mitigate this, we must build the architecture strictly modularly, separating input processing from game logic. Please generate a comprehensive Technical Design Document (TDD) and the foundational code structure for this MVP. Break your response into the following 4 phases: Phase 1: Input Abstraction & Mocking (The VR Loop Fix) Design an Interface-based input system (IPlayerInput). I need the ability to test 90% of the cockpit interactions (pushing buttons, pulling thruster levers, steering) on my PC using a Mouse/Keyboard without putting on the Quest 3 headset. Provide the C# (or GDScript) architecture for an InputManager that seamlessly switches between OpenXRControllers and MouseSimulator based on the active build target. Phase 2: 6DOF Underwater Physics & Buoyancy Engine I need the mathematical logic for a heavy ROV submarine. Write a structural outline for a SubmarineController that applies forces at specific thruster points (using Rigidbody physics). Include a system for Buoyancy and Drag that reacts to a "Thermocline" variable (water density changing by depth/temperature). The code must be highly optimized for mobile XR chips (Snapdragon XR2) — avoid expensive FixedUpdate physics calls where simple vector math suffices. Phase 3: The Interactive Cockpit (State Machine) Design the architecture for physical cabin interactions. Provide a pattern for InteractableCockpitItem (buttons, levers, valves). How should we structure the Event System so that physically grabbing and pulling a virtual lever directly maps its 0.0 to 1.0 normalized position to the SubmarineController's engine thrust? Phase 4: CI/CD and Optimization Pipeline Given my background in Google Cloud and GitHub Actions, propose a pipeline to automate VR builds. Write a YAML workflow for GitHub Actions that automatically builds an Android .apk for Quest 3 when code is pushed to the main branch. List 5 strict rules for rendering and optimization we must follow in our scripts to maintain a stable 72/90 FPS on Quest 3 (e.g., Object Pooling for sonar pings, avoiding garbage collection spikes in Update()).99 Отобранных репозиториев с открытым кодом I. 4X, Глобальная стратегия и Дипломатия Freeciv — C / C++ — Легендарная 4X-стратегия с глубокой дипломатией, торговлей и сетевым кодом.
https://github.com/freeciv/freeciv

Unciv — Kotlin — Открытый кроссплатформенный ремейк Civilization V. Образцовая архитектура пошаговой логики и ИИ.

https://github.com/yairm210/Unciv

FreeOrion — C++ / Python — Космическая 4X-стратегия, вдохновленная Master of Orion. Мощный скриптовый движок дипломатии.

https://github.com/freeorion/freeorion

Remnants of the Precursors — Java — Полный open-source ремастер Master of Orion с развитым ИИ переговоров.

https://github.com/RayFowler/rotp-public

TripleA — Java — Пошаговый глобальный движок военных стратегий (Axis & Allies) с XML-модульностью правил.

https://github.com/triplea-game/triplea

OpenRA — C# — Модульный RTS/RTT-движок для классических 2D-стратегий с развитым мультиплеером.

https://github.com/OpenRA/OpenRA

Widelands — C++ — Экономическая пошагово-стратегическая игра (наследник The Settlers II) с глубокой логистикой дорог.

https://github.com/widelands/widelands

Unknown Horizons — Python / C++ — Изометрическая 2D-стратегия градостроительства и торговли в духе серии Anno.

https://github.com/unknown-horizons/unknown-horizons

Seven Kingdoms: Ancient Adversaries — C++ — Стратегия с фокусом на шпионаж, подкуп дипломатов и торговлю.

https://github.com/7kfans/7kaa

OpenDungeons — C++ — Сеточная стратегия реального времени с управлением подземным поселением (Dungeon Keeper).

https://github.com/OpenDungeons/OpenDungeons

OpenXcom — C++ — Движок тактической стратегии с глобальной картой геополитики и пошаговой базой.

https://github.com/OpenXcom/OpenXcom

Endless Sky — C++ — Космическая 2D-песочница с развитыми торговыми маршрутами и экономическими системами.

https://github.com/endless-sky/endless-sky

II. Пошаговая тактика, РПГ и Изометрия The Battle for Wesnoth — C++ / Lua — Золотой стандарт пошаговой тактики на гексагональной сетке с богатым скриптингом.

https://github.com/wesnoth/wesnoth

Cataclysm: Dark Days Ahead — C++ — Эталонная симуляция хардкорного выживания, крафта, физики холода и дебаффов.

https://github.com/CleverRaven/Cataclysm-DDA

Dungeon Crawl Stone Soup (DCSS) — C++ — Классический рогалик с идеальной системой дискретной логики ходов и магии.

https://github.com/crawl/crawl

Shattered Pixel Dungeon — Java — Прекрасно спроектированная мобильная пошаговая механика боя и менеджмента предметов.

https://github.com/00-Evan/shattered-pixel-dungeon

Jagged Alliance 2 Stracciatella — C++ — Открытый движок тактики с наемниками, психологией страха и торговлей оружием.

https://github.com/ja2-stracciatella/ja2-stracciatella

BrogueCE — C — Минималистичный и строгий пошаговый рогалик с открытой архитектурой видимости и света.

https://github.com/tmewett/BrogueCE

FLARE Engine — C++ — Изометрический 2D экшен-РПГ движок с настраиваемыми через конфиги навыками и инвентарем.

https://github.com/clintbellanger/flare-engine

Julius — C — Открытый ремейк движка Caesar III: логика движения плебеев, снабжение водой и пожаротушение.

https://github.com/bvschaik/julius

CorsixTH — C++ / Lua — Движок симуляции госпиталя (Theme Hospital). Идеален для механик эпидемий и лечения.

https://github.com/CorsixTH/CorsixTH

Angband — C — Прародитель пошаговых партийных подземелий с чистым разделением интерфейса и игровой логики.

https://github.com/angband/angband

OpenApoc — C++ — Переработка X-COM: Apocalypse с механикой политических отношений корпораций и фракций.

https://github.com/OpenApoc/OpenApoc

OpenLara — C++ — Классический движок перемещения персонажей и физики взаимодействия с платформами.

https://github.com/XProger/OpenLara

III. Карточные движки, Deckbuilding и Механика кубиков Fireplace — Python — Полноценный симулятор правил Hearthstone с обработкой очередей триггеров и эффектов карт.

https://github.com/jleclanche/fireplace

Forge — Java — Движок правил Magic: The Gathering с поддержкой тысяч карт и продвинутым ИИ оппонента.

https://github.com/Card-Forge/forge

XMage — Java — Клиент-серверный карточный движок с жестким соблюдением стека фаз и приоритетов ходов.

https://github.com/magefree/mage

Cockatrice — C++ — Мультиплеерный виртуальный стол для карточных игр с открытой структурой колод.

https://github.com/Cockatrice/Cockatrice

YGOPRO Core — C++ — Изолированное ядро дуэльной карточной игры с детальной логикой цепочек заклинаний.

https://github.com/Fluorohydride/ygopro-core

Dice-Roller — JavaScript — Мощный парсер формул кубиков, математики вероятностей и сложных бросков (Fudge, D20, Exploding).

https://github.com/rpg-dice-roller/dice-roller

Dominion Simulator — Java — Симулятор декбилдинговой механики Dominion для статистического анализа баланса карт.

https://github.com/jmerle/dominion-sim

Pokemon Showdown — TypeScript — Серверное ядро пошаговых дуэлей с симуляцией эффектов погоды, баффов и рандома.

https://github.com/smogon/pokemon-showdown

Godot Card Game Framework — GDScript — Готовый архитектурный фреймворк для карточных игр на движке Godot.

https://github.com/benbishopnz/godot-card-game-framework

CardGame.framework — Swift — Чистая объектно-ориентированная модель сущностей: рука, сброс, колода, стол.

https://github.com/gonzalezreal/CardGame

LibDice — C# — Библиотека для генерации бросков, взрывающихся граней и кастомных таблиц выпадения.

https://github.com/Vbitz/LibDice

TabletopClub — GDScript — Физическая 3D-песочница настольных игр на Godot (броски костей, колоды карт, жетоны).

https://github.com/drwhut/tabletop-club

IV. Колонии, Градостроительство, Выживание и Менеджмент OpenTTD — C++ — Лучший симулятор транспортной логистики, грузопотоков и станций на тайловой сетке.

https://github.com/OpenTTD/OpenTTD

Simutrans — C++ — Глубокий тайловый транспортный симулятор с экономической моделью производства товаров.

https://github.com/simutrans/simutrans

Mindustry — Java — Гибрид башенной защиты, логистики конвейеров и менеджмента ресурсов в реальном времени.

https://github.com/Anuken/Mindustry

Space Station 14 — C# — Мультиплеерный симулятор выживания экипажа станции с глубокой физикой газов и проводов.

https://github.com/space-wizards/space-station-14

Citybound — Rust — Микросимуляция города на базе агентной модели и акторов, написанная для максимальной производительности.

https://github.com/citybound/citybound

Micropolis — C++ — Открытый исходный код классического SimCity от Уилла Райта с сеточным расчетом зон.

https://github.com/SimHacker/micropolis

Return to the Roots — C++ — Ремейк The Settlers II с экономикой цепочек ремесел и пограничных столбов.

https://github.com/Return-To-The-Roots/s25client

Lincity-NG — C++ — Градостроительный симулятор с акцентом на экологию, дефицит воды и устойчивое развитие.

https://github.com/lincity-ng/lincity-ng

OpenLocomotion — C++ — Модернизированный движок Криса Сойера для симуляции подвижного состава и логистики.

https://github.com/OpenLocomotion/OpenLocomotion

KeeperFX — C++ — Модульное расширение Dungeon Keeper: копание породы, настроение существ, налоги.

https://github.com/dkfans/keeperfx

OpenCity — C++ — 3D градостроительный симулятор на OpenGL со строгим алгоритмом прокладки труб и дорог.

https://github.com/opencity/opencity

Colony Engine (Prototype) — C# — Минималистичный шаблон симулятора выживания поселенцев на сетке.

https://github.com/mizipzor/colony-game

V. Движки и базовые фреймворки (Turn-based friendly) Godot Engine — C++ / GDScript — Идеальный открытый движок для пошаговых 2D/3D стратегий с узловой архитектурой сцен.

https://github.com/godotengine/godot

Raylib — C — Модульная легковесная библиотека для написания прототипов без тяжелых графических редакторов.

https://github.com/raysan5/raylib

Bevy — Rust — Промышленный движок на архитектуре ECS (Entity Component System) с высокой параллелизацией.

https://github.com/bevyengine/bevy

Love2D — C++ / Lua — Легковесный 2D-фреймворк для быстрой сборки процедурных прототипов и карточных столов.

https://github.com/love2d/love

MonoGame — C# — Открытая реализация Microsoft XNA, на которой созданы Bastion, Celeste и Stardew Valley.

https://github.com/MonoGame/MonoGame

Fyrox — Rust — Полнофункциональный 3D/2D движок на Rust с собственным редактором сцен и гибким UI.

https://github.com/FyroxEngine/Fyrox

Defold — C++ / Lua — Оптимизированный 2D-движок с нулевым overhead, идеально подходящий для мобильных пошаговых игр.

https://github.com/defold/defold

Panda3D — C++ / Python — Игровой движок от Disney с удобной связкой быстрого кода C++ и гибкой логики на Python.

https://github.com/panda3d/panda3d

Urho3D — C++ — Легковесный компонентный 3D-движок, удобный для встраивания в сторонние приложения.

https://github.com/urho3d/urho3d

Cocos2d-x — C++ — Классический кроссплатформенный фреймворк для 2D-интерфейсов и тайловых карт.

https://github.com/cocos2d/cocos2d-x

Amethyst — Rust — Архитектурная база данных данных и ECS-концептов для масштабируемых симуляций.

https://github.com/amethyst/amethyst

bgfx — C++ — Кроссплатформенная библиотека рендеринга без привязки к конкретному графическому API.

https://github.com/bkaradzic/bgfx

VI. Roblox / Luau: Архитектура, стейт и профилирование Rojo — Rust — Профессиональный инструмент сборки, позволяющий писать код Roblox в VS Code и вести Git-контроль.

https://github.com/rojo-rbx/rojo

Luau — C++ / Luau — Официальный оптимизированный язык Roblox со статической типизацией и песочницей.

https://github.com/luau-lang/luau

ProfileService — Luau — Стандарт индустрии Roblox для отказоустойчивой работы с DataStoreService (защита от дюпов).

https://github.com/MadStudioRoblox/ProfileService

ReplicaService — Luau — Архитектура сервер-клиентной односторонней синхронизации состояния мира и инвентарей.

https://github.com/MadStudioRoblox/ReplicaService

Knit — Luau — Легковесный фреймворк управления сервисами и контроллерами на базе паттерна Singleton.

https://github.com/Sleitnick/Knit

Fusion — Luau — Современный реактивный декларативный UI-фреймворк для построения сложных HUD и меню в Roblox.

https://github.com/Elttob/Fusion

Roact — Luau — Порт React на Luau от инженеров Roblox для создания масштабируемых интерфейсов.

https://github.com/Roblox/roact

Matter — Luau — Полноценный высокопроизводительный ECS-фреймворк для разделения логики и отображения в Roblox.

https://github.com/evaera/matter

ByteNet — Luau — Сверхбыстрый сериализатор сетевых пакетов через буферы (buffer) для оптимизации RemoteEvent.

https://github.com/ffrostfall/ByteNet

Wally — Rust — Менеджер пакетов для экосистемы Roblox (аналог npm / cargo).

https://github.com/UpliftGames/wally

Flamework — TypeScript — Комплексный фреймворк для разработки плейсов Roblox на TypeScript с внедрением зависимостей.

https://github.com/flamework-rbx/core

Comm — Luau — Модуль декларативного связывания сетевых вызовов (RemoteEvents / RemoteFunctions) без спагетти-кода.

https://github.com/Sleitnick/rbx-comm

VII. Искусственный интеллект, Деревья решений и Дипломатия BehaviorTree.CPP — C++ — Промышленная библиотека создания деревьев поведения с XML-конфигурацией и мониторингом.

https://github.com/BehaviorTree/BehaviorTree.CPP

OpenSpiel — C++ / Python — Коллекция игровых сред DeepMind для исследования теории игр, блефа и переговоров.

https://github.com/deepmind/open_spiel

Diplomacy Engine — Python — Игровой симулятор классической игры Diplomacy для обучения ИИ переговорам и предательствам.

https://github.com/diplomacy/diplomacy

Recast Navigation — C++ — Индустриальный стандарт построения навигационных сеток и поиска пути в 3D.

https://github.com/recastnavigation/recastnavigation

MicroPather — C++ — Сверхкомпактный модуль поиска пути A* для пошаговых тайловых и сеточных игр.

https://github.com/leethomason/MicroPather

BrainTree — C++ — Заголовочная (header-only) библиотека деревьев поведения для легковесного ИИ ботов.

https://github.com/arvidsson/BrainTree

Pathfinding.js — JavaScript — Исчерпывающая библиотека алгоритмов обхода препятствий (A*, Dijkstra, IDA*, JPS).

https://github.com/qiao/Pathfinding.js

GOAP (Goal-Oriented Action Planning) — C++ — Движок планирования действий ботов на основе динамического графа целей.

https://github.com/cpv79/goap

Python StateMachine — Python — Конечный автомат для моделирования фаз переговорных раундов и условий Ясы.

https://github.com/fgmacedo/python-statemachine

VIII. Процедурная генерация карт, Гексы и Террейн Mapgen4 — JavaScript — Процедурный генератор карт от Amit Patel (Red Blob Games) с симуляцией климата и ветров.

https://github.com/amitp/mapgen4

WaveFunctionCollapse (WFC) — C# — Алгоритм процедурной генерации связанных карт и структур на основе квантования тайлов.

https://github.com/mxgmn/WaveFunctionCollapse

FastNoiseLite — C++ / C# / Java — Библиотека генерации когерентного шума (Perlin, Simplex, Cellular) для ландшафтов.

https://github.com/Auburn/FastNoiseLite

Fantasy-Map-Generator (Azgaar) — JavaScript — Масштабный генератор политических карт мира с культурами и реками.

https://github.com/Azgaar/Fantasy-Map-Generator

WorldEngine — Python — Геологическая и климатическая симуляция целых планет с эрозией и тектоникой плит.

https://github.com/Mindwerks/worldengine

Libnoise — C++ — Классический расширяемый генератор процедурного шума для создания многослойных биомов.

https://github.com/qknight/libnoise

Delaunator — JavaScript / C++ — Высокоскоростная триангуляция Делоне для построения нерегулярных полигональных сеток карт.

https://github.com/mapbox/delaunator

Poisson-Disk-Sampling — JavaScript — Алгоритм распределения точек интереса (оазисы, руины, стоянки) без скучивания.

https://github.com/kchapelier/poisson-disk-sampling

HexLib — Multi-language — Официальная математическая реализация гексагональных сеток от Red Blob Games.

https://github.com/flann/hexgrid

IX. UI/UX Системы и Экраны торговли (GalCiv Style) Dear ImGui — C++ — Стандарт отладочных и игровых окон с мгновенным рендерингом (идеален для матриц торговли).

https://github.com/ocornut/imgui

RmlUi — C++ — HTML/CSS-ориентированный движок для создания сложных стилизованных интерфейсов в играх на C++.

https://github.com/mikke89/RmlUi

Nuklear — C — Однофайловая ANSI C GUI-библиотека непосредственного режима для минималистичных интерфейсов.

https://github.com/Immediate-Mode-UI/Nuklear

Slint — Rust / C++ — Декларативный легковесный GUI-инструментарий для создания современных адаптивных окон.

https://github.com/slint-ui/slint

NanoGUI — C++ — Компактная библиотека виджетов на OpenGL, подходящая для научных и инженерных панелей.

https://github.com/mitsuba-renderer/nanogui

ImGuizmo — C++ — Модуль манипуляторов и визуализации кривых/графиков для движков на Dear ImGui.

https://github.com/CedricGuillemet/ImGuizmo

Godot-Next — GDScript — Набор базовых классов и UI-компонентов расширения стандартной библиотеки Godot.

https://github.com/godot-extended-libraries/godot-next

Guisan — C++ — Легковесный C++ GUI-фреймворк для 2D-стратегий с поддержкой SDL и OpenGL.

https://github.com/guisan/guisan

ImGui-Godot — C# / GDScript — Интеграция Dear ImGui в Godot Engine для высокоскоростного создания тулбаров и экранов обмена.

https://github.com/pkulchenko/imgui-godot

🛑 мега ТАБУ №1: игра НИКОГДА не пишет в богослужебные модули и не пересекаются эти два раздела никак — читать можно, писать/изменять НЕЛЬЗЯ (STANDING RULE, Абсолютное табу.** Любая игровая работа (код, арт, циклы, VR, Llama-повествование) может
