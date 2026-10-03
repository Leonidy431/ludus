# «Ржевский и Ложа Трёх Циркулей» — вторая серия Ludus (единая папка)

Оператор, 2026-10-03: «серию назовем „Ржевский и Ложа Трёх Циркулей“»;
«в main лудуса объедини все файлы». Здесь собраны обе сессии, которые
работали над серией; ниже — какие решения действуют, когда версии
расходятся.

## Действующие решения (сведение двух версий)

| Вопрос | Решение | Откуда |
|---|---|---|
| Название | «Ржевский и Ложа Трёх Циркулей» (прежнее рабочее — «Поручик Ржевский против Ордена») | слово оператора |
| Место в сериале | вторая серия Ludus, XIX век, юмор; читает серию 1 (дневник рыцаря попадает к гусару) | слово оператора «вторую серию делаем юморной» |
| Основа HLD | [`HLD_RZHEVSKY_VS_ORDER`](../docs/HLD_RZHEVSKY_VS_ORDER_2026-10-03.md) (v0.2) + граница и фазы R1–R5 из [`HLD_RZHEVSKY_SERIES2`](../docs/HLD_RZHEVSKY_SERIES2_2026-10-03.md) | обе сессии |
| Диалоги | [`texts/ep2_act1_dialogue.json`](texts/ep2_act1_dialogue.json), [`texts/ep3_act1_dialogue.json`](texts/ep3_act1_dialogue.json), план — [`texts/OUTLINE_EP2_EP3.md`](texts/OUTLINE_EP2_EP3.md) | сессия main |
| Сцены сверху | трактир «Три Самовара» (лото без ставок, пирожковая рулетка, безалкогольное травяное пиво), англичане сэра Реджинальда, юмор «понятный всем странам» — [`EPISODE2_RZHEVSKY_LODGE`](../docs/story/rzhevsky/EPISODE2_RZHEVSKY_LODGE_2026-10-03.md) | эта сессия |
| Стиль | [`STYLE_COMEDY_STUDY`](../docs/story/rzhevsky/STYLE_COMEDY_STUDY_2026-10-03.md) + стайл-гайд в [`RZHEVSKY_RESEARCH`](../docs/RZHEVSKY_RESEARCH_2026-10-03.md) | обе |
| 2D→3D сейчас (без видеокарты, детерминированно) | герои — послойный вырез; предметы — выдавливание силуэта; декорации — рельеф по глубине (Depth Anything V2 Small, Apache-2.0) — `scripts/decisions/convert_2d3d_choice.py` | эта сессия |
| 2D→3D потом (машина с GPU) | герои — TRELLIS (MIT), предметы — TripoSR (MIT); результат фиксируется и проверяется, как всё остальное | сессия main |
| Голос | Piper, запасной RHVoice (лицензии моделей проверить до релиза); голос Шуры Каретного — только с письменного согласия исполнителя | обе |
| Чужое | тексты, графика и герои «Петьки», «ГЭГ», «Братьев Пилотов» в серию не идут; движки — только изучение (GPLv3, переписью) | обе |
| Кадры видео | `scripts/video/slice_frames.py` — только для локальных файлов, кадры в `build/reference/` | эта сессия |

## Все файлы серии

- HLD: [`docs/HLD_RZHEVSKY_VS_ORDER_2026-10-03.md`](../docs/HLD_RZHEVSKY_VS_ORDER_2026-10-03.md), [`docs/HLD_RZHEVSKY_SERIES2_2026-10-03.md`](../docs/HLD_RZHEVSKY_SERIES2_2026-10-03.md)
- исследование: [`docs/RZHEVSKY_RESEARCH_2026-10-03.md`](../docs/RZHEVSKY_RESEARCH_2026-10-03.md); репозитории и диалог: [`docs/RZHEVSKY_REPOS_AND_DIALOGUE_2026-10-03.md`](../docs/RZHEVSKY_REPOS_AND_DIALOGUE_2026-10-03.md)
- сценарий и стиль: [`docs/story/rzhevsky/`](../docs/story/rzhevsky/)
- тексты: [`texts/`](texts/), хор редакторов — [`texts/EDITORS_CHORUS_LOG.md`](texts/EDITORS_CHORUS_LOG.md)
- код: `scripts/decisions/convert_2d3d_choice.py`, `scripts/video/slice_frames.py`

**Конституция:** ФОРМА (одна папка, одно название, одни решения) →
ДЕЙСТВИЕ (обе сессии работают по одной таблице) → ЦЕЛЬ (серия не
двоится, и каждый, кто её продолжит, видит, что действует).
