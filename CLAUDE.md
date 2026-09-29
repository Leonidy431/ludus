# ludus — ядро правил (CLAUDE.md)

## 🛑 ТАБУ №0 (ВЫШЕ ВСЕХ): КОНСТИТУЦИЯ ПРОЕКТА — DEMIURGIC CAUSALITY

**Дата:** 2026-09-28  
**Приоритет:** ВЫШЕ ВСЕХ ОСТАЛЬНЫХ ПРАВИЛ  
**Статус:** ФУНДАМЕНТАЛЬНЫЙ — не может быть изменён без явного разрешения

---

### Формулировка Конституции

Ludus — это **теологическая ролевая система**, где каждая сущность (персонаж, NPC, локация, система) подчиняется принципу **Demiurgic Causality**:

```
ФОРМА (Attributes) → ДЕЙСТВИЕ (Behavior) → ЦЕЛЬ (Spiritual Teaching)
```

**Это означает:**

1. **ФОРМА (Attributes):** Каждый персонаж/NPC имеет набор атрибутов (Wisdom, Faith, Dexterity, Constitution, Charisma, Cunning, Erudition), которые определяют его онтологический статус в сотворённом мире.

2. **ДЕЙСТВИЕ (Behavior):** На основе ФОРМЫ выполняются действия — диалоги, выбор пути, боевые решения, молитвы. Действие должно быть логическим следствием ФОРМЫ.

3. **ЦЕЛЬ (Spiritual Teaching):** Каждое действие ведёт к духовному обучению (через диалоги с NPCs, решение загадок, достижение knowledge gates). ЦЕЛЬ — освещение (theoria).

---

## 🛑 ТАБУ №0.1: ТЕХНОЛОГИЯ «СЫРЬЁ → 35 %» (правило оператора по совету юриста, 2026-09-29)

**Приоритет:** сразу после Конституции, выше всех остальных правил.

Графика, звук и другие объекты из сторонних источников (например, из репозиториев в `backlog`) считаются **сырьём**. В игру они попадают только через конвейер `scripts/raw_assets/`, который запускается на раннере (`.github/workflows/raw-asset-intake.yml`):
1. **Приём:** скачиваются только изображения и тексты лицензий; ревизия источника фиксируется.
2. **Переработка:** каждый объект изменяется **не менее чем на 35 %** по **обоим** измерениям: цвет в пределах объекта **и** форма (1 − IoU силуэтов). Одна перекраска не проходит.
3. **Патентная формула:** для каждого объекта формируется перечень признаков в стиле «отличающийся тем, что». Способ описан в `docs/PATENT_FORMULA_RAW_ASSET_PIPELINE.md`.
4. **Реестр лицензий:** источник, ревизия, лицензия и измеренные проценты записываются в `THIRD_PARTY_NOTICES.md`.

**Табу:**
- Сырьё, не прошедшее конвейер, в игру не попадает.
- Нельзя заявлять «изменено на 35 %» без измерения конвейером.
- Порог 35 % — внутреннее технологическое правило. Лицензионные обязанности источника (указание автора, share-alike, раскрытие исходника для GPL/AGPL) он **не снимает**. Реестр ведётся всегда.
- Машинная тонировка годится для учёта. Игровые объекты рисуются художниками по мотивам сырья, а конвейер измеряет их отличие от источника.

---

## 🛑 ТАБУ №0.5: CHORUS DECISION FRAMEWORK — АРИСТОТЕЛЕВА ДИАЛЕКТИКА

**Дата внедрения:** 2026-09-29  
**Приоритет:** ВЫШЕ, чем локальные оптимизации  
**Применение:** Все критические решения на фазах разработки

### Принцип: Множественные Голоса, Одно Решение

Когда стоит выбор между вариантами реализации (выбор из 24 вариантов из 999 по 32 параметрам проекта):

**ШАГ 1 — Слушать хор (Chorus Auditio):**
- Perspective A (Инженер): "Как реализовать технически оптимально?"
- Perspective B (Тестировщик): "Как это протестировать без слепых зон?"
- Perspective C (Пользователь): "Что это значит для игрока/учебного опыта?"
- Perspective D (Архитектор): "Как это встраивается в систему Demiurgic Causality?"

