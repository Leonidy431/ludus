# HLD: бекенд Ludus версии 3.0 — свой контейнер на VM8 рядом с горячим зеркалом (2026-10-01)

Оператор (2026-10-01): «мы медленно мигрируем на свой бекенд к версии 3.0 найди HLD и начинай по фазам дублируя наше горячее зеркало на нашем бекенд контейнера VM8»; «найди все HLD и создай папку version 3.0, туда все перенеси и открой там новый мд».

## Что собрано в этой папке

Из `docs/` ludus сюда перенесены 16 документов о бекенде, развёртывании, Firebase и VM8:
- `LUDUS_BACKEND_CONTAINER_DEPLOYMENT.md`;
- `VM8_BACKEND_CONTAINER_DEPLOYMENT.md`;
- `S12_FIRESTORE_AUTH.md`;
- `CLOUD_FUNCTIONS_DIALOGUE_API.md`;
- `A10_OFFLINE_SYNC.md`;
- `API_ERROR_HANDLING_GUIDE.md`;
- `FRONTEND_BACKEND_INTEGRATION_TESTING.md`;
- `LOCAL_DEV_SETUP.md`;
- `DEPLOYMENT_READINESS_V0_1.md`;
- `DEPLOYMENT_READINESS_FINAL.md`;
- `DEPLOYMENT_PHASE2_3_GUIDE.md`;
- `PHASE2_LOCAL_DEPLOYMENT_GUIDE.md`;
- `PHASE2_EXECUTION_CHECKLIST.md`;
- `PHASE2_CRITICAL_BLOCKERS.md`;
- `PHASE_3_DEPLOYMENT_CHECKLIST.md`;
- `PRE_DEPLOYMENT_CHECKLIST.md`.

Ссылки на них в остальных документах исправлены.

Игровые HLD (погружение, «Атлас», локации, звук и прочие) остаются в `docs/`. Это не бекенд, а сборка шлема (ТАБУ №0.01). Если нужна папка со всеми HLD проекта, их можно перенести одной командой.

**HLD горячего зеркала в webtypicon2.** По ТАБУ №0.05 они не переносятся и не правятся: в webtypicon2 разрешено трогать только код игры. Здесь они — опора, ревизия `origin/main` 7da10c6d7:
- `docs/PANOPTICON_FULL_MIRROR_HLD.md`: VM как точная копия www.typikon.site, контейнер `backup-frontend` :8444 рядом с `panopticon-mirror` :8443, 8 HTTP-поверхностей, среди них `gameApi`;
- `docs/HLD_VM_MIGRATION.md`: помодульный уход с Firebase Functions по циклу аудит → развязка → адаптация → маршрут; §5 — «связка», то есть параллельная работа Cloud Function и VM и сверка ответов до переключения;
- `docs/ru/PANOPTICON_FULL_MIRROR_HLD.md`, `docs/ru/HLD_VM_MIGRATION.md`;
- `docs/ru/HLD_ДОЛГОВЕЧНАЯ_АВТОНОМИЯ_РАННЕРА_VM8_2026-09-04.md`;
- `docs/ru/ВОССТАНОВЛЕНИЕ_МАШИНЫ_VM8_PANOPTICON_2026-09-24.md`;
- `docs/HLD_CLOUDFLARE_ZTNA_MIGRATION.md`, `docs/HLD_FULL_VM_MIGRATION_TOR.md`, `docs/HLD_RUNNER_SPOT_MIGRATION.md`.

## Можно ли обновить firebase-functions 4.9

Да. Это обычный npm-пакет: версию задаёт наш `functions/package.json`, а не правила Firebase. Ограничения такие:
- `firebase-functions` 4.x принимает `firebase-admin` только 10–12 (peer). Поэтому PR 6 (admin 13) ломает `npm ci`.
- В v6 импорт `firebase-functions` по умолчанию даёт API v2. Обработчики, написанные как `functions.https.onRequest` (v1), переводятся на `import * as functions from 'firebase-functions/v1'`. Тогда поведение то же, и обе версии можно поднять вместе.
- Для v6 нужен Node 18 или новее, у нас `engines.node = 18`.

В плане 3.0 это фаза P6. Когда код живёт как обычный Express-сервер (P1), зависимость от Firebase Functions становится тонкой обёрткой, и обновление дешевеет.

## Фазы

