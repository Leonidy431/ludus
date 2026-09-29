# Аудит слепых зон: графика, звук, интерфейс — 2026-09-29

Процедура ТАБУ №0.6: dev-сервер + хор 7 агентов (6 правят свои файлы, 1 картограф репо) + проверка ведущим в Playwright.
**Итого: 85 слепых зон** (до 99 не добивались). Исправлено: 68, отложено: 15, передано: 2.

| Приоритет | Исправлено | Отложено/передано |
|---|---|---|
| P0 | 13 | 0 |
| P1 | 23 | 2 |
| P2 | 26 | 8 |
| P3 | 6 | 7 |

## Доказательства

- До: пустой тёмный экран на desktop/Quest 3/mobile, console `LudusGame module not loaded`.
- После: гостевой режим, профиль с 7 атрибутами, 4 наставника, лестница 6 врат; диалог со старцем Сергием: 2 из 3 ответов закрыты ФОРМОЙ, выбор даёт +2 Веры, значение сохраняется после перезагрузки.
- Бэкенд: `tsc` чист; Jest 20/20 под эмулятором.
- Оставшиеся 404 в браузере: `/api/...` (на статическом сервере нет функций — сработал встроенный пакет) и `/ludus/audio/*.mp3` (аудио не существует, BS-061).
- **Не проверено на реальном Quest 3** — только эмуляция viewport в Chromium.

## Реестр