**ШАГ 2 — Найти один вариант (Dialectical Synthesis):**
- Вариант правильный не потому, что все согласны, а потому что:
  1. Соответствует Constitution (Demiurgic Causality)
  2. Тестируется полностью
  3. Работает для игрока
  4. Масштабируется (32 параметра проекта учтены)

**ШАГ 3 — Документировать решение (Why, not What):**
- Запиши NOT: "Сделали X"
- Запиши: "Выбрали X потому что A+B+C+D согласились что..."
- Это правило раз в час критических решений

**ПРИМЕРЫ:**

| Решение | Инженер | Тестировщик | Пользователь | Архитектор | Консенсус |
|---------|---------|------------|--------------|-----------|-----------|
| **gap_014: 10 vs 20 players** | "20 = больше работы" | "20 = лучше coverage" | "не видит разницу" | "20 лучше для Demiurgic edges" | ✅ TAKE 20 |
| **gap_016: baseline targets** | "50ms оптимистично" | "нужно verify on Quest 3" | "не должен ждать >500ms" | "форма (attributes) → действие (latency) → цель (UX)" | ✅ TARGETS OK, VERIFY Oct 1 |
| **gap_011: error handling** | "14 status codes покрывает" | "10 scenarios еще не tested" | "ошибки должны быть понятны" | "ФОРМА error → ЦЕЛЬ: game continues or user understands" | ✅ IMPLEMENT + TEST Oct 1 |
| **gap_012: 13 test scenarios** | "много, можно меньше" | "13 = min для critical path" | "нужны user-facing flows" | "6 functionality + 2 security + 3 error + 2 data = complete" | ✅ TAKE 13, ALL OCT 1 |

### Правило Применения (Binding Rule)

- **На каждой фазе разработки:** применяй хор (Chorus) для выбора между вариантами
- **Частота:** минимум раз в час для критических решений
- **Документация:** каждое крупное решение = запись "Почему выбрали X (A+B+C+D согласны)"
- **Табу:** не принимай решение, если хоры не согласны (или не написал почему один хор overridden)

---

## 🛑 ТАБУ №0.6: АУДИТ-ХОР 7 АГЕНТОВ РАЗ В 6 ЧАСОВ — ГРАФИКА, ЗВУК, ИНТЕРФЕЙС

**Дата внедрения:** 2026-09-29
**Приоритет:** выше всех правил, кроме ТАБУ №0 и №0.5
**Частота:** каждые 6 часов активной работы над проектом (и перед любым заявлением «готово к тесту»)

**Процедура (обязательна целиком):**
1. **Поднять dev-сервер** и открыть реальную страницу: `cd public && python3 -m http.server 8080`, затем Playwright (Chromium из `/opt/pw-browsers`) → скриншоты, console errors, HTTP 4xx/5xx.
2. **Хор 7 агентов** (Workflow). 24 агента оказались слишком медленными (2026-09-29: за всё время вернулся 1 голос из 24), поэтому хор ограничен 7 голосами. Шесть голосов сами правят код, каждый только свои файлы, поэтому правки не конфликтуют. Седьмой голос только читает. Каждый голос приводит доказательства `file:line` и наблюдаемый runtime-результат до и после правки:
   1. **boot-shell** (`index.html`, `sw.js`): контракт с модулями, spinner, error boundary, offline/SW, XSS.
   2. **game-core** (`ludus-game.js/.css`): 7 атрибутов Конституции, Firebase-fallback, XSS, поля бэкенда.
   3. **dialogue** (`ludus-npc-dialogue-*.js`, `ludus-dialogue.css`): поток диалога, FORM-гейты, a11y, Quest 3.
   4. **audio** (`ludus-audio-manager.js`): autoplay, 4-слойный микс, пространственный звук, ассеты, утечки, смысловые звуки.
   5. **visual-system** (`ludus-design-system.css`): контраст, темы, reduced-motion, типографика (кириллица, греческий, ЦСЯ, CJK), Quest 3 viewport 1832×1920.
   6. **rov-lake** (`rov-lake-manager.js/.css`): телеметрия, единицы измерения, детерминированные бонусы.
   7. **repo-cartographer** (только чтение): карта всех репозиториев и разделение «Meta-сборка (ludus)» и «Webtypikon (только Конституция и текстовая версия игры)».
   - Код пишется сразу, комментарии оформляются по PEP 8: полные предложения, объясняют «почему», строки не длиннее 79 символов. Python-код должен проходить pycodestyle.