| Фаза | Что делаем | Приёмка — доказательство |
|---|---|---|
| P0 | Этот HLD. Документы бекенда собраны в `docs/version-3.0/`, ссылки исправлены. | файл в коммите; `grep` старых путей пуст |
| P1 | **Один код — два входа.** Маршрутизатор `/api/ludus/**` выделяется в функцию `dispatch(req, res)`. Её используют и Cloud Function `api`, и новый сервер `functions/src/server.ts` (Express, `PORT`, по умолчанию 3000, `/health` → `/api/ludus/health`). Сейчас `Dockerfile.ludus-backend` запускает `node lib/index.js`, где есть только экспорт функций и нет `listen`, поэтому контейнер ничего не обслуживает. Исправление: `CMD node lib/server.js`. | jest: сервер на случайном порту отвечает 404 JSON на неизвестный путь и проводит известный путь через те же `ROUTES`; `tsc` чисто; `docker build` (если в песочнице есть docker) или проверка `node lib/server.js` локально |
| P2 | **Хранилище — горячее зеркало.** Тот же адаптер, что `mirrorSync.ts` у зеркала webtypicon2. Режим `LUDUS_STORE=firestore` (сервисный аккаунт, как Cloud Function) или `mirror` (SQLite на томе VM8, наполняется зеркалированием коллекций `ludus_*`). Чтение сначала из зеркала, запись — только в режиме `firestore`, пока нет переключения. | тесты адаптера на обоих режимах; одинаковые ответы на фикстурах |
| P3 | **Контейнер на VM8.** CI собирает образ (`ludus-backend:3.0.x`), публикует его и разворачивает рабочим процессом через существующий `vm-relay` на `panopticon-mirror-vm` рядом с `panopticon-mirror` :8443 и `backup-frontend` :8444. Порт ludus — :8445, только внутренний VPC. | прогон CI зелёный; `docker ps` на VM8 из лога; `curl :8445/health` 200 из лога |
| P4 | **«Связка»** (HLD_VM_MIGRATION §5). Cloud Function и VM работают вместе. Скрипт сравнения шлёт одинаковые запросы в оба входа и сверяет ответы. | отчёт сравнения: 0 расхождений на наборе запросов из `INTEGRATION_TEST_SCENARIOS` |
| P5 | **Переключение — флаг клиента.** Веб и шлем вызывают VM-адрес при `LUDUS_API_BASE`. Cloud Function остаётся на окно отката и удаляется отдельным, явно помеченным коммитом. | Playwright на :8080 с обоими адресами; шлем — APK с адресом в настройке |
| P6 | **Обновление Firebase.** Импорт `firebase-functions/v1`, затем `firebase-functions` 6 и `firebase-admin` 13 вместе. Это закрывает PR 6. | `npm ci`, `tsc`, jest зелёные |

## Решения хора

- **Предубеждение (инженер):** «проще сразу выключить Firebase и поднять VM». **Контраргумент (тестировщик; HLD_VM_MIGRATION §5):** без «связки» нет доказательства, что ответы совпадают. **Почему:** сначала обе стороны и сверка, переключение — флагом, откат — через Firebase.
- **Предубеждение:** «контейнер уже описан в `VM8_BACKEND_CONTAINER_DEPLOYMENT.md`, значит готов». **Контраргумент (Аристотель-скептик):** образ запускает модуль без `listen`. **Почему:** P1 начинается с того, чтобы контейнер действительно отвечал, и это проверяется тестом.
- **Предубеждение:** «перенести в эту папку и HLD горячего зеркала из webtypicon2». **Контраргумент (ТАБУ №0.05):** в webtypicon2 правится только код игры. **Почему:** здесь ссылки с ревизией, документы остаются на месте.
- **P2, запись в зеркало.** **Предубеждение (инженер):** «раз SQLite под рукой, пусть зеркало и пишет, а потом догонит Firestore». **Контраргумент (тестировщик, Аристотель-скептик):** две записи без переключения расходятся, и следующий проход `mirrorSync` молча затирает выбор игрока. **Почему:** до P5 зеркало только читает; запись игрока там отвечает 503 с понятным текстом и `Retry-After`, а сам `SqliteStore` бросает ошибку на любую запись, если охрану забыли.
- **P2, движок SQLite.** **Предубеждение:** «`node:sqlite` без нативной сборки». **Контраргумент:** в CI Node 20, в образе Node 18, `node:sqlite` там нет. **Почему:** `better-sqlite3` 11.10, как у зеркала webtypicon2. Готовые бинарники есть для Node 18 musl (образ), Node 20 glibc (CI) и Node 22 (песочница), все три отвечают HTTP 200, поэтому компилятор не нужен. Модуль грузится лениво, только в режиме `mirror` и в скрипте синхронизации.
- **P2, водяной знак.** **Предубеждение:** «водяной знак — значит, читаем только новое». **Контраргумент (гидроакустик: верь приборам):** Firestore не фильтрует запрос по `updateTime`. **Почему:** каждый проход читает коллекцию целиком; водяной знак (`updateTime` до наносекунд) избавляет от лишних записей, а полный список позволяет удалить из зеркала то, что удалено в Firestore. Опустевшая коллекция берётся из `sync_state`, потому что `listCollections()` её уже не видит (тест это поймал).
- **P2, найденная ошибка.** `getDialogueStats` искал память через `collectionGroup('players').where('__name__', '==', playerId)`. Firestore отклоняет такой запрос: фильтру по id в группе коллекций нужен полный путь. Значит, эндпоинт всегда отвечал 500. Теперь память читается по точному пути для каждого NPC из `ludus_dialogue_states`. `persistDialogueState` пишет состояние и память вместе, так что набор полный. Остальные ответы не изменились.

