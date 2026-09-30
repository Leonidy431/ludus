# Опись «веб → шлем» (ТАБУ №0.01 п. 5)

Что есть в веб-версии Ludus и чего ещё нет в APK для Quest 3. Каждая задача сокращает список или пишет, почему пункт в шлем не идёт. Обновлено 2026-09-30.

| Что в вебе | Где | В APK | Состояние / почему |
|---|---|---|---|
| Погружение, телеметрия, физика воды | `public/ludus/dive/dive-core.js` | `godot/scripts/dive_core.gd` | ✅ сверено: 638 проверок |
| 99 объектов озера, 20 рыб | `public/ludus/data/lake-objects-99.json`, `issyk-kul-fish.json` | `godot/data`, `godot/models/lake` | ✅ данные сверяются `cmp` в CI |
| Врата знания, вервица, безмолвие, поклон | `public/ludus/ludus-actions.js` | `godot/scripts/hub_core.gd` | ✅ 792 проверки |
| Диалоги 24 наставников | `public/ludus/data/dialogue-trees.json` | хаб, скрипторий (4 наставника врат) | частично: в шлеме 4 из 24 NPC |
| Звук: исон, колокол по уставу, сонар | `ludus-sacred-synth.js`, `ludus-glas.js`, `ludus-liturgical-clock.js` | `godot/scripts/audio` | ✅ погружение; во дворе и на тропе — нет |
| Кокпит, аппарат «Мангустик», трос | трос — `dive-core.js` (задача `tether`) | `godot/scripts/cockpit_*`, `rov_body.gd`, `dive_core.gd` | ✅ |
| Гидрофон оператора (posoh «модель 1») на «Мангустике» | в вебе нет (сначала шлем) | `godot/models/posoh/hydrophone.glb`, `godot/scripts/posoh_core.gd`, карточка «ГИДРОФОН» на втором экране | ✅ 92 проверки; в веб-версию — следующей задачей, если нужно (HLD_POSOH_HYDROPHONE, открытый вопрос 4) |
| Семь сцен «игрок — свидетель» | `public/vr/models/scene/sacrament-*.glb` | `godot/scenes/witness.tscn`, вход — арка во дворе | ✅ 77 проверок; исон и колокол на тропе — позже, через `LudusTypikon` |
| Испытания врат (выбор на пороге) | `public/ludus/data/gate-trials.json`, `ludus-missions.js` | `godot/scripts/trial_core.gd`, хаб у лестницы | ✅ 205 проверок |
| Восемь страстей, признак распознавания, падение и трезвение | `ludus-passion.js`, `data/passions.json`, `ludus-antagonist-factory.js` | `godot/scripts/passion_core.gd`, калитка на дорогу во дворе | ✅ логика 17 925 проверок, встреча 161 проверка, 132 спрайта |
| Практика поста (врата 3) | `ludus-actions.js` (`keepFast`, по дням) | `HubCore.keep_fast`, стол трапезной во дворе | ✅ сверено с JS (фикстура хаба: неверный день, повтор в тот же день, следующий день) |
| «Атлас воды» — сквозной сюжет (99 узлов) | `docs/story/`, `public/ludus/data/atlas-99.json` | аналой в скриптории (`AtlasCore`) | ✅ чтение; ✅ летопись (выбор один раз), следы рыцаря на дне (дневник, амфора, астролябия, щит — писцу), хачкар (пульт гаснет), страница писца на аналое; в вебе следов нет; `.glb`-прокси следов — следующим |
| Миссии и хребет кампании | `ludus-missions.js`, `data/campaign-spine.json` | — | нет |
| Журнал действий | `ludus-journal.js` | — | нет |
| Листок подготовки к исповеди | `ludus-confession.js` | — | по ТАБУ №0.26 п. 9: в шлеме поля для записи нет, только вопросы; перенос вопросов — через хор ТАБУ №0.37 |
| Синхронизация с сервером (Firebase) | `ludus-outbox.js`, `ludus-rest.js` | — | нет: в шлеме сохранения локальные (`user://`) |
| Объёмные прокси 1300+ SVG и промтов | `public/vr/models/{loc,npc,obj,event,ui,gate,attr}` | — | нет: нужен отбор по ТАБУ №0.07, в шлем не всё |
| Карта озера 2D | `ludus-lake-view.js` | — | не идёт: в шлеме есть само озеро |
| Текстовая версия игры | Webtypikon | — | не идёт: размещение (нормы сессии) |