3. **Синтез ≤ 99 слепых зон** — дедупликация, проверка P0/P1 по коду, ранжирование. **Не добивать до 99** выдуманными пунктами.
4. **Исправить** все P0 и те P1, что в пределах задачи; каждое исправление подтвердить повторным прогоном Playwright (до/после).
5. **Записать** результат в `docs/BLINDSPOTS_AUDIT_<дата>.md`: найдено / исправлено / отложено и почему.
6. **Раз в час — промежуточное сравнение до/после:** одинаковые кадры desktop 1280×720, Quest 3 1832×1920 и mobile 390×844. «До» — исходная версия из git (:8081), «после» — рабочее дерево (:8080). Монтаж отправляется оператору. Сравнение запускает Routine «Ludus hourly before/after comparison».
7. **Графика:** в первую очередь переиспользуются собственные SVG проекта (webtypicon2 `public/game/art` → `public/ludus/art`). Чужие ассеты из списка в `backlog` (freeciv, wesnoth, flare и др.) — это сырьё: в игру они попадают только через конвейер ТАБУ №0.1 (35 % по цвету и форме, патентная формула, реестр лицензий).

**Табу:**
- Нельзя писать «✅ FIXED / tests pass / GO» без вывода команды, который это доказывает (`tsc`, `jest`, Playwright-лог, скриншот).
- Нельзя считать фронтенд проверенным, если страница не открывалась в браузере.
- Нельзя пропускать цикл из-за «нет времени» — пропуск фиксируется в журнале аудита с причиной.

> Урок 2026-09-29: документы Phase 3 заявляли «gap_001–003 FIXED», «Jest pass», «ZERO BLOCKERS», а первый реальный прогон показал пустой экран (index.html вызывал несуществующий `LudusGame.init`, 7 ассетов отсутствовали в репо) и 8/10 падающих Jest-тестов. Этот ТАБУ существует, чтобы так больше не было.

---

### Принципы реализации

#### 1. Диалоги NPC (Разговоры в аппарате)

- **Каждый диалог учит** — не просто рассказывает, а передаёт знание через диалектику (Sokratic method)
- **Ветвление по ФОРМЕ** — разные ответы для Wisdom ≥ 8 vs < 5; Faith влияет на доступные пути
- **NPC имеют позицию** — Elder Sergius следует Hesychasm, Theodora проповедует практику, каждый учит своим путём
- **Память** — NPCs помнят выбор игрока, повторяющиеся встречи углубляют отношение (progression)

#### 2. Звуки (Хором гуру — смачно и красиво)

- **Звук отражает ФОРМУ** — высокие ноты для духовного подъёма (Wisdom), низкие для укоренения (Constitution)
- **Музыка учит** — православная литургия, паузы для размышления, хоральные полосы как голос монастыря
- **Никакого "чистого" дизайна** — каждый SFX имеет смысл (звон колокола = молитва передана, шум ветра = изменение миров)
- **Пространственный звук** — NPC голос идёт из их позиции в сцене, молитва окружает игрока в 3D

#### 3. Система атрибутов

**7 атрибутов, каждый отражает аспект духовного роста:**