| ID | Область | P | Статус | Что | Файл | Доказательство |
|---|---|---|---|---|---|---|
| BS-001 | ui | P0 | fixed | Error boundary put event.error.message into innerHTML (XSS) and wiped #app | `public/index.html` | Spot-checked: errors are written to #ludus-fatal-message via textContent (index.html:185-187). Playwright probe after the fix: {xss:0, imgs:0}. |
| BS-002 | ui | P0 | fixed | index.html called the undefined LudusGame.init, so the game never mounted | `public/index.html` | The console now logs 'Initializing module...'. When the module returns 404, data-ludus-boot=failed and the fatal panel is shown. |
| BS-003 | ui | P0 | fixed | The 5 shared containers (#ludus-auth, profile, network, gates, error) were missing | `public/index.html` | After the fix the probe finds all 5 inside #ludus-game-container. #ludus-error has role=alert and starts hidden. |
| BS-004 | ui | P1 | fixed | Spinner was hidden before init finished; boot hung forever when the CDN was blocked | `public/index.html` | The spinner stays up until init settles. A 15s watchdog sets data-ludus-boot=degraded and shows a notice. |
| BS-005 | ui | P1 | fixed | No unhandledrejection handler; init errors were re-thrown and lost | `public/index.html` | After the fix rejectionShown:true and pageerrors:[]. |
| BS-006 | ui | P1 | fixed | Relative asset URLs broke on deep links under the ** -> /index.html rewrite | `public/index.html` | All asset URLs are now root-absolute (/ludus/...). An offline deep-route navigation loads the modules from cache. |
| BS-007 | ui | P1 | fixed | SW precache listed a non-existent idb-schema.js; the cache stayed empty but install succeeded | `public/ludus/sw.js` | Spot-checked: sw.js:14-22 has a versioned CACHE_VERSION and comments on the removed entry. The cache now holds 11 entries with no 404. |
| BS-008 | ui | P2 | fixed | Unversioned cache-first SW served stale code, and activate deleted every other cache on the origin | `public/ludus/sw.js` | Static and runtime caches are versioned. Modules use stale-while-revalidate. activate now deletes only 'ludus-' caches. |
| BS-009 | ui | P2 | fixed | SW cached HTML under script URLs, returned a fake 200 for failed JS, and cached per-player /api/ responses | `public/ludus/sw.js` | Offline probe: a text/html response for a JS URL is not cached, /api/ returns 503 JSON, and a missing JS file gives a real network error. |
| BS-010 | ui | P2 | fixed | Background sync faked completion; the message handler crashed on null data | `public/ludus/sw.js` | SYNC_COMPLETE now carries confirmed true/false from the client's ack. Verified only with node --check; no runtime sync-event test was run. |
| BS-011 | ui | P1 | fixed | SW at /ludus/sw.js cannot control / because the Service-Worker-Allowed header is missing | `public/ludus/sw.js` | firebase.json: Service-Worker-Allowed: / и Cache-Control: no-cache для /ludus/sw.js |
| BS-012 | ui | P0 | fixed | Firebase SDK loader had no onerror or timeout, so init() never settled when the CDN was blocked | `public/ludus/ludus-game.js` | Abort resolves in 95ms and a hang resolves in 10053ms, both into offline guest mode with a Try again button. This also covers boot-shell's handoff. |
| BS-013 | ui | P0 | fixed | Undeclared maxDepth assignment threw a ReferenceError, so no player data rendered | `public/ludus/ludus-game.js` | Spot-checked: ludus-game.js:397 now calls performBFS(playerId, nodes, edges, 2), and maxDepth is a parameter at line 415. |
| BS-014 | ui | P0 | fixed | Stored XSS: displayName and Firestore fields went into innerHTML unescaped | `public/ludus/ludus-game.js` | Spot-checked: escapeHtml is at ludus-game.js:143 and is used in the interpolations. Probe after the fix: pwned=0, imgs=0. |
| BS-015 | ui | P1 | fixed | 9 D&D attributes instead of the constitution's 7, with an invented default of 10 | `public/ludus/ludus-game.js` | Mock shows exactly the 7 labels with values from ludus_players.form. Missing values show 0; nothing random. |
| BS-016 | ui | P1 | fixed | UI read ludus_nodes.attributes, but the backend writes ludus_players.form | `public/ludus/ludus-game.js` | The readPlayerForm() adapter prefers form. Reads use Promise.allSettled, so one failed read only blanks its own panel. |
| BS-017 | ui | P2 | fixed | Inline onclick handlers would be blocked by a strict CSP | `public/ludus/ludus-game.js` | inlineOnclick=0. Clicks go through one delegated data-action listener. |
| BS-018 | ui | P2 | fixed | Attribute bars were not tied to gate thresholds, and the 6-gate ladder was missing | `public/ludus/ludus-game.js` | Wisdom bar has ticks at 4-14. The GATE_LADDER shows Ascetic as current when wisdom=9. |
| BS-019 | ui | P2 | fixed | ludus-game.css redefined the shared --ludus-* tokens on :root, and design-system rules collapsed the bars | `public/ludus/ludus-game.css` | Tokens are now private --lg-* aliases scoped to #ludus-game-container. Real index.html shows all 7 bars at 961px. |
| BS-020 | ui | P3 | fixed | Error toast timer was not reset, so a second error disappeared early | `public/ludus/ludus-game.js` | clearTimeout is added before the new timer. Code review only; no runtime test. |
| BS-021 | ui | P0 | fixed | processChoice always threw 'No branches available' because currentDialogue was never set | `public/ludus/ludus-npc-dialogue-manager.js` | Spot-checked: ludus-npc-dialogue-manager.js:278 sets state.currentDialogue = tree. after.js processed 3 choices through to complete. |
| BS-022 | ui | P0 | fixed | Dialogue UI XSS and attribute injection through innerHTML and aria-label | `public/ludus/ludus-npc-dialogue-ui.js` | The UI is built with createElement/textContent only. __xss and __xss2 both stayed false. |
| BS-023 | ui | P1 | fixed | Locked FORM-gated branches were filtered out before the locked flag was computed, so they were never shown | `public/ludus/ludus-npc-dialogue-manager.js` | 3 choices are shown, 2 locked with a 'Requires Faith 7 (you have 4)' hint. A forged processChoice on a locked branch is refused. |
| BS-024 | ui | P1 | fixed | Dialogue modal was unpositioned: the CSS used a class selector but the container only has an id | `public/ludus/ludus-dialogue.css` | The modal is position:fixed and the close button sits inside it (after-node1.png). |
| BS-025 | ui | P1 | fixed | Dialogue modal had no accessibility: no role, focus trap or Escape, and it used an inline onclick | `public/ludus/ludus-npc-dialogue-ui.js` | role=dialog and aria-modal=true. Focus is trapped over 6 Tabs, Escape closes and restores focus, and the text has aria-live=polite. |
| BS-026 | ui | P1 | fixed | Quest 3 legibility: 15-16px text and 36-44px targets, under the 48px minimum | `public/ludus/ludus-dialogue.css` | Choice text is 20px, NPC text 22px, the close button 56px, and choices 91-122px tall. |
| BS-027 | ui | P1 | fixed | Offline: a tree 404 threw with no fallback, and failed state POSTs were dropped | `public/ludus/ludus-npc-dialogue-manager.js` | A cached tree plays offline. Pending state is queued in localStorage, and flushPending leaves 0 after reconnect. |
| BS-028 | ui | P1 | fixed | The final choice was never persisted, NPC memory leaked between NPCs, and /memory/null was requested for guests | `public/ludus/ludus-npc-dialogue-manager.js` | persist.js shows both POSTs, including complete:true, sent with a Bearer token. |
| BS-029 | ui | P1 | fixed | Audio rejections surfaced as app errors in the dialogue UI | `public/ludus/ludus-npc-dialogue-ui.js` | 0 pageerrors and 0 unhandled rejections. SFX are fire-and-forget. |
| BS-030 | ui | P2 | fixed | The Isaias profile used a non-existent 'intelligence' attribute, and bonuses were unbounded | `public/ludus/ludus-npc-dialogue-manager.js` | Spot-checked: 'intelligence' appears only in a comment at line 78. Bonuses are filtered to the 7 attributes and clamped to +5. |
| BS-031 | ui | P3 | fixed | Gains preview summed mutually exclusive choices and showed raw JSON | `public/ludus/ludus-npc-dialogue-ui.js` | Each choice now reads like '+2 Wisdom, +1 Faith'. The summed preview is removed. |
| BS-032 | ui | P3 | fixed | Light-mode dialogue modal clashed with the dark-only design system | `public/ludus/ludus-dialogue.css` | after-complete.png shows a dark modal. |
| BS-033 | sound | P0 | fixed | playMusic always threw because AudioBufferSourceNode.gain does not exist | `public/ludus/ludus-audio-manager.js` | Spot-checked: fade-in now ramps voice.gain, a per-voice GainNode (lines 629-630). A routed WAV plays as a loop. |
| BS-034 | sound | P0 | fixed | Missing or undecodable assets rejected and logged console.error, with no buffer cache | `public/ludus/ludus-audio-manager.js` | Load failures resolve to null and are cached per path; each missing URL is fetched once. The assets themselves are still missing (BS-061). |
| BS-035 | sound | P2 | fixed | No semantic cue map (bell, wind, per-attribute pitch); UI feedback was silent | `public/ludus/ludus-audio-manager.js` | SEMANTIC_CUES and playCue() were added. All 12 cues play, synthesised deterministically with no Math.random. |
| BS-036 | sound | P1 | fixed | AudioContext was created without a user gesture, and the suspended state was not handled | `public/ludus/ludus-audio-manager.js` | With no gesture the context stays null. It is created on a gesture, and resumes after suspend on the next click. |
| BS-037 | sound | P1 | fixed | Spatial voice was also routed dry, used the default panner, and never got the NPC position | `public/ludus/ludus-audio-manager.js` | Chain is source -> HRTF panner -> voice -> layer. Exactly 1 panner is created, at position [2,1.6,-3]. |
| BS-038 | sound | P2 | fixed | Ended or stopped audio nodes were never disconnected (leak) | `public/ludus/ludus-audio-manager.js` | After 60 cues and 4s idle: activeSources 0, liveNodes 0. |
| BS-039 | sound | P2 | fixed | Volume, ducking and stop jumped abruptly; ducking overwrote user levels; no mute or persistence | `public/ludus/ludus-audio-manager.js` | Separate duck gains, smoothed parameter changes, and setMuted (line 977) exist. Preferences survive a reload. Audible clicks were not measured. |
| BS-040 | sound | P3 | deferred | No clipping protection on the master bus | `public/ludus/ludus-audio-manager.js` | A limiter was added (createDynamicsCompressor, line 374), but peak output under load was not measured. |
| BS-041 | graphics | P1 | fixed | Design-system and rov-lake animations ignored prefers-reduced-motion | `public/ludus/ludus-design-system.css` | Spot-checked: @media (prefers-reduced-motion: reduce) is at ludus-design-system.css:681 and rov-lake.css:360. Under reduce, ANIMS is []. |
| BS-042 | graphics | P2 | fixed | Error token failed AA contrast on its tinted badge | `public/ludus/ludus-design-system.css` | Now #ff6b6b: 5.63:1 on the badge and 6.27:1 on the card. |
| BS-043 | graphics | P2 | fixed | Light attribute value text on gold/cyan bars was unreadable (1.7-1.85:1) | `public/ludus/ludus-design-system.css` | Value now sits on a card-coloured pill: 15.27:1. |
| BS-044 | graphics | P2 | fixed | Root font-size shrank to 13-14px on narrow screens | `public/ludus/ludus-design-system.css` | Root is 16px at every tested width. This exposed the gate-list overflow in BS-052. |
| BS-045 | graphics | P2 | fixed | Focus ring was nearly invisible on the dark UI | `public/ludus/ludus-design-system.css` | New --ludus-focus-ring: solid 3px cyan with a 2px offset. |
| BS-046 | graphics | P2 | fixed | No color-scheme declared, and the dark-mode block silently changed surface colours | `public/ludus/ludus-design-system.css` | colorScheme=dark, and the card is #1a1a1a in both schemes. Chorus decision: dark-only. |
| BS-047 | graphics | P2 | fixed | Font stack had no Church Slavonic, polytonic Greek, CJK or emoji fallbacks | `public/ludus/ludus-design-system.css` | The :lang stacks resolve in computed styles. Real glyph rendering is unverified until the Quest 3 test (fonts are not installed here). |
| BS-048 | graphics | P3 | fixed | Secondary text contrast was 6.66:1, weak at Quest reading distance | `public/ludus/ludus-design-system.css` | Now #bdbdbd: 9.26:1. |
| BS-049 | graphics | P3 | fixed | 44px hit targets; tabs had no min-height and buttons did not inherit font | `public/ludus/ludus-design-system.css` | --ludus-btn-height is 48px. Buttons use font: inherit and tabs have a min-height. |
| BS-050 | graphics | P3 | deferred | Card borders are 1.21:1 against the card fill | `public/ludus/ludus-design-system.css` | Decorative, so WCAG 1.4.11 exempts them. Changing them would restyle every panel; needs an owner decision. |
| BS-051 | graphics | P0 | fixed | ROV panel never rendered: it targeted non-existent ids and nothing called connect() | `public/ludus/rov-lake-manager.js` | The panel renders in #ludus-rov-container. It connects automatically on ludus:player-changed and unsubscribes cleanly when the player changes. |
| BS-052 | graphics | P3 | fixed | Horizontal overflow at 360-375px from the gate ladder (.ludus-gate-name/.ludus-gate-status) | `public/ludus/ludus-game.css` | ludus-game.css: auto auto minmax(0,1fr) + overflow-wrap:anywhere |
| BS-053 | graphics | P0 | fixed | Stored XSS in the ROV panel through playerId and string telemetry | `public/ludus/rov-lake-manager.js` | Spot-checked: rov-lake-manager.js:191-193 builds nodes with createElement, with no innerHTML. Probe: xss 0. |
| BS-054 | graphics | P1 | fixed | Telemetry overwrote FORM with absolute 8-18 scores instead of a deterministic Wisdom observation bonus | `public/ludus/rov-lake-manager.js` | Depth bands give +0..+5 Wisdom: 150m gives +3. The module only emits ludus:rov-insight and never writes FORM. |
| BS-055 | graphics | P2 | fixed | ROV panel had no temperature or pressure, heading was not normalised, and power was not clamped | `public/ludus/rov-lake-manager.js` | Shows temperature and ≈pressure. Heading 450 is shown as 90. |
| BS-056 | graphics | P2 | fixed | ROV listeners leaked on reconnect; no staleness detection or rAF coalescing | `public/ludus/rov-lake-manager.js` | 0 intervals after disconnect. A sample older than 5s shows 'Signal lost'. Rendering goes through one rAF. |
| BS-057 | graphics | P2 | fixed | ROV CSS: reduced motion ignored, fixed 600px min-height, status shown by colour only | `public/ludus/rov-lake.css` | Under reduce, animationName is 'none'. Status has a text change plus a ●/○ mark. min-height removed. |
| BS-058 | ui | P1 | fixed | Hosting rewrites /api/** to a function 'api' that functions/src/index.ts does not export | `firebase.json` | functions/src/api/ludus-router.ts: функция api, заполняет req.params; 10 тестов |
| BS-059 | ui | P1 | fixed | Nothing wires the dialogue manager/UI or ludus:rov-insight into ludus-game.js; bonuses are never applied to FORM | `public/ludus/ludus-game.js` | ludus-game.js: раздел наставников, talkTo() → LudusDialogueUI.open, бонусы в ФОРМУ; Playwright: Вера 1→3 |
| BS-060 | ui | P2 | handoff | FIREBASE_CONFIG is defined nowhere, so the build always runs in 'not configured' guest mode | `public/index.html` | From the game-core handoff. Needs a public window.FIREBASE_CONFIG before ludus-game.js; secrets stay in Secret Manager. |
| BS-061 | sound | P1 | handoff | No audio assets exist: all 31 catalogue URLs under /ludus/audio/ return 404 | `public/ludus/ludus-audio-manager.js` | The repo map confirms there are no .mp3, .wav or .ogg files in either repo. SFX fall back to synthesised cues; music and voice resolve to null silently. |
| BS-062 | repo | P1 | deferred | public/ludus/* is duplicated identically in webtypicon2 and ludus; there is no canonical copy | `public/ludus/` | From the repo map: diff -rq shows the 9 shared files identical, and ludus has 3 extra files (idb-schema.ts, optimistic-mutations.ts, sw.js). The fixes in this run exist only in the ludus copy. |
| BS-063 | repo | P2 | deferred | Meta-only WebXR scene (vr.html, vr.js) lives in the text-only webtypicon2 site | `webtypicon2/public/game/vr.html` | From the repo map split_violations. |
| BS-064 | repo | P2 | deferred | Needle Engine/three.js VR vendor bundle is inside the text site | `webtypicon2/public/game/vendor/needle/` | From the repo map split_violations. |
| BS-065 | repo | P2 | deferred | 3D GLB VR assets and the Quest headset icon are in the text site | `webtypicon2/public/game/vr-assets/gerat.glb` | From the repo map: gerat.glb, character-items-01.glb and art/obj-shlem-quest.svg. |
| BS-066 | repo | P2 | deferred | ROV telemetry and the spatial audio mixer (Meta scope) are shipped in webtypicon2 | `webtypicon2/public/ludus/rov-lake-manager.js` | From the repo map: rov-lake-manager.js, rov-lake.css and ludus-audio-manager.js. |
| BS-067 | repo | P3 | deferred | VR/Quest specs and Ludus sound/NPC rules are stored in webtypicon2 | `webtypicon2/docs/ru/ТЗ_VR_QUEST3S_WEBXR_2026-08-17.md` | From the repo map: the ТЗ_VR and ПЕРВЫЙ_ЗАПУСК_VR docs, LUDUS_FRONTEND_INTEGRATION.md and .claude/rules/ludus-npc-sound-frontend.md. |
| BS-068 | repo | P3 | deferred | Ludus game container deploy infrastructure lives in webtypicon2 | `webtypicon2/.github/workflows/ludus-runner-deploy.yml` | From the repo map: ludus-runner-deploy.yml and functions/docker-compose.ludus-runner.yml. |
| BS-069 | repo | P3 | deferred | Text-game and constitution content is duplicated into the ludus repo | `game_orden_3.txt` | From the repo map: game.txt, game_Orden*/game_orden_*.txt and exportfromWebtypicon_repo_all/ duplicate webtypicon2 content. |
| BS-070 | repo | P2 | deferred | A browser web frontend (index.html plus public/ludus/*.js) sits inside the Meta repo | `public/index.html` | From the repo map: under the split it belongs in webtypicon2, or should be removed once Unity is the Meta client. |
| BS-071 | repo | P3 | deferred | Junk files at the ludus root from a mis-pasted heredoc, plus a stray duplicate InputProvider.cs | `InputProvider.cs` | From the repo map: files named '(IVehicleCommandSource)', '}', 'Phase 5 (Instruments) ─┘' and others at the repo root. |
| BS-072 | ui | P0 | fixed | Эндпоинты диалогов читали req.params, но onRequest без роутера его не заполняет: в продакшене каждый запрос отвечал бы 400 | `functions/src/api/ludus-dialogue.ts` | ludus-router.ts + ludus-router.test.ts (10/10); Jest всего 20/20 под эмулятором |
| BS-073 | ui | P1 | fixed | Первый гость без сети не мог начать ни одного диалога: кэш пуст, API недоступно | `public/ludus/ludus-npc-dialogue-manager.js` | Встроенный пакет data/dialogue-trees.json (scripts/export-dialogue-pack.js из сид-данных); Playwright: диалог открывается при 404 от API |
| BS-074 | ui | P1 | fixed | Прогресс гостя терялся при перезагрузке | `public/ludus/ludus-game.js` | localStorage ludus.guest.form (try/catch); Playwright: Вера 3 после reload |
| BS-075 | graphics | P2 | fixed | Атрибуты показывались эмодзи, которые отсутствуют в части шрифтов Quest | `public/ludus/ludus-game.js` | 7 SVG attr-*.svg в едином стиле |
| BS-076 | graphics | P2 | fixed | Текст загрузки 18px нечитаем при ширине Quest 3 1832px | `public/index.html` | font-size: clamp(18px, 2.2vw, 40px) |
| BS-077 | graphics | P2 | fixed | У открытого диалога нет затемнения: панель сливается с карточками и вратами | `public/ludus/ludus-dialogue.css` | box-shadow 0 0 0 100vmax rgba(0,0,0,.6) (псевдоэлемент невозможен из-за transform) |
| BS-078 | graphics | P2 | fixed | Текст 0.8rem (статусы врат, значения атрибутов) мелок для Quest | `public/ludus/ludus-game.css` | 0.8rem → 0.875rem |
| BS-079 | ui | P2 | fixed | Феодора обращается к герою-диакону «Welcome, sister» | `functions/src/scripts/seedComprehensiveTestData.ts` | «Welcome, brother deacon»; пакет диалогов пересобран |
| BS-080 | ui | P2 | fixed | Спецификация NPC использует атрибут Strength, которого нет в Конституции | `docs/NPC_DIALOGUE_SYSTEM.md` | Strength → Constitution (Конституция выше спецификации) |
| BS-081 | ui | P2 | deferred | Среди NPC — католические святые после раскола (Хильдегарда, Бонавентура, Екатерина Сиенская) при православной Конституции | `docs/NPC_DIALOGUE_SYSTEM.md` | Не нарисованы; решение за оператором |
| BS-082 | graphics | P3 | deferred | Нимбы: главные герои без нимбов (канон §9.0 «без нимбов»), 7 второстепенных святых — с нимбами | `public/ludus/art/npc-*.svg` | Решение за оператором: единообразие в любую сторону — одна правка на файл |
| BS-083 | graphics | P2 | fixed | Метрика «35 %» обманывалась перекраской («$» белый→золотой = 100 %) | `scripts/raw_assets/transform.py` | Добавлена метрика формы 1−IoU; перекраска теперь 3–12 % → отклоняется |
| BS-084 | ui | P1 | fixed | npm test без Firestore-эмулятора всегда красный (8/10), а документы писали «Jest pass» | `functions/package.json` | npm run test:emu; эмулятор на 8085, не конфликтует с dev-сервером |
| BS-085 | graphics | P2 | deferred | На Quest 3 (1832px) интерфейс занимает малую часть ширины, базовый шрифт 16px мелок | `public/ludus/ludus-design-system.css` | Следующий цикл visual-system: масштаб по viewport для VR |

## Открытые вопросы к оператору

1. Католические святые в спецификации NPC — заменить на православных?
2. Нимбы у святых — единый канон: с нимбами или без (§9.0)?
3. Аудио: 31 файл каталога отсутствует; источник — репо kolokol и другие (нужен доступ).
4. Разделение репо (BS-062…BS-071): перенос VR-сцены из webtypicon2 в ludus; мусорные файлы в корне ludus.
5. FIREBASE_CONFIG для онлайн-режима (BS-060).
