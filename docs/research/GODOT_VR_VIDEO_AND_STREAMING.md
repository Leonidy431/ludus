# Godot в VR/XR: игры, видео, подгрузка контента, XR-стек (исследование, 2026-10-02)

Метод: веб-поиск (WebSearch) и поиск кода на GitHub. Большинство страниц
(godotengine.org, itch.io, w4games.com, claire-blackshaw.com, developers.meta.com,
forum.godotengine.org) прокси песочницы **не открывает**. Поэтому многие факты
взяты из выдержек поисковой выдачи, а не из прочитанной страницы. Такие строки
помечены «(выдача)». Отмечено «(прочитано)», если страница или код открыты напрямую.

## 1. Честный итог

- **Подтверждено (Godot + VR, есть источник): 13 проектов.** Из них коммерческий
  релиз в магазине Meta/Steam с открытым разбором — **1** (Augmental Puzzles).
  Остальные — itch.io/SideQuest, джемы, демо, некоммерческие.
- Ещё 5 названий (Gut Grease, dashton, Fugitive 3D, Paddle Frog VR, Pizza Panic)
  есть только в выдаче по каталогу itch.io «Oculus Quest + made with Godot»
  (52 результата). Подробностей о них нет: это не проверено.
- **Не подтверждено, не выдумываю:** «Gravity Lab» (VR-игра Mark Schramm, Rift/Quest/Steam,
  движок в источниках не назван), «Rhythm Dash», «Unbearable Ghosts», «Tafl Champions» —
  в выдаче не найдены. «Cubic Odyssey» — не VR, не проверялся. «Puzzling Places» — Unity, исключён.
- **Видео:** ни у одной найденной Godot-VR игры нет публичного описания того,
  как она играет видео. Есть только механизмы движка и плагины (раздел 3) и
  один тред форума про просадку кадров.
- **Подгрузка .pck по HTTP:** механизм документирован, но ни одна Godot-VR игра
  публично не описала, что им пользуется. Meta Asset Files в godot-meta-toolkit
  подтверждены кодом.

## 2. Таблица проектов