| Атрибут | Значение | Источник (Patristic) | Диалоговое влияние |
|---------|----------|----------------------|-------------------|
| **Wisdom** | Понимание учений, Noesis | Gregory of Nyssa | Доступ к глубоким диалогам, разгадка тайн |
| **Faith** | Вера, πίστις | Pseudo-Dionysius | Одобрение от духовных NPC, чудеса |
| **Dexterity** | Ловкость действия, практика | John of Damascus | Успех в ритуалах, быстрые решения |
| **Constitution** | Выносливость, постоянство | Isaac the Syrian | Пост, долгие молитвы, сопротивление |
| **Charisma** | Влияние, лидерство | Gregory the Theologian | Убеждение, создание общины |
| **Cunning** | Хитрость, стратегия | (Редко, не одобряется) | Тайные пути, исключения |
| **Erudition** | Знание текстов | Synaxarion tradition | Разблокировка knowledge gates |

**Источник и использование:**
- Диалоги с NPCs дают +1 до +5 к атрибутам (зависит от глубины выбора)
- Knowledge gates требуют порога (Wisdom ≥ 7 для access to Apophatic Theology)
- Никаких случайных бросков — только выбор и его следствия

#### 4. Knowledge Gates (Ворота знания)

Система **Gating** проводит игрока через 6 уровней духовного роста:

```
1. Foundational (основание) — Евангелие, азы веры
2. Liturgical (литургическое) — Служба, молитва в общине
3. Ascetic (аскетическое) — Пост, монашеская дисциплина
4. Contemplative (созерцательное) — Noesis, молитва сердца
5. Mystical (мистическое) — Theoria, видение Бога
6. Apophatic (апофатическое) — Отрицательная теология, молчание
```

Каждый уровень требует:
- Определённых атрибутов (Wisdom ≥ 4, 6, 8, 10, 12, 14+)
- Диалогов с конкретными NPCs
- Выполнения ритуального действия (молитва, пост, медитация)

#### 5. Firestore как "Небеса" (Database Shape)

Структура должна отражать теологию:

```
ludus/
├── players/{playerId}
│   ├── form: { wisdom, faith, dexterity, … }
│   ├── actions: { prayerCount, fastDays, meditationHours }
│   └── goal: { currentGate, enlightenmentLevel, npcRelations }
├── npcs/{npcId}
│   ├── name, theology, role
│   ├── dialogueTree: { nodes, branches }
│   └── memory: { playersInteracted, depth }
├── knowledgeGates/{gateId}
│   ├── level, requirements, theologicalTheme
│   └── testNode: { question, attributes_required }
└── telemetry/{rovId}
    ├── depth, temperature, pressure
    └── playerInsight: { attribute, bonus }
```

---

## Практические следствия для разработки

### A. Диалоги (NPC_DIALOGUE_SYSTEM.md)

✅ **Требуется:**
- Каждый NPC имеет полное диалоговое дерево (≥ 5 узлов)
- Ветвления по ФОРМЕ (Wisdom, Faith, Dexterity checks)
- Бонусы атрибутов за правильные ответы
- Память (NPC помнит прошлые встречи)
- Соответствие паtristic источникам (Gregory of Nyssa, Isaac the Syrian и т.д.)

❌ **Запрещено:**
- Бессмысленные диалоги ("Привет!" без учения)
- Случайные бонусы (только выбор → следствие)
- NPC без позиции (все обязаны иметь теологическую позицию)

### B. Звуки (SOUND_DESIGN_SYSTEM.md)

✅ **Требуется:**
- Минимум 40 музыкальных треков (12 ambient + 8 NPC theme + 6 gates + 9 attributes + 5 story moments)
- 12 хоровых произведений (32-голосный SATB)
- Динамическое смешивание (музыка → диалог → SFX → амбиенс)
- Пространственный звук (биинауральная обработка для Quest 3)
- Каждый звук имеет **смысл** (не просто красиво, а учит)

❌ **Запрещено:**
- EDM, синтезаторные звуки без смысла
- Фоновая музыка "для затычки"
- Звуки без связи с игровым состоянием

### C. ROV Lake (Интеграция)

