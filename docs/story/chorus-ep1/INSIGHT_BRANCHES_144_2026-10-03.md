# Инсайты серии 1: 144 варианта как ветки развития игры

Оператор (2026-10-03, дословно): «задачу по 144 вариантам преобразуй в разные ветки развития игры. как сделаешь эти 144 ролики к ним допиши текст и комить видео»; «на каждый негатив два позитива».

Данные — `godot/data/pilot-insight-branches.json`, генератор — `scripts/story/insight_branches.py`, проверка хора — `scripts/story/check_branches.py` (тест `scripts/tests/test_insight_branches.py`), технология — `docs/TECH_INSIGHT_RENDER_144_2026-10-03.md`, кадры и хор вариантов — `INSIGHT_VARIANTS_144_2026-10-03.md`.

**Как выбирается ветка.** Вариант выбирают часы устройства игрока в миг, когда приходит инсайт: двенадцать часов дня — двенадцать вариантов. Без случайности, ничего не уходит в сеть. Просмотр и пропуск не награждаются и не наказываются (ТАБУ №0.021 п. 3). След ветки — строка журнала, память одного героя и один ответ в диалоге сходящегося бита, который может дать +1 к одному из семи атрибутов (никогда к Вере — без наград за веру, ТАБУ №0.023; никогда к Хитрости).

**Узкое горло.** Все 12 веток инсайта сходятся в его бит `bridge_to` из `godot/data/pilot-1.json`, поэтому дерево не взрывается: 144 ветки — 9 сходящихся битов. Вариантов у святыни (кайрак, id `khachkar`) нет: у неё инсайтов нет (ТАБУ №0.021 п. 6, №0.027).

**Хор.** Шоураннер, сценарист ветвлений, дизайнер последствий (авторы); катехизатор, историк, оператор-постановщик, Аристотель-скептик (проверяющие). У каждой ветки замечание «− / + / +»: на каждый негатив два позитива.

Предубеждение: «144 ветки — это 144 сюжета» / контраргумент (скептик, дизайнер последствий): комбинаторный взрыв не делается и не проверяется; ветка — час и его след, а сюжет сходится в следующий бит / почему: слово оператора о ветках исполнено без разрыва ритма сериала (ТАБУ №0.015 п. 2).

### Вариант ID: ink_first_line/v01 — Предрассветный синий час — рука передаёт руке

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «предрассветный синий час» (часы устройства игрока, без случайности): в журнал ложится строка «ink_first_line, предрассветный синий час», а переписчик обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `hands_on_stick` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `hands_on_stick` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: pre-dawn blue hour, solar 06:40, sun elevation -7 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 32 mm lens, orbit -11 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Синий час до утрени. / Переписчик дышит на пальцы, чтобы чернила не стыли, и под строкой рыцаря выводит: «Кто прочтёт…» Под водой рукоять возьмёт другая рука.

**4. Метаданные:**

```json
{"node_id": "v_ink_first_line_01", "video_prompt": "A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: pre-dawn blue hour, solar 06:40, sun elevation -7 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 32 mm lens, orbit -11 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Синий час до утрени. Переписчик дышит на пальцы, чтобы чернила не стыли, и под строкой рыцаря выводит: «Кто прочтёт…» Под водой рукоять возьмёт другая рука.", "git_commit_msg": "feat(story): add narrative branch ink_first_line and video assets", "status": "ready_for_render"}
```

Хор: − лампа перебивает синий час, окно читается слабо / + холодное окно против тёплой лампы — рифма холода и руки / + лист и мокрая строка в центре

### Вариант ID: ink_first_line/v02 — Заря — рука передаёт руке

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «заря» (часы устройства игрока, без случайности): в журнал ложится строка «ink_first_line, заря», а переписчик обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `hands_on_stick` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `hands_on_stick` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: dawn, solar 07:07, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 40 mm lens, orbit +7 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Окно светлеет. / Он греет пальцы дыханием, и под словами рыцаря встаёт его первая строка: «Кто прочтёт…» Под водой рукоять возьмёт другая рука.

**4. Метаданные:**

