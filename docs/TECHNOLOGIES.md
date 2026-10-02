# Технологии Ludus — реестр

Один файл со всеми технологиями проекта. В каждой строке — что это, зачем, где код, где документ и чем проверено. Добавляя технологию, допиши строку сюда. Указатель всех файлов — `105/INDEX.md`.

## Сборка и доставка на шлем

| Технология | Зачем | Код | Документ | Проверка |
|---|---|---|---|---|
| **Godot 4.7.1, GL Compatibility, OpenXR, плагин Meta** | движок шлема (MIT) | `godot/` | CLAUDE.md, ТАБУ №0.02 | задания `test`, `android` |
| **Свой шаблон движка**: `optimize=size`, thin LTO, профиль классов, 20 модулей выключено | −30 % `libgodot_android.so`, место под голоса | `scripts/godot/engine/`, `.github/workflows/godot-engine.yml` | `docs/HLD_ENGINE_BUILD_2026-10-02.md`, `docs/decisions/ENGINE_BUILD_2026-10-02.md` | `profile.py --check` |
| **APK в GitHub Release `headset-latest`**, постоянный ключ, растущая версия | ставится поверх прежнего | `.github/workflows/godot.yml` | ТАБУ №0.01, `105/СБОРКА.md` | `check_budgets.py --apk` |
| **Git + GitHub Releases как «жёсткий диск» и «CD»** (как The Pandora Directive) | APK ≤ 128 МиБ, тяжёлое — пакетами | `godot/scripts/pack_fetch.gd`, `godot/data/packs.json` | **`docs/gost/ОП_ДОСТАВКА_НА_ШЛЕМ_GIT_GITHUB_RELEASES_ГОСТ_19.402.md`**, `docs/HLD_PACKS_STREAM_2026-10-02.md`, ТАБУ №0.018 | `test_pack_fetch.gd`, `stream_choice.py --check` |
| **Пакеты ресурсов `.pck`, OBB** | монтирование пакетов без подмены файлов игры | `godot/scripts/data_packs.gd` | `docs/gost/ОП_OBB_ПАКЕТ_РАСШИРЕНИЯ_ГОСТ_19.402.md` | `test_data_packs.gd` |
| **Папка 105** | указатель и комплект сборки | `105/make_105.py`, `.github/workflows/build-105.yml` | `105/СБОРКА.md` | `make_105.py --check` |

| **Установка Godot у Claude и у оператора** | тесты на сервере, тест в шлеме | `scripts/godot/ci_setup.sh` | [docs/INSTALL_GODOT_AND_HEADSET_TESTING.md](INSTALL_GODOT_AND_HEADSET_TESTING.md) | — |

## Мера (ревизор лимитов APK, ТАБУ №0.011)

| Технология | Зачем | Код | Проверка |
|---|---|---|---|
| Бюджеты APK, PCK, дерева | вес | `scripts/godot/check_budgets.py`, `scripts/godot/apk-budgets.json` | CI |
| Бюджеты сцен: вызовы отрисовки, треугольники, память, звук | кадр 72 Гц | `godot/tools/measure_budgets.gd` (hub, dive, witness, pilot), `measure_locations.gd` | CI под Xvfb |
| Склейка неподвижной геометрии `StaticBatch` | меньше вызовов отрисовки | `godot/scripts/static_batch.gd` | `test_static_batch` |
| Фоновая подгрузка крупных модулей | без рывка кадра | `godot/scripts/module_loader.gd` | `test_module_loader.gd` |
| Прогноз OBB и голосов | планирование 128 МиБ | `scripts/godot/obb_forecast.py` | CI |

## Графика

| Технология | Зачем | Код | Документ |
|---|---|---|---|
| **Подмена при осмотре (Swap Rendering)**: прокси в мире, пререндер в очках | точность там, куда смотрит глаз (как Pandora 1996) | `godot/scripts/pilot.gd` (`_examine`), `godot/art/prerender/` | `docs/HLD_SWAP_RENDERING_2026-10-02.md` |
| **Наш «Silicon Graphics»: Blender 4.5 LTS (`bpy`), Cycles CPU, OIDN, seed 1375** | офлайн-рендер крупных планов | `scripts/prerender/render_items.py` | выбор `scripts/decisions/prerender_choice.py` (пул 864) |
| Объёмные прокси из SVG и промтов | всё в объёме для Meta | `scripts/meta3d/` | ТАБУ №0.32 |
| Конвейер сырья: 35 % по альфе, 12 вариаций, антагонисты | чужое сырьё — только переработанным | `scripts/raw_assets/` | ТАБУ №0.1, `docs/PATENT_FORMULA_RAW_ASSET_PIPELINE.md` |
| Гравитация кодом: посадка по нижней вершине | ничего не висит в воздухе (физика вырезана) | `pilot.gd` `_land`, `bottom_of` | ТАБУ №0.016 |
| Три класса света (лампада, лучина, прибор) | стиль «Киберслав» | `ludus-design-system.css`, сцены | ТАБУ №0.38 |