Конституция (P2): ФОРМА (7 атрибутов и выборы игрока лежат в одном источнике правды, Firestore; зеркало — его копия на VM8) → ДЕЙСТВИЕ (контейнер читает из зеркала, а запись до переключения отклоняет честным 503) → ЦЕЛЬ (ни один выбор игрока не теряется и не раздваивается, а учение остаётся доступным и без чужой платформы).

Конституция: ФОРМА (данные игрока — его 7 атрибутов и выборы — живут в нашем хранилище, как «Небеса» раздела 5) → ДЕЙСТВИЕ (тот же код отвечает и из облака, и из своего контейнера, а ответы сверяются) → ЦЕЛЬ (учение не зависит от чужой платформы и не теряет ни одного выбора игрока).

## Блокеры оператора (одна строка — одно действие)

- **P3:** доступ CI к VM8. Нужен рабочий `vm-relay` для репо ludus или раннер VM8, зарегистрированный именно на ludus (ТАБУ №0.15 п. 1). Без него образ собирается, но не разворачивается.
- **P2:** сервисный аккаунт с доступом к коллекциям `ludus_*`, как секрет репо или файл на томе VM8. В репо его не класть.

## Состояние

| Фаза | Состояние | Доказательство |
|---|---|---|
| P0 | сделано | этот файл; 16 документов перенесены (`git mv`), ссылки в 9 файлах исправлены |
| P1 | сделано (кроме сборки образа) | `dispatch()` в `ludus-router.ts` — один для Cloud Function `api` и для `src/server.ts`. Живой процесс `PORT=3999 node lib/server.js` отвечает `404 {"error":"No route for GET /api/ludus/nowhere"}`. jest: `server.test.ts` 3/3, модульные наборы 29/29, интеграционный ждёт эмулятор. `npm ci` с новым lock проходит. `Dockerfile.ludus-backend` запускает `lib/server.js`. `docker build` в песочнице не запускался: демона Docker нет, сборка образа идёт в CI (P3) |
| P2 | сделано (кроме проверки на живом Firestore) | Шов `functions/src/store/`: `store.ts` (интерфейс, `getStore()` по `LUDUS_STORE`, `refuseWriteOnMirror`), `firestore-store.ts`, `sqlite-store.ts` (`MirrorDb` пишет, `SqliteStore` только читает). Через шов идут `ludus-dialogue.ts`, `ludus-actions.ts`, `ludus-health.ts`. `functions/src/scripts/mirrorSync.ts`: копирует `ludus_*` и группу `players` под `ludus_*`, ведёт водяной знак на источник, повторный проход ничего не пишет. `npm ci` → `added 624 packages`. `npx tsc --noEmit -p .` → код 0, без ошибок. `npx jest --testPathIgnorePatterns integration` → `Test Suites: 5 passed`, `Tests: 47 passed` (новый `store-mirror.test.ts` 18/18: 10 одинаковых ответов из Firestore-фейка и из SQLite, 503 на три записи, запись в режиме `firestore`, идемпотентность и удаление в `mirrorSync`, выбор режима). Живой процесс `LUDUS_STORE=mirror PORT=3998 node lib/server.js` пишет `ludus backend listening on 3998, store mirror`; `GET /api/ludus/dialogue/tree/elder_sergius` → 200 из SQLite; `POST /api/ludus/dialogue/state` → `503 {"error":"Read-only mirror: player writes are paused until cutover",…}`. Тест добавлен в шаг «Functions unit tests» в `raw-asset-intake.yml`. Не проверено: проход `mirrorSync` по настоящему Firestore, он ждёт сервисного аккаунта (блокер P2) |