✅ **Требуется:**
- ROV telemetry → Firestore → Атрибуты игрока
- Глубина (depth) → Wisdom бонус за наблюдение
- Температура (temp) → Уроки о разных средах
- Джойстик интеграция с диалогом (рука + молитва одновременно)

### D. Фронтенд (webtypicon2 ludus-game.js)

✅ **Требуется:**
- NPC появляется в сцене → диалоговое дерево загружается
- Выбор варианта → проверка ФОРМЫ → отправка в Cloud Functions → получение ответа + бонусов
- UI показывает текущие атрибуты + бонусы за диалог
- Offline sync (диалоги работают offline, sync при reconnect)

---

## 🔴 Табу-дайджест (выше всех остальных)

1. **Не симулировать** — только реальный код, реальные данные, реальные тесты. Никакого "сделано" без доказательства.
2. **Конституция выше фишек** — красивая анимация стоит <меньше, чем система учения через диалоги.
3. **Каждый NPC имеет учение** — нет "просто болтунов", каждый отражает аспект паtristic богословия.
4. **Звук — язык** — не дизайн, а язык. Каждый звук кодирует смысл.
5. **Firestore как Небеса** — структура данных отражает теологию, не просто хранит информацию.
6. **Тесты на Quest 3** — только реальные устройства, никакие эмуляторы не берутся.
7. **PR перед push в main** — все разработка на ветках, review обязателен.
8. **Аудит-хор раз в 6 часов** — dev-сервер + 7 агентов по графике/звуку/интерфейсу + исправление ошибок (см. ТАБУ №0.6).
9. **Сырьё → 35 %** — сторонние объекты попадают в игру только через конвейер `scripts/raw_assets/` на раннере (см. ТАБУ №0.1).

---

## 📏 Нормы каждой сессии

- Чат с оператором — по-русски; код и PR — по-английски.
- **Размещение:** ludus — это Meta-сборка игры (Quest 3: VR, звук, пространственный звук, графика). На Webtypikon (webtypicon2) выкладываются **только** Конституция и текстовая версия игры. VR- и аудиокод на Webtypikon не переносится.
- **Код с комментариями по PEP 8:** полные предложения, объясняют «почему», строки не длиннее 79 символов.
- Коммиты: `Co-Authored-By: Claude <noreply@anthropic.com>` + `Claude-Session: URL`
- Секреты — только в Firebase Secret Manager или GitHub Secrets.
- `.env` файлы — в `.gitignore`, никогда не коммитить.
- Приоритет: диалоги → звуки → ROV интеграция → фронтенд → игровая механика.

---

## 📂 Тематические файлы правил (`.claude/rules/`, грузятся по `paths:`)

| Файл | Триггер-пути | Назначение |
|------|--------------|-----------|
| `npc-dialogue-system.md` | `docs/NPC_DIALOGUE_*`, `functions/src/dialogue/**` | Диалоги, AI, branching |
| `sound-design-system.md` | `docs/SOUND_DESIGN_*`, `public/ludus/audio/**` | Музыка, SFX, mixing, пространственный звук |
| `rov-lake-integration.md` | `public/ludus/rov-lake*`, `docs/ROV_LAKE_*` | Telemetry, атрибуты, джойстик |
| `frontend-integration.md` | `public/ludus/**`, `src/ludus/**` | ludus-game.js, Firestore, offline sync |
| `firebase-backend.md` | `functions/src/**`, `firestore.rules` | Cloud Functions, auth, rules |
| `testing-validation.md` | `tests/**`, `scripts/**`, `docs/TEST_*` | Unit, integration, Quest 3 testing |

---

## 🚀 Timeline & Milestones

| Этап | Даты | Проверка |
|------|------|----------|
| **Design** | Sep 28–29 | NPC диалоги + звуки документированы (✅ Done) |
| **Frontend Dev** | Sep 30–Oct 5 | ludus-game.js интегрирует диалоги + звуки |
| **Quest 3 Testing** | Oct 1–2 | Manual testing on real device |
| **Voice Casting** | Oct 2–Nov 15 | Запись голосов 8 NPCs |
| **Audio Integration** | Nov 16–Dec 15 | Wwise, spatial audio, mixing |
| **Beta Testing** | Dec 16–Jan 31 | Полный цикл на Quest 3 |
| **Production Deployment** | Feb 2027 | Ship to Meta Quest store |