| **Видео осмотра — флипбук-атлас** (оборот 24 кадра, смена UV), кэш 2 мин в памяти, LRU на диске | видео без видеоплеера в движке | `pilot.gd` `load_clip`, `render_items.py --turntable` | `docs/HLD_VIDEO_TECH_2026-10-02.md`, исследования `docs/research/` |
| **Сборка пакета `.pck`** с SHA-256 | «CD» серии | `godot/tools/make_pack.gd` | ТАБУ №0.018 |

## Звук

| Технология | Код | Документ |
|---|---|---|
| Процедурный синтез: колокол по kolokol, исон, сонар, вода | `godot/scripts/audio/` | ТАБУ №0.2, №0.35 п. 8–10 |
| **Черновой голос рассказчика**: Piper TTS, голос «irina» (данные RHVoice, GPLv2), Ogg Vorbis в пакете — до живой записи | `scripts/prerender/build_closeups.py` | ТАБУ №0.019 п. 5, Д-22 |
| **Закадровый текст хора** | `godot/data/pilot-narration.json`, `PilotCore.check_narration` | ТАБУ №0.020, `docs/story/chorus-ep1/` |
| Правила звона по Типикону | `godot/data/bell-rules.json`, `TypikonCore` | `docs/HLD_BELL_RULES_TYPIKON_2026-09-30.md` |

## Игра и смысл

| Технология | Код | Документ |
|---|---|---|
| Пилот «Табу»: ритм серии, табу телом, 55 деталей | `godot/scripts/pilot_core.gd`, `pilot.gd`, `godot/data/pilot-1.json`, `pilot-details.json` | ТАБУ №0.015, `docs/story/PILOT_EPISODE_1_TABU_2026-10-02.md` |
| **Инсайты-флешбеки**: память эпох по месту, порядку, времени, глубине, ступени помысла и неподвижности; часы стоят; пропуск стиком 1 с, рукоятями или взглядом/лучом на значок в мире | `godot/scripts/insight_core.gd`, `godot/data/pilot-insights.json`, `pilot.gd` `_insight` | `docs/HLD_INSIGHTS_FLASHBACKS_2026-10-02.md` |
| **Аппараты оператора в игре**: опись 41 идеи из его репо, прибор бита на панели робота и поверхности | `godot/scripts/apparatus_core.gd`, `godot/data/apparatus.json` | `docs/HLD_APPARATUS_IN_GAME_2026-10-02.md`, `docs/story/OPERATOR_APPARATUS_2026-10-02.md` |
| **Видео приборов кодом** (`ScreenFeed`): сонар, магнитометр в нТл, спектр гидрофона, дальность, камера, карта — из телеметрии сцены, 8 Гц, без видеофайлов | `godot/scripts/screen_feed.gd` | ТАБУ №0.022 |
| **Контракт в духе «Ведьмака»** (`ContractCore`): улики → бестиарий → подготовка → встреча → проба → лаборатория → выбор; длина рыбы по силе эха | `godot/scripts/contract_core.gd`, `godot/data/contract-akula.json` | `docs/HLD_CONTRACT_AKULA_2026-10-02.md` |
| Улики «под и над», классы находок | `PilotCore.clue_seen`, `check_finds` | ТАБУ №0.017, `docs/HLD_PANDORA_SURPASS_2026-10-02.md` |
| Лестница помысла (страсти) | `godot/scripts/passion_core.gd` | ТАБУ №0.2 п. 8 |
| Отбор «из N лучших K» | `scripts/decisions/*.py`, `scripts/lake/lake_objects.py` | ТАБУ №0.07, `docs/OBJECT_SELECTION_TECHNOLOGY.md` |

## Аудитория

| Документ | Что |
|---|---|
| [docs/research/AUDIENCE_LUDUS_2026-10-02.md](research/AUDIENCE_LUDUS_2026-10-02.md) | хор 24 линз, 7 сегментов, 8 персон, 91 успешная игра с цифрой и источником (+25 без цифры, 6 поучительных неудач), тон, крючки, цена, языки, риски |