```json
{"node_id": "v_ink_first_line_02", "video_prompt": "A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: dawn, solar 07:07, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 40 mm lens, orbit +7 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Окно светлеет. Он греет пальцы дыханием, и под словами рыцаря встаёт его первая строка: «Кто прочтёт…» Под водой рукоять возьмёт другая рука.", "git_commit_msg": "feat(story): add narrative branch ink_first_line and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ink_first_line/v03 — Восход — рука передаёт руке

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «восход» (часы устройства игрока, без случайности): в журнал ложится строка «ink_first_line, восход», а переписчик обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `hands_on_stick` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `hands_on_stick` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: sunrise, solar 07:34, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 54 mm lens, orbit -4 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Первый луч на листе. Переписчик дует на перо и пишет под рыцарем своё: «Кто прочтёт…» Чужое слово стало его. / Под водой рукоять возьмёт другая рука.

**4. Метаданные:**

```json
{"node_id": "v_ink_first_line_03", "video_prompt": "A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: sunrise, solar 07:34, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 54 mm lens, orbit -4 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Первый луч на листе. Переписчик дует на перо и пишет под рыцарем своё: «Кто прочтёт…» Чужое слово стало его. Под водой рукоять возьмёт другая рука.", "git_commit_msg": "feat(story): add narrative branch ink_first_line and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ink_first_line/v04 — Утро — рука передаёт руке

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «утро» (часы устройства игрока, без случайности): в журнал ложится строка «ink_first_line, утро», а переписчик обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `hands_on_stick` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Ловкость». Все 12 вариантов сходятся в `hands_on_stick` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: morning, solar 09:07, sun elevation +15 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 36 mm lens, orbit +13 deg around the subject from the reference view, +1 deg tilt, roll -3 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Зимнее утро в обители. Он кончил список рыцаря и, подышав на пальцы, начал своё: «Кто прочтёт…» Под водой рукоять возьмёт другая рука.

**4. Метаданные:**

```json
{"node_id": "v_ink_first_line_04", "video_prompt": "A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: morning, solar 09:07, sun elevation +15 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 36 mm lens, orbit +13 deg around the subject from the reference view, +1 deg tilt, roll -3 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Зимнее утро в обители. Он кончил список рыцаря и, подышав на пальцы, начал своё: «Кто прочтёт…» Под водой рукоять возьмёт другая рука.", "git_commit_msg": "feat(story): add narrative branch ink_first_line and video assets", "status": "ready_for_render"}
```

Хор: − окно у края кадра пересвечено / + утро зимы читается сразу: серый свет окна и лампа / + обе страницы и перо видны, рифма руки цела

### Вариант ID: ink_first_line/v05 — Позднее утро — рука передаёт руке

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «позднее утро» (часы устройства игрока, без случайности): в журнал ложится строка «ink_first_line, позднее утро», а переписчик обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `hands_on_stick` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `hands_on_stick` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: late morning, solar 10:30, sun elevation +23 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit -15 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Свет ровный, холод тот же. Он пишет под словами рыцаря «Кто прочтёт…» и знает: читать будут не его. Под водой рукоять возьмёт другая рука.

**4. Метаданные:**

```json
{"node_id": "v_ink_first_line_05", "video_prompt": "A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: late morning, solar 10:30, sun elevation +23 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit -15 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Свет ровный, холод тот же. Он пишет под словами рыцаря «Кто прочтёт…» и знает: читать будут не его. Под водой рукоять возьмёт другая рука.", "git_commit_msg": "feat(story): add narrative branch ink_first_line and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2150 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ink_first_line/v06 — Полдень — рука передаёт руке

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «полдень» (часы устройства игрока, без случайности): в журнал ложится строка «ink_first_line, полдень», а переписчик обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `hands_on_stick` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `hands_on_stick` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: solar noon, solar 12:00, sun elevation +26 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 40 mm lens, orbit +0 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Полдень, а чернила густеют от стужи. Он дышит на них и пишет под рыцарем: «Кто прочтёт…» Рука передаёт руке. / Под водой рукоять возьмёт другая рука.

**4. Метаданные:**

```json
{"node_id": "v_ink_first_line_06", "video_prompt": "A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: solar noon, solar 12:00, sun elevation +26 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 40 mm lens, orbit +0 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Полдень, а чернила густеют от стужи. Он дышит на них и пишет под рыцарем: «Кто прочтёт…» Рука передаёт руке. Под водой рукоять возьмёт другая рука.", "git_commit_msg": "feat(story): add narrative branch ink_first_line and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2200 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ink_first_line/v07 — После полудня — рука передаёт руке

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «после полудня» (часы устройства игрока, без случайности): в журнал ложится строка «ink_first_line, после полудня», а переписчик обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `hands_on_stick` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `hands_on_stick` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: afternoon, solar 14:30, sun elevation +17 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 46 mm lens, orbit +17 deg around the subject from the reference view, -1 deg tilt, roll 3 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** После трапезы он вернулся к листу. Пальцы стынут, он дышит на них, прежде чем вывести: «Кто прочтёт…» Под водой рукоять возьмёт другая рука.

**4. Метаданные:**

```json
{"node_id": "v_ink_first_line_07", "video_prompt": "A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: afternoon, solar 14:30, sun elevation +17 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 46 mm lens, orbit +17 deg around the subject from the reference view, -1 deg tilt, roll 3 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "После трапезы он вернулся к листу. Пальцы стынут, он дышит на них, прежде чем вывести: «Кто прочтёт…» Под водой рукоять возьмёт другая рука.", "git_commit_msg": "feat(story): add narrative branch ink_first_line and video assets", "status": "ready_for_render"}
```

Хор: − наклон +3° заметен; в шлеме — на грани / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ink_first_line/v08 — Золотой час — рука передаёт руке

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «золотой час» (часы устройства игрока, без случайности): в журнал ложится строка «ink_first_line, золотой час», а переписчик обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `hands_on_stick` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `hands_on_stick` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: golden hour, solar 15:41, sun elevation +8 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 60 mm lens, orbit -8 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Низкое солнце золотит пергамент. Он дописал рыцаря и оставил своё: «Кто прочтёт…» Строка ждёт читателя. / Под водой рукоять возьмёт другая рука.

**4. Метаданные:**

```json
{"node_id": "v_ink_first_line_08", "video_prompt": "A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: golden hour, solar 15:41, sun elevation +8 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 60 mm lens, orbit -8 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Низкое солнце золотит пергамент. Он дописал рыцаря и оставил своё: «Кто прочтёт…» Строка ждёт читателя. Под водой рукоять возьмёт другая рука.", "git_commit_msg": "feat(story): add narrative branch ink_first_line and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ink_first_line/v09 — Закат — рука передаёт руке

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «закат» (часы устройства игрока, без случайности): в журнал ложится строка «ink_first_line, закат», а переписчик обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `hands_on_stick` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `hands_on_stick` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: sunset, solar 16:35, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 34 mm lens, orbit +10 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Свет уходит из окна. Он торопится: под словами рыцаря ещё одна строка — «Кто прочтёт…» Ответа он не узнает. / Под водой рукоять возьмёт другая рука.

**4. Метаданные:**

```json
{"node_id": "v_ink_first_line_09", "video_prompt": "A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: sunset, solar 16:35, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 34 mm lens, orbit +10 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Свет уходит из окна. Он торопится: под словами рыцаря ещё одна строка — «Кто прочтёт…» Ответа он не узнает. Под водой рукоять возьмёт другая рука.", "git_commit_msg": "feat(story): add narrative branch ink_first_line and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ink_first_line/v10 — Сумерки — рука передаёт руке

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «сумерки» (часы устройства игрока, без случайности): в журнал ложится строка «ink_first_line, сумерки», а переписчик обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `hands_on_stick` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `hands_on_stick` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: dusk, solar 17:08, sun elevation -5 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 40 mm lens, orbit -18 deg around the subject from the reference view, +2 deg tilt, roll -2 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сумерки, лампа только зажжена. Он пишет почти наощупь: «Кто прочтёт…» Он читал рыцаря, его прочтут другие. / Под водой рукоять возьмёт другая рука.

**4. Метаданные:**

```json
{"node_id": "v_ink_first_line_10", "video_prompt": "A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: dusk, solar 17:08, sun elevation -5 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 40 mm lens, orbit -18 deg around the subject from the reference view, +2 deg tilt, roll -2 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сумерки, лампа только зажжена. Он пишет почти наощупь: «Кто прочтёт…» Он читал рыцаря, его прочтут другие. Под водой рукоять возьмёт другая рука.", "git_commit_msg": "feat(story): add narrative branch ink_first_line and video assets", "status": "ready_for_render"}
```

Хор: − наклон -2° заметен; в шлеме — на грани / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ink_first_line/v11 — Ночь с луной — рука передаёт руке

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «ночь с луной» (часы устройства игрока, без случайности): в журнал ложится строка «ink_first_line, ночь с луной», а переписчик обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `hands_on_stick` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `hands_on_stick` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: night with moon, solar 22:30, sun elevation -62 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 36 mm lens, orbit +4 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Луна в окне, лампа у локтя. Он дует на пальцы и пишет под рыцарем: «Кто прочтёт…» Так эпоха читает эпоху. / Под водой рукоять возьмёт другая рука.

**4. Метаданные:**

```json
{"node_id": "v_ink_first_line_11", "video_prompt": "A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: night with moon, solar 22:30, sun elevation -62 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 36 mm lens, orbit +4 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Луна в окне, лампа у локтя. Он дует на пальцы и пишет под рыцарем: «Кто прочтёт…» Так эпоха читает эпоху. Под водой рукоять возьмёт другая рука.", "git_commit_msg": "feat(story): add narrative branch ink_first_line and video assets", "status": "ready_for_render"}
```

Хор: − вид в окне ночью серый, как днём / + лампа одна держит лист, ночь честная / + строка рассказчика и кадр совпадают: луна в окне, лампа у локтя

### Вариант ID: ink_first_line/v12 — Глухая ночь, только огонь — рука передаёт руке

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «глухая ночь, только огонь» (часы устройства игрока, без случайности): в журнал ложится строка «ink_first_line, глухая ночь, только огонь», а переписчик обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `hands_on_stick` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `hands_on_stick` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: deep night, solar 02:45, sun elevation -50 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 50 mm lens, orbit -2 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Глухая ночь, один огонёк лампы. Он греет пальцы над ним и пишет: «Кто прочтёт…» Память держит рука. Под водой рукоять возьмёт другая рука.

**4. Метаданные:**

```json
{"node_id": "v_ink_first_line_12", "video_prompt": "A copyist cell of lime plaster, a walnut desk, an open parchment codex with brown ink lines, a reed pen with a wet nib on the right leaf, a clay inkpot, a small clay oil lamp, a window opening in the left wall onto a grey winter lake and white mountains. No person in frame. Time: deep night, solar 02:45, sun elevation -50 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 50 mm lens, orbit -2 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the oil-lamp flame flickers at 2-3 Hz; the wet ink on the last line catches a specular glint; faint dust drifts in the window light. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Глухая ночь, один огонёк лампы. Он греет пальцы над ним и пишет: «Кто прочтёт…» Память держит рука. Под водой рукоять возьмёт другая рука.", "git_commit_msg": "feat(story): add narrative branch ink_first_line and video assets", "status": "ready_for_render"}
```

Хор: − правая страница уходит в тень / + один огонёк — самый тихий кадр серии / + тёплый класс огня 1900 K, не лампада

### Вариант ID: bazaar_jug/v01 — Предрассветный синий час — копия указывает на подлинник

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «предрассветный синий час» (часы устройства игрока, без случайности): в журнал ложится строка «bazaar_jug, предрассветный синий час», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: pre-dawn blue hour, solar 04:18, sun elevation -7 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit -18 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Каракол до рассвета. Гончар ставит кувшины: «Так лепили всегда». Он возьмёт копию и не спросит, где подлинник. / Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_bazaar_jug_01", "video_prompt": "A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: pre-dawn blue hour, solar 04:18, sun elevation -7 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit -18 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Каракол до рассвета. Гончар ставит кувшины: «Так лепили всегда». Он возьмёт копию и не спросит, где подлинник. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch bazaar_jug and video assets", "status": "ready_for_render"}
```

Хор: − первый фонарь стоял в 30 см от кувшинов и пересветил их (перерисовано: фонарь у края стола, 6 W) / + синий час над рядами читается / + кувшин-герой в центре

### Вариант ID: bazaar_jug/v02 — Заря — копия указывает на подлинник

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «заря» (часы устройства игрока, без случайности): в журнал ложится строка «bazaar_jug, заря», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: dawn, solar 04:45, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit +11 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Базар просыпается. «Так лепили всегда», — сказал гончар. Он заплатил за кувшин и не спросил, с чего его лепили. / Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_bazaar_jug_02", "video_prompt": "A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: dawn, solar 04:45, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit +11 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Базар просыпается. «Так лепили всегда», — сказал гончар. Он заплатил за кувшин и не спросил, с чего его лепили. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch bazaar_jug and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bazaar_jug/v03 — Восход — копия указывает на подлинник

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «восход» (часы устройства игрока, без случайности): в журнал ложится строка «bazaar_jug, восход», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: sunrise, solar 05:12, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 47.2 mm lens, orbit -6 deg around the subject from the reference view, -5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце встаёт над рядами. Гончар вертит кувшин: «Так лепили всегда». Он платит, а подлинник молчит где-то. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_bazaar_jug_03", "video_prompt": "A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: sunrise, solar 05:12, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 47.2 mm lens, orbit -6 deg around the subject from the reference view, -5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце встаёт над рядами. Гончар вертит кувшин: «Так лепили всегда». Он платит, а подлинник молчит где-то. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch bazaar_jug and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bazaar_jug/v04 — Утро — копия указывает на подлинник

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «утро» (часы устройства игрока, без случайности): в журнал ложится строка «bazaar_jug, утро», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Ловкость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: morning, solar 06:45, sun elevation +18 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 31.5 mm lens, orbit +21 deg around the subject from the reference view, +2 deg tilt, roll -3 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Утро, год назад. Гончар хвалил форму: «Так лепили всегда». Он купил копию и не спросил, чья рука была первой. / Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_bazaar_jug_04", "video_prompt": "A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: morning, solar 06:45, sun elevation +18 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 31.5 mm lens, orbit +21 deg around the subject from the reference view, +2 deg tilt, roll -3 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Утро, год назад. Гончар хвалил форму: «Так лепили всегда». Он купил копию и не спросил, чья рука была первой. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch bazaar_jug and video assets", "status": "ready_for_render"}
```

Хор: − видны края навеса и стоек — макет / + утренние полосы от бахромы ложатся на стол / + вмятина пальца на кувшине различима

### Вариант ID: bazaar_jug/v05 — Позднее утро — копия указывает на подлинник

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «позднее утро» (часы устройства игрока, без случайности): в журнал ложится строка «bazaar_jug, позднее утро», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: late morning, solar 10:30, sun elevation +57 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 26.2 mm lens, orbit -24 deg around the subject from the reference view, +5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Пыль над рядами. «Так лепили всегда», — гончар постучал по глазури. Он заплатил и ушёл без вопроса. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_bazaar_jug_05", "video_prompt": "A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: late morning, solar 10:30, sun elevation +57 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 26.2 mm lens, orbit -24 deg around the subject from the reference view, +5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Пыль над рядами. «Так лепили всегда», — гончар постучал по глазури. Он заплатил и ушёл без вопроса. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch bazaar_jug and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2150 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bazaar_jug/v06 — Полдень — копия указывает на подлинник

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «полдень» (часы устройства игрока, без случайности): в журнал ложится строка «bazaar_jug, полдень», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: solar noon, solar 12:00, sun elevation +63 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit +0 deg around the subject from the reference view, +7 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Полдень, тень от навеса. Гончар сказал: «Так лепили всегда». Копия легла ему в руки, подлинник остался ненайденным. / Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_bazaar_jug_06", "video_prompt": "A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: solar noon, solar 12:00, sun elevation +63 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit +0 deg around the subject from the reference view, +7 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Полдень, тень от навеса. Гончар сказал: «Так лепили всегда». Копия легла ему в руки, подлинник остался ненайденным. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch bazaar_jug and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2200 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bazaar_jug/v07 — После полудня — копия указывает на подлинник

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «после полудня» (часы устройства игрока, без случайности): в журнал ложится строка «bazaar_jug, после полудня», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: afternoon, solar 14:30, sun elevation +48 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.2 mm lens, orbit +27 deg around the subject from the reference view, -2 deg tilt, roll 3 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Базар редеет. Он торгуется за кувшин; гончар пожимает плечами: «Так лепили всегда». Где подлинник, он не спросил. / Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_bazaar_jug_07", "video_prompt": "A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: afternoon, solar 14:30, sun elevation +48 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.2 mm lens, orbit +27 deg around the subject from the reference view, -2 deg tilt, roll 3 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Базар редеет. Он торгуется за кувшин; гончар пожимает плечами: «Так лепили всегда». Где подлинник, он не спросил. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch bazaar_jug and video assets", "status": "ready_for_render"}
```

Хор: − наклон +3° заметен; в шлеме — на грани / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bazaar_jug/v08 — Золотой час — копия указывает на подлинник

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «золотой час» (часы устройства игрока, без случайности): в журнал ложится строка «bazaar_jug, золотой час», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: golden hour, solar 18:03, sun elevation +10 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 52.5 mm lens, orbit -13 deg around the subject from the reference view, -6 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Вечернее солнце в глазури. «Так лепили всегда», — сказал гончар. Форма пережила руку, а он купил только копию. / Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_bazaar_jug_08", "video_prompt": "A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: golden hour, solar 18:03, sun elevation +10 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 52.5 mm lens, orbit -13 deg around the subject from the reference view, -6 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Вечернее солнце в глазури. «Так лепили всегда», — сказал гончар. Форма пережила руку, а он купил только копию. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch bazaar_jug and video assets", "status": "ready_for_render"}
```

Хор: − соседние ряды в пыли почти без деталей / + золотой свет в бирюзовой глазури — лучший цвет серии / + кувшин-герой крупно, копии рядом: копия указывает на подлинник

### Вариант ID: bazaar_jug/v09 — Закат — копия указывает на подлинник

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «закат» (часы устройства игрока, без случайности): в журнал ложится строка «bazaar_jug, закат», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: sunset, solar 18:57, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 29.8 mm lens, orbit +16 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Закат, ряды сворачивают. Гончар отдал ему последний кувшин: «Так лепили всегда». Откуда форма, он не спросил. / Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_bazaar_jug_09", "video_prompt": "A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: sunset, solar 18:57, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 29.8 mm lens, orbit +16 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Закат, ряды сворачивают. Гончар отдал ему последний кувшин: «Так лепили всегда». Откуда форма, он не спросил. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch bazaar_jug and video assets", "status": "ready_for_render"}
```

Хор: − солнце у горизонта ушло за глинобитные стены, кадр плоский / + тишина конца базарного дня / + честная физика: на закате свет не доходит в переулок

### Вариант ID: bazaar_jug/v10 — Сумерки — копия указывает на подлинник

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «сумерки» (часы устройства игрока, без случайности): в журнал ложится строка «bazaar_jug, сумерки», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: dusk, solar 19:30, sun elevation -5 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit -29 deg around the subject from the reference view, +2 deg tilt, roll -2 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сумерки на базаре. Он несёт копию, а слова гончара «так лепили всегда» указывают на подлинник. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_bazaar_jug_10", "video_prompt": "A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: dusk, solar 19:30, sun elevation -5 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit -29 deg around the subject from the reference view, +2 deg tilt, roll -2 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сумерки на базаре. Он несёт копию, а слова гончара «так лепили всегда» указывают на подлинник. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch bazaar_jug and video assets", "status": "ready_for_render"}
```

Хор: − экспонометр не дошёл до цели (0.12 против 0.17) / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bazaar_jug/v11 — Ночь с луной — копия указывает на подлинник

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «ночь с луной» (часы устройства игрока, без случайности): в журнал ложится строка «bazaar_jug, ночь с луной», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: night with moon, solar 22:30, sun elevation -28 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 31.5 mm lens, orbit +6 deg around the subject from the reference view, +5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Луна над пустым базаром. Здесь гончар сказал: «Так лепили всегда». Он купил копию и не спросил о подлиннике. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_bazaar_jug_11", "video_prompt": "A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: night with moon, solar 22:30, sun elevation -28 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 31.5 mm lens, orbit +6 deg around the subject from the reference view, +5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Луна над пустым базаром. Здесь гончар сказал: «Так лепили всегда». Он купил копию и не спросил о подлиннике. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch bazaar_jug and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bazaar_jug/v12 — Глухая ночь, только огонь — копия указывает на подлинник

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «глухая ночь, только огонь» (часы устройства игрока, без случайности): в журнал ложится строка «bazaar_jug, глухая ночь, только огонь», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: deep night, solar 02:45, sun elevation -21 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 43.8 mm lens, orbit -3 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Ночь, у прилавка фонарь. «Так лепили всегда», — повторяет гончар. Копия ушла с ним, подлинник ждёт. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_bazaar_jug_12", "video_prompt": "A market stall in Karakol: a poplar table under a faded cotton awning, a turquoise crackle-glazed jug 28 cm tall with a thumb dent low on its side, eight smaller jugs behind it, neighbouring stalls and adobe walls in warm dust. No person in frame. Time: deep night, solar 02:45, sun elevation -21 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 43.8 mm lens, orbit -3 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: awning valance strips sway 1-2 cm in a light wind; dust hangs in the air; the hero jug stays still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Ночь, у прилавка фонарь. «Так лепили всегда», — повторяет гончар. Копия ушла с ним, подлинник ждёт. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch bazaar_jug and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: tape_at_night/v01 — Предрассветный синий час — память, которой не верят сети

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «предрассветный синий час» (часы устройства игрока, без случайности): в журнал ложится строка «tape_at_night, предрассветный синий час», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: pre-dawn blue hour, solar 05:29, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; no fire; instrument screen 6500 K; never 1800 K. Camera: 28 mm lens, orbit -10 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Пять утра, окно синеет. Скотч трещит. Он клеит копию журнала под стол и прячет её от своих. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_tape_at_night_01", "video_prompt": "Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: pre-dawn blue hour, solar 05:29, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; no fire; instrument screen 6500 K; never 1800 K. Camera: 28 mm lens, orbit -10 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Пять утра, окно синеет. Скотч трещит. Он клеит копию журнала под стол и прячет её от своих. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch tape_at_night and video assets", "status": "ready_for_render"}
```

Хор: − первый прогон: дневной свет не доходил под стол, все 12 часов выглядели одинаково (перерисовано: окно опущено к полу) / + флешка и две полосы скотча читаются / + огня нет — только свет прибора 6500 K, как велит класс 2026 года

### Вариант ID: tape_at_night/v02 — Заря — память, которой не верят сети

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «заря» (часы устройства игрока, без случайности): в журнал ложится строка «tape_at_night, заря», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: dawn, solar 05:56, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; no fire; instrument screen 6500 K; never 1800 K. Camera: 35 mm lens, orbit +6 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Рассвет над Караколом. Он проверяет флешку под столом: на месте. От своих он уже прячет правду. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_tape_at_night_02", "video_prompt": "Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: dawn, solar 05:56, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; no fire; instrument screen 6500 K; never 1800 K. Camera: 35 mm lens, orbit +6 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Рассвет над Караколом. Он проверяет флешку под столом: на месте. От своих он уже прячет правду. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch tape_at_night and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: экран прибора 6500 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: tape_at_night/v03 — Восход — память, которой не верят сети

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «восход» (часы устройства игрока, без случайности): в журнал ложится строка «tape_at_night, восход», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: sunrise, solar 06:23, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; no fire; instrument screen 6500 K; never 1800 K. Camera: 47.2 mm lens, orbit -4 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце в окне, а он под столом с мотком скотча. Копия журнала спрятана от своих, не от чужих. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_tape_at_night_03", "video_prompt": "Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: sunrise, solar 06:23, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; no fire; instrument screen 6500 K; never 1800 K. Camera: 47.2 mm lens, orbit -4 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце в окне, а он под столом с мотком скотча. Копия журнала спрятана от своих, не от чужих. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch tape_at_night and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: экран прибора 6500 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: tape_at_night/v04 — Утро — память, которой не верят сети

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «утро» (часы устройства игрока, без случайности): в журнал ложится строка «tape_at_night, утро», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Ловкость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: morning, solar 07:56, sun elevation +18 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; no fire; instrument screen 6500 K; never 1800 K. Camera: 31.5 mm lens, orbit +12 deg around the subject from the reference view, +1 deg tilt, roll -3 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Утро, команда за стеной пьёт чай. Он тихо прижимает скотч. Копия журнала — память, которой не верят сети. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_tape_at_night_04", "video_prompt": "Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: morning, solar 07:56, sun elevation +18 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; no fire; instrument screen 6500 K; never 1800 K. Camera: 31.5 mm lens, orbit +12 deg around the subject from the reference view, +1 deg tilt, roll -3 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Утро, команда за стеной пьёт чай. Он тихо прижимает скотч. Копия журнала — память, которой не верят сети. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch tape_at_night and video assets", "status": "ready_for_render"}
```

Хор: − наклон -3° заметен; в шлеме — на грани / + свет класса часа честный: экран прибора 6500 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: tape_at_night/v05 — Позднее утро — память, которой не верят сети

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «позднее утро» (часы устройства игрока, без случайности): в журнал ложится строка «tape_at_night, позднее утро», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: late morning, solar 10:30, sun elevation +40 deg. Lighting: high sun about 5000 K, even working light; no fire; instrument screen 6500 K; never 1800 K. Camera: 26.2 mm lens, orbit -14 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Скотч отходит, он прижимает его ногтем. Кто продаст, он ещё не знает, но прячет уже от своих. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_tape_at_night_05", "video_prompt": "Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: late morning, solar 10:30, sun elevation +40 deg. Lighting: high sun about 5000 K, even working light; no fire; instrument screen 6500 K; never 1800 K. Camera: 26.2 mm lens, orbit -14 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Скотч отходит, он прижимает его ногтем. Кто продаст, он ещё не знает, но прячет уже от своих. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch tape_at_night and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: экран прибора 6500 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: tape_at_night/v06 — Полдень — память, которой не верят сети

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «полдень» (часы устройства игрока, без случайности): в журнал ложится строка «tape_at_night, полдень», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: solar noon, solar 12:00, sun elevation +44 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; no fire; instrument screen 6500 K; never 1800 K. Camera: 35 mm lens, orbit +0 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Полдень, в комнате пусто. Он клеит копию журнала под стол, пока никто не видит. Предательство начинается внутри. / Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_tape_at_night_06", "video_prompt": "Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: solar noon, solar 12:00, sun elevation +44 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; no fire; instrument screen 6500 K; never 1800 K. Camera: 35 mm lens, orbit +0 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Полдень, в комнате пусто. Он клеит копию журнала под стол, пока никто не видит. Предательство начинается внутри. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch tape_at_night and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: экран прибора 6500 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: tape_at_night/v07 — После полудня — память, которой не верят сети

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «после полудня» (часы устройства игрока, без случайности): в журнал ложится строка «tape_at_night, после полудня», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: afternoon, solar 14:30, sun elevation +33 deg. Lighting: sun from the other side at about 5200 K; no fire; instrument screen 6500 K; never 1800 K. Camera: 40.2 mm lens, orbit +15 deg around the subject from the reference view, -1 deg tilt, roll 3 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** День в разгаре. Под столом флешка в двух полосках скотча. Он прячет копию от своих. Время пока ничего не значит. / Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_tape_at_night_07", "video_prompt": "Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: afternoon, solar 14:30, sun elevation +33 deg. Lighting: sun from the other side at about 5200 K; no fire; instrument screen 6500 K; never 1800 K. Camera: 40.2 mm lens, orbit +15 deg around the subject from the reference view, -1 deg tilt, roll 3 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "День в разгаре. Под столом флешка в двух полосках скотча. Он прячет копию от своих. Время пока ничего не значит. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch tape_at_night and video assets", "status": "ready_for_render"}
```

Хор: − наклон +3° заметен; в шлеме — на грани / + свет класса часа честный: экран прибора 6500 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: tape_at_night/v08 — Золотой час — память, которой не верят сети

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «золотой час» (часы устройства игрока, без случайности): в журнал ложится строка «tape_at_night, золотой час», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: golden hour, solar 16:52, sun elevation +10 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; no fire; instrument screen 6500 K; never 1800 K. Camera: 52.5 mm lens, orbit -7 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Закатный луч на полу. Он ещё раз проводит пальцем по скотчу. Копия под столом надёжнее любой сети. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_tape_at_night_08", "video_prompt": "Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: golden hour, solar 16:52, sun elevation +10 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; no fire; instrument screen 6500 K; never 1800 K. Camera: 52.5 mm lens, orbit -7 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Закатный луч на полу. Он ещё раз проводит пальцем по скотчу. Копия под столом надёжнее любой сети. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch tape_at_night and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: экран прибора 6500 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: tape_at_night/v09 — Закат — память, которой не верят сети

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «закат» (часы устройства игрока, без случайности): в журнал ложится строка «tape_at_night, закат», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: sunset, solar 17:46, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; no fire; instrument screen 6500 K; never 1800 K. Camera: 29.8 mm lens, orbit +9 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце ушло за горы. Флешка остаётся под столом: копия, которую не увидят ни свои, ни сеть. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_tape_at_night_09", "video_prompt": "Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: sunset, solar 17:46, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; no fire; instrument screen 6500 K; never 1800 K. Camera: 29.8 mm lens, orbit +9 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце ушло за горы. Флешка остаётся под столом: копия, которую не увидят ни свои, ни сеть. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch tape_at_night and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: экран прибора 6500 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: tape_at_night/v10 — Сумерки — память, которой не верят сети

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «сумерки» (часы устройства игрока, без случайности): в журнал ложится строка «tape_at_night, сумерки», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: dusk, solar 18:19, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; no fire; instrument screen 6500 K; never 1800 K. Camera: 35 mm lens, orbit -16 deg around the subject from the reference view, +1 deg tilt, roll -2 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сумерки, свет только от экрана. Скотч трещит громко. Он прячет копию от своих и сам этого стыдится. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_tape_at_night_10", "video_prompt": "Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: dusk, solar 18:19, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; no fire; instrument screen 6500 K; never 1800 K. Camera: 35 mm lens, orbit -16 deg around the subject from the reference view, +1 deg tilt, roll -2 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сумерки, свет только от экрана. Скотч трещит громко. Он прячет копию от своих и сам этого стыдится. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch tape_at_night and video assets", "status": "ready_for_render"}
```

Хор: − наклон -2° заметен; в шлеме — на грани / + свет класса часа честный: экран прибора 6500 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: tape_at_night/v11 — Ночь с луной — память, которой не верят сети

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «ночь с луной» (часы устройства игрока, без случайности): в журнал ложится строка «tape_at_night, ночь с луной», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: night with moon, solar 22:30, sun elevation -46 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; no fire; instrument screen 6500 K; never 1800 K. Camera: 31.5 mm lens, orbit +4 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Ночь, луна в окне. Три двенадцать. Скотч трещит громко. Он клеит копию журнала под стол, прячет от своих. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_tape_at_night_11", "video_prompt": "Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: night with moon, solar 22:30, sun elevation -46 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; no fire; instrument screen 6500 K; never 1800 K. Camera: 31.5 mm lens, orbit +4 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Ночь, луна в окне. Три двенадцать. Скотч трещит громко. Он клеит копию журнала под стол, прячет от своих. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch tape_at_night and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: экран прибора 6500 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: tape_at_night/v12 — Глухая ночь, только огонь — память, которой не верят сети

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «глухая ночь, только огонь» (часы устройства игрока, без случайности): в журнал ложится строка «tape_at_night, глухая ночь, только огонь», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `immersion` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `immersion` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: deep night, solar 02:45, sun elevation -36 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; no fire; instrument screen 6500 K; never 1800 K. Camera: 43.8 mm lens, orbit -2 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Три двенадцать, горит один экран. Скотч трещит на весь дом. Копия под столом. Время пока ничего не значит. Вода в комнате уже поднимается.

**4. Метаданные:**

```json
{"node_id": "v_tape_at_night_12", "video_prompt": "Under a birch desk: a black USB drive taped to the underside of the board with two parallel strips of paper tape, one strip end curling loose; an orange ROV tether coiled on a wall hook; a crate with a turned-away alarm clock. No person in frame. Time: deep night, solar 02:45, sun elevation -36 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; no fire; instrument screen 6500 K; never 1800 K. Camera: 43.8 mm lens, orbit -2 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the loose tape end trembles slightly; the laptop screen light from above is steady; no motion otherwise. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Три двенадцать, горит один экран. Скотч трещит на весь дом. Копия под столом. Время пока ничего не значит. Вода в комнате уже поднимается.", "git_commit_msg": "feat(story): add narrative branch tape_at_night and video assets", "status": "ready_for_render"}
```

Хор: − буква «Н» из двух полос скотча всё ещё читается на расстоянии / + три двенадцать ночи: один экран, комната во тьме / + красный отсвет будильника без цифр — время без счётчика

### Вариант ID: ford_of_cold/v01 — Предрассветный синий час — порог холода

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «предрассветный синий час» (часы устройства игрока, без случайности): в журнал ложится строка «ford_of_cold, предрассветный синий час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: pre-dawn blue hour, solar 06:09, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 22.4 mm lens, orbit -15 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Синий холод перед зарёй. Рыцарь ведёт коня вброд. На середине конь встал, и рыцарь не дышал. Внизу трос дёрнется, как тот порог.

**4. Метаданные:**

```json
{"node_id": "v_ford_of_cold_01", "video_prompt": "A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: pre-dawn blue hour, solar 06:09, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 22.4 mm lens, orbit -15 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Синий холод перед зарёй. Рыцарь ведёт коня вброд. На середине конь встал, и рыцарь не дышал. Внизу трос дёрнется, как тот порог.", "git_commit_msg": "feat(story): add narrative branch ford_of_cold and video assets", "status": "ready_for_render"}
```

Хор: − камни ближнего берега почти без инея / + синий холод перед зарёй — порог читается телом / + костёр на дальнем берегу — тёплая точка против холода

### Вариант ID: ford_of_cold/v02 — Заря — порог холода

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «заря» (часы устройства игрока, без случайности): в журнал ложится строка «ford_of_cold, заря», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: dawn, solar 06:36, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit +10 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Заря над хребтом. Конь вошёл в реку и встал на середине. Рыцарь задержал дыхание: порог холода один и резкий. / Внизу трос дёрнется, как тот порог.

**4. Метаданные:**

```json
{"node_id": "v_ford_of_cold_02", "video_prompt": "A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: dawn, solar 06:36, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit +10 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Заря над хребтом. Конь вошёл в реку и встал на середине. Рыцарь задержал дыхание: порог холода один и резкий. Внизу трос дёрнется, как тот порог.", "git_commit_msg": "feat(story): add narrative branch ford_of_cold and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ford_of_cold/v03 — Восход — порог холода

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «восход» (часы устройства игрока, без случайности): в журнал ложится строка «ford_of_cold, восход», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: sunrise, solar 07:03, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 37.8 mm lens, orbit -6 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце тронуло гребни. Рыцарь ведёт коня к озеру, что не замерзает. На середине конь встал; рыцарь не дышал. / Внизу трос дёрнется, как тот порог.

**4. Метаданные:**

```json
{"node_id": "v_ford_of_cold_03", "video_prompt": "A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: sunrise, solar 07:03, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 37.8 mm lens, orbit -6 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце тронуло гребни. Рыцарь ведёт коня к озеру, что не замерзает. На середине конь встал; рыцарь не дышал. Внизу трос дёрнется, как тот порог.", "git_commit_msg": "feat(story): add narrative branch ford_of_cold and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ford_of_cold/v04 — Утро — порог холода

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «утро» (часы устройства игрока, без случайности): в журнал ложится строка «ford_of_cold, утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Ловкость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: morning, solar 08:36, sun elevation +17 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 25.2 mm lens, orbit +18 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Утро в ущелье. Вода по колено коню, на середине он встал. Рыцарь замер: тело помнит порог раньше ума. Внизу трос дёрнется, как тот порог.

**4. Метаданные:**

```json
{"node_id": "v_ford_of_cold_04", "video_prompt": "A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: morning, solar 08:36, sun elevation +17 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 25.2 mm lens, orbit +18 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Утро в ущелье. Вода по колено коню, на середине он встал. Рыцарь замер: тело помнит порог раньше ума. Внизу трос дёрнется, как тот порог.", "git_commit_msg": "feat(story): add narrative branch ford_of_cold and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ford_of_cold/v05 — Позднее утро — порог холода

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «позднее утро» (часы устройства игрока, без случайности): в журнал ложится строка «ford_of_cold, позднее утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: late morning, solar 10:30, sun elevation +30 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 21 mm lens, orbit -21 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Иней сошёл с камней. Рыцарь ведёт коня вброд; посреди потока конь стоит, и рыцарь не смеет вдохнуть. Внизу трос дёрнется, как тот порог.

**4. Метаданные:**

```json
{"node_id": "v_ford_of_cold_05", "video_prompt": "A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: late morning, solar 10:30, sun elevation +30 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 21 mm lens, orbit -21 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Иней сошёл с камней. Рыцарь ведёт коня вброд; посреди потока конь стоит, и рыцарь не смеет вдохнуть. Внизу трос дёрнется, как тот порог.", "git_commit_msg": "feat(story): add narrative branch ford_of_cold and video assets", "status": "ready_for_render"}
```

Хор: − при подъёме камеры видна плоская кромка дальней отмели / + полуденная вода прозрачна, пена у камней читается / + хребет с отражением держит глубину

### Вариант ID: ford_of_cold/v06 — Полдень — порог холода

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «полдень» (часы устройства игрока, без случайности): в журнал ложится строка «ford_of_cold, полдень», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: solar noon, solar 12:00, sun elevation +34 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit +0 deg around the subject from the reference view, +6 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Полдень, а река ледяная. Рыцарь ведёт коня вброд. Порог холода солнце не смягчает: его переходят собой. Внизу трос дёрнется, как тот порог.

**4. Метаданные:**

```json
{"node_id": "v_ford_of_cold_06", "video_prompt": "A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: solar noon, solar 12:00, sun elevation +34 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit +0 deg around the subject from the reference view, +6 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Полдень, а река ледяная. Рыцарь ведёт коня вброд. Порог холода солнце не смягчает: его переходят собой. Внизу трос дёрнется, как тот порог.", "git_commit_msg": "feat(story): add narrative branch ford_of_cold and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2200 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ford_of_cold/v07 — После полудня — порог холода

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «после полудня» (часы устройства игрока, без случайности): в журнал ложится строка «ford_of_cold, после полудня», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: afternoon, solar 14:30, sun elevation +24 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 32.2 mm lens, orbit +24 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Тени удлинились. Конь встал посреди брода, и рыцарь ждал, не дыша. Граница воды честная: одна и резкая. Внизу трос дёрнется, как тот порог.

**4. Метаданные:**

```json
{"node_id": "v_ford_of_cold_07", "video_prompt": "A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: afternoon, solar 14:30, sun elevation +24 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 32.2 mm lens, orbit +24 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Тени удлинились. Конь встал посреди брода, и рыцарь ждал, не дыша. Граница воды честная: одна и резкая. Внизу трос дёрнется, как тот порог.", "git_commit_msg": "feat(story): add narrative branch ford_of_cold and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ford_of_cold/v08 — Золотой час — порог холода

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «золотой час» (часы устройства игрока, без случайности): в журнал ложится строка «ford_of_cold, золотой час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: golden hour, solar 16:12, sun elevation +9 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 42 mm lens, orbit -11 deg around the subject from the reference view, -6 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Золото на склонах, в реке стужа. Рыцарь вёл коня к озеру. На середине конь встал, и он не дышал. Внизу трос дёрнется, как тот порог.

**4. Метаданные:**

```json
{"node_id": "v_ford_of_cold_08", "video_prompt": "A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: golden hour, solar 16:12, sun elevation +9 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 42 mm lens, orbit -11 deg around the subject from the reference view, -6 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Золото на склонах, в реке стужа. Рыцарь вёл коня к озеру. На середине конь встал, и он не дышал. Внизу трос дёрнется, как тот порог.", "git_commit_msg": "feat(story): add narrative branch ford_of_cold and video assets", "status": "ready_for_render"}
```

Хор: − первый прогон: камера упёрлась в валун (перерисовано: камера поднимается над препятствием) / + золото на склонах против стужи в реке / + след копыт на дальнем берегу в фокусе

### Вариант ID: ford_of_cold/v09 — Закат — порог холода

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «закат» (часы устройства игрока, без случайности): в журнал ложится строка «ford_of_cold, закат», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: sunset, solar 17:06, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 23.8 mm lens, orbit +14 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце за хребтом. Рыцарь торопится через брод. Конь встал на середине, и рыцарь затаил дыхание у порога. / Внизу трос дёрнется, как тот порог.

**4. Метаданные:**

```json
{"node_id": "v_ford_of_cold_09", "video_prompt": "A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: sunset, solar 17:06, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 23.8 mm lens, orbit +14 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце за хребтом. Рыцарь торопится через брод. Конь встал на середине, и рыцарь затаил дыхание у порога. Внизу трос дёрнется, как тот порог.", "git_commit_msg": "feat(story): add narrative branch ford_of_cold and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ford_of_cold/v10 — Сумерки — порог холода

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «сумерки» (часы устройства игрока, без случайности): в журнал ложится строка «ford_of_cold, сумерки», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: dusk, solar 17:39, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit -25 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сумерки, след копыт полон воды. Здесь конь встал, и рыцарь не дышал: порог переходят собой, не машиной. Внизу трос дёрнется, как тот порог.

**4. Метаданные:**

```json
{"node_id": "v_ford_of_cold_10", "video_prompt": "A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: dusk, solar 17:39, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit -25 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сумерки, след копыт полон воды. Здесь конь встал, и рыцарь не дышал: порог переходят собой, не машиной. Внизу трос дёрнется, как тот порог.", "git_commit_msg": "feat(story): add narrative branch ford_of_cold and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ford_of_cold/v11 — Ночь с луной — порог холода

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «ночь с луной» (часы устройства игрока, без случайности): в журнал ложится строка «ford_of_cold, ночь с луной», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: night with moon, solar 22:30, sun elevation -56 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 25.2 mm lens, orbit +6 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Луна над рекой. Рыцарь ведёт коня вброд к озеру, что не замерзает. На середине конь встал, рыцарь не дышал. / Внизу трос дёрнется, как тот порог.

**4. Метаданные:**

```json
{"node_id": "v_ford_of_cold_11", "video_prompt": "A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: night with moon, solar 22:30, sun elevation -56 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 25.2 mm lens, orbit +6 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Луна над рекой. Рыцарь ведёт коня вброд к озеру, что не замерзает. На середине конь встал, рыцарь не дышал. Внизу трос дёрнется, как тот порог.", "git_commit_msg": "feat(story): add narrative branch ford_of_cold and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: ford_of_cold/v12 — Глухая ночь, только огонь — порог холода

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «глухая ночь, только огонь» (часы устройства игрока, без случайности): в журнал ложится строка «ford_of_cold, глухая ночь, только огонь», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: deep night, solar 02:45, sun elevation -44 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit -3 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Ночь, у брода тлеет костёр. Рыцарь знает: на середине конь встанет, и дыхание остановится само. Внизу трос дёрнется, как тот порог.

**4. Метаданные:**

```json
{"node_id": "v_ford_of_cold_12", "video_prompt": "A cold mountain ford: wet dark river stones with torn foam on their downstream side, rimed stones on the near bank, hoof prints filled with water and a dropped leather glove on the far gravel bank, a snow range across a lake behind. No person or horse in frame. Time: deep night, solar 02:45, sun elevation -44 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit -3 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the river runs left to right at about 1 m/s; foam drifts and breaks; a thin mist lies 30 cm over the water. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Ночь, у брода тлеет костёр. Рыцарь знает: на середине конь встанет, и дыхание остановится само. Внизу трос дёрнется, как тот порог.", "git_commit_msg": "feat(story): add narrative branch ford_of_cold and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: hands_of_masons/v01 — Предрассветный синий час — шнур держат свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «предрассветный синий час» (часы устройства игрока, без случайности): в журнал ложится строка «hands_of_masons, предрассветный синий час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: pre-dawn blue hour, solar 03:46, sun elevation -7 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 68 mm lens, orbit -13 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** До рассвета братья натянули шнур меж колышков. Ряд камня ляжет по нему. Стена ровна, пока шнур не тронут свои. / Внизу трос дёрнется — с ближнего конца.

**4. Метаданные:**

```json
{"node_id": "v_hands_of_masons_01", "video_prompt": "A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: pre-dawn blue hour, solar 03:46, sun elevation -7 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 68 mm lens, orbit -13 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "До рассвета братья натянули шнур меж колышков. Ряд камня ляжет по нему. Стена ровна, пока шнур не тронут свои. Внизу трос дёрнется — с ближнего конца.", "git_commit_msg": "feat(story): add narrative branch hands_of_masons and video assets", "status": "ready_for_render"}
```

Хор: − первый прогон: чёрный кадр — камера оказалась внутри стены (перерисовано: луч из тела стены не считается препятствием) / + ночной костёр сторожа по рецепту 2100 K / + шнур остаётся единственной прямой в кадре

### Вариант ID: hands_of_masons/v02 — Заря — шнур держат свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «заря» (часы устройства игрока, без случайности): в журнал ложится строка «hands_of_masons, заря», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: dawn, solar 04:13, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 85 mm lens, orbit +8 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Заря. Шнур натянут меж двух колышков, и первый камень лёг под него. Тронуть шнур может только свой. Внизу трос дёрнется — с ближнего конца.

**4. Метаданные:**

```json
{"node_id": "v_hands_of_masons_02", "video_prompt": "A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: dawn, solar 04:13, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 85 mm lens, orbit +8 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Заря. Шнур натянут меж двух колышков, и первый камень лёг под него. Тронуть шнур может только свой. Внизу трос дёрнется — с ближнего конца.", "git_commit_msg": "feat(story): add narrative branch hands_of_masons and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: hands_of_masons/v03 — Восход — шнур держат свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «восход» (часы устройства игрока, без случайности): в журнал ложится строка «hands_of_masons, восход», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: sunrise, solar 04:40, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 114.8 mm lens, orbit -5 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце вдоль шнура. Братья кладут ряд по натянутой нити. Прямая линия выдаёт руку человека. Внизу трос дёрнется — с ближнего конца.

**4. Метаданные:**

```json
{"node_id": "v_hands_of_masons_03", "video_prompt": "A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: sunrise, solar 04:40, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 114.8 mm lens, orbit -5 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце вдоль шнура. Братья кладут ряд по натянутой нити. Прямая линия выдаёт руку человека. Внизу трос дёрнется — с ближнего конца.", "git_commit_msg": "feat(story): add narrative branch hands_of_masons and video assets", "status": "ready_for_render"}
```

Хор: − длинный фокус 114.8 мм сжимает план, место теряется / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: hands_of_masons/v04 — Утро — шнур держат свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «утро» (часы устройства игрока, без случайности): в журнал ложится строка «hands_of_masons, утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Ловкость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: morning, solar 06:13, sun elevation +17 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 76.5 mm lens, orbit +16 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Утро на стройке обители. Шнур меж колышков, ряд камня ложится по нему. Стена ровна, пока шнур цел. Внизу трос дёрнется — с ближнего конца.

**4. Метаданные:**

```json
{"node_id": "v_hands_of_masons_04", "video_prompt": "A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: morning, solar 06:13, sun elevation +17 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 76.5 mm lens, orbit +16 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Утро на стройке обители. Шнур меж колышков, ряд камня ложится по нему. Стена ровна, пока шнур цел. Внизу трос дёрнется — с ближнего конца.", "git_commit_msg": "feat(story): add narrative branch hands_of_masons and video assets", "status": "ready_for_render"}
```

Хор: − камни верхнего ряда одинаково серые / + утро, длинные тени: шнур над рядом виден / + отвес и тренога на втором плане — мера стены

### Вариант ID: hands_of_masons/v05 — Позднее утро — шнур держат свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «позднее утро» (часы устройства игрока, без случайности): в журнал ложится строка «hands_of_masons, позднее утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: late morning, solar 10:30, sun elevation +63 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 63.8 mm lens, orbit -18 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Жара поднимается. Отвес висит неподвижно, шнур натянут. Ломать прямую будет не ветер, а свой. Внизу трос дёрнется — с ближнего конца.

**4. Метаданные:**

```json
{"node_id": "v_hands_of_masons_05", "video_prompt": "A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: late morning, solar 10:30, sun elevation +63 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 63.8 mm lens, orbit -18 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Жара поднимается. Отвес висит неподвижно, шнур натянут. Ломать прямую будет не ветер, а свой. Внизу трос дёрнется — с ближнего конца.", "git_commit_msg": "feat(story): add narrative branch hands_of_masons and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2150 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: hands_of_masons/v06 — Полдень — шнур держат свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «полдень» (часы устройства игрока, без случайности): в журнал ложится строка «hands_of_masons, полдень», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: solar noon, solar 12:00, sun elevation +70 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 85 mm lens, orbit +0 deg around the subject from the reference view, +5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Полдень, тени коротки. Братья ушли к воде, шнур остался натянутым. Стена ровна, пока его не тронут свои. / Внизу трос дёрнется — с ближнего конца.

**4. Метаданные:**

```json
{"node_id": "v_hands_of_masons_06", "video_prompt": "A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: solar noon, solar 12:00, sun elevation +70 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 85 mm lens, orbit +0 deg around the subject from the reference view, +5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Полдень, тени коротки. Братья ушли к воде, шнур остался натянутым. Стена ровна, пока его не тронут свои. Внизу трос дёрнется — с ближнего конца.", "git_commit_msg": "feat(story): add narrative branch hands_of_masons and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2200 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: hands_of_masons/v07 — После полудня — шнур держат свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «после полудня» (часы устройства игрока, без случайности): в журнал ложится строка «hands_of_masons, после полудня», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: afternoon, solar 14:30, sun elevation +53 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 97.7 mm lens, orbit +20 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** После полудня ряд почти лёг. Шнур меж колышков держит всю стену, а тронуть его может только свой. Внизу трос дёрнется — с ближнего конца.

**4. Метаданные:**

```json
{"node_id": "v_hands_of_masons_07", "video_prompt": "A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: afternoon, solar 14:30, sun elevation +53 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 97.7 mm lens, orbit +20 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "После полудня ряд почти лёг. Шнур меж колышков держит всю стену, а тронуть его может только свой. Внизу трос дёрнется — с ближнего конца.", "git_commit_msg": "feat(story): add narrative branch hands_of_masons and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: hands_of_masons/v08 — Золотой час — шнур держат свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «золотой час» (часы устройства игрока, без случайности): в журнал ложится строка «hands_of_masons, золотой час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: golden hour, solar 18:35, sun elevation +9 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 127.5 mm lens, orbit -10 deg around the subject from the reference view, -5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Низкое солнце вдоль кладки, шнур светится нитью. Прямая держит, пока её не дёрнет рука изнутри. Внизу трос дёрнется — с ближнего конца.

**4. Метаданные:**

```json
{"node_id": "v_hands_of_masons_08", "video_prompt": "A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: golden hour, solar 18:35, sun elevation +9 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 127.5 mm lens, orbit -10 deg around the subject from the reference view, -5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Низкое солнце вдоль кладки, шнур светится нитью. Прямая держит, пока её не дёрнет рука изнутри. Внизу трос дёрнется — с ближнего конца.", "git_commit_msg": "feat(story): add narrative branch hands_of_masons and video assets", "status": "ready_for_render"}
```

Хор: − длинный фокус 127.5 мм сжимает план, место теряется / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: hands_of_masons/v09 — Закат — шнур держат свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «закат» (часы устройства игрока, без случайности): в журнал ложится строка «hands_of_masons, закат», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: sunset, solar 19:29, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 72.2 mm lens, orbit +12 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Закат. Братья оставили шнур натянутым на ночь. Стена ровна, пока никто из своих его не коснётся. Внизу трос дёрнется — с ближнего конца.

**4. Метаданные:**

```json
{"node_id": "v_hands_of_masons_09", "video_prompt": "A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: sunset, solar 19:29, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 72.2 mm lens, orbit +12 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Закат. Братья оставили шнур натянутым на ночь. Стена ровна, пока никто из своих его не коснётся. Внизу трос дёрнется — с ближнего конца.", "git_commit_msg": "feat(story): add narrative branch hands_of_masons and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: hands_of_masons/v10 — Сумерки — шнур держат свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «сумерки» (часы устройства игрока, без случайности): в журнал ложится строка «hands_of_masons, сумерки», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: dusk, solar 20:02, sun elevation -5 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 85 mm lens, orbit -22 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сумерки над кладкой. Шнур еле виден, отвес замер. Чужой его не найдёт, тронуть может только свой. Внизу трос дёрнется — с ближнего конца.

**4. Метаданные:**

```json
{"node_id": "v_hands_of_masons_10", "video_prompt": "A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: dusk, solar 20:02, sun elevation -5 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 85 mm lens, orbit -22 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сумерки над кладкой. Шнур еле виден, отвес замер. Чужой его не найдёт, тронуть может только свой. Внизу трос дёрнется — с ближнего конца.", "git_commit_msg": "feat(story): add narrative branch hands_of_masons and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: hands_of_masons/v11 — Ночь с луной — шнур держат свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «ночь с луной» (часы устройства игрока, без случайности): в журнал ложится строка «hands_of_masons, ночь с луной», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: night with moon, solar 22:30, sun elevation -22 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 76.5 mm lens, orbit +5 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Луна на свежем ряду. Шнур натянут меж колышков, как днём. Стена ровна, пока шнур не тронут свои. Внизу трос дёрнется — с ближнего конца.

**4. Метаданные:**

```json
{"node_id": "v_hands_of_masons_11", "video_prompt": "A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: night with moon, solar 22:30, sun elevation -22 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 76.5 mm lens, orbit +5 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Луна на свежем ряду. Шнур натянут меж колышков, как днём. Стена ровна, пока шнур не тронут свои. Внизу трос дёрнется — с ближнего конца.", "git_commit_msg": "feat(story): add narrative branch hands_of_masons and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: hands_of_masons/v12 — Глухая ночь, только огонь — шнур держат свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «глухая ночь, только огонь» (часы устройства игрока, без случайности): в журнал ложится строка «hands_of_masons, глухая ночь, только огонь», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `tether_jerk` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `tether_jerk` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: deep night, solar 02:45, sun elevation -15 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 106.2 mm lens, orbit -2 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Ночь, у кладки тлеет костёр сторожа. Шнур держит линию в темноте. Ломает прямую только человек изнутри. / Внизу трос дёрнется — с ближнего конца.

**4. Метаданные:**

```json
{"node_id": "v_hands_of_masons_12", "video_prompt": "A monastery wall under construction by a lake: three courses of split granite and sandstone, a linen string taut 5 mm above the top course between two ash stakes, a tripod with a lead plumb bob, a mallet, a trowel, a wicker basket of mortar, bare footprints in the dust. No person in frame. Time: deep night, solar 02:45, sun elevation -15 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 106.2 mm lens, orbit -2 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the plumb bob hangs perfectly still; the string does not move; dust settles. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Ночь, у кладки тлеет костёр сторожа. Шнур держит линию в темноте. Ломает прямую только человек изнутри. Внизу трос дёрнется — с ближнего конца.", "git_commit_msg": "feat(story): add narrative branch hands_of_masons and video assets", "status": "ready_for_render"}
```

Хор: − тренога и шнур еле видны / + костёр сторожа красит кладку тёплым / + ночь честная: работы нет, шнур оставлен натянутым

### Вариант ID: harbor_of_ayas/v01 — Предрассветный синий час — швартов отдают свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «предрассветный синий час» (часы устройства игрока, без случайности): в журнал ложится строка «harbor_of_ayas, предрассветный синий час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `lure` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `lure` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: pre-dawn blue hour, solar 04:01, sun elevation -7 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit -6 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Аяс до зари. Юный рыцарь бежал к причалу, а свой уже отдал швартов. Трос рвут с ближнего конца. Внизу его уже ждёт приманка.

**4. Метаданные:**

```json
{"node_id": "v_harbor_of_ayas_01", "video_prompt": "A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: pre-dawn blue hour, solar 04:01, sun elevation -7 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit -6 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Аяс до зари. Юный рыцарь бежал к причалу, а свой уже отдал швартов. Трос рвут с ближнего конца. Внизу его уже ждёт приманка.", "git_commit_msg": "feat(story): add narrative branch harbor_of_ayas and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: harbor_of_ayas/v02 — Заря — швартов отдают свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «заря» (часы устройства игрока, без случайности): в журнал ложится строка «harbor_of_ayas, заря», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `lure` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `lure` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: dawn, solar 04:28, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit +4 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Заря над гаванью Аяса. Свой отдал швартов, и корабль ушёл. Юный рыцарь понял: связь рвут свои, не враги. Внизу его уже ждёт приманка.

**4. Метаданные:**

```json
{"node_id": "v_harbor_of_ayas_02", "video_prompt": "A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: dawn, solar 04:28, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit +4 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Заря над гаванью Аяса. Свой отдал швартов, и корабль ушёл. Юный рыцарь понял: связь рвут свои, не враги. Внизу его уже ждёт приманка.", "git_commit_msg": "feat(story): add narrative branch harbor_of_ayas and video assets", "status": "ready_for_render"}
```

Хор: − первый прогон: обход вокруг точки в море увёл камеру с причала, тумба и швартов пропали (перерисовано: размах 0,25) / + розовая заря над морем / + ког на горизонте с убранным парусом, без креста реи

### Вариант ID: harbor_of_ayas/v03 — Восход — швартов отдают свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «восход» (часы устройства игрока, без случайности): в журнал ложится строка «harbor_of_ayas, восход», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `lure` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `lure` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: sunrise, solar 04:55, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 47.2 mm lens, orbit -2 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце из моря, порт Марко Поло. Швартов в воде, корабль уходит. Его отдала рука своего, у причала. Внизу его уже ждёт приманка.

**4. Метаданные:**

```json
{"node_id": "v_harbor_of_ayas_03", "video_prompt": "A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: sunrise, solar 04:55, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 47.2 mm lens, orbit -2 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце из моря, порт Марко Поло. Швартов в воде, корабль уходит. Его отдала рука своего, у причала. Внизу его уже ждёт приманка.", "git_commit_msg": "feat(story): add narrative branch harbor_of_ayas and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: harbor_of_ayas/v04 — Утро — швартов отдают свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «утро» (часы устройства игрока, без случайности): в журнал ложится строка «harbor_of_ayas, утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `lure` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Ловкость». Все 12 вариантов сходятся в `lure` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: morning, solar 06:28, sun elevation +19 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 31.5 mm lens, orbit +6 deg around the subject from the reference view, +0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Утро в Аясе, ещё до мамлюков. Юный рыцарь видел, как свой снял швартов. Трос рвут с ближнего конца. Внизу его уже ждёт приманка.

**4. Метаданные:**

```json
{"node_id": "v_harbor_of_ayas_04", "video_prompt": "A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: morning, solar 06:28, sun elevation +19 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 31.5 mm lens, orbit +6 deg around the subject from the reference view, +0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Утро в Аясе, ещё до мамлюков. Юный рыцарь видел, как свой снял швартов. Трос рвут с ближнего конца. Внизу его уже ждёт приманка.", "git_commit_msg": "feat(story): add narrative branch harbor_of_ayas and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: harbor_of_ayas/v05 — Позднее утро — швартов отдают свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «позднее утро» (часы устройства игрока, без случайности): в журнал ложится строка «harbor_of_ayas, позднее утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `lure` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `lure` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: late morning, solar 10:30, sun elevation +66 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 26.2 mm lens, orbit -8 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Гавань в разгаре дня. Канат мокрый у тумбы, корабль на горизонте. Отдал его свой, не враг. Внизу его уже ждёт приманка.

**4. Метаданные:**

```json
{"node_id": "v_harbor_of_ayas_05", "video_prompt": "A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: late morning, solar 10:30, sun elevation +66 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 26.2 mm lens, orbit -8 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Гавань в разгаре дня. Канат мокрый у тумбы, корабль на горизонте. Отдал его свой, не враг. Внизу его уже ждёт приманка.", "git_commit_msg": "feat(story): add narrative branch harbor_of_ayas and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2150 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: harbor_of_ayas/v06 — Полдень — швартов отдают свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «полдень» (часы устройства игрока, без случайности): в журнал ложится строка «harbor_of_ayas, полдень», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `lure` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `lure` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: solar noon, solar 12:00, sun elevation +77 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit +0 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Полдень в Аясе. Швартов лежит на камнях, корабль уже далеко. Юный рыцарь запомнил: рвут свои. Внизу его уже ждёт приманка.

**4. Метаданные:**

```json
{"node_id": "v_harbor_of_ayas_06", "video_prompt": "A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: solar noon, solar 12:00, sun elevation +77 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit +0 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Полдень в Аясе. Швартов лежит на камнях, корабль уже далеко. Юный рыцарь запомнил: рвут свои. Внизу его уже ждёт приманка.", "git_commit_msg": "feat(story): add narrative branch harbor_of_ayas and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2200 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: harbor_of_ayas/v07 — После полудня — швартов отдают свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «после полудня» (часы устройства игрока, без случайности): в журнал ложится строка «harbor_of_ayas, после полудня», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `lure` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `lure` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: afternoon, solar 14:30, sun elevation +55 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.2 mm lens, orbit +8 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Ветер с моря. Корабль ушёл, у тумбы мокрый трос. Его отдал свой, и юный рыцарь остался на берегу. Внизу его уже ждёт приманка.

**4. Метаданные:**

```json
{"node_id": "v_harbor_of_ayas_07", "video_prompt": "A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: afternoon, solar 14:30, sun elevation +55 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.2 mm lens, orbit +8 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Ветер с моря. Корабль ушёл, у тумбы мокрый трос. Его отдал свой, и юный рыцарь остался на берегу. Внизу его уже ждёт приманка.", "git_commit_msg": "feat(story): add narrative branch harbor_of_ayas and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: harbor_of_ayas/v08 — Золотой час — швартов отдают свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «золотой час» (часы устройства игрока, без случайности): в журнал ложится строка «harbor_of_ayas, золотой час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `lure` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `lure` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: golden hour, solar 18:20, sun elevation +10 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 52.5 mm lens, orbit -4 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Золотой час в Аясе. Юный рыцарь смотрит вслед кораблю. Швартов отдала своя рука, с ближнего конца. Внизу его уже ждёт приманка.

**4. Метаданные:**

```json
{"node_id": "v_harbor_of_ayas_08", "video_prompt": "A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: golden hour, solar 18:20, sun elevation +10 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 52.5 mm lens, orbit -4 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Золотой час в Аясе. Юный рыцарь смотрит вслед кораблю. Швартов отдала своя рука, с ближнего конца. Внизу его уже ждёт приманка.", "git_commit_msg": "feat(story): add narrative branch harbor_of_ayas and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: harbor_of_ayas/v09 — Закат — швартов отдают свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «закат» (часы устройства игрока, без случайности): в журнал ложится строка «harbor_of_ayas, закат», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `lure` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `lure` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: sunset, solar 19:14, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 29.8 mm lens, orbit +5 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Закат над гаванью. Корабль уходит без юного рыцаря. Трос рвут свои, у самого причала. Внизу его уже ждёт приманка.

**4. Метаданные:**

```json
{"node_id": "v_harbor_of_ayas_09", "video_prompt": "A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: sunset, solar 19:14, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 29.8 mm lens, orbit +5 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Закат над гаванью. Корабль уходит без юного рыцаря. Трос рвут свои, у самого причала. Внизу его уже ждёт приманка.", "git_commit_msg": "feat(story): add narrative branch harbor_of_ayas and video assets", "status": "ready_for_render"}
```

Хор: − ког мал, читается только силуэтом / + закат над гаванью — швартов в воде на первом плане / + фонарь 1900–2200 K на столбе — тёплая точка ухода

### Вариант ID: harbor_of_ayas/v10 — Сумерки — швартов отдают свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «сумерки» (часы устройства игрока, без случайности): в журнал ложится строка «harbor_of_ayas, сумерки», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `lure` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `lure` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: dusk, solar 19:47, sun elevation -5 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit -9 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сумерки, у причала зажгли фонарь. Швартов в воде. Юный рыцарь понял: связь рвут не враги снаружи. Внизу его уже ждёт приманка.

**4. Метаданные:**

```json
{"node_id": "v_harbor_of_ayas_10", "video_prompt": "A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: dusk, solar 19:47, sun elevation -5 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit -9 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сумерки, у причала зажгли фонарь. Швартов в воде. Юный рыцарь понял: связь рвут не враги снаружи. Внизу его уже ждёт приманка.", "git_commit_msg": "feat(story): add narrative branch harbor_of_ayas and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: harbor_of_ayas/v11 — Ночь с луной — швартов отдают свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «ночь с луной» (часы устройства игрока, без случайности): в журнал ложится строка «harbor_of_ayas, ночь с луной», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `lure` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `lure` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: night with moon, solar 22:30, sun elevation -26 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 31.5 mm lens, orbit +2 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Луна над Аясом. Корабль ушёл в ночь без него. Свой отдал швартов, и этот рывок рыцарь узнает через годы. Внизу его уже ждёт приманка.

**4. Метаданные:**

```json
{"node_id": "v_harbor_of_ayas_11", "video_prompt": "A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: night with moon, solar 22:30, sun elevation -26 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 31.5 mm lens, orbit +2 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Луна над Аясом. Корабль ушёл в ночь без него. Свой отдал швартов, и этот рывок рыцарь узнает через годы. Внизу его уже ждёт приманка.", "git_commit_msg": "feat(story): add narrative branch harbor_of_ayas and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: harbor_of_ayas/v12 — Глухая ночь, только огонь — швартов отдают свои

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «глухая ночь, только огонь» (часы устройства игрока, без случайности): в журнал ложится строка «harbor_of_ayas, глухая ночь, только огонь», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `lure` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `lure` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: deep night, solar 02:45, sun elevation -18 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 43.8 mm lens, orbit -1 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Ночь, только фонарь у тумбы. Мокрый трос уходит в чёрную воду. Его отдал свой, с ближнего конца. Внизу его уже ждёт приманка.

**4. Метаданные:**

```json
{"node_id": "v_harbor_of_ayas_12", "video_prompt": "A medieval stone quay at Ayas: courses of dressed limestone, the lowest wet and dark, an oak bollard with iron bands, a laid hemp mooring rope running over the edge into the sea, a canvas sack, a small horn lantern on a post, a dark cog with a furled sail on the horizon. No person in frame. Time: deep night, solar 02:45, sun elevation -18 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 43.8 mm lens, orbit -1 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: small swell laps the wet course; the rope end sways in the water; the cog moves slowly away along the horizon. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Ночь, только фонарь у тумбы. Мокрый трос уходит в чёрную воду. Его отдал свой, с ближнего конца. Внизу его уже ждёт приманка.", "git_commit_msg": "feat(story): add narrative branch harbor_of_ayas and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: purse_at_the_gate/v01 — Предрассветный синий час — тёплое серебро

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «предрассветный синий час» (часы устройства игрока, без случайности): в журнал ложится строка «purse_at_the_gate, предрассветный синий час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `price_rises` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `price_rises` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: pre-dawn blue hour, solar 06:28, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 36 mm lens, orbit -11 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сис, 1374, перед зарёй. Рыцарю сунули кошель драм: царь верхом на монетах. Он держал его, пока серебро не согрелось. / А цена тем временем растёт.

**4. Метаданные:**

```json
{"node_id": "v_purse_at_the_gate_01", "video_prompt": "A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: pre-dawn blue hour, solar 06:28, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 36 mm lens, orbit -11 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сис, 1374, перед зарёй. Рыцарю сунули кошель драм: царь верхом на монетах. Он держал его, пока серебро не согрелось. А цена тем временем растёт.", "git_commit_msg": "feat(story): add narrative branch purse_at_the_gate and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: purse_at_the_gate/v02 — Заря — тёплое серебро

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «заря» (часы устройства игрока, без случайности): в журнал ложится строка «purse_at_the_gate, заря», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `price_rises` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `price_rises` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: dawn, solar 06:55, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 45 mm lens, orbit +7 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Заря в бойнице. Драмы лежат у ключа от ворот. Рыцарь держал серебро, и оно грелось. Ответ — на следующем листе. А цена тем временем растёт.

**4. Метаданные:**

```json
{"node_id": "v_purse_at_the_gate_02", "video_prompt": "A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: dawn, solar 06:55, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 45 mm lens, orbit +7 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Заря в бойнице. Драмы лежат у ключа от ворот. Рыцарь держал серебро, и оно грелось. Ответ — на следующем листе. А цена тем временем растёт.", "git_commit_msg": "feat(story): add narrative branch purse_at_the_gate and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: purse_at_the_gate/v03 — Восход — тёплое серебро

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «восход» (часы устройства игрока, без случайности): в журнал ложится строка «purse_at_the_gate, восход», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `price_rises` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `price_rises` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: sunrise, solar 07:22, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 60.8 mm lens, orbit -4 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Первый луч в щели бойницы. Серебро с конным царём уже тёплое от его руки. Выбор ещё свободен. А цена тем временем растёт.

**4. Метаданные:**

```json
{"node_id": "v_purse_at_the_gate_03", "video_prompt": "A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: sunrise, solar 07:22, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 60.8 mm lens, orbit -4 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Первый луч в щели бойницы. Серебро с конным царём уже тёплое от его руки. Выбор ещё свободен. А цена тем временем растёт.", "git_commit_msg": "feat(story): add narrative branch purse_at_the_gate and video assets", "status": "ready_for_render"}
```

Хор: − кошель в тёплом свете читается как головка чеснока / + полоса из бойницы режет монеты и ключ / + свеча тёплым пятном, ключ нетронут

### Вариант ID: purse_at_the_gate/v04 — Утро — тёплое серебро

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «утро» (часы устройства игрока, без случайности): в журнал ложится строка «purse_at_the_gate, утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `price_rises` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Ловкость». Все 12 вариантов сходятся в `price_rises` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: morning, solar 08:55, sun elevation +16 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.5 mm lens, orbit +13 deg around the subject from the reference view, +1 deg tilt, roll -3 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Утро в Сисе. Кошель сунули тихо, в тёплую руку. Чем дольше рыцарь держит серебро, тем больше оно его. А цена тем временем растёт.

**4. Метаданные:**

```json
{"node_id": "v_purse_at_the_gate_04", "video_prompt": "A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: morning, solar 08:55, sun elevation +16 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.5 mm lens, orbit +13 deg around the subject from the reference view, +1 deg tilt, roll -3 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Утро в Сисе. Кошель сунули тихо, в тёплую руку. Чем дольше рыцарь держит серебро, тем больше оно его. А цена тем временем растёт.", "git_commit_msg": "feat(story): add narrative branch purse_at_the_gate and video assets", "status": "ready_for_render"}
```

Хор: − наклон -3° заметен; в шлеме — на грани / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: purse_at_the_gate/v05 — Позднее утро — тёплое серебро

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «позднее утро» (часы устройства игрока, без случайности): в журнал ложится строка «purse_at_the_gate, позднее утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `price_rises` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `price_rises` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: late morning, solar 10:30, sun elevation +27 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 33.8 mm lens, orbit -15 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнечная полоса режет подоконник. Драмы у ключа. Рыцарь держал их, пока не согрел. Ответ — дальше. А цена тем временем растёт.

**4. Метаданные:**

```json
{"node_id": "v_purse_at_the_gate_05", "video_prompt": "A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: late morning, solar 10:30, sun elevation +27 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 33.8 mm lens, orbit -15 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнечная полоса режет подоконник. Драмы у ключа. Рыцарь держал их, пока не согрел. Ответ — дальше. А цена тем временем растёт.", "git_commit_msg": "feat(story): add narrative branch purse_at_the_gate and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2150 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: purse_at_the_gate/v06 — Полдень — тёплое серебро

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «полдень» (часы устройства игрока, без случайности): в журнал ложится строка «purse_at_the_gate, полдень», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `price_rises` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `price_rises` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: solar noon, solar 12:00, sun elevation +30 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 45 mm lens, orbit +0 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Полдень, луч в бойнице отвесный. Кошель у ключа от ворот. Цену предлагают тихо; рыцарь ещё не ответил. А цена тем временем растёт.

**4. Метаданные:**

```json
{"node_id": "v_purse_at_the_gate_06", "video_prompt": "A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: solar noon, solar 12:00, sun elevation +30 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 45 mm lens, orbit +0 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Полдень, луч в бойнице отвесный. Кошель у ключа от ворот. Цену предлагают тихо; рыцарь ещё не ответил. А цена тем временем растёт.", "git_commit_msg": "feat(story): add narrative branch purse_at_the_gate and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2200 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: purse_at_the_gate/v07 — После полудня — тёплое серебро

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «после полудня» (часы устройства игрока, без случайности): в журнал ложится строка «purse_at_the_gate, после полудня», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `price_rises` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `price_rises` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: afternoon, solar 14:30, sun elevation +21 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 51.7 mm lens, orbit +17 deg around the subject from the reference view, -1 deg tilt, roll 3 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** День за стенами Сиса. Рыцарь держит драмы с конным царём. Серебро тёплое: оно уже наполовину его. А цена тем временем растёт.

**4. Метаданные:**

```json
{"node_id": "v_purse_at_the_gate_07", "video_prompt": "A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: afternoon, solar 14:30, sun elevation +21 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 51.7 mm lens, orbit +17 deg around the subject from the reference view, -1 deg tilt, roll 3 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "День за стенами Сиса. Рыцарь держит драмы с конным царём. Серебро тёплое: оно уже наполовину его. А цена тем временем растёт.", "git_commit_msg": "feat(story): add narrative branch purse_at_the_gate and video assets", "status": "ready_for_render"}
```

Хор: − наклон +3° заметен; в шлеме — на грани / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: purse_at_the_gate/v08 — Золотой час — тёплое серебро

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «золотой час» (часы устройства игрока, без случайности): в журнал ложится строка «purse_at_the_gate, золотой час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `price_rises` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `price_rises` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: golden hour, solar 15:53, sun elevation +9 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 67.5 mm lens, orbit -8 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Вечерний луч на серебре. Кошель сунули молча. Монеты согрелись в руке, а ключ лежит рядом нетронутым. А цена тем временем растёт.

**4. Метаданные:**

```json
{"node_id": "v_purse_at_the_gate_08", "video_prompt": "A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: golden hour, solar 15:53, sun elevation +9 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 67.5 mm lens, orbit -8 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Вечерний луч на серебре. Кошель сунули молча. Монеты согрелись в руке, а ключ лежит рядом нетронутым. А цена тем временем растёт.", "git_commit_msg": "feat(story): add narrative branch purse_at_the_gate and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: purse_at_the_gate/v09 — Закат — тёплое серебро

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «закат» (часы устройства игрока, без случайности): в журнал ложится строка «purse_at_the_gate, закат», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `price_rises` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `price_rises` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: sunset, solar 16:47, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 38.2 mm lens, orbit +10 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Закат гаснет в бойнице. Драмы тёплые от его руки. Выбор свободен до конца. Ответ — на следующем листе. А цена тем временем растёт.

**4. Метаданные:**

```json
{"node_id": "v_purse_at_the_gate_09", "video_prompt": "A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: sunset, solar 16:47, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 38.2 mm lens, orbit +10 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Закат гаснет в бойнице. Драмы тёплые от его руки. Выбор свободен до конца. Ответ — на следующем листе. А цена тем временем растёт.", "git_commit_msg": "feat(story): add narrative branch purse_at_the_gate and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: purse_at_the_gate/v10 — Сумерки — тёплое серебро

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «сумерки» (часы устройства игрока, без случайности): в журнал ложится строка «purse_at_the_gate, сумерки», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `price_rises` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `price_rises` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: dusk, solar 17:20, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 45 mm lens, orbit -18 deg around the subject from the reference view, +2 deg tilt, roll -2 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сумерки, зажгли сальную свечу. Рыцарь держит кошель, пока серебро не согрелось. Ключ от ворот рядом. А цена тем временем растёт.

**4. Метаданные:**

```json
{"node_id": "v_purse_at_the_gate_10", "video_prompt": "A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: dusk, solar 17:20, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 45 mm lens, orbit -18 deg around the subject from the reference view, +2 deg tilt, roll -2 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сумерки, зажгли сальную свечу. Рыцарь держит кошель, пока серебро не согрелось. Ключ от ворот рядом. А цена тем временем растёт.", "git_commit_msg": "feat(story): add narrative branch purse_at_the_gate and video assets", "status": "ready_for_render"}
```

Хор: − наклон -2° заметен; в шлеме — на грани / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: purse_at_the_gate/v11 — Ночь с луной — тёплое серебро

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «ночь с луной» (часы устройства игрока, без случайности): в журнал ложится строка «purse_at_the_gate, ночь с луной», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `price_rises` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `price_rises` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: night with moon, solar 22:30, sun elevation -65 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.5 mm lens, orbit +4 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сис, 1374. Ночью рыцарю сунули кошель драм: царь верхом на монетах. Он держал его, пока серебро не согрелось. А цена тем временем растёт.

**4. Метаданные:**

```json
{"node_id": "v_purse_at_the_gate_11", "video_prompt": "A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: night with moon, solar 22:30, sun elevation -65 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.5 mm lens, orbit +4 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сис, 1374. Ночью рыцарю сунули кошель драм: царь верхом на монетах. Он держал его, пока серебро не согрелось. А цена тем временем растёт.", "git_commit_msg": "feat(story): add narrative branch purse_at_the_gate and video assets", "status": "ready_for_render"}
```

Хор: − кошель светлее, чем кожа / + луна в щели и свеча — канон серии / + монеты с конным царём и ключ в одной полосе света

### Вариант ID: purse_at_the_gate/v12 — Глухая ночь, только огонь — тёплое серебро

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «глухая ночь, только огонь» (часы устройства игрока, без случайности): в журнал ложится строка «purse_at_the_gate, глухая ночь, только огонь», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `price_rises` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `price_rises` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: deep night, solar 02:45, sun elevation -51 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 56.2 mm lens, orbit -2 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Глухая ночь, один огарок. Серебро в руке рыцаря тёплое, как живое. Цену дают тихо. Ответ — на следующем листе. А цена тем временем растёт.

**4. Метаданные:**

```json
{"node_id": "v_purse_at_the_gate_12", "video_prompt": "A stone window sill in a gate tower of Sis, 1374: a leather purse, seven silver drams with a mounted king spilt from it, an iron gate key lying untouched, a tallow candle stub; light enters through a 3 cm arrow slit as a thin stripe. No person in frame. Time: deep night, solar 02:45, sun elevation -51 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 56.2 mm lens, orbit -2 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the candle flame flickers at 2-3 Hz; the light stripe is still; dust drifts through the stripe. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Глухая ночь, один огарок. Серебро в руке рыцаря тёплое, как живое. Цену дают тихо. Ответ — на следующем листе. А цена тем временем растёт.", "git_commit_msg": "feat(story): add narrative branch purse_at_the_gate and video assets", "status": "ready_for_render"}
```

Хор: − ключ уходит в тень / + глухая ночь: только огарок / + серебро бликует теплом — «серебро согрелось»

### Вариант ID: gate_opened_inside/v01 — Предрассветный синий час — засов скрипнул один раз

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «предрассветный синий час» (часы устройства игрока, без случайности): в журнал ложится строка «gate_opened_inside, предрассветный синий час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: pre-dawn blue hour, solar 04:50, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit -10 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Синий час у ворот Сиса. Говорят, их отворили изнутри за серебро. Тот человек сперва только смотрел. / Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_gate_opened_inside_01", "video_prompt": "The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: pre-dawn blue hour, solar 04:50, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit -10 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Синий час у ворот Сиса. Говорят, их отворили изнутри за серебро. Тот человек сперва только смотрел. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch gate_opened_inside and video assets", "status": "ready_for_render"}
```

Хор: − монеты на плитах мелки / + синий клин через створку и факел — две эпохи света в одном кадре / + засов у стены и пустые скобы видны

### Вариант ID: gate_opened_inside/v02 — Заря — засов скрипнул один раз

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «заря» (часы устройства игрока, без случайности): в журнал ложится строка «gate_opened_inside, заря», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: dawn, solar 05:17, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit +6 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Заря в щели створок. Засов стоит у стены. Говорят, тот, кто открыл, сперва только смотрел. Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_gate_opened_inside_02", "video_prompt": "The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: dawn, solar 05:17, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit +6 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Заря в щели створок. Засов стоит у стены. Говорят, тот, кто открыл, сперва только смотрел. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch gate_opened_inside and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: gate_opened_inside/v03 — Восход — засов скрипнул один раз

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «восход» (часы устройства игрока, без случайности): в журнал ложится строка «gate_opened_inside, восход», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: sunrise, solar 05:44, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 47.2 mm lens, orbit -4 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце в щель ворот. Серебро рассыпано по плитам. Засов скрипнул один раз, и Сис отворился изнутри. / Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_gate_opened_inside_03", "video_prompt": "The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: sunrise, solar 05:44, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 47.2 mm lens, orbit -4 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце в щель ворот. Серебро рассыпано по плитам. Засов скрипнул один раз, и Сис отворился изнутри. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch gate_opened_inside and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: gate_opened_inside/v04 — Утро — засов скрипнул один раз

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «утро» (часы устройства игрока, без случайности): в журнал ложится строка «gate_opened_inside, утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Ловкость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: morning, solar 07:17, sun elevation +20 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 31.5 mm lens, orbit +12 deg around the subject from the reference view, +1 deg tilt, roll -3 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Утро. Ворота приоткрыты, засов снят. Говорят, за такое же серебро. Пленение начинается с «только посмотрю». / Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_gate_opened_inside_04", "video_prompt": "The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: morning, solar 07:17, sun elevation +20 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 31.5 mm lens, orbit +12 deg around the subject from the reference view, +1 deg tilt, roll -3 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Утро. Ворота приоткрыты, засов снят. Говорят, за такое же серебро. Пленение начинается с «только посмотрю». Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch gate_opened_inside and video assets", "status": "ready_for_render"}
```

Хор: − наклон -3° заметен; в шлеме — на грани / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: gate_opened_inside/v05 — Позднее утро — засов скрипнул один раз

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «позднее утро» (часы устройства игрока, без случайности): в журнал ложится строка «gate_opened_inside, позднее утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: late morning, solar 10:30, sun elevation +55 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 26.2 mm lens, orbit -14 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Свет клином по плитам. Пустые скобы, где лежал засов. Тот человек тоже сперва только смотрел. Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_gate_opened_inside_05", "video_prompt": "The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: late morning, solar 10:30, sun elevation +55 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 26.2 mm lens, orbit -14 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Свет клином по плитам. Пустые скобы, где лежал засов. Тот человек тоже сперва только смотрел. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch gate_opened_inside and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2150 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: gate_opened_inside/v06 — Полдень — засов скрипнул один раз

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «полдень» (часы устройства игрока, без случайности): в журнал ложится строка «gate_opened_inside, полдень», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: solar noon, solar 12:00, sun elevation +61 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit +0 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Полдень, тень ворот коротка. Монеты на плитах. Зло сделал человек, а не судьба: засов скрипнул один раз. / Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_gate_opened_inside_06", "video_prompt": "The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: solar noon, solar 12:00, sun elevation +61 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit +0 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Полдень, тень ворот коротка. Монеты на плитах. Зло сделал человек, а не судьба: засов скрипнул один раз. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch gate_opened_inside and video assets", "status": "ready_for_render"}
```

Хор: − полуденный клин пересвечен / + тень ворот коротка, как в строке / + створка и засов читаются без подсказки

### Вариант ID: gate_opened_inside/v07 — После полудня — засов скрипнул один раз

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «после полудня» (часы устройства игрока, без случайности): в журнал ложится строка «gate_opened_inside, после полудня», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: afternoon, solar 14:30, sun elevation +46 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.2 mm lens, orbit +15 deg around the subject from the reference view, -1 deg tilt, roll 3 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** День. Створка отошла, засов прислонён к стене. Говорят, открыли изнутри, за такое же серебро. Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_gate_opened_inside_07", "video_prompt": "The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: afternoon, solar 14:30, sun elevation +46 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.2 mm lens, orbit +15 deg around the subject from the reference view, -1 deg tilt, roll 3 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "День. Створка отошла, засов прислонён к стене. Говорят, открыли изнутри, за такое же серебро. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch gate_opened_inside and video assets", "status": "ready_for_render"}
```

Хор: − наклон +3° заметен; в шлеме — на грани / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: gate_opened_inside/v08 — Золотой час — засов скрипнул один раз

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «золотой час» (часы устройства игрока, без случайности): в журнал ложится строка «gate_opened_inside, золотой час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: golden hour, solar 17:31, sun elevation +11 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 52.5 mm lens, orbit -7 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Вечерний луч в щели ворот. Пустой кошель на плитах. Предательство возвращается, когда его выбирают снова. / Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_gate_opened_inside_08", "video_prompt": "The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: golden hour, solar 17:31, sun elevation +11 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 52.5 mm lens, orbit -7 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Вечерний луч в щели ворот. Пустой кошель на плитах. Предательство возвращается, когда его выбирают снова. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch gate_opened_inside and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: gate_opened_inside/v09 — Закат — засов скрипнул один раз

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «закат» (часы устройства игрока, без случайности): в журнал ложится строка «gate_opened_inside, закат», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: sunset, solar 18:25, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 29.8 mm lens, orbit +9 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Закат у ворот Сиса. Засов снят изнутри. Тот человек сперва только смотрел на серебро. Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_gate_opened_inside_09", "video_prompt": "The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: sunset, solar 18:25, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 29.8 mm lens, orbit +9 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Закат у ворот Сиса. Засов снят изнутри. Тот человек сперва только смотрел на серебро. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch gate_opened_inside and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: gate_opened_inside/v10 — Сумерки — засов скрипнул один раз

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «сумерки» (часы устройства игрока, без случайности): в журнал ложится строка «gate_opened_inside, сумерки», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: dusk, solar 18:58, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit -16 deg around the subject from the reference view, +1 deg tilt, roll -2 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сумерки, зажгли факел. Ворота отворены изнутри. Засов скрипнул один раз, и этого хватило. Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_gate_opened_inside_10", "video_prompt": "The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: dusk, solar 18:58, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit -16 deg around the subject from the reference view, +1 deg tilt, roll -2 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сумерки, зажгли факел. Ворота отворены изнутри. Засов скрипнул один раз, и этого хватило. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch gate_opened_inside and video assets", "status": "ready_for_render"}
```

Хор: − наклон -2° заметен; в шлеме — на грани / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: gate_opened_inside/v11 — Ночь с луной — засов скрипнул один раз

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «ночь с луной» (часы устройства игрока, без случайности): в журнал ложится строка «gate_opened_inside, ночь с луной», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: night with moon, solar 22:30, sun elevation -39 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 31.5 mm lens, orbit +4 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Луна в щели ворот. Говорят, их отворили изнутри за такое же серебро. Засов скрипнул один раз. Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_gate_opened_inside_11", "video_prompt": "The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: night with moon, solar 22:30, sun elevation -39 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 31.5 mm lens, orbit +4 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Луна в щели ворот. Говорят, их отворили изнутри за такое же серебро. Засов скрипнул один раз. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch gate_opened_inside and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: gate_opened_inside/v12 — Глухая ночь, только огонь — засов скрипнул один раз

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «глухая ночь, только огонь» (часы устройства игрока, без случайности): в журнал ложится строка «gate_opened_inside, глухая ночь, только огонь», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: deep night, solar 02:45, sun elevation -30 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 43.8 mm lens, orbit -2 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Ночь, факел в скобе. Серебро на плитах, засов у стены. Тот человек сперва только смотрел. Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_gate_opened_inside_12", "video_prompt": "The inner side of the city gate of Sis: two oak leaves, one ajar by 12 degrees, empty iron staples where the bar lay, the oak bar leaned on the wall, silver coins spilt along a wedge of light on the flagstones, an empty purse, a torch in an iron bracket. No person in frame. Time: deep night, solar 02:45, sun elevation -30 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 43.8 mm lens, orbit -2 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the torch flame of three tongues flickers; the wedge of light through the gap is still; smoke rises slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Ночь, факел в скобе. Серебро на плитах, засов у стены. Тот человек сперва только смотрел. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch gate_opened_inside and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bread_in_siege/v01 — Предрассветный синий час — хлеб соседу

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «предрассветный синий час» (часы устройства игрока, без случайности): в журнал ложится строка «bread_in_siege, предрассветный синий час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: pre-dawn blue hour, solar 05:53, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 24 mm lens, orbit -13 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Синий час на стене Сиса. Рыцарь разломил последний хлеб и отдал половину соседу. У ворот звенело серебро. Он не пошёл. / Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_bread_in_siege_01", "video_prompt": "On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: pre-dawn blue hour, solar 05:53, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 24 mm lens, orbit -13 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Синий час на стене Сиса. Рыцарь разломил последний хлеб и отдал половину соседу. У ворот звенело серебро. Он не пошёл. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch bread_in_siege and video assets", "status": "ready_for_render"}
```

Хор: − первый прогон: швы кладки висели в воздухе над бойницей (перерисовано: шов кончается у зубца) / + синий час и жаровня — осада без солнца / + два куска хлеба, больший у пустого места

### Вариант ID: bread_in_siege/v02 — Заря — хлеб соседу

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «заря» (часы устройства игрока, без случайности): в журнал ложится строка «bread_in_siege, заря», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: dawn, solar 06:20, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit +8 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Заря над осадой. Хлеб разломлен, большая часть подвинута соседу. Внизу звон серебра; рыцарь дышит медленно. / Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_bread_in_siege_02", "video_prompt": "On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: dawn, solar 06:20, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit +8 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Заря над осадой. Хлеб разломлен, большая часть подвинута соседу. Внизу звон серебра; рыцарь дышит медленно. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch bread_in_siege and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + выбор хора: смысл строки и свет совпали

### Вариант ID: bread_in_siege/v03 — Восход — хлеб соседу

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «восход» (часы устройства игрока, без случайности): в журнал ложится строка «bread_in_siege, восход», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: sunrise, solar 06:47, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.5 mm lens, orbit -5 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце в бойнице. Рыцарь отдал соседу половину последнего хлеба. Отданное говорит о свободе громче взятого. / Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_bread_in_siege_03", "video_prompt": "On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: sunrise, solar 06:47, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.5 mm lens, orbit -5 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце в бойнице. Рыцарь отдал соседу половину последнего хлеба. Отданное говорит о свободе громче взятого. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch bread_in_siege and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bread_in_siege/v04 — Утро — хлеб соседу

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «утро» (часы устройства игрока, без случайности): в журнал ложится строка «bread_in_siege, утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Ловкость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: morning, solar 08:20, sun elevation +19 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 27 mm lens, orbit +16 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Утро осады. Последний хлеб пополам, соседу больше. Звон у ворот он слышал. Не пошёл. Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_bread_in_siege_04", "video_prompt": "On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: morning, solar 08:20, sun elevation +19 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 27 mm lens, orbit +16 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Утро осады. Последний хлеб пополам, соседу больше. Звон у ворот он слышал. Не пошёл. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch bread_in_siege and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bread_in_siege/v05 — Позднее утро — хлеб соседу

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «позднее утро» (часы устройства игрока, без случайности): в журнал ложится строка «bread_in_siege, позднее утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: late morning, solar 10:30, sun elevation +37 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 22.5 mm lens, orbit -18 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** День в осаде долог. Рыцарь дышит медленно над разломленным хлебом. Серебро у ворот, хлеб у соседа. / Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_bread_in_siege_05", "video_prompt": "On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: late morning, solar 10:30, sun elevation +37 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 22.5 mm lens, orbit -18 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "День в осаде долог. Рыцарь дышит медленно над разломленным хлебом. Серебро у ворот, хлеб у соседа. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch bread_in_siege and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2150 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bread_in_siege/v06 — Полдень — хлеб соседу

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «полдень» (часы устройства игрока, без случайности): в журнал ложится строка «bread_in_siege, полдень», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: solar noon, solar 12:00, sun elevation +41 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit +0 deg around the subject from the reference view, +5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Полдень, жар от камня. Половина хлеба ждёт соседа. Отказ тоже дело: рыцарь слышал серебро и остался. / Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_bread_in_siege_06", "video_prompt": "On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: solar noon, solar 12:00, sun elevation +41 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit +0 deg around the subject from the reference view, +5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Полдень, жар от камня. Половина хлеба ждёт соседа. Отказ тоже дело: рыцарь слышал серебро и остался. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch bread_in_siege and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2200 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bread_in_siege/v07 — После полудня — хлеб соседу

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «после полудня» (часы устройства игрока, без случайности): в журнал ложится строка «bread_in_siege, после полудня», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: afternoon, solar 14:30, sun elevation +30 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 34.5 mm lens, orbit +20 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** У ворот снова звенит. Рыцарь не встал. Он разломил последний хлеб и отдал соседу большую часть. Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_bread_in_siege_07", "video_prompt": "On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: afternoon, solar 14:30, sun elevation +30 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 34.5 mm lens, orbit +20 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "У ворот снова звенит. Рыцарь не встал. Он разломил последний хлеб и отдал соседу большую часть. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch bread_in_siege and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bread_in_siege/v08 — Золотой час — хлеб соседу

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «золотой час» (часы устройства игрока, без случайности): в журнал ложится строка «bread_in_siege, золотой час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: golden hour, solar 16:28, sun elevation +10 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 45 mm lens, orbit -10 deg around the subject from the reference view, -5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Закатный свет на крошках. Хлеб соседу сильнее серебра у ворот, и этого не видит ни один протокол цены. / Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_bread_in_siege_08", "video_prompt": "On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: golden hour, solar 16:28, sun elevation +10 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 45 mm lens, orbit -10 deg around the subject from the reference view, -5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Закатный свет на крошках. Хлеб соседу сильнее серебра у ворот, и этого не видит ни один протокол цены. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch bread_in_siege and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bread_in_siege/v09 — Закат — хлеб соседу

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «закат» (часы устройства игрока, без случайности): в журнал ложится строка «bread_in_siege, закат», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: sunset, solar 17:22, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 25.5 mm lens, orbit +12 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце садится за стены Сиса. Хлеб отдан пополам. Рыцарь слушал звон у ворот и дышал медленно. Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_bread_in_siege_09", "video_prompt": "On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: sunset, solar 17:22, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 25.5 mm lens, orbit +12 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце садится за стены Сиса. Хлеб отдан пополам. Рыцарь слушал звон у ворот и дышал медленно. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch bread_in_siege and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bread_in_siege/v10 — Сумерки — хлеб соседу

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «сумерки» (часы устройства игрока, без случайности): в журнал ложится строка «bread_in_siege, сумерки», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: dusk, solar 17:55, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit -22 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сумерки, разгорается жаровня. Последний хлеб разломлен. Он не пошёл к воротам. Дышал медленно. Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_bread_in_siege_10", "video_prompt": "On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: dusk, solar 17:55, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit -22 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сумерки, разгорается жаровня. Последний хлеб разломлен. Он не пошёл к воротам. Дышал медленно. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch bread_in_siege and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bread_in_siege/v11 — Ночь с луной — хлеб соседу

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «ночь с луной» (часы устройства игрока, без случайности): в журнал ложится строка «bread_in_siege, ночь с луной», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: night with moon, solar 22:30, sun elevation -57 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 27 mm lens, orbit +5 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Луна над осадой. Рыцарь отдал соседу половину последнего хлеба. Серебро звенело у ворот. Он не пошёл. / Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_bread_in_siege_11", "video_prompt": "On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: night with moon, solar 22:30, sun elevation -57 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 27 mm lens, orbit +5 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Луна над осадой. Рыцарь отдал соседу половину последнего хлеба. Серебро звенело у ворот. Он не пошёл. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch bread_in_siege and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: bread_in_siege/v12 — Глухая ночь, только огонь — хлеб соседу

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «глухая ночь, только огонь» (часы устройства игрока, без случайности): в журнал ложится строка «bread_in_siege, глухая ночь, только огонь», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `choice_echo` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `choice_echo` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: deep night, solar 02:45, sun elevation -45 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 37.5 mm lens, orbit -2 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Ночь, только жаровня и факел у ворот. Хлеб пополам, соседу больше. Рыцарь дышит медленно. Его выбор отзовётся эхом в следующем выборе.

**4. Метаданные:**

```json
{"node_id": "v_bread_in_siege_12", "video_prompt": "On a city wall of Sis in siege: a grey wool cloth on stone, one round flat loaf torn 60/40 with the larger part pushed toward an empty place, crumbs, two clay cups (one overturned), a wooden spoon, a brazier; through the crenel far below a gate yard with a torch and a faint glint of silver. No person in frame. Time: deep night, solar 02:45, sun elevation -45 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 37.5 mm lens, orbit -2 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the brazier embers pulse; the torch far below flickers; crumbs and bread stay still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Ночь, только жаровня и факел у ворот. Хлеб пополам, соседу больше. Рыцарь дышит медленно. Его выбор отзовётся эхом в следующем выборе.", "git_commit_msg": "feat(story): add narrative branch bread_in_siege and video assets", "status": "ready_for_render"}
```

Хор: − хлеб почти не виден в темноте / + жаровня и факел у ворот — ночь осады / + двор ворот внизу виден огнём

### Вариант ID: scribe_lifts_eyes/v01 — Предрассветный синий час — недописанное — дверь

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «предрассветный синий час» (часы устройства игрока, без случайности): в журнал ложится строка «scribe_lifts_eyes, предрассветный синий час», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `mark_line` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `mark_line` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: pre-dawn blue hour, solar 04:28, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 22.4 mm lens, orbit -10 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Синий час над озером. Переписчик дописал строку рыцаря и поднял глаза. Своё «Кто прочтёт…» он так и не кончил. / Он сам проведёт черту на своей странице.

**4. Метаданные:**

```json
{"node_id": "v_scribe_lifts_eyes_01", "video_prompt": "A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: pre-dawn blue hour, solar 04:28, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 22.4 mm lens, orbit -10 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Синий час над озером. Переписчик дописал строку рыцаря и поднял глаза. Своё «Кто прочтёт…» он так и не кончил. Он сам проведёт черту на своей странице.", "git_commit_msg": "feat(story): add narrative branch scribe_lifts_eyes and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: scribe_lifts_eyes/v02 — Заря — недописанное — дверь

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «заря» (часы устройства игрока, без случайности): в журнал ложится строка «scribe_lifts_eyes, заря», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `mark_line` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `mark_line` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: dawn, solar 04:55, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit +6 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Заря встаёт за хребтом. Перо сохнет на краю чернильницы. Недописанная строка ждёт следующего читателя. / Он сам проведёт черту на своей странице.

**4. Метаданные:**

```json
{"node_id": "v_scribe_lifts_eyes_02", "video_prompt": "A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: dawn, solar 04:55, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit +6 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Заря встаёт за хребтом. Перо сохнет на краю чернильницы. Недописанная строка ждёт следующего читателя. Он сам проведёт черту на своей странице.", "git_commit_msg": "feat(story): add narrative branch scribe_lifts_eyes and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: scribe_lifts_eyes/v03 — Восход — недописанное — дверь

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «восход» (часы устройства игрока, без случайности): в журнал ложится строка «scribe_lifts_eyes, восход», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `mark_line` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `mark_line` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: sunrise, solar 05:22, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 37.8 mm lens, orbit -4 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце из-за гор, вода засветилась. Переписчик смотрит на озеро. «Кто прочтёт…» осталось без конца. Он сам проведёт черту на своей странице.

**4. Метаданные:**

```json
{"node_id": "v_scribe_lifts_eyes_03", "video_prompt": "A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: sunrise, solar 05:22, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 37.8 mm lens, orbit -4 deg around the subject from the reference view, -3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце из-за гор, вода засветилась. Переписчик смотрит на озеро. «Кто прочтёт…» осталось без конца. Он сам проведёт черту на своей странице.", "git_commit_msg": "feat(story): add narrative branch scribe_lifts_eyes and video assets", "status": "ready_for_render"}
```

Хор: − лист на переднем плане размыт / + восход над хребтом в окне — свет пришёл сам / + перо на чернильнице читается

### Вариант ID: scribe_lifts_eyes/v04 — Утро — недописанное — дверь

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «утро» (часы устройства игрока, без случайности): в журнал ложится строка «scribe_lifts_eyes, утро», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `mark_line` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Ловкость». Все 12 вариантов сходятся в `mark_line` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: morning, solar 06:55, sun elevation +19 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 25.2 mm lens, orbit +12 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Весеннее утро в келье. Строка рыцаря дописана, своя нет. Он смотрит на озеро, и перо сохнет. Он сам проведёт черту на своей странице.

**4. Метаданные:**

```json
{"node_id": "v_scribe_lifts_eyes_04", "video_prompt": "A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: morning, solar 06:55, sun elevation +19 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 25.2 mm lens, orbit +12 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Весеннее утро в келье. Строка рыцаря дописана, своя нет. Он смотрит на озеро, и перо сохнет. Он сам проведёт черту на своей странице.", "git_commit_msg": "feat(story): add narrative branch scribe_lifts_eyes and video assets", "status": "ready_for_render"}
```

Хор: − стены кельи серые, без фактуры / + весеннее утро: снег на хребте, озеро в окне / + недописанная строка и перо на краю — дверь для читателя

### Вариант ID: scribe_lifts_eyes/v05 — Позднее утро — недописанное — дверь

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «позднее утро» (часы устройства игрока, без случайности): в журнал ложится строка «scribe_lifts_eyes, позднее утро», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `mark_line` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `mark_line` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: late morning, solar 10:30, sun elevation +54 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 21 mm lens, orbit -14 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Свет на столе, строка оборвана на полуслове. Переписчик молчит у окна. Его тишина тоже текст. Он сам проведёт черту на своей странице.

**4. Метаданные:**

```json
{"node_id": "v_scribe_lifts_eyes_05", "video_prompt": "A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: late morning, solar 10:30, sun elevation +54 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 21 mm lens, orbit -14 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Свет на столе, строка оборвана на полуслове. Переписчик молчит у окна. Его тишина тоже текст. Он сам проведёт черту на своей странице.", "git_commit_msg": "feat(story): add narrative branch scribe_lifts_eyes and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2150 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: scribe_lifts_eyes/v06 — Полдень — недописанное — дверь

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «полдень» (часы устройства игрока, без случайности): в журнал ложится строка «scribe_lifts_eyes, полдень», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `mark_line` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `mark_line` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: solar noon, solar 12:00, sun elevation +60 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit +0 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Полдень над Иссык-Кулем. Перо высохло на чернильнице. Кончить «Кто прочтёт…» выпало тому, кто читает теперь. / Он сам проведёт черту на своей странице.

**4. Метаданные:**

```json
{"node_id": "v_scribe_lifts_eyes_06", "video_prompt": "A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: solar noon, solar 12:00, sun elevation +60 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit +0 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Полдень над Иссык-Кулем. Перо высохло на чернильнице. Кончить «Кто прочтёт…» выпало тому, кто читает теперь. Он сам проведёт черту на своей странице.", "git_commit_msg": "feat(story): add narrative branch scribe_lifts_eyes and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2200 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: scribe_lifts_eyes/v07 — После полудня — недописанное — дверь

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «после полудня» (часы устройства игрока, без случайности): в журнал ложится строка «scribe_lifts_eyes, после полудня», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `mark_line` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `mark_line` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: afternoon, solar 14:30, sun elevation +46 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 32.2 mm lens, orbit +15 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Он так и не вернулся к листу. Озеро в окне, перо сухое. Недописанное — дверь для следующего читателя. / Он сам проведёт черту на своей странице.

**4. Метаданные:**

```json
{"node_id": "v_scribe_lifts_eyes_07", "video_prompt": "A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: afternoon, solar 14:30, sun elevation +46 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 32.2 mm lens, orbit +15 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Он так и не вернулся к листу. Озеро в окне, перо сухое. Недописанное — дверь для следующего читателя. Он сам проведёт черту на своей странице.", "git_commit_msg": "feat(story): add narrative branch scribe_lifts_eyes and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: scribe_lifts_eyes/v08 — Золотой час — недописанное — дверь

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «золотой час» (часы устройства игрока, без случайности): в журнал ложится строка «scribe_lifts_eyes, золотой час», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `mark_line` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `mark_line` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: golden hour, solar 17:53, sun elevation +10 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 42 mm lens, orbit -7 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Золотой час в келье. Он поднял глаза на озеро и не дописал своё. Строка оставлена тому, кто прочтёт. / Он сам проведёт черту на своей странице.

**4. Метаданные:**

```json
{"node_id": "v_scribe_lifts_eyes_08", "video_prompt": "A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: golden hour, solar 17:53, sun elevation +10 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 42 mm lens, orbit -7 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Золотой час в келье. Он поднял глаза на озеро и не дописал своё. Строка оставлена тому, кто прочтёт. Он сам проведёт черту на своей странице.", "git_commit_msg": "feat(story): add narrative branch scribe_lifts_eyes and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: scribe_lifts_eyes/v09 — Закат — недописанное — дверь

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «закат» (часы устройства игрока, без случайности): в журнал ложится строка «scribe_lifts_eyes, закат», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `mark_line` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `mark_line` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: sunset, solar 18:47, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 23.8 mm lens, orbit +9 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Закат на воде. Переписчик смотрит в окно, перо сохнет. «Кто прочтёт…» так и обрывается. Он сам проведёт черту на своей странице.

**4. Метаданные:**

```json
{"node_id": "v_scribe_lifts_eyes_09", "video_prompt": "A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: sunset, solar 18:47, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 23.8 mm lens, orbit +9 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Закат на воде. Переписчик смотрит в окно, перо сохнет. «Кто прочтёт…» так и обрывается. Он сам проведёт черту на своей странице.", "git_commit_msg": "feat(story): add narrative branch scribe_lifts_eyes and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: scribe_lifts_eyes/v10 — Сумерки — недописанное — дверь

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «сумерки» (часы устройства игрока, без случайности): в журнал ложится строка «scribe_lifts_eyes, сумерки», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `mark_line` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `mark_line` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: dusk, solar 19:20, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit -16 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сумерки в келье. Лист с недописанной строкой ещё виден. Закончит её тот, кто прочтёт. Он сам проведёт черту на своей странице.

**4. Метаданные:**

```json
{"node_id": "v_scribe_lifts_eyes_10", "video_prompt": "A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: dusk, solar 19:20, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 28 mm lens, orbit -16 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сумерки в келье. Лист с недописанной строкой ещё виден. Закончит её тот, кто прочтёт. Он сам проведёт черту на своей странице.", "git_commit_msg": "feat(story): add narrative branch scribe_lifts_eyes and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: scribe_lifts_eyes/v11 — Ночь с луной — недописанное — дверь

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «ночь с луной» (часы устройства игрока, без случайности): в журнал ложится строка «scribe_lifts_eyes, ночь с луной», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `mark_line` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `mark_line` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: night with moon, solar 22:30, sun elevation -31 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 25.2 mm lens, orbit +4 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Луна над озером. Перо на краю чернильницы, строка оборвана. Переписчик оставил дверь открытой. Он сам проведёт черту на своей странице.

**4. Метаданные:**

```json
{"node_id": "v_scribe_lifts_eyes_11", "video_prompt": "A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: night with moon, solar 22:30, sun elevation -31 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 25.2 mm lens, orbit +4 deg around the subject from the reference view, +3 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Луна над озером. Перо на краю чернильницы, строка оборвана. Переписчик оставил дверь открытой. Он сам проведёт черту на своей странице.", "git_commit_msg": "feat(story): add narrative branch scribe_lifts_eyes and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: scribe_lifts_eyes/v12 — Глухая ночь, только огонь — недописанное — дверь

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «глухая ночь, только огонь» (часы устройства игрока, без случайности): в журнал ложится строка «scribe_lifts_eyes, глухая ночь, только огонь», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `mark_line` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `mark_line` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: deep night, solar 02:45, sun elevation -23 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit -2 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Ночь, лампа у листа. Своё «Кто прочтёт…» он так и не кончил. Тишина переписчика ждёт читателя. Он сам проведёт черту на своей странице.

**4. Метаданные:**

```json
{"node_id": "v_scribe_lifts_eyes_12", "video_prompt": "A copyist cell with an open window onto Issyk-Kul: an empty stool, a desk with an open codex whose last line breaks off mid-word with a tiny blot, a dry reed pen across the lip of a clay inkpot, beyond the window a spring meadow, the lake and a snow range mirrored in still water. No person in frame. Time: deep night, solar 02:45, sun elevation -23 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 35 mm lens, orbit -2 deg around the subject from the reference view, -0 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the lake surface shimmers faintly; no wind in the cell; the pen lies still. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Ночь, лампа у листа. Своё «Кто прочтёт…» он так и не кончил. Тишина переписчика ждёт читателя. Он сам проведёт черту на своей странице.", "git_commit_msg": "feat(story): add narrative branch scribe_lifts_eyes and video assets", "status": "ready_for_render"}
```

Хор: − стол почти пропал во тьме / + лампа 1900–2200 K у листа, ночь за окном / + окно с хребтом под звёздами держит место

### Вариант ID: same_comet/v01 — Предрассветный синий час — знак идёт строкой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «предрассветный синий час» (часы устройства игрока, без случайности): в журнал ложится строка «same_comet, предрассветный синий час», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `ascent` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `ascent` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: pre-dawn blue hour, solar 06:25, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 80 mm lens, orbit -13 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Синий свет на листе. Знак-комету переписчик скопировал буква в букву. Поля рядом пусты. Чья это рука, лист молчит. Пора подниматься к людям.

**4. Метаданные:**

```json
{"node_id": "v_same_comet_01", "video_prompt": "Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: pre-dawn blue hour, solar 06:25, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 80 mm lens, orbit -13 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Синий свет на листе. Знак-комету переписчик скопировал буква в букву. Поля рядом пусты. Чья это рука, лист молчит. Пора подниматься к людям.", "git_commit_msg": "feat(story): add narrative branch same_comet and video assets", "status": "ready_for_render"}
```

Хор: − край листа и синий фон видны: лист как будто в воздухе / + холодный свет делает чернила чётче / + комета без лучей-звезды, поля у неё пусты

### Вариант ID: same_comet/v02 — Заря — знак идёт строкой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «заря» (часы устройства игрока, без случайности): в журнал ложится строка «same_comet, заря», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `ascent` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `ascent` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: dawn, solar 06:52, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 100 mm lens, orbit +8 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Утренний свет. Везде на полях его споры со строкой, а у кометы пусто. Он скопировал знак и промолчал. Пора подниматься к людям.

**4. Метаданные:**

```json
{"node_id": "v_same_comet_02", "video_prompt": "Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: dawn, solar 06:52, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 100 mm lens, orbit +8 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Утренний свет. Везде на полях его споры со строкой, а у кометы пусто. Он скопировал знак и промолчал. Пора подниматься к людям.", "git_commit_msg": "feat(story): add narrative branch same_comet and video assets", "status": "ready_for_render"}
```

Хор: − длинный фокус 100 мм сжимает план, место теряется / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: same_comet/v03 — Восход — знак идёт строкой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «восход» (часы устройства игрока, без случайности): в журнал ложится строка «same_comet, восход», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `ascent` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `ascent` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: sunrise, solar 07:19, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 135 mm lens, orbit -5 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Луч на пергаменте. Комета переписана точно, без единой пометки. Знак переходит строкой из рук в руки. Пора подниматься к людям.

**4. Метаданные:**

```json
{"node_id": "v_same_comet_03", "video_prompt": "Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: sunrise, solar 07:19, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 135 mm lens, orbit -5 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Луч на пергаменте. Комета переписана точно, без единой пометки. Знак переходит строкой из рук в руки. Пора подниматься к людям.", "git_commit_msg": "feat(story): add narrative branch same_comet and video assets", "status": "ready_for_render"}
```

Хор: − длинный фокус 135 мм сжимает план, место теряется / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: same_comet/v04 — Утро — знак идёт строкой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «утро» (часы устройства игрока, без случайности): в журнал ложится строка «same_comet, утро», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `ascent` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Ловкость». Все 12 вариантов сходятся в `ascent` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: morning, solar 08:52, sun elevation +16 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 90 mm lens, orbit +16 deg around the subject from the reference view, +1 deg tilt, roll -3 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Утро в скриптории. Переписчик спорил с каждой строкой, но не с кометой. Чья она, лист не говорит. Пора подниматься к людям.

**4. Метаданные:**

```json
{"node_id": "v_same_comet_04", "video_prompt": "Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: morning, solar 08:52, sun elevation +16 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 90 mm lens, orbit +16 deg around the subject from the reference view, +1 deg tilt, roll -3 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Утро в скриптории. Переписчик спорил с каждой строкой, но не с кометой. Чья она, лист не говорит. Пора подниматься к людям.", "git_commit_msg": "feat(story): add narrative branch same_comet and video assets", "status": "ready_for_render"}
```

Хор: − фон за краем листа синий / + утренний ровный свет: каждая пометка на полях читается / + комета точно по центру, рядом пусто

### Вариант ID: same_comet/v05 — Позднее утро — знак идёт строкой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «позднее утро» (часы устройства игрока, без случайности): в журнал ложится строка «same_comet, позднее утро», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `ascent` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `ascent` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: late morning, solar 10:30, sun elevation +26 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 75 mm lens, orbit -18 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Ровный свет на полях. Пометки густы, у кометы ни одной. Молчание переписчика честнее догадки. Пора подниматься к людям.

**4. Метаданные:**

```json
{"node_id": "v_same_comet_05", "video_prompt": "Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: late morning, solar 10:30, sun elevation +26 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 75 mm lens, orbit -18 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Ровный свет на полях. Пометки густы, у кометы ни одной. Молчание переписчика честнее догадки. Пора подниматься к людям.", "git_commit_msg": "feat(story): add narrative branch same_comet and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2150 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: same_comet/v06 — Полдень — знак идёт строкой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «полдень» (часы устройства игрока, без случайности): в журнал ложится строка «same_comet, полдень», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `ascent` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `ascent` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: solar noon, solar 12:00, sun elevation +30 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 100 mm lens, orbit +0 deg around the subject from the reference view, +5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Полдень. Знак-комета скопирован буква в букву. Связь эпох — рукопись: знак идёт строкой, из рук в руки. Пора подниматься к людям.

**4. Метаданные:**

```json
{"node_id": "v_same_comet_06", "video_prompt": "Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: solar noon, solar 12:00, sun elevation +30 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 100 mm lens, orbit +0 deg around the subject from the reference view, +5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Полдень. Знак-комета скопирован буква в букву. Связь эпох — рукопись: знак идёт строкой, из рук в руки. Пора подниматься к людям.", "git_commit_msg": "feat(story): add narrative branch same_comet and video assets", "status": "ready_for_render"}
```

Хор: − длинный фокус 100 мм сжимает план, место теряется / + свет класса часа честный: огонь 2200 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: same_comet/v07 — После полудня — знак идёт строкой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «после полудня» (часы устройства игрока, без случайности): в журнал ложится строка «same_comet, после полудня», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `ascent` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `ascent` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: afternoon, solar 14:30, sun elevation +20 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 115 mm lens, orbit +20 deg around the subject from the reference view, -1 deg tilt, roll 3 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** День клонится. На полях спор, у кометы тишина. Он переписал знак и не стал гадать, чья рука. Пора подниматься к людям.

**4. Метаданные:**

```json
{"node_id": "v_same_comet_07", "video_prompt": "Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: afternoon, solar 14:30, sun elevation +20 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 115 mm lens, orbit +20 deg around the subject from the reference view, -1 deg tilt, roll 3 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "День клонится. На полях спор, у кометы тишина. Он переписал знак и не стал гадать, чья рука. Пора подниматься к людям.", "git_commit_msg": "feat(story): add narrative branch same_comet and video assets", "status": "ready_for_render"}
```

Хор: − длинный фокус 115 мм сжимает план, место теряется / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: same_comet/v08 — Золотой час — знак идёт строкой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «золотой час» (часы устройства игрока, без случайности): в журнал ложится строка «same_comet, золотой час», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `ascent` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `ascent` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: golden hour, solar 15:56, sun elevation +9 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 135 mm lens, orbit -10 deg around the subject from the reference view, -5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Золотой свет на пергаменте. Комета скопирована точно, поля рядом пусты. Лист молчит о руке. Пора подниматься к людям.

**4. Метаданные:**

```json
{"node_id": "v_same_comet_08", "video_prompt": "Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: golden hour, solar 15:56, sun elevation +9 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 135 mm lens, orbit -10 deg around the subject from the reference view, -5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Золотой свет на пергаменте. Комета скопирована точно, поля рядом пусты. Лист молчит о руке. Пора подниматься к людям.", "git_commit_msg": "feat(story): add narrative branch same_comet and video assets", "status": "ready_for_render"}
```

Хор: − длинный фокус 135 мм сжимает план, место теряется / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: same_comet/v09 — Закат — знак идёт строкой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «закат» (часы устройства игрока, без случайности): в журнал ложится строка «same_comet, закат», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `ascent` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `ascent` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: sunset, solar 16:50, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 85 mm lens, orbit +12 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Закатный свет скользит по листу. У кометы ни одной пометки. Переписчик не знал и честно не написал. Пора подниматься к людям.

**4. Метаданные:**

```json
{"node_id": "v_same_comet_09", "video_prompt": "Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: sunset, solar 16:50, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 85 mm lens, orbit +12 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Закатный свет скользит по листу. У кометы ни одной пометки. Переписчик не знал и честно не написал. Пора подниматься к людям.", "git_commit_msg": "feat(story): add narrative branch same_comet and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: same_comet/v10 — Сумерки — знак идёт строкой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «сумерки» (часы устройства игрока, без случайности): в журнал ложится строка «same_comet, сумерки», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `ascent` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `ascent` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: dusk, solar 17:23, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 100 mm lens, orbit -22 deg around the subject from the reference view, +2 deg tilt, roll -2 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сумерки. Знак-комету ещё видно. Чья это рука, лист молчит, и переписчик молчит вместе с ним. Пора подниматься к людям.

**4. Метаданные:**

```json
{"node_id": "v_same_comet_10", "video_prompt": "Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: dusk, solar 17:23, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 100 mm lens, orbit -22 deg around the subject from the reference view, +2 deg tilt, roll -2 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сумерки. Знак-комету ещё видно. Чья это рука, лист молчит, и переписчик молчит вместе с ним. Пора подниматься к людям.", "git_commit_msg": "feat(story): add narrative branch same_comet and video assets", "status": "ready_for_render"}
```

Хор: − длинный фокус 100 мм сжимает план, место теряется / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: same_comet/v11 — Ночь с луной — знак идёт строкой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «ночь с луной» (часы устройства игрока, без случайности): в журнал ложится строка «same_comet, ночь с луной», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `ascent` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `ascent` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: night with moon, solar 22:30, sun elevation -59 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 90 mm lens, orbit +5 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Луна и свеча. Знак-комета скопирован буква в букву. На полях, где он спорил с каждой строкой, тут пусто. Пора подниматься к людям.

**4. Метаданные:**

```json
{"node_id": "v_same_comet_11", "video_prompt": "Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: night with moon, solar 22:30, sun elevation -59 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 90 mm lens, orbit +5 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Луна и свеча. Знак-комета скопирован буква в букву. На полях, где он спорил с каждой строкой, тут пусто. Пора подниматься к людям.", "git_commit_msg": "feat(story): add narrative branch same_comet and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: same_comet/v12 — Глухая ночь, только огонь — знак идёт строкой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «глухая ночь, только огонь» (часы устройства игрока, без случайности): в журнал ложится строка «same_comet, глухая ночь, только огонь», а Клауд запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `ascent` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `ascent` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: deep night, solar 02:45, sun elevation -47 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 125 mm lens, orbit -2 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Ночь, огонь свечи. Комета переходит строкой из рук в руки. У знака пусто: переписчик не стал гадать. Пора подниматься к людям.

**4. Метаданные:**

```json
{"node_id": "v_same_comet_12", "video_prompt": "Macro of a parchment page: dense brown script with margin notes everywhere except beside a small inked comet sign (a round head ringed by eight short ticks and three thin strands of tail). Never a star of rays. No hand in frame. Time: deep night, solar 02:45, sun elevation -47 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 125 mm lens, orbit -2 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the light moves imperceptibly across the parchment fibres as the push-in advances; nothing else moves. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Ночь, огонь свечи. Комета переходит строкой из рук в руки. У знака пусто: переписчик не стал гадать. Пора подниматься к людям.", "git_commit_msg": "feat(story): add narrative branch same_comet and video assets", "status": "ready_for_render"}
```

Хор: − строки в тени теряют форму / + свеча даёт фактуру пергамента / + комета читается даже в глухую ночь

### Вариант ID: error_of_a_finger/v01 — Предрассветный синий час — ошибка стала картой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «предрассветный синий час» (часы устройства игрока, без случайности): в журнал ложится строка «error_of_a_finger, предрассветный синий час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `room_drains` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `room_drains` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: pre-dawn blue hour, solar 05:59, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 24 mm lens, orbit -13 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Синий час над озером. Рыцарь ловит астролябией последнюю звезду. Качка сбила её на палец, и лодка пошла к братьям. / Комната уходит под воду; он запомнит этот берег.

**4. Метаданные:**

```json
{"node_id": "v_error_of_a_finger_01", "video_prompt": "Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: pre-dawn blue hour, solar 05:59, sun elevation -8 deg. Lighting: no direct sun; sky 10000-12000 K blue ambient; the only warm source is human fire; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 24 mm lens, orbit -13 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Синий час над озером. Рыцарь ловит астролябией последнюю звезду. Качка сбила её на палец, и лодка пошла к братьям. Комната уходит под воду; он запомнит этот берег.", "git_commit_msg": "feat(story): add narrative branch error_of_a_finger and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: error_of_a_finger/v02 — Заря — ошибка стала картой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «заря» (часы устройства игрока, без случайности): в журнал ложится строка «error_of_a_finger, заря», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `room_drains` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `room_drains` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: dawn, solar 06:26, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit +8 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Заря на воде. Астролябия качается на ремне. Ошибка в палец уже легла в путь: берег будет не тот, а братья. / Комната уходит под воду; он запомнит этот берег.

**4. Метаданные:**

```json
{"node_id": "v_error_of_a_finger_02", "video_prompt": "Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: dawn, solar 06:26, sun elevation -3 deg. Lighting: sun just below the horizon; pink-violet sky glow, soft shadowless light; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit +8 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Заря на воде. Астролябия качается на ремне. Ошибка в палец уже легла в путь: берег будет не тот, а братья. Комната уходит под воду; он запомнит этот берег.", "git_commit_msg": "feat(story): add narrative branch error_of_a_finger and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: error_of_a_finger/v03 — Восход — ошибка стала картой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «восход» (часы устройства игрока, без случайности): в журнал ложится строка «error_of_a_finger, восход», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `room_drains` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `room_drains` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: sunrise, solar 06:53, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.5 mm lens, orbit -5 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце из-за гор. Рыцарь меряет его высоту астролябией, а волна сбивает визир. Ошибка станет картой. / Комната уходит под воду; он запомнит этот берег.

**4. Метаданные:**

```json
{"node_id": "v_error_of_a_finger_03", "video_prompt": "Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: sunrise, solar 06:53, sun elevation +2 deg. Lighting: sun 2 deg above the horizon at about 2500 K, long raking shadows; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 40.5 mm lens, orbit -5 deg around the subject from the reference view, -4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце из-за гор. Рыцарь меряет его высоту астролябией, а волна сбивает визир. Ошибка станет картой. Комната уходит под воду; он запомнит этот берег.", "git_commit_msg": "feat(story): add narrative branch error_of_a_finger and video assets", "status": "ready_for_render"}
```

Хор: − первый прогон: низкая камера легла на астролябию, в кадре только размытая вода (перерисовано: астролябия — часть вещи, а не препятствие) / + розовый восход над хребтом / + латунь крупно, шкала читается

### Вариант ID: error_of_a_finger/v04 — Утро — ошибка стала картой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «утро» (часы устройства игрока, без случайности): в журнал ложится строка «error_of_a_finger, утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `room_drains` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Ловкость». Все 12 вариантов сходятся в `room_drains` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: morning, solar 08:26, sun elevation +17 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 27 mm lens, orbit +16 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Утро в лодке. Качка сбила астролябию на ширину пальца. Рыцарь пристанет не к тому берегу, а к братьям. / Комната уходит под воду; он запомнит этот берег.

**4. Метаданные:**

```json
{"node_id": "v_error_of_a_finger_04", "video_prompt": "Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: morning, solar 08:26, sun elevation +17 deg. Lighting: sun 15-20 deg at about 4100 K, modelled shadows; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 27 mm lens, orbit +16 deg around the subject from the reference view, +1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Утро в лодке. Качка сбила астролябию на ширину пальца. Рыцарь пристанет не к тому берегу, а к братьям. Комната уходит под воду; он запомнит этот берег.", "git_commit_msg": "feat(story): add narrative branch error_of_a_finger and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2050 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: error_of_a_finger/v05 — Позднее утро — ошибка стала картой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «позднее утро» (часы устройства игрока, без случайности): в журнал ложится строка «error_of_a_finger, позднее утро», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `room_drains` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `room_drains` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: late morning, solar 10:30, sun elevation +32 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 22.5 mm lens, orbit -18 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Солнце высоко, волна мелкая. Рыцарь сверяет путь по латуни. Промах в палец ляжет следом в мир. / Комната уходит под воду; он запомнит этот берег.

**4. Метаданные:**

```json
{"node_id": "v_error_of_a_finger_05", "video_prompt": "Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: late morning, solar 10:30, sun elevation +32 deg. Lighting: high sun about 5000 K, even working light; human fire 2150 K (inside the 1900-2200 K band); never 1800 K. Camera: 22.5 mm lens, orbit -18 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Солнце высоко, волна мелкая. Рыцарь сверяет путь по латуни. Промах в палец ляжет следом в мир. Комната уходит под воду; он запомнит этот берег.", "git_commit_msg": "feat(story): add narrative branch error_of_a_finger and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2150 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: error_of_a_finger/v06 — Полдень — ошибка стала картой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «полдень» (часы устройства игрока, без случайности): в журнал ложится строка «error_of_a_finger, полдень», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `room_drains` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `room_drains` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: solar noon, solar 12:00, sun elevation +36 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit +0 deg around the subject from the reference view, +5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Полдень, астролябия ловит солнце. Палец ошибки, и путь ушёл к братьям. Прошлое меняет настоящее следами. / Комната уходит под воду; он запомнит этот берег.

**4. Метаданные:**

```json
{"node_id": "v_error_of_a_finger_06", "video_prompt": "Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: solar noon, solar 12:00, sun elevation +36 deg. Lighting: sun at its highest for the date, about 5600 K, short hard shadows; human fire 2200 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit +0 deg around the subject from the reference view, +5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Полдень, астролябия ловит солнце. Палец ошибки, и путь ушёл к братьям. Прошлое меняет настоящее следами. Комната уходит под воду; он запомнит этот берег.", "git_commit_msg": "feat(story): add narrative branch error_of_a_finger and video assets", "status": "ready_for_render"}
```

Хор: − полуденная латунь пересвечена / + астролябией мерят солнце днём — кадр подтверждает строку / + лодка и уключина читаются целиком

### Вариант ID: error_of_a_finger/v07 — После полудня — ошибка стала картой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «после полудня» (часы устройства игрока, без случайности): в журнал ложится строка «error_of_a_finger, после полудня», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `room_drains` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `room_drains` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: afternoon, solar 14:30, sun elevation +26 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 34.5 mm lens, orbit +20 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** День над водой. Рыцарь правит по ошибке, о которой не знает. Его промах потом прочтут как карту. / Комната уходит под воду; он запомнит этот берег.

**4. Метаданные:**

```json
{"node_id": "v_error_of_a_finger_07", "video_prompt": "Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: afternoon, solar 14:30, sun elevation +26 deg. Lighting: sun from the other side at about 5200 K; human fire 2100 K (inside the 1900-2200 K band); never 1800 K. Camera: 34.5 mm lens, orbit +20 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "День над водой. Рыцарь правит по ошибке, о которой не знает. Его промах потом прочтут как карту. Комната уходит под воду; он запомнит этот берег.", "git_commit_msg": "feat(story): add narrative branch error_of_a_finger and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2100 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: error_of_a_finger/v08 — Золотой час — ошибка стала картой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «золотой час» (часы устройства игрока, без случайности): в журнал ложится строка «error_of_a_finger, золотой час», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `room_drains` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Мудрость». Все 12 вариантов сходятся в `room_drains` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: golden hour, solar 16:22, sun elevation +10 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 45 mm lens, orbit -10 deg around the subject from the reference view, -5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Низкое солнце на латуни. Качка сбила визир на палец. Свободный человек ошибся, и ошибка стала путём. / Комната уходит под воду; он запомнит этот берег.

**4. Метаданные:**

```json
{"node_id": "v_error_of_a_finger_08", "video_prompt": "Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: golden hour, solar 16:22, sun elevation +10 deg. Lighting: sun 8-10 deg at about 3100 K, warm grazing light across textures; human fire 1950 K (inside the 1900-2200 K band); never 1800 K. Camera: 45 mm lens, orbit -10 deg around the subject from the reference view, -5 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Низкое солнце на латуни. Качка сбила визир на палец. Свободный человек ошибся, и ошибка стала путём. Комната уходит под воду; он запомнит этот берег.", "git_commit_msg": "feat(story): add narrative branch error_of_a_finger and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1950 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: error_of_a_finger/v09 — Закат — ошибка стала картой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «закат» (часы устройства игрока, без случайности): в журнал ложится строка «error_of_a_finger, закат», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `room_drains` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `room_drains` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: sunset, solar 17:16, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 25.5 mm lens, orbit +12 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Закат за кормой. Рыцарь правит к берегу, сбитый на палец. Пристанет он к братьям. Комната уходит под воду; он запомнит этот берег.

**4. Метаданные:**

```json
{"node_id": "v_error_of_a_finger_09", "video_prompt": "Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: sunset, solar 17:16, sun elevation +0 deg. Lighting: sun on the horizon at about 2400 K, warm backlight; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 25.5 mm lens, orbit +12 deg around the subject from the reference view, -2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Закат за кормой. Рыцарь правит к берегу, сбитый на палец. Пристанет он к братьям. Комната уходит под воду; он запомнит этот берег.", "git_commit_msg": "feat(story): add narrative branch error_of_a_finger and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 1900 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: error_of_a_finger/v10 — Сумерки — ошибка стала картой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «сумерки» (часы устройства игрока, без случайности): в журнал ложится строка «error_of_a_finger, сумерки», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `room_drains` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Слово». Все 12 вариантов сходятся в `room_drains` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: dusk, solar 17:49, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit -22 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Сумерки, огня на берегу ещё не видно. Астролябия качается на ремне. Ошибка в палец уже ведёт лодку. / Комната уходит под воду; он запомнит этот берег.

**4. Метаданные:**

```json
{"node_id": "v_error_of_a_finger_10", "video_prompt": "Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: dusk, solar 17:49, sun elevation -6 deg. Lighting: sun gone 5 deg below; blue air, first human fire; human fire 2000 K (inside the 1900-2200 K band); never 1800 K. Camera: 30 mm lens, orbit -22 deg around the subject from the reference view, +2 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Сумерки, огня на берегу ещё не видно. Астролябия качается на ремне. Ошибка в палец уже ведёт лодку. Комната уходит под воду; он запомнит этот берег.", "git_commit_msg": "feat(story): add narrative branch error_of_a_finger and video assets", "status": "ready_for_render"}
```

Хор: − кадр ровный, но час читается только по свету, не по событию / + свет класса часа честный: огонь 2000 K, не 1800 K / + вещь, которую называет рассказчик, в центре внимания

### Вариант ID: error_of_a_finger/v11 — Ночь с луной — ошибка стала картой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «ночь с луной» (часы устройства игрока, без случайности): в журнал ложится строка «error_of_a_finger, ночь с луной», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `room_drains` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Книжность». Все 12 вариантов сходятся в `room_drains` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: night with moon, solar 22:30, sun elevation -53 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 27 mm lens, orbit +5 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Ночь в лодке, луна. Качка сбила астролябию на ширину пальца, и рыцарь пристал не к тому берегу, а к братьям. / Комната уходит под воду; он запомнит этот берег.

**4. Метаданные:**

```json
{"node_id": "v_error_of_a_finger_11", "video_prompt": "Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: night with moon, solar 22:30, sun elevation -53 deg. Lighting: moon 30 deg high rendered at 7500 K by film convention; warm human fire as a small pool; human fire 2050 K (inside the 1900-2200 K band); never 1800 K. Camera: 27 mm lens, orbit +5 deg around the subject from the reference view, +4 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Ночь в лодке, луна. Качка сбила астролябию на ширину пальца, и рыцарь пристал не к тому берегу, а к братьям. Комната уходит под воду; он запомнит этот берег.", "git_commit_msg": "feat(story): add narrative branch error_of_a_finger and video assets", "status": "ready_for_render"}
```

Хор: − ремень астролябии тонок и теряется / + ночь с луной: окно братьев тёплой точкой у хребта / + латунь в огне лампы, ошибка «на палец» видна в наклоне

### Вариант ID: error_of_a_finger/v12 — Глухая ночь, только огонь — ошибка стала картой

**1. Логика ветки (Игровой Импакт):** Инсайт пришёл в час «глухая ночь, только огонь» (часы устройства игрока, без случайности): в журнал ложится строка «error_of_a_finger, глухая ночь, только огонь», а писец обители запоминает этот час. Просмотр и пропуск ничего не дают и не отнимают; в сходящемся бите `room_drains` один ответ в диалоге, который вспоминает этот час, может дать +1 к атрибуту «Стойкость». Все 12 вариантов сходятся в `room_drains` (узкое горло сюжета), денег и инвентаря цены нет.

**2. Режиссура видео (Промпт для видео-нейросети):** Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: deep night, solar 02:45, sun elevation -42 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 37.5 mm lens, orbit -2 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.

**3. Закадровый текст:** Глухая ночь, звёзды и огонёк у братьев. Рыцарь сбился на палец и пристал к ним. Ошибка стала картой. / Комната уходит под воду; он запомнит этот берег.

**4. Метаданные:**

```json
{"node_id": "v_error_of_a_finger_12", "video_prompt": "Inside a tarred wooden boat on Issyk-Kul: a brass astrolabe hanging by its ring on a leather thong from the thole, a coil of hemp rope, a small brass oil lamp, black water beyond the gunwale, a dark mountain ridge with one small warm window light at its foot. No person in frame. Time: deep night, solar 02:45, sun elevation -42 deg. Lighting: no sun, no moon; stars only, and human fire or an instrument screen; human fire 1900 K (inside the 1900-2200 K band); never 1800 K. Camera: 37.5 mm lens, orbit -2 deg around the subject from the reference view, -1 deg tilt, roll 0 deg, locked off with a 6% slow push-in. In frame, physics only: the astrolabe swings gently, about 9 deg, with the swell; the lamp flame flickers; the water surface moves slowly. Exclude: any human face, any saint's face, halo, blood, text overlays, carved cross-stones; nothing holy used as a lure.", "voiceover_ru": "Глухая ночь, звёзды и огонёк у братьев. Рыцарь сбился на палец и пристал к ним. Ошибка стала картой. Комната уходит под воду; он запомнит этот берег.", "git_commit_msg": "feat(story): add narrative branch error_of_a_finger and video assets", "status": "ready_for_render"}
```

Хор: − окно братьев в дымке мало / + глухая ночь: лампа красит латунь, шкала астролябии читается / + звёзды и тёмный хребет держат «ошибка стала картой»