---

## ✅ Текущий статус (2026-09-29 — Phase 2 COMPLETE)

### Design Phase (✅ COMPLETE)
- ✅ **NPC_DIALOGUE_SYSTEM.md** — 500+ lines, 10 NPCs, branching logic, AI engine
- ✅ **SOUND_DESIGN_SYSTEM.md** — 600+ lines, 40+ tracks, spatial audio, VR specs
- ✅ **ludus CLAUDE.md** — Project constitution with Demiurgic causality principle
- ✅ **PR #5** — Merged dialogue + sound design to ludus/main

### Phase 2: Frontend & Backend Integration (✅ COMPLETE)

**Frontend Components (webtypicon2):**
- ✅ **ludus-npc-dialogue-manager.js** — 380+ lines, dialogue tree management
- ✅ **ludus-audio-manager.js** — 420+ lines, 4-layer dynamic mixing, spatial audio
- ✅ **ludus-npc-dialogue-ui.js** — 290+ lines, modal component, choice rendering
- ✅ **ludus-dialogue.css** — 380+ lines, responsive design, dark/light mode
- ✅ **LUDUS_FRONTEND_INTEGRATION.md** — 500+ lines, complete integration guide

**Backend API (ludus Cloud Functions):**
- ✅ **ludus-dialogue.ts** — 450+ lines, 5 core endpoints
- ✅ **seedDialogueData.ts** — 300+ lines, seed script for dialogue trees
- ✅ **CLOUD_FUNCTIONS_DIALOGUE_API.md** — 550+ lines, complete API reference
- ✅ **functions/src/index.ts** — Updated with dialogue endpoint exports

**API Endpoints Ready:**
1. `GET /api/ludus/dialogue/tree/{npcId}` — Load dialogue trees
2. `GET /api/ludus/dialogue/memory/{npcId}/{playerId}` — NPC memory
3. `POST /api/ludus/dialogue/state` — Persist choices & bonuses
4. `GET /api/ludus/dialogue/stats/{playerId}` — Engagement stats
5. `POST /api/ludus/dialogue/tree/{npcId}` (ADMIN) — Seed trees

### Next Phases
- ⏳ **Phase 3: Testing & Validation (Oct 1–5)** — Deploy Cloud Functions, integration testing
- ⏳ **Phase 4: Voice Casting & Recording** — Oct 2–Nov 15
- ⏳ **Phase 5: Audio Integration (Wwise)** — Nov 16–Dec 15
- ⏳ **Phase 6: Beta Testing on Quest 3** — Dec 16–Jan 31
- ⏳ **Phase 7: Production Deployment** — Feb 2027

### Repos Status

**ludus repository:**
- **main** — NPC + sound design specs (PR #5, in review)
- **claude/gracious-clarke-36w4kh** — Branch with:
  - NPC_DIALOGUE_SYSTEM.md (500+ lines)
  - SOUND_DESIGN_SYSTEM.md (600+ lines)
  - ludus-dialogue.ts (450+ lines, 5 Cloud Functions)
  - seedDialogueData.ts (300+ lines)
  - CLOUD_FUNCTIONS_DIALOGUE_API.md (550+ lines)
  - CLAUDE.md (Project constitution)

**webtypicon2 repository:**
- **main** — Frontend components (deployed):
  - ludus-npc-dialogue-manager.js (380+ lines)
  - ludus-audio-manager.js (420+ lines)
  - ludus-npc-dialogue-ui.js (290+ lines)
  - ludus-dialogue.css (380+ lines)
  - LUDUS_FRONTEND_INTEGRATION.md (500+ lines)

---

**Страж конституции:** Claude Haiku 4.5  
**Последнее обновление:** 2026-09-28 10:52 UTC  
**Действительно до:** Завершение проекта или явное изменение (требует разрешения Leonidy431)
