# Решение: семь способов уложить игру в шлем — по опыту других разработчиков и 48 параметрам проекта (2026-10-02)

Поручение оператора (дословно): «погугли как другие разработчики решают с таким небольшим объемом памяти поищи 7 вариантов из 999 по параметрам проекта и зачем шлему OBB»; «наш шлем 3s ocolus»; «подбери оператору лучший шлем и поставь в долг замена железа. тестируем на тех технологиях и железе что есть пока».

**Конституция:** ФОРМА (что шлем может нести и чего стоит нести больше) → ДЕЙСТВИЕ (каждый известный способ взвешен по параметрам самого проекта) → ЦЕЛЬ (голоса и места учения доходят до шлема целиком, без рывков и без сети).

## Сначала факт: памяти у шлема не мало — мал наш собственный бюджет

| Что | Шлем оператора: Meta Quest 3S | Источник |
|---|---|---|
| Чип | Snapdragon XR2 Gen 2 (как у Quest 3) | [Road to VR](https://roadtovr.com/quest-3s-quest-3-quest-2-specs-compared/) |
| Экран | 1832 × 1920 на глаз (как у Quest 2), линзы Френеля | там же |
| Оперативная память | 8 ГБ, из них приложению — **5,75 ГиБ** (предел по PSS для Quest 3 и 3S) | [Meta: Memory (RAM)](https://developers.meta.com/horizon/documentation/unity/po-memory-ram/) |
| Накопитель | 128 или 256 ГБ | [Adorama](https://www.adorama.com/meta-quest-3s-128gb-vr-headset/p/meq3s128g) |
| APK в магазине | до 1 ГБ | [Meta: Publish an APK](https://developers.meta.com/horizon/resources/publish-apk/) |
| OBB | один файл до 4 ГБ; кроме него — обязательные файлы ресурсов до 4 ГБ каждый (рекомендуется до 2 ГБ) | [Meta: Asset files](https://developers.meta.com/horizon/documentation/native/ps-assets/) |

Наши бюджеты строже шлема в десятки раз, и это выбор проекта, а не предел железа: APK 128 МиБ, куча сцены 64 МиБ, текстуры 32 МиБ (`docs/APK_REQUIREMENTS.md`). Их смысл — плавность кадра и быстрые обновления, а не нехватка памяти.
- Предубеждение: «у шлема мало памяти, значит, режем всё».
- Контраргумент: 5,75 ГиБ на приложение и 1 ГБ APK; тесно только в нашем же бюджете.
- Почему: бюджеты остаются как мера плавности. Решение по ним — Д-7 и новая строка Д-16 в долге оператора.

## Зачем шлему OBB

OBB — второй файл рядом с APK. Его магазин Meta сам скачивает при установке и кладёт в `/Android/obb/<пакет>/`. Он нужен, когда:
1. **APK перерастает 1 ГБ** — без OBB или файлов ресурсов игру нельзя выложить в магазин;
2. **обновления кода частые, а данные тяжёлые и редкие.** Meta прямо советует делить большое приложение на APK и файлы расширения: быстрее загрузка для разработчика и патч для игрока ([Meta: Asset files](https://developers.meta.com/horizon/documentation/native/ps-assets/)).

Для нас OBB — способ **доставки** пакетов ресурсов Godot через магазин. Сами данные делаются как пакеты `.pck` (способы 3 и 6 ниже). При ручной установке, как сейчас, тот же пакет кладётся `adb push`. Поэтому в выборе OBB стоит ниже пакетов: он нужен в день выхода в магазин, а пакеты нужны уже сейчас.

## Пул и выбор

Команда: `python3 scripts/decisions/size_strategy_choice.py`; в CI — `--check`.

- Найдено 15 приёмов других разработчиков и самого проекта, каждый с источником. С семью видами содержимого (движок, голоса EN, голоса RU, музыка и хор, модели, текстуры, эффекты) они дают **35 применимых пар** — это весь честный пул, а не 999 (ТАБУ №0.07 п. 2).
- Каждая пара оценена по 48 параметрам `scripts/decisions/engine-params-48.json`. Параметры, которые приём не затрагивает, получают одинаковый балл у всех пар.
- Берутся 7 лучших, не больше одной пары на приём, чтобы семь ответов были разными.

| № | Баллы (из 178) | Способ | К чему | Источник |
|---|---|---|---|---|
| 1 | 170 | Оптимизация по размеру и thin LTO | движок | [Godot forums: extreme APK size reduction](https://godotforums.org/d/21005-extreme-attempts-at-reducing-the-apk-size-of-the-game) |
| 2 | 169 | Ogg Vorbis с потоковым декодированием | голоса EN (и RU, музыка) | [Zilliz: compression for VR assets](https://zilliz.com/ai-faq/what-compression-techniques-are-effective-for-vr-assets) |
| 3 | 166 | Голоса каждого языка — отдельным пакетом | голоса EN | [Meta: Asset files](https://developers.meta.com/horizon/documentation/native/ps-assets/); [Godot: Exporting packs](https://docs.godotengine.org/ru/4.5/tutorials/export/exporting_pcks.html) |
| 4 | 165 | Свой шаблон движка без неиспользуемых модулей | движок | [Godot: Compiling for Android](https://godot.readthedocs.io/ru/latest/contributing/development/compiling/compiling_for_android.html); там же форум (APK ~30 → ~7 МБ) |
| 5 | 165 | Бюджет памяти по PSS против предела шлема 5,75 ГиБ | движок, модели, текстуры, звук | [Meta: Memory (RAM)](https://developers.meta.com/horizon/documentation/unity/po-memory-ram/); [Meta blog: Quest memory usage](https://developers.meta.com/horizon/blog/getting-a-handle-on-meta-quest-memory-usage/) |
| 6 | 161 | Пакеты ресурсов Godot (`.pck`) через `load_resource_pack` | голоса, музыка, модели | [Godot: Exporting packs, patches, and mods](https://docs.godotengine.org/ru/4.5/tutorials/export/exporting_pcks.html) |
| 7 | 161 | Сжатие текстур на GPU (ETC2/ASTC) | модели, текстуры | [Meta blog: Top tips from Arm](https://developers.meta.com/horizon/blog/top-tips-from-arm-for-vr-asset-optimization/) |
| следующие | 160 | прокси вдали, полная модель вблизи | модели | ТАБУ №0.32; Б-2 |
| | 159 | только arm64-v8a | движок | [Godot forums 24453](https://godotforums.org/d/24453-optimize-the-size-of-the-apk-for-google-play-store) (уже сделано) |
| | 156 | файл расширения OBB | голоса, музыка, модели | [Meta: Publish an APK](https://developers.meta.com/horizon/resources/publish-apk/) |

Что ниже и почему:
- докачка после установки (DLC) — нужна сеть, а игра работает без сети (ТАБУ №0.26, №0.02);
- сжатые нативные библиотеки — вес переезжает на диск шлема;
- Crunch/Basis — помогает только скачиванию, не памяти.

## Что делаем сейчас, на Quest 3S

1. **Движок:** способы 1 и 4 — свой шаблон (`docs/HLD_ENGINE_BUILD_2026-10-02.md`). Сборка подбирается так, чтобы у `lib/*.so` был запас не меньше 10 % (параметр e01).
2. **Английские голоса:** способы 2, 3 и 6. Пакет `voice-en.pck` подключается при запуске, если он есть: в шлеме — из `/Android/obb/org.ludus.dive/` (сейчас кладётся через `adb push`, в магазине придёт как OBB) или из `user://packs/`. Без пакета игра идёт на тексте. Механизм делается сейчас, записи придут с озвучкой.
3. **Память:** способ 5 — сверять пик PSS в шлеме с пределом 5,75 ГиБ (OVR Metrics, долг Д-5).
4. **Текстуры:** способ 7 уже действует (ETC2/ASTC при импорте).

## Шлем для оператора — замена железа (долг Д-16)

| Шлем | За | Против | Источник |
|---|---|---|---|
| **Meta Quest 3, 512 ГБ — выбор** | тот же магазин и тот же чип XR2 Gen 2, что у 3S: замеры на 3S остаются в силе; линзы-блины и 2064 × 2208 на глаз — самая тяжёлая цель для GPU среди шлемов Meta, на ней видно худший кадр; цветной mixed reality | дороже 3S | [PC Gamer: Best VR headset 2026](https://www.pcgamer.com/best-vr-headset/); [Road to VR](https://roadtovr.com/quest-3s-quest-3-quest-2-specs-compared/) |
| Samsung Galaxy XR (Android XR) | открытый OpenXR, WebXR | другой магазин и система; сборку для шлема пришлось бы переносить | [Three.js resources 2026](https://threejsresources.com/blog/best-vr-headsets-with-webxr-support-for-threejs-developers-2026) |
| Steam Frame | 2160 × 2160 на глаз, до 144 Гц | SteamOS, не магазин Meta | [VR Expert 2026](https://vrx.vr-expert.com/best-vr-headsets-of-2026-standalone-pcvr-and-enterprise-picks/) |
| Pico 4 Ultra | тот же чип, AMOLED | меньше экосистема, не магазин Meta | [TechRadar](https://www.techradar.com/computing/virtual-reality-augmented-reality/pico-4-ultra-vs-meta-quest-3-the-battle-of-the-best-mid-range-vr-headsets) |

- Предубеждение: «надо самый мощный шлем».
- Контраргумент: игра идёт в магазин Meta; тестировать нужно на тех шлемах, что у игроков. Quest 3 — верхняя граница нагрузки, а 3S — массовая.
- Почему: Quest 3 как второй тестовый шлем, 3S остаётся. Пока замены нет, тестируем на 3S (оператор, 2026-10-02).