| Игра / приложение | Год | Шлем | Godot | Видео | Подгрузка / паки | XR-стек | Источник |
|---|---|---|---|---|---|---|---|
| **Augmental Puzzles** (Flammable Penguins, Claire Blackshaw) | Quest 2026-02-03, Steam 2026-02-13; порт PSVR2 в работе | Quest, PCVR (Steam), PSVR2 (порт) | свой форк; порт на 4.7 с переписанным render server (выдача) | не описано | не описано (ежедневные головоломки и таблица лидеров — вероятно, сетевые данные; *вывод*) | OpenXR; свой FastText вместо Label3D (один draw call на текст); захват viewport через blit-конвейер компоновщика (PR для Vulkan и GLES); GDExtension против правки движка; «≈ £80k труда сверх Unity/Unreal» | https://claire-blackshaw.com/blog/2026/04/shipping_vr_godot/ ; https://www.claire-blackshaw.com/blog/2026/07/shipping-godot-vr-and-porting-to-psvr2-a-partial-post-mortem/ ; https://claire-blackshaw.com/blog/2025/08/fast_text/ ; https://talks.godotengine.org/godotcon-ams-2026/talk/VG9FRB/ (выдача) |
| **Friday Night Funkin' VR** (Ben Kurtin) | 2021–2022 | PCVR, Quest 1/2 (itch, SideQuest) | Godot 3 (*вывод*: по дате) | не описано | — | — ; на Quest жалобы на лаги, оптимизация нот «данными вместо объектов» | https://godotengine.org/article/godot-showcase-ben-kurtin-fnf-vr/ ; https://thisisbennyk.itch.io/funkin-vr (выдача) |
| **SOMAR XR** (Collabora: F. Plourde, D. Castellanos) | 2024–2025 | автономные шлемы + Google Cardboard через Monado | Godot 4 (*вывод*) | — | — | OpenXR, рантайм Monado; опыт про **подводный шум** (звук — главный канал) | https://godotengine.org/article/godot-showcase-somar/ ; https://www.khronos.org/news/permalink/making-the-invisible-audible-building-an-openxr-experience-for-ocean-protection (выдача) |
| **Expedition to Blobotopia** (D. Snopek, L. Lang) | 2025 (Godot Wild Jam #81) | Quest 3 | Godot 4, **сделана целиком в редакторе на Quest 3** | — | — | OpenXR, физика | https://dsnopek.itch.io/expedition-to-blobotopia ; https://talks.godotengine.org/godotcon-boston-2026/talk/YHRHSN/ (выдача) |
| **Beep Saber** (NeoSpark314) | ~2020 | Quest, PCVR | 3.2; есть форк на 4.3 + OpenXR | — | — | Oculus mobile → OpenXR | https://awesome.ecosyste.ms/projects/github.com%2Fneospark314%2Fbeepsaber (выдача) |
| **Voxel Works Quest** (NeoSpark314) | ~2020–2022 | Quest | Godot 3 | — | — | hand tracking, бег на месте; **снят с SideQuest: обновление Meta сломало игру** | https://neospark314.itch.io (выдача) |
| **Open Saber** (leandrodreamer) | — | VR HMD | Godot | — | — | — | https://leandrodreamer.itch.io/open-saber (выдача) |
| **Open Target Shooter VR** (teddybear082) | — | PCVR (SteamVR) + Quest APK | Godot, «Godot OpenXR» | — | — | OpenXR | https://teddybear082.itch.io/open-target-shooter-vr (выдача) |
| **Quest Arena** (yxt0531) | — | Quest | Godot | — | — | — | https://yxt0531.itch.io/quest-arena (выдача) |
| **Godot VR Range** (nubbo) | — | VR | Godot 4 (демо XR-тулкита) | — | — | godot-xr-tools (*вывод*: «demo VR toolkit») | https://nubbo.itch.io/godot-xr-range (выдача) |
| **Godot TongueDrum VR** (yaelmartin) | — | VR | Godot | — | — | — | https://yaelmartin.itch.io/godot-tonguedrum-vr (выдача) |
| **3D Tic Tac Toe** | 2024 | Quest 1/2/3 (SideQuest) | Godot | — | — | — | https://forum.godotengine.org/t/3d-tic-tac-toe-for-quest-1-2-and-3/87624/8 (выдача) |
| **Portal** (kfj001), просмотрщик иммерсивных медиа | 2026 | Quest | **4.6** | просмотр медиа (как именно — не выяснено) | — | OpenXR, hand tracking | https://git.westerntechnologies.duckdns.org/kfj001/portal (выдача; источник слабый) |
| *Godot Editor на Horizon Store* (инструмент, не игра) | 2024-12 (early access) | Quest 3 / Pro, Horizon OS ≥ v69 | 4.4 | — | — | редактор + экспорт прямо в шлеме; порт сделал инженер Meta Fredia Huya-Kouadio | https://godotengine.org/article/godot-editor-horizon-store-early-access-release/ ; https://www.uploadvr.com/godot-engine-standalone-on-quest-horizon-os/ (выдача) |

Только по выдаче каталога itch.io, без проверки: Gut Grease, dashton, Fugitive 3D,
Paddle Frog VR, Pizza Panic, DestCraft, While Waiting, Dark City, Rocketeer Training —
https://itch.io/games/input-oculus-quest/made-with-godot

## 3. Технологии — что есть на самом деле

### 3.1 Видео
| Средство | Что это | Android/Quest | Источник |
|---|---|---|---|
| `VideoStreamPlayer` + Theora | единственный формат ядра (Ogg Theora + Vorbis), декодирование на CPU | работает, но дорого | https://docs.godotengine.org/en/stable/tutorials/animation/playing_videos.html (выдача) |
| Тред форума «Big framerate drop when playing a video on XR project» | 360-видео в SubViewport на сфере: 5760×2880 роняло кадры, 2880×1440 — норма | XR | https://forum.godotengine.org/t/solved-big-framerate-drop-when-playing-a-video-on-xr-project/69189 (выдача) |
| **`OpenXRCompositionLayer.use_android_surface`** + `get_android_surface()` | слой композиции получает `android.view.Surface`; в него можно рисовать Android-плеером (MediaPlayer/ExoPlayer/MediaCodec) — **аппаратное декодирование, картинку рисует компоновщик OpenXR, а не рендер Godot** | только Android, только в активной OpenXR-сессии | **(прочитано)** `modules/openxr/doc_classes/OpenXRCompositionLayer.xml` в godotengine/godot; страница класса в docs 4.4+ |
| GDE GoZen (Voylin) | FFmpeg-GDExtension, MP4 и др., сетевой поток HTTPS, альфа-видео | **Android есть**; Godot 4.3+; **LGPL-2.1**; про аппаратное декодирование не сказано | **(прочитано)** https://github.com/VoylinsGamedevJourney/gde_gozen |
| EIRTeam.FFmpeg | FFmpeg-GDExtension для Godot > 4.1, h264 (патентные вопросы) | **Android не поддерживается** (выдача) | https://eirteam-docs.readthedocs.io/en/latest/documentation/ffmpeg/ffmpeg_getting_started.html |
| Android-плагины v2 (Godot 4.2+) | путь к JNI/Kotlin/MediaCodec из GDScript; шаблон GDExtension-Android | Android | https://github.com/m4gr3d/GDExtension-Android-Plugin-Template (выдача) |

Готового открытого плагина «MediaCodec → Godot на Quest» поиск не нашёл (не значит, что его нет).

### 3.2 Подгрузка контента
- `ProjectSettings.load_resource_pack()` + `HTTPRequest`/`HTTPClient`: DLC, патчи
  и моды через .pck/.zip; вызывать в `_init()` автолоада; второй аргумент `false`
  запрещает паку перекрывать файлы. https://docs.godotengine.org/en/4.7/tutorials/export/exporting_pcks.html (выдача)
- **godot-meta-toolkit** (W4 Games, спонсор Meta, MIT, Godot 4.3+): обёртка
  Meta Platform SDK (v71 → v72 → v77), экспорт-плагин, Meta XR Simulator.
  **Asset Files подтверждены кодом**: классы `MetaPlatformSDK_AssetFileDownloadResult`,
  `..._AssetFileDownloadUpdate`, `..._AssetFileDownloadCancelResult`,
  `..._AssetFileDeleteResult` (поиск кода GitHub, прочитано). Это официальный путь
  DLC/доп. файлов для игры из Horizon Store. https://github.com/godot-sdk-integrations/godot-meta-toolkit ;
  https://godotengine.org/article/godot-xr-update-feb-2025/
- OBB: в найденных источниках про Godot+Quest не встретился.

### 3.3 XR-стек и рендер
- OpenXR в ядре; vendor-функции Meta/Pico/HTC — в `godot_openxr_vendors`
  (4.1.0: OpenXR 1.1.49; 5.1, май 2026: Android XR наравне с Quest).
  Passthrough и его фильтры, геометрия passthrough, Scene Discovery — в vendors-плагине.
  `XRHandModifier3D` заменил `OpenXRHand` (4.3). https://godotengine.org/article/godot-xr-update-oct-2024/ ;
  https://www.w4games.com/blog/w4-games-news-1/godot-4-3-released-enhancing-meta-quest-support-39 (выдача)
- **Рендер на Quest.** Долго рекомендовался Compatibility (OpenGL ES, дешёвый MSAA на TBDR).
  Доклад W4 «Where Every Millisecond Counts» (GodotCon Boston, 2026-07-22):
  на Quest 3 вначале OpenGL 72/66/72 fps, Vulkan Mobile 36/36/60; работа W4
  удвоила кадры Vulkan; с 4.7 для новых XR-проектов советуют **Mobile**;
  фовеация работает в Vulkan на Android (VRS), в 4.7 — Vulkan subsampled images.
  https://www.w4games.com/blog/w4-games-news-1/where-every-millisecond-counts-optimizing-godot-for-standalone-xr-159 ;
  https://talks.godotengine.org/godotcon-boston-2026/talk/TDJU8V/ (выдача)
- Godot 4.7 (июнь 2026): улучшены композиционные слои; один проект — Quest,
  Steam Frame, Pico, Galaxy XR; профиль Pico 4. https://vr.org/articles/godot-4-7-xr-steam-frame-android-xr-open-source-2026 (выдача)
- visionOS-экспорт с 4.5 — **только плоское окно, иммерсив не поддержан**.
  https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_visionos.html (выдача)
- Pico: OpenXR-совместим с 2023; выпущенной Godot-игры для Pico поиск не нашёл.

### 3.4 Спонсорство Meta (хронология)
- Грант Facebook Reality Labs на VR в Godot (≈2020): https://godotengine.org/article/godot-engine-receiving-support-funded-facebook-reality-labs/
- 2024-03-14: W4 Games + Meta — OpenXR, плагин SDK Quest, оптимизированный шаблон, примеры:
  https://www.businesswire.com/news/home/20240314670069/en/
- 2024-12: редактор Godot в Horizon Store (Quest 3/Pro).
- 2025-02: Godot Meta Toolkit.
- 2026: W4 работает с Google над Android XR.
  https://www.w4games.com/blog/w4-games-news-1/w4-games-works-with-the-androidxr-team-and-the-godot-foundation-to-improve-godots-android-xr-support-123

### 3.5 Звук
Ни в одном источнике не нашлось особого аудиостека Godot-VR игр. Используется
штатный AudioStreamPlayer3D. SOMAR — пример, где звук и есть содержание
(подводный шум). Это не проверено глубже.

## 4. Уроки для нашего проекта
(Godot 4.7.1, своя сборка без VideoStreamPlayer/Theora, флипбук-атласы,
.pck по HTTP из GitHub Releases, Quest 3S)

1. **Отказ от Theora верен.** Ни одна найденная Godot-VR игра не описывает
   Theora как рабочий путь. Программное декодирование на CPU в XR уже давало
   просадку (тред форума). Для коротких петель (вода, огонь лампы, муть) флипбук-атлас
   в сжатой текстуре (ASTC/ETC2) дешевле и детерминирован.
   *Вывод:* атлас 2048² в ASTC 4×4 ≈ 4 МиБ (+⅓ на мипы). Это надо мерить ревизором (ТАБУ №0.011).
2. **Если понадобится длинное видео** (кадры ROV, «летопись»), не возвращать Theora.
   Подходящий путь — `OpenXRCompositionLayer` с `use_android_surface` (ядро, 4.4+)
   и Android-плагин v2 с MediaPlayer/ExoPlayer: аппаратный декодер XR2 Gen 2, рисует компоновщик,
   нагрузка на рендер почти нулевая. Ограничения: только в активной OpenXR-сессии, только Android,
   слой — плоскость/цилиндр/экваториальная проекция, а не текстура в сцене.
   *Вывод*, в наших источниках нет игры, которая это доказала, — нужен прототип и замер на шлеме.
   GDE GoZen работает на Android, но лицензия LGPL-2.1 и FFmpeg, а аппаратного декода нет в описании.
   EIRTeam.FFmpeg на Android не работает.
3. **.pck по HTTP — штатный механизм**, публичных VR-примеров нет. Что нужно:
   - пак собирать тем же движком и версией (наша сборка 4.7.1);
   - качать `HTTPRequest` в `user://` (GitHub Releases отвечает редиректом на CDN,
     поэтому `max_redirects` > 0), сверять SHA-256 до `load_resource_pack`;
   - грузить пак в `_init()` автолоада; крупные сцены из него — через
     `ResourceLoader.load_threaded_request` (ТАБУ №0.014);
   - выкладка на GitHub годится для sideload. Для Horizon Store официальный путь —
     Asset Files через godot-meta-toolkit (подтверждено кодом). Правила магазина
     о скачиваемом коде (GDScript внутри .pck) **не проверены**: сверить с VRC Meta до подачи.
4. **Рендер:** под 4.7 советуют Mobile (Vulkan) с фовеацией. До доклада W4 Vulkan
   был вдвое медленнее OpenGL на Quest 3. Свою сборку держать на 4.7.x, иначе
   мы теряем эти оптимизации. Quest 3S — тот же XR2 Gen 2, что у Quest 3 (*вывод*),
   поэтому числа W4 к нему близки, но подтверждает только замер в шлеме.
5. **Augmental Puzzles учит:** текст в VR дорог (Label3D заменили своим FastText,
   один draw call); форк движка стоит денег и усложняет обратное слияние; лучше
   GDExtension, чем правка ядра, где это возможно. Godot выбирают как MIT-основу
   своего стека, а не как готовый AAA.
6. **Voxel Works учит:** обновление Horizon OS может сломать сторонний билд.
   Держать vendors-плагин свежим и проверять каждый релиз ОС.
7. **visionOS** нам не цель: экспорт Godot там только плоский.
